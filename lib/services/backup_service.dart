import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:file_picker/file_picker.dart';
import 'storage_service.dart';

/// BackupService — handles JSON backup file creation, restore,
/// auto local backup, and backup reminder tracking.
///
/// Backup format: versioned JSON file with schema version, timestamp,
/// and all app data (entries, customers, bills, qrHistory, settings).
class BackupService {
  static const String _backupDirName = 'note_counter_backups';
  static const int _maxLocalBackups = 7;

  /// Create a JSON backup file and share it (WhatsApp, Email, Drive, etc.)
  /// Returns the file path, or null on failure.
  static Future<String?> createAndShareBackup(StorageService storage) async {
    try {
      final data = storage.exportAllData();
      final jsonStr = const JsonEncoder.withIndent('  ').convert(data);

      final now = DateTime.now();
      final dateStr = '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}_${now.hour.toString().padLeft(2, '0')}${now.minute.toString().padLeft(2, '0')}';
      final filename = 'note-counter-backup-$dateStr.json';

      // Get temp directory
      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/$filename');
      await file.writeAsString(jsonStr);

      // Record last backup time
      await recordBackupTime(storage);

      // Share the file
      await Share.shareXFiles(
        [XFile(file.path)],
        subject: 'Note Counter Pro Backup - $dateStr',
      );

      return file.path;
    } catch (e) {
      debugPrint('Backup creation failed: $e');
      return null;
    }
  }

  /// Pick a JSON backup file and restore data from it.
  /// Returns true on success, false on failure.
  /// Caller must show confirmation dialog before calling this.
  static Future<bool> restoreFromFile(StorageService storage) async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['json'],
        allowMultiple: false,
      );

      if (result == null || result.files.isEmpty) {
        return false;
      }

      final filePath = result.files.first.path;
      if (filePath == null) {
        return false;
      }

      final file = File(filePath);
      final jsonStr = await file.readAsString();
      final backup = jsonDecode(jsonStr) as Map<String, dynamic>;

      // Validate it's a backup file (has either 'data' key or 'entries' key)
      if (!backup.containsKey('data') && !backup.containsKey('entries')) {
        debugPrint('Invalid backup file format');
        return false;
      }

      // Create a safety backup before restore
      await createLocalBackup(storage);

      // Import data
      final success = await storage.importData(backup);
      if (success) {
        storage.notifyListeners();
      }
      return success;
    } catch (e) {
      debugPrint('Restore failed: $e');
      return false;
    }
  }

  /// Create a local backup file in app's documents directory.
  /// Used for auto-backup and as safety backup before restore.
  static Future<String?> createLocalBackup(StorageService storage) async {
    try {
      final data = storage.exportAllData();
      final jsonStr = const JsonEncoder.withIndent('  ').convert(data);

      final now = DateTime.now();
      final timestamp = now.millisecondsSinceEpoch;
      final dateStr = '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';

      final dir = await getApplicationDocumentsDirectory();
      final backupDir = Directory('${dir.path}/$_backupDirName');
      if (!await backupDir.exists()) {
        await backupDir.create(recursive: true);
      }

      final filename = 'auto_backup_$timestamp.json';
      final file = File('${backupDir.path}/$filename');
      await file.writeAsString(jsonStr);

      // Clean up old backups (keep only last _maxLocalBackups)
      await _cleanupOldBackups(backupDir);

      // Record last backup time
      await recordBackupTime(storage);

      debugPrint('Local backup created: $filename');
      return file.path;
    } catch (e) {
      debugPrint('Local backup failed: $e');
      return null;
    }
  }

  /// Clean up old local backups, keeping only the most recent _maxLocalBackups.
  static Future<void> _cleanupOldBackups(Directory backupDir) async {
    try {
      final files = backupDir.listSync().whereType<File>().toList();
      if (files.length <= _maxLocalBackups) return;

      // Sort by modification time (newest first)
      files.sort((a, b) {
        final aStat = a.statSync();
        final bStat = b.statSync();
        return bStat.modified.compareTo(aStat.modified);
      });

      // Delete all but the newest _maxLocalBackups
      for (int i = _maxLocalBackups; i < files.length; i++) {
        await files[i].delete();
        debugPrint('Deleted old backup: ${files[i].path}');
      }
    } catch (e) {
      debugPrint('Cleanup failed: $e');
    }
  }

  /// Record the last backup timestamp in SharedPreferences.
  static Future<void> recordBackupTime(StorageService storage) async {
    try {
      final now = DateTime.now().toIso8601String();
      // Access prefs through storage service's internal prefs
      // We'll use a method on storage service
      await storage.setLastBackupTime(now);
    } catch (e) {
      debugPrint('Record backup time failed: $e');
    }
  }

  /// Get the last backup time as a formatted string.
  /// Returns null if no backup has been made.
  static String? getLastBackupString(StorageService storage) {
    final last = storage.lastBackupTime;
    if (last == null) return null;
    try {
      final dt = DateTime.parse(last);
      final now = DateTime.now();
      final diff = now.difference(dt);

      if (diff.inMinutes < 1) return 'Just now';
      if (diff.inMinutes < 60) return '${diff.inMinutes} minutes ago';
      if (diff.inHours < 24) return '${diff.inHours} hours ago';
      if (diff.inDays < 7) return '${diff.inDays} days ago';
      return '${dt.day}/${dt.month}/${dt.year}';
    } catch (e) {
      return null;
    }
  }

  /// Check if user should be reminded to backup (7+ days since last backup).
  static bool shouldShowBackupReminder(StorageService storage) {
    final last = storage.lastBackupTime;
    if (last == null) return true; // Never backed up
    try {
      final dt = DateTime.parse(last);
      final diff = DateTime.now().difference(dt);
      return diff.inDays >= 7;
    } catch (e) {
      return true;
    }
  }

  /// Get count of local auto-backups available.
  static Future<int> getLocalBackupCount() async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      final backupDir = Directory('${dir.path}/$_backupDirName');
      if (!await backupDir.exists()) return 0;
      return backupDir.listSync().whereType<File>().length;
    } catch (e) {
      return 0;
    }
  }

  /// List available local auto-backups (path + timestamp).
  static Future<List<Map<String, dynamic>>> listLocalBackups() async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      final backupDir = Directory('${dir.path}/$_backupDirName');
      if (!await backupDir.exists()) return [];

      final files = backupDir.listSync().whereType<File>().toList();
      files.sort((a, b) {
        final aStat = a.statSync();
        final bStat = b.statSync();
        return bStat.modified.compareTo(aStat.modified);
      });

      return files.map((f) {
        final stat = f.statSync();
        return {
          'path': f.path,
          'name': f.uri.pathSegments.last,
          'modified': stat.modified,
          'size': stat.size,
        };
      }).toList();
    } catch (e) {
      return [];
    }
  }

  /// Restore from a specific local backup file.
  static Future<bool> restoreFromLocalBackup(
      StorageService storage, String filePath) async {
    try {
      final file = File(filePath);
      if (!await file.exists()) return false;

      final jsonStr = await file.readAsString();
      final backup = jsonDecode(jsonStr) as Map<String, dynamic>;

      final success = await storage.importData(backup);
      if (success) {
        storage.notifyListeners();
      }
      return success;
    } catch (e) {
      debugPrint('Local restore failed: $e');
      return false;
    }
  }
}
