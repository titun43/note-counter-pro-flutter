import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import '../services/storage_service.dart';
import '../utils/constants.dart';
import 'upi_qr_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});
  
  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  PackageInfo? _packageInfo;
  
  @override
  void initState() {
    super.initState();
    _loadPackageInfo();
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
            child: const Text('Cancel'),
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
    final theme = Theme.of(context);
    final storage = context.watch<StorageService>();
    
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        children: [
          // === APPEARANCE ===
          _sectionHeader('Appearance'),
          SwitchListTile(
            secondary: const Icon(Icons.dark_mode),
            title: const Text('Dark Mode'),
            subtitle: const Text('Toggle dark theme'),
            value: storage.isDarkMode,
            onChanged: (value) => storage.setDarkMode(value),
          ),
          ListTile(
            leading: const Icon(Icons.vibration),
            title: const Text('Haptic Feedback'),
            trailing: Switch(
              value: storage.hapticFeedback,
              onChanged: (value) => storage.setHapticFeedback(value),
            ),
          ),
          
          // === CURRENCY ===
          _sectionHeader('Currency'),
          ListTile(
            leading: const Icon(Icons.currency_rupee),
            title: const Text('Default Currency'),
            subtitle: Text(storage.defaultCurrency),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => _showCurrencyPicker(),
          ),
          
          // === LANGUAGE ===
          _sectionHeader('Language'),
          ListTile(
            leading: const Icon(Icons.language),
            title: const Text('App Language'),
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
          _sectionHeader('Quick Actions'),
          ListTile(
            leading: const Icon(Icons.qr_code, color: AppColors.info),
            title: const Text('UPI QR Code'),
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
          _sectionHeader('Rate & Share'),
          ListTile(
            leading: const Icon(Icons.star, color: AppColors.primary),
            title: const Text('Rate Us'),
            subtitle: const Text('Rate on Play Store'),
            trailing: const Icon(Icons.chevron_right),
            onTap: _rateApp,
          ),
          ListTile(
            leading: const Icon(Icons.share, color: AppColors.success),
            title: const Text('Share App'),
            subtitle: const Text('Share with friends'),
            trailing: const Icon(Icons.chevron_right),
            onTap: _shareApp,
          ),
          ListTile(
            leading: const Icon(Icons.feedback, color: AppColors.info),
            title: const Text('Send Feedback'),
            subtitle: const Text('Email us your suggestions'),
            trailing: const Icon(Icons.chevron_right),
            onTap: _sendFeedback,
          ),
          
          // === DATA ===
          _sectionHeader('Data'),
          ListTile(
            leading: const Icon(Icons.delete_forever, color: AppColors.danger),
            title: const Text('Clear All Data'),
            subtitle: const Text('Delete all entries, customers, bills'),
            trailing: const Icon(Icons.chevron_right),
            onTap: _showClearDataDialog,
          ),
          
          // === ABOUT ===
          _sectionHeader('About'),
          ListTile(
            leading: const Icon(Icons.info, color: AppColors.info),
            title: const Text('App Info'),
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
            title: const Text('Privacy Policy'),
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
  
  void _showCurrencyPicker() {
    final storage = context.read<StorageService>();
    showDialog(
      context: context,
      builder: (context) => SimpleDialog(
        title: const Text('Select Currency'),
        children: AppConstants.currencies.map((currency) {
          return SimpleDialogOption(
            onPressed: () {
              storage.setDefaultCurrency(currency['code']!);
              Navigator.pop(context);
            },
            child: ListTile(
              leading: Text(
                currency['symbol']!,
                style: const TextStyle(fontSize: 24),
              ),
              title: Text(currency['name']!),
              subtitle: Text(currency['code']!),
              trailing: storage.defaultCurrency == currency['code']
                  ? const Icon(Icons.check, color: AppColors.success)
                  : null,
            ),
          );
        }).toList(),
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
