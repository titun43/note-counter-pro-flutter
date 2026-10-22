// =============================================================================
// Note Counter Pro - Cloud Backup Service (Google Drive)
// =============================================================================
// Premium feature: Backup app data to user's Google Drive (appDataScope).
// Data stored in hidden app-specific folder — user can't see it directly,
// only the app can access. No manual file management needed.
//
// Flow:
//   1. signIn() — Google Sign-In with Drive.appDataScope
//   2. backup() — upload JSON backup file to Drive
//   3. restore() — download latest backup from Drive
//   4. signOut() — disconnect Google account
// =============================================================================

import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:googleapis/drive/v3.dart' as drive;
import 'package:extension_google_sign_in_as_googleapis_auth/extension_google_sign_in_as_googleapis_auth.dart';
import 'package:http/http.dart' as http;
import 'storage_service.dart';
import 'backup_service.dart';
import 'premium_service.dart';

class CloudBackupService {
  CloudBackupService._();
  static final CloudBackupService _instance = CloudBackupService._();
  factory CloudBackupService() => _instance;

  static const List<String> _scopes = [
    'https://www.googleapis.com/auth/drive.appdata',
  ];

  final GoogleSignIn _googleSignIn = GoogleSignIn(
    scopes: _scopes,
    // ServerClientId intentionally omitted — we only need client-side access
    // for Drive appData. The OAuth client ID is configured in the native
    // Android config (android/app/src/main/AndroidManifest.xml or
    // google-services.json).
  );

  GoogleSignInAccount? _currentUser;
  bool _isBackingUp = false;
  bool _isRestoring = false;

  GoogleSignInAccount? get currentUser => _currentUser;
  bool get isSignedIn => _currentUser != null;
  bool get isBackingUp => _isBackingUp;
  bool get isRestoring => _isRestoring;

  /// Initialize — listen to sign-in state changes
  void init() {
    _googleSignIn.onCurrentUserChanged.listen((account) {
      _currentUser = account;
    });
    // Silent sign-in attempt (if user previously signed in)
    _googleSignIn.signInSilently().catchError((_) => null);
  }

  /// Sign in to Google with Drive.appData scope
  Future<bool> signIn() async {
    // Premium-only feature
    if (!PremiumService().isPremium) {
      debugPrint('CloudBackupService: premium required');
      return false;
    }
    try {
      final account = await _googleSignIn.signIn();
      _currentUser = account;
      return account != null;
    } catch (e) {
      debugPrint('CloudBackupService: signIn failed: $e');
      return false;
    }
  }

  /// Sign out
  Future<void> signOut() async {
    try {
      await _googleSignIn.signOut();
      _currentUser = null;
    } catch (_) {}
  }

  /// Backup app data to Google Drive (appData folder)
  /// Returns true on success.
  Future<bool> backup(StorageService storage) async {
    if (!PremiumService().isPremium) return false;
    if (_currentUser == null) {
      final signedIn = await signIn();
      if (!signedIn) return false;
    }
    if (_isBackingUp) return false;
    _isBackingUp = true;

    try {
      final httpClient = await _currentUser!.authenticatedClient();
      if (httpClient == null) {
        debugPrint('CloudBackupService: failed to get authenticated client');
        return false;
      }
      final driveApi = drive.DriveApi(httpClient);

      // Generate JSON backup
      final backupJson = await BackupService.createBackupJson(storage);
      final bytes = Uint8List.fromList(utf8.encode(backupJson));
      final timestamp = DateTime.now().toIso8601String().replaceAll(':', '-');

      // Upload to Drive appData folder
      final fileToUpload = drive.File()
        ..name = 'note_counter_backup_$timestamp.json'
        ..parents = ['appDataFolder'];

      final media = drive.Media(
        Stream.fromIterable([bytes]),
        bytes.length,
      );

      await driveApi.files.create(
        fileToUpload,
        uploadMedia: media,
      );

      // Save last backup timestamp
      await storage.setLastCloudBackup(DateTime.now());
      debugPrint('CloudBackupService: backup uploaded successfully');
      return true;
    } catch (e) {
      debugPrint('CloudBackupService: backup failed: $e');
      return false;
    } finally {
      _isBackingUp = false;
    }
  }

  /// Restore latest backup from Google Drive
  /// Returns the backup JSON string, or null on failure.
  Future<String?> restore() async {
    if (!PremiumService().isPremium) return null;
    if (_currentUser == null) {
      final signedIn = await signIn();
      if (!signedIn) return null;
    }
    if (_isRestoring) return null;
    _isRestoring = true;

    try {
      final httpClient = await _currentUser!.authenticatedClient();
      if (httpClient == null) return null;
      final driveApi = drive.DriveApi(httpClient);

      // List backup files in appData folder, sorted by modifiedTime desc
      final fileList = await driveApi.files.list(
        spaces: 'appDataFolder',
        orderBy: 'modifiedTime desc',
        pageSize: 1,
        q: "name contains 'note_counter_backup_'",
      );

      if (fileList.files == null || fileList.files!.isEmpty) {
        debugPrint('CloudBackupService: no backups found');
        return null;
      }

      final latestFile = fileList.files!.first;
      debugPrint('CloudBackupService: restoring ${latestFile.name}');

      // Download file content
      final media = await driveApi.files.get(
        latestFile.id!,
        downloadOptions: drive.DownloadOptions.fullMedia,
      ) as drive.Media;

      final buffer = <int>[];
      await for (final chunk in media.stream) {
        buffer.addAll(chunk);
      }

      final json = utf8.decode(buffer);
      debugPrint('CloudBackupService: restore complete');
      return json;
    } catch (e) {
      debugPrint('CloudBackupService: restore failed: $e');
      return null;
    } finally {
      _isRestoring = false;
    }
  }

  /// Get list of all backups (for showing in UI)
  Future<List<Map<String, dynamic>>> listBackups() async {
    if (!PremiumService().isPremium || _currentUser == null) return [];
    try {
      final httpClient = await _currentUser!.authenticatedClient();
      if (httpClient == null) return [];
      final driveApi = drive.DriveApi(httpClient);

      final fileList = await driveApi.files.list(
        spaces: 'appDataFolder',
        orderBy: 'modifiedTime desc',
        pageSize: 10,
        q: "name contains 'note_counter_backup_'",
      );

      return (fileList.files ?? []).map((f) {
        return {
          'id': f.id,
          'name': f.name,
          'modifiedTime': f.modifiedTime?.toString(),
          'size': f.size,
        };
      }).toList();
    } catch (e) {
      debugPrint('CloudBackupService: listBackups failed: $e');
      return [];
    }
  }
}
