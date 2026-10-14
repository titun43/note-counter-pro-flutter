import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import '../services/storage_service.dart';
import '../services/backup_service.dart';
import '../services/tts_service.dart';
import '../utils/constants.dart';
import '../utils/app_localizations.dart';
import 'upi_qr_screen.dart';
import 'reports_screen.dart';
import 'bills_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});
  
  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  PackageInfo? _packageInfo;
  bool _voiceEnabled = true;

  @override
  void initState() {
    super.initState();
    _loadPackageInfo();
    _loadVoiceSetting();
  }

  Future<void> _loadVoiceSetting() async {
    final enabled = await TtsService().isVoiceEnabled();
    if (mounted) {
      setState(() {
        _voiceEnabled = enabled;
      });
    }
  }

  Future<void> _setVoiceEnabled(bool value) async {
    setState(() {
      _voiceEnabled = value;
    });
    await TtsService().setVoiceEnabled(value);
  }

  Future<void> _loadPackageInfo() async {
    final info = await PackageInfo.fromPlatform();
    setState(() {
      _packageInfo = info;
    });
  }
  
  Future<void> _exportCsv(String type) async {
    final storage = context.read<StorageService>();
    String csv = '';
    String filename = '';
    
    if (type == 'entries' || type == 'both') {
      csv = storage.exportEntriesAsCsv();
      filename = 'note-counter-entries-${DateTime.now().toIso8601String().substring(0, 10)}.csv';
      if (csv.isNotEmpty) {
        await _saveAndShareCsv(csv, filename);
      } else {
        _showMessage('No entries found');
      }
    }
    
    if (type == 'customers' || type == 'both') {
      csv = storage.exportCustomersAsCsv();
      filename = 'note-counter-customers-${DateTime.now().toIso8601String().substring(0, 10)}.csv';
      if (csv.isNotEmpty) {
        await Future.delayed(const Duration(milliseconds: 500));
        await _saveAndShareCsv(csv, filename);
      } else {
        _showMessage('No customers found');
      }
    }
  }
  
  Future<void> _saveAndShareCsv(String csv, String filename) async {
    final directory = await getApplicationDocumentsDirectory();
    final file = File('${directory.path}/$filename');
    await file.writeAsString('\ufeff$csv'); // BOM for Excel
    
    await Share.shareXFiles(
      [XFile(file.path)],
      subject: filename,
    );
  }
  
  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }
  
  Future<void> _rateApp() async {
    final uri = Uri.parse(AppConstants.playStoreUrl);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }
  
  Future<void> _shareApp() async {
    await Share.share(
      '💵 Note Counter Pro - Free Cash Counter App!\n\n'
      'Count any cash in seconds with multi-currency support, PDF reports, and more.\n\n'
      'Download now:\n${AppConstants.playStoreUrl}',
      subject: 'Note Counter Pro',
    );
  }

  // === Backup & Restore Methods ===

  /// Create a JSON backup and share it (WhatsApp, Email, Drive, etc.)
  Future<void> _backupData() async {
    final loc = context.loc;
    final storage = context.read<StorageService>();

    // Show loading
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(loc.t('backupData') + '...'),
        duration: const Duration(seconds: 1),
      ),
    );

    final result = await BackupService.createAndShareBackup(storage);

    if (result != null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(loc.t('backupSuccess')),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(loc.t('backupFailed')),
            backgroundColor: AppColors.danger,
          ),
        );
      }
    }
  }

  /// Restore data from a JSON backup file.
  Future<void> _restoreData() async {
    final loc = context.loc;

    // Show confirmation dialog
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.warning, color: AppColors.warning),
            const SizedBox(width: 8),
            Text(loc.t('restoreConfirmTitle')),
          ],
        ),
        content: Text(loc.t('restoreConfirmMsg')),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(loc.t('cancel')),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.warning),
            onPressed: () => Navigator.pop(context, true),
            child: Text(loc.t('restoreData')),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    final storage = context.read<StorageService>();

    // Show loading
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(loc.t('restoreData') + '...'),
          duration: const Duration(seconds: 1),
        ),
      );
    }

    final success = await BackupService.restoreFromFile(storage);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(success ? loc.t('restoreSuccess') : loc.t('restoreFailed')),
          backgroundColor: success ? AppColors.success : AppColors.danger,
        ),
      );
    }
  }

  /// Show list of local auto-backups and allow restore from any.
  Future<void> _showLocalBackups() async {
    final loc = context.loc;
    final backups = await BackupService.listLocalBackups();

    if (!mounted) return;

    if (backups.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(loc.t('noLocalBackups'))),
      );
      return;
    }

    showModalBottomSheet(
      context: context,
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  loc.t('localBackups'),
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const Divider(height: 1),
              Flexible(
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: backups.length,
                  itemBuilder: (context, index) {
                    final b = backups[index];
                    final modified = b['modified'] as DateTime;
                    final size = b['size'] as int;
                    final sizeStr = size > 1024
                        ? '${(size / 1024).toStringAsFixed(1)} KB'
                        : '$size B';

                    return ListTile(
                      leading: const Icon(Icons.history, color: AppColors.success),
                      title: Text(
                        '${modified.day}/${modified.month}/${modified.year} '
                        '${modified.hour}:${modified.minute.toString().padLeft(2, '0')}',
                      ),
                      subtitle: Text('$sizeStr • ${b['name']}'),
                      trailing: const Icon(Icons.restore, size: 20),
                      onTap: () async {
                        Navigator.pop(context);
                        await _restoreFromLocal(b['path'] as String);
                      },
                    );
                  },
                ),
              ),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
  }

  /// Restore from a specific local backup file path.
  Future<void> _restoreFromLocal(String filePath) async {
    final loc = context.loc;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.warning, color: AppColors.warning),
            const SizedBox(width: 8),
            Text(loc.t('restoreConfirmTitle')),
          ],
        ),
        content: Text(loc.t('restoreConfirmMsg')),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(loc.t('cancel')),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.warning),
            onPressed: () => Navigator.pop(context, true),
            child: Text(loc.t('restoreData')),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    final storage = context.read<StorageService>();
    final success = await BackupService.restoreFromLocalBackup(storage, filePath);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(success ? loc.t('restoreSuccess') : loc.t('restoreFailed')),
          backgroundColor: success ? AppColors.success : AppColors.danger,
        ),
      );
    }
  }
  
  Future<void> _sendFeedback() async {
    final uri = Uri(
      scheme: 'mailto',
      path: AppConstants.supportEmail,
      query: 'subject=Note Counter Pro Feedback&body=Hi, I have feedback about Note Counter Pro:',
    );
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }
  
  Future<void> _openPrivacyPolicy() async {
    final uri = Uri.parse(AppConstants.privacyPolicyUrl);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }
  
  Future<void> _showClearDataDialog() async {
    final loc = context.loc;
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear All Data?'),
        content: const Text(
          'This will permanently delete all entries, customers, and bills. This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(loc.t('cancel')),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(backgroundColor: AppColors.danger),
            child: const Text('Delete All'),
          ),
        ],
      ),
    );
    
    if (result == true) {
      await context.read<StorageService>().clearAllData();
      _showMessage('All data cleared');
    }
  }
  
  @override
  Widget build(BuildContext context) {
    final loc = context.loc;
    final theme = Theme.of(context);
    final storage = context.watch<StorageService>();
    
    return Scaffold(
      appBar: AppBar(title: Text(loc.t('settings'))),
      body: ListView(
        children: [
          // === APPEARANCE ===
          _sectionHeader(loc.t('appearance')),
          SwitchListTile(
            secondary: const Icon(Icons.dark_mode),
            title: Text(loc.t('darkMode')),
            subtitle: const Text('Toggle dark theme'),
            value: storage.isDarkMode,
            onChanged: (value) => storage.setDarkMode(value),
          ),
          ListTile(
            leading: const Icon(Icons.vibration),
            title: Text(loc.t('hapticFeedback')),
            trailing: Switch(
              value: storage.hapticFeedback,
              onChanged: (value) => storage.setHapticFeedback(value),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.fingerprint),
            title: const Text('App Lock'),
            subtitle: const Text('Fingerprint / PIN to open app'),
            trailing: Switch(
              value: storage.appLockEnabled,
              onChanged: (value) => storage.setAppLockEnabled(value),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.record_voice_over),
            title: Text(loc.t('voiceAnnouncement')),
            subtitle: Text(loc.t('voiceAnnouncementDesc')),
            trailing: Switch(
              value: _voiceEnabled,
              onChanged: (value) => _setVoiceEnabled(value),
            ),
          ),
          
          // === LANGUAGE ===
          _sectionHeader(loc.t('language')),
          ListTile(
            leading: const Icon(Icons.language),
            title: Text(loc.t('appLanguage')),
            subtitle: Text(
              AppConstants.languages.firstWhere(
                (l) => l['code'] == storage.languageCode,
                orElse: () => {'name': 'English'},
              )['name']!,
            ),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => _showLanguagePicker(),
          ),
          
          // === QUICK ACTIONS ===
          _sectionHeader(loc.t('quickActions')),
          ListTile(
            leading: const Icon(Icons.qr_code, color: AppColors.info),
            title: Text(loc.t('upiQrCode')),
            subtitle: const Text('Generate payment QR'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const UpiQrScreen()),
              );
            },
          ),
          ListTile(
            leading: const Icon(Icons.business, color: AppColors.primary),
            title: Text(loc.t('businessDetails')),
            subtitle: Text(loc.t('businessDetailsSubtitle')),
            trailing: const Icon(Icons.chevron_right),
            onTap: _showBusinessDetails,
          ),
          ListTile(
            leading: const Icon(Icons.bar_chart, color: AppColors.primary),
            title: Text(loc.t('reports')),
            subtitle: const Text('View weekly, monthly, all-time stats'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const ReportsScreen()),
              );
            },
          ),
          // === BACKUP & RESTORE ===
          _sectionHeader(loc.t('backupRestore')),

          // Last backup info card
          Consumer<StorageService>(
            builder: (context, storage, child) {
              final lastBackup = BackupService.getLastBackupString(storage);
              return Container(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppColors.primary.withOpacity(0.3)),
                ),
                child: Row(
                  children: [
                    Icon(Icons.cloud_done, color: AppColors.primary, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            loc.t('lastBackup'),
                            style: const TextStyle(
                              fontSize: 11,
                              color: Colors.grey,
                            ),
                          ),
                          Text(
                            lastBackup ?? loc.t('neverBackedUp'),
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              color: lastBackup != null ? AppColors.success : AppColors.danger,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Text(
                      loc.t('autoBackupInfo'),
                      style: const TextStyle(
                        fontSize: 9,
                        color: Colors.grey,
                        fontStyle: FontStyle.italic,
                      ),
                      textAlign: TextAlign.end,
                    ),
                  ],
                ),
              );
            },
          ),

          // Backup button
          ListTile(
            leading: const Icon(Icons.backup, color: AppColors.info),
            title: Text(loc.t('backupData')),
            subtitle: Text(loc.t('backupSubtitle')),
            trailing: const Icon(Icons.chevron_right),
            onTap: _backupData,
          ),

          // Restore button
          ListTile(
            leading: const Icon(Icons.restore, color: AppColors.warning),
            title: Text(loc.t('restoreData')),
            subtitle: Text(loc.t('restoreSubtitle')),
            trailing: const Icon(Icons.chevron_right),
            onTap: _restoreData,
          ),

          // Local backups (auto)
          ListTile(
            leading: const Icon(Icons.history, color: AppColors.success),
            title: Text(loc.t('localBackups')),
            subtitle: Text(loc.t('restoreFromLocal')),
            trailing: const Icon(Icons.chevron_right),
            onTap: _showLocalBackups,
          ),

          // === CSV EXPORT ===
          _sectionHeader(loc.t('exportToExcel')),
          ListTile(
            leading: const Icon(Icons.file_download, color: AppColors.success),
            title: const Text('Export Entries (CSV)'),
            subtitle: const Text('Export to Excel/Sheets'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => _exportCsv('entries'),
          ),
          ListTile(
            leading: const Icon(Icons.people_alt, color: AppColors.success),
            title: const Text('Export Customers (CSV)'),
            subtitle: const Text('Export to Excel/Sheets'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => _exportCsv('customers'),
          ),
          ListTile(
            leading: const Icon(Icons.download, color: AppColors.primary),
            title: const Text('Export All Data'),
            subtitle: const Text('Both entries and customers'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => _exportCsv('both'),
          ),
          
          // === RATE & SHARE ===
          _sectionHeader(loc.t('rateShare')),
          ListTile(
            leading: const Icon(Icons.star, color: AppColors.primary),
            title: Text(loc.t('rateUs')),
            subtitle: const Text('Rate on Play Store'),
            trailing: const Icon(Icons.chevron_right),
            onTap: _rateApp,
          ),
          ListTile(
            leading: const Icon(Icons.share, color: AppColors.success),
            title: Text(loc.t('shareApp')),
            subtitle: const Text('Share with friends'),
            trailing: const Icon(Icons.chevron_right),
            onTap: _shareApp,
          ),
          ListTile(
            leading: const Icon(Icons.feedback, color: AppColors.info),
            title: Text(loc.t('sendFeedback')),
            subtitle: const Text('Email us your suggestions'),
            trailing: const Icon(Icons.chevron_right),
            onTap: _sendFeedback,
          ),
          
          // === DATA ===
          _sectionHeader(loc.t('data')),
          ListTile(
            leading: const Icon(Icons.delete_forever, color: AppColors.danger),
            title: Text(loc.t('clearAllData')),
            subtitle: const Text('Delete all entries, customers, bills'),
            trailing: const Icon(Icons.chevron_right),
            onTap: _showClearDataDialog,
          ),
          
          // === ABOUT ===
          _sectionHeader(loc.t('about')),
          ListTile(
            leading: const Icon(Icons.info, color: AppColors.info),
            title: Text(loc.t('appInfo')),
            subtitle: Text(
              _packageInfo != null
                  ? '${_packageInfo!.appName} v${_packageInfo!.version} (build ${_packageInfo!.buildNumber})'
                  : 'Note Counter Pro v${AppConstants.appVersion} (vc${AppConstants.appVersionCode})',
            ),
          ),
          ListTile(
            leading: const Icon(Icons.code, color: AppColors.primary),
            title: const Text('Version Code'),
            subtitle: Text('NCP v${AppConstants.appVersion} (vc${AppConstants.appVersionCode})'),
          ),
          ListTile(
            leading: const Icon(Icons.privacy_tip, color: AppColors.textSecondary),
            title: Text(loc.t('privacyPolicy')),
            trailing: const Icon(Icons.open_in_new),
            onTap: _openPrivacyPolicy,
          ),
          ListTile(
            leading: const Icon(Icons.email, color: AppColors.textSecondary),
            title: const Text('Support Email'),
            subtitle: const Text(AppConstants.supportEmail),
            onTap: _sendFeedback,
          ),
          
          const SizedBox(height: 32),
          Center(
            child: Text(
              'Made with ❤️ in India',
              style: theme.textTheme.bodySmall?.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
  
  Widget _sectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
      child: Text(
        title.toUpperCase(),
        style: TextStyle(
          color: AppColors.primary,
          fontWeight: FontWeight.bold,
          fontSize: 12,
          letterSpacing: 1,
        ),
      ),
    );
  }
  
  void _showBusinessDetails() {
    final storage = context.read<StorageService>();
    final nameController = TextEditingController(text: storage.businessName);
    final ownerController = TextEditingController(text: storage.businessOwner);
    final phoneController = TextEditingController(text: storage.businessPhone);
    final addressController = TextEditingController(text: storage.businessAddress);
    final upiController = TextEditingController(text: storage.businessUpiId);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.business, color: AppColors.primary),
            const SizedBox(width: 8),
            Text(context.loc.t('businessDetails')),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: const InputDecoration(
                  labelText: 'Business Name',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.store),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: ownerController,
                decoration: const InputDecoration(
                  labelText: 'Owner Name',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.person),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: phoneController,
                decoration: const InputDecoration(
                  labelText: 'Phone',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.phone),
                ),
                keyboardType: TextInputType.phone,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: addressController,
                decoration: const InputDecoration(
                  labelText: 'Address',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.location_on),
                ),
                maxLines: 2,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: upiController,
                decoration: const InputDecoration(
                  labelText: 'UPI ID (for receiving payments)',
                  hintText: 'yourname@upi',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.payment),
                ),
                keyboardType: TextInputType.emailAddress,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(context.loc.t('cancel')),
          ),
          FilledButton(
            onPressed: () async {
              await storage.setBusinessDetails(
                name: nameController.text.trim(),
                owner: ownerController.text.trim(),
                phone: phoneController.text.trim(),
                address: addressController.text.trim(),
                upiId: upiController.text.trim(),
              );
              if (context.mounted) {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Business details saved!'),
                    backgroundColor: AppColors.success,
                  ),
                );
              }
            },
            child: Text(context.loc.t('save')),
          ),
        ],
      ),
    );
  }

  void _showLanguagePicker() {
    final storage = context.read<StorageService>();
    showDialog(
      context: context,
      builder: (context) => SimpleDialog(
        title: const Text('Select Language'),
        children: AppConstants.languages.map((language) {
          return SimpleDialogOption(
            onPressed: () {
              storage.setLanguageCode(language['code']!);
              Navigator.pop(context);
            },
            child: ListTile(
              title: Text(language['name']!),
              trailing: storage.languageCode == language['code']
                  ? const Icon(Icons.check, color: AppColors.success)
                  : null,
            ),
          );
        }).toList(),
      ),
    );
  }
}
