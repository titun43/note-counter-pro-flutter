// =============================================================================
// Note Counter Pro - Cloud Backup Screen (Google Drive)
// =============================================================================
// Premium feature: Backup/restore app data to user's Google Drive.
// =============================================================================

import 'package:flutter/material.dart';
import '../widgets/banner_ad_widget.dart';
import 'dart:convert';
import 'package:provider/provider.dart';
import '../services/cloud_backup_service.dart';
import '../services/premium_service.dart';
import '../services/storage_service.dart';
import '../utils/constants.dart';
import '../utils/app_localizations.dart';
import 'premium_screen.dart';

class CloudBackupScreen extends StatefulWidget {
  const CloudBackupScreen({super.key});

  @override
  State<CloudBackupScreen> createState() => _CloudBackupScreenState();
}

class _CloudBackupScreenState extends State<CloudBackupScreen> {
  bool _isLoading = false;
  List<Map<String, dynamic>> _backups = [];

  @override
  void initState() {
    super.initState();
    _loadBackups();
  }

  Future<void> _loadBackups() async {
    if (!CloudBackupService().isSignedIn) return;
    final backups = await CloudBackupService().listBackups();
    if (mounted) setState(() => _backups = backups);
  }

  Future<void> _signIn() async {
    setState(() => _isLoading = true);
    final success = await CloudBackupService().signIn();
    setState(() => _isLoading = false);
    if (success) {
      await _loadBackups();
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Sign-in failed. Please try again.'),
          backgroundColor: AppColors.danger,
        ),
      );
    }
  }

  Future<void> _backup() async {
    setState(() => _isLoading = true);
    final storage = context.read<StorageService>();
    final success = await CloudBackupService().backup(storage);
    setState(() => _isLoading = false);
    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('☁️ Backup uploaded to Google Drive!'),
          backgroundColor: AppColors.success,
        ),
      );
      await _loadBackups();
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Backup failed. Please try again.'),
          backgroundColor: AppColors.danger,
        ),
      );
    }
  }

  Future<void> _restore() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Restore Backup?'),
        content: const Text(
            'This will replace all your current data with the latest cloud backup. '
            'This cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(backgroundColor: AppColors.warning),
            child: const Text('Restore'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    setState(() => _isLoading = true);
    final json = await CloudBackupService().restore();
    setState(() => _isLoading = false);

    if (json != null) {
      final storage = context.read<StorageService>();
      try {
        final data = jsonDecode(json) as Map<String, dynamic>;
        await storage.importData(data);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('✅ Backup restored successfully!'),
              backgroundColor: AppColors.success,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Restore failed: $e'),
              backgroundColor: AppColors.danger,
            ),
          );
        }
      }
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No backup found or restore failed.'),
          backgroundColor: AppColors.danger,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final loc = context.loc;
    final theme = Theme.of(context);
    final isPremium = PremiumService().isPremium;
    final isSignedIn = CloudBackupService().isSignedIn;

    return Scaffold(
      appBar: AppBar(title: Text(loc.t('cloudBackup'))),
      body: !isPremium
          ? _buildPremiumRequired(context)
          : _isLoading
              ? const Center(child: CircularProgressIndicator())
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Header
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Column(
                          children: [
                            const Icon(Icons.cloud_upload,
                                size: 56, color: AppColors.primary),
                            const SizedBox(height: 8),
                            Text(
                              loc.t('cloudBackupTitle'),
                              style: theme.textTheme.titleLarge
                                  ?.copyWith(fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              loc.t('cloudBackupDesc'),
                              textAlign: TextAlign.center,
                              style: theme.textTheme.bodySmall,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),

                      // Sign-in status
                      if (!isSignedIn) ...[
                        Text(
                          loc.t('cloudBackupSignIn'),
                          textAlign: TextAlign.center,
                          style: theme.textTheme.bodyMedium,
                        ),
                        const SizedBox(height: 16),
                        FilledButton.icon(
                          onPressed: _signIn,
                          icon: const Icon(Icons.login),
                          label: Text(loc.t('cloudBackupSignInBtn')),
                          style: FilledButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                          ),
                        ),
                      ] else ...[
                        // Signed in — show backup/restore buttons
                        Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: AppColors.success.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.check_circle,
                                  color: AppColors.success),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  '${loc.t('cloudBackupConnected')}: ${CloudBackupService().currentUser?.email ?? ''}',
                                  style: theme.textTheme.bodySmall,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                        FilledButton.icon(
                          onPressed: _backup,
                          icon: const Icon(Icons.backup),
                          label: Text(loc.t('cloudBackupUpload')),
                          style: FilledButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                          ),
                        ),
                        const SizedBox(height: 12),
                        OutlinedButton.icon(
                          onPressed: _restore,
                          icon: const Icon(Icons.restore),
                          label: Text(loc.t('cloudBackupRestore')),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                          ),
                        ),
                        const SizedBox(height: 24),
                        // Backups list
                        if (_backups.isNotEmpty) ...[
                          Text(
                            loc.t('cloudBackupHistory'),
                            style: theme.textTheme.titleSmall
                                ?.copyWith(fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 8),
                          ..._backups.map((b) => Card(
                                child: ListTile(
                                  leading: const Icon(Icons.backup_table,
                                      color: AppColors.primary),
                                  title: Text(
                                    b['name'] ?? '',
                                    style: const TextStyle(fontSize: 13),
                                  ),
                                  subtitle: Text(
                                    b['modifiedTime'] ?? '',
                                    style: theme.textTheme.bodySmall,
                                  ),
                                ),
                              )),
                        ],
                      ],
                    ],
                  ),
                ),
      bottomNavigationBar: const BannerAdWidget(),
    );
  }

  Widget _buildPremiumRequired(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.workspace_premium,
                size: 80, color: Color(0xFFD4AF37)),
            const SizedBox(height: 16),
            Text(
              context.loc.t('cloudBackupPremiumRequired'),
              textAlign: TextAlign.center,
              style: const TextStyle(
                  fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              context.loc.t('cloudBackupPremiumDesc'),
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey[600]),
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const PremiumScreen()),
              ),
              icon: const Icon(Icons.workspace_premium),
              label: Text(context.loc.t('premiumUpgradeTitle')),
            ),
          ],
        ),
      ),
    );
  }
}
