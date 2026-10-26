import 'dart:async';
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
import '../services/premium_service.dart';
import '../services/admob_service.dart';
import '../utils/constants.dart';
import '../utils/app_localizations.dart';
import 'upi_qr_screen.dart';
import 'reports_screen.dart';
import 'bills_screen.dart';
import 'reminder_settings_screen.dart';
import 'reminder_history_screen.dart';
import 'premium_screen.dart';
import 'cloud_backup_screen.dart';
import 'printer_screen.dart';
import 'refer_earn_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});
  
  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  PackageInfo? _packageInfo;
  bool _voiceEnabled = true;
  // Notifier so the Premium tile re-renders when user returns from
  // PremiumScreen after a successful purchase.
  final ValueNotifier<bool> _premiumNotifier = ValueNotifier<bool>(false);
  // Periodic timer that refreshes the trial countdown every minute so the
  // "Trial Active: 23h 45m" label stays accurate without user interaction.
  Timer? _trialCountdownTimer;

  @override
  void initState() {
    super.initState();
    _loadPackageInfo();
    _loadVoiceSetting();
    _premiumNotifier.value = PremiumService().isPremium;
    // CRITICAL: listen to PremiumService so that when a rewarded-ad trial
    // is granted (PremiumService.grantRewardedTrialDays calls
    // notifyListeners), this screen rebuilds and the App Lock / Voice
    // Announcement / Cloud Backup / Printer toggles immediately become
    // enabled. Without this listener, the toggles stay gated even after
    // the trial becomes active.
    PremiumService().addListener(_onPremiumChanged);
    // Preload the rewarded ad so it's ready by the time the user taps
    // "Watch Ad" or "Extend".
    AdMobService.preloadRewardedAd();
    // Refresh the trial countdown label every 60 seconds while the trial
    // is active. The label shows "Trial Active: 23h 45m" and we want it
    // to count down in real time.
    _trialCountdownTimer = Timer.periodic(const Duration(minutes: 1), (_) {
      if (mounted && PremiumService().isTrialActive) {
        // Toggle notifier so the ValueListenableBuilder re-renders the
        // trial status tile with the updated remaining time.
        _premiumNotifier.value = !_premiumNotifier.value;
        _premiumNotifier.value = PremiumService().isPremium;
      }
    });
  }

  void _onPremiumChanged() {
    if (!mounted) return;
    // Force the ValueNotifier to fire by toggling its value. Simply
    // setting it to the same value (e.g. true → true) does NOT notify
    // listeners. So we toggle to the opposite first, then set the
    // correct value — this guarantees the listeners rebuild.
    final newValue = PremiumService().isPremium;
    if (_premiumNotifier.value == newValue) {
      // Same value — force a rebuild via setState.
      setState(() {});
    } else {
      _premiumNotifier.value = newValue;
    }
  }

  @override
  void dispose() {
    _trialCountdownTimer?.cancel();
    PremiumService().removeListener(_onPremiumChanged);
    _premiumNotifier.dispose();
    super.dispose();
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
    final isDark = theme.brightness == Brightness.dark;
    final storage = context.watch<StorageService>();
    final isPremium = PremiumService().isPremium;

    // NOTE: We do NOT wrap the body in ValueListenableBuilder on
    // themeNotifier anymore. That caused a DOUBLE rebuild when dark
    // mode was toggled — once from the VLB, once from Theme.of(context)
    // changing (because MaterialApp.themeMode changed). The double
    // rebuild caused visible flashing.
    //
    // Instead, we rely on Theme.of(context) which is ALREADY reactive:
    // when MaterialApp.themeMode changes, every widget using
    // Theme.of(context) automatically rebuilds with the new theme.
    // This gives us a single, smooth rebuild — no flash.
    return Scaffold(
      // No AppBar — saves ~56px of empty space at the top.
      // SafeArea in body provides the status-bar padding.
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 16),
          children: [
            // ===== PROFILE / PREMIUM HEADER CARD =====
            ValueListenableBuilder<bool>(
            valueListenable: _premiumNotifier,
            builder: (context, premium, _) {
              return _buildPremiumHeader(premium, isDark);
            },
          ),

          // ===== 1. APPEARANCE =====
          _sectionHeader(
            icon: Icons.palette_outlined,
            title: loc.t('appearance'),
            color: AppColors.primary,
          ),
          _settingsCard(
            isDark: isDark,
            children: [
              // Dark Mode toggle uses themeNotifier (a dedicated
              // ValueNotifier) so that the toggle updates immediately
              // WITHOUT triggering a full StorageService rebuild.
              // This is critical for the flashing fix — the previous
              // implementation called notifyListeners() which rebuilt
              // every screen watching StorageService.
              ValueListenableBuilder<bool>(
                valueListenable: storage.themeNotifier,
                builder: (context, isDarkMode, _) {
                  return SwitchListTile(
                    secondary: const Icon(Icons.dark_mode_outlined, color: AppColors.primary),
                    title: Text(loc.t('darkMode')),
                    subtitle: Text(loc.t('toggleDarkTheme')),
                    value: isDarkMode,
                    onChanged: (value) => storage.setDarkMode(value),
                  );
                },
              ),
              const _Divider(),
              SwitchListTile(
                secondary: const Icon(Icons.vibration_outlined, color: AppColors.primary),
                title: Text(loc.t('hapticFeedback')),
                value: storage.hapticFeedback,
                onChanged: (value) => storage.setHapticFeedback(value),
              ),
              const _Divider(),
              ListTile(
                leading: const Icon(Icons.language_outlined, color: AppColors.primary),
                title: Text(loc.t('appLanguage')),
                subtitle: Text(
                  AppConstants.languages.firstWhere(
                    (l) => l['code'] == storage.languageCode,
                    orElse: () => {'name': 'English'},
                  )['name']!,
                ),
                trailing: const Icon(Icons.chevron_right),
                onTap: _showLanguagePicker,
              ),
            ],
          ),

          // ===== 2. SECURITY =====
          _sectionHeader(
            icon: Icons.shield_outlined,
            title: loc.t('security'),
            color: AppColors.info,
          ),
          _settingsCard(
            isDark: isDark,
            children: [
              SwitchListTile(
                secondary: Icon(Icons.fingerprint, color: AppColors.info),
                title: Row(
                  children: [
                    Flexible(child: Text(loc.t('appLock'))),
                    if (!isPremium) ...[
                      const SizedBox(width: 8),
                      _proBadge(),
                    ],
                  ],
                ),
                subtitle: Text(loc.t('appLockDesc')),
                value: isPremium ? storage.appLockEnabled : false,
                onChanged: (value) {
                  if (!isPremium) {
                    Navigator.push(context,
                        MaterialPageRoute(builder: (_) => const PremiumScreen()));
                    return;
                  }
                  storage.setAppLockEnabled(value);
                },
              ),
            ],
          ),

          // ===== 3. PREMIUM =====
          _sectionHeader(
            icon: Icons.workspace_premium_outlined,
            title: loc.t('goPremium'),
            color: const Color(0xFFD4AF37),
          ),
          _settingsCard(
            isDark: isDark,
            children: [
              ValueListenableBuilder<bool>(
                valueListenable: _premiumNotifier,
                builder: (context, premium, _) {
                  if (premium) {
                    return ListTile(
                      leading: const Icon(Icons.verified, color: Color(0xFFD4AF37)),
                      title: Text(loc.t('premiumStatus'),
                          style: const TextStyle(fontWeight: FontWeight.bold)),
                      subtitle: Text(loc.t('premiumActiveSub')),
                      trailing: const Icon(Icons.check_circle, color: AppColors.success),
                    );
                  }
                  return ListTile(
                    leading: const Icon(Icons.workspace_premium, color: Color(0xFFD4AF37)),
                    title: Text(loc.t('premiumUpgradeTitle'),
                        style: const TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: Text(loc.t('removeAdsForever')),
                    trailing: const Icon(Icons.chevron_right, color: Color(0xFFD4AF37)),
                    onTap: () async {
                      await Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const PremiumScreen()),
                      );
                      _premiumNotifier.value = PremiumService().isPremium;
                    },
                  );
                },
              ),
              const _Divider(),
              ListTile(
                leading: const Icon(Icons.card_giftcard_outlined, color: Color(0xFFD4AF37)),
                title: Text(loc.t('referEarn')),
                subtitle: Text(loc.t('referEarnSettingsDesc')),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const ReferEarnScreen()),
                ),
              ),
            ],
          ),

          // ===== 4. PRO TOOLS =====
          _sectionHeader(
            icon: Icons.build_outlined,
            title: loc.t('proTools'),
            color: AppColors.info,
          ),
          _settingsCard(
            isDark: isDark,
            children: [
              ListTile(
                leading: const Icon(Icons.cloud_upload_outlined, color: AppColors.info),
                title: Row(
                  children: [
                    Flexible(child: Text(loc.t('cloudBackup'))),
                    if (!isPremium) ...[const SizedBox(width: 8), _proBadge()],
                  ],
                ),
                subtitle: Text(loc.t('cloudBackupSettingsDesc')),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const CloudBackupScreen()),
                ),
              ),
              const _Divider(),
              ListTile(
                leading: const Icon(Icons.print_outlined, color: AppColors.info),
                title: Row(
                  children: [
                    Flexible(child: Text(loc.t('printer'))),
                    if (!isPremium) ...[const SizedBox(width: 8), _proBadge()],
                  ],
                ),
                subtitle: Text(loc.t('printerSettingsDesc')),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const PrinterScreen()),
                ),
              ),
              const _Divider(),
              SwitchListTile(
                secondary: const Icon(Icons.record_voice_over_outlined, color: AppColors.info),
                title: Row(
                  children: [
                    Flexible(child: Text(loc.t('voiceAnnouncement'))),
                    if (!isPremium) ...[const SizedBox(width: 8), _proBadge()],
                  ],
                ),
                subtitle: Text(loc.t('voiceAnnouncementDesc')),
                value: isPremium ? _voiceEnabled : false,
                onChanged: (value) {
                  if (!isPremium) {
                    Navigator.push(context,
                        MaterialPageRoute(builder: (_) => const PremiumScreen()));
                    return;
                  }
                  _setVoiceEnabled(value);
                },
              ),
              const _Divider(),
              ListTile(
                leading: const Icon(Icons.notifications_active_outlined, color: AppColors.info),
                title: Text(loc.t('reminderSettings')),
                subtitle: Text(loc.t('reminderSettingsDesc')),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const ReminderSettingsScreen()),
                ),
              ),
              const _Divider(),
              ListTile(
                leading: const Icon(Icons.history_outlined, color: AppColors.info),
                title: Text(loc.t('reminderHistory')),
                subtitle: Text(loc.t('reminderHistoryDesc')),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const ReminderHistoryScreen()),
                ),
              ),
              // Rewarded ad / trial status section.
              // Visible when:
              //   - user is NOT a paid premium user (paid users hide this)
              //   - OR user has an active rewarded-ad trial (so they can see
              //     the countdown and extend the trial by watching another ad)
              // Hidden ONLY for users with a paid IAP plan.
              if (!isPremium || PremiumService().isTrialActive) ...[
                const _Divider(),
                ValueListenableBuilder<bool>(
                  valueListenable: _premiumNotifier,
                  builder: (context, _, __) {
                    // Trial active → show trial status + extend option
                    if (PremiumService().isTrialActive) {
                      return ListTile(
                        leading: const Icon(Icons.verified,
                            color: AppColors.success),
                        title: Text(
                          '${loc.t('trialActive')}: ${PremiumService().trialRemainingLabel}',
                          style: const TextStyle(
                              color: AppColors.success,
                              fontWeight: FontWeight.bold),
                        ),
                        subtitle: Text(loc.t('trialActiveDesc')),
                        trailing: AdMobService.isRewardedAdReady
                            ? Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.add_circle,
                                      color: AppColors.success, size: 20),
                                  const SizedBox(width: 4),
                                  Text(
                                    loc.t('extend'),
                                    style: const TextStyle(
                                        color: AppColors.success,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 12),
                                  ),
                                ],
                              )
                            : const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2),
                              ),
                        onTap: _watchRewardedAd,
                      );
                    }
                    // Not premium at all → show "Watch Ad for 1 Day Free" CTA
                    return ListTile(
                      leading: const Icon(Icons.play_circle_outline,
                          color: AppColors.success),
                      title: Text(loc.t('watchAdFreePremium')),
                      subtitle: Text(loc.t('watchAdFreePremiumDesc')),
                      trailing: AdMobService.isRewardedAdReady
                          ? const Icon(Icons.chevron_right,
                              color: AppColors.success)
                          : const SizedBox(
                              width: 18,
                              height: 18,
                              child:
                                  CircularProgressIndicator(strokeWidth: 2),
                            ),
                      onTap: _watchRewardedAd,
                    );
                  },
                ),
              ],
            ],
          ),

          // ===== 5. BUSINESS =====
          _sectionHeader(
            icon: Icons.business_center_outlined,
            title: loc.t('business'),
            color: AppColors.primary,
          ),
          _settingsCard(
            isDark: isDark,
            children: [
              ListTile(
                leading: const Icon(Icons.store_outlined, color: AppColors.primary),
                title: Row(
                  children: [
                    Flexible(child: Text(loc.t('businessDetails'))),
                    if (!isPremium) ...[const SizedBox(width: 8), _proBadge()],
                  ],
                ),
                subtitle: Text(
                  storage.businessName.isEmpty
                      ? loc.t('setUpBusiness')
                      : storage.businessName,
                  style: storage.businessName.isEmpty
                      ? TextStyle(fontStyle: FontStyle.italic, color: AppColors.warning)
                      : null,
                ),
                trailing: const Icon(Icons.chevron_right),
                onTap: () {
                  if (!isPremium) {
                    Navigator.push(context,
                        MaterialPageRoute(builder: (_) => const PremiumScreen()));
                    return;
                  }
                  _showBusinessDetails();
                },
              ),
              const _Divider(),
              ListTile(
                leading: const Icon(Icons.qr_code_2, color: AppColors.primary),
                title: Row(
                  children: [
                    Flexible(child: Text(loc.t('upiQrCode'))),
                    if (!isPremium) ...[const SizedBox(width: 8), _proBadge()],
                  ],
                ),
                subtitle: Text(loc.t('generatePaymentQr')),
                trailing: const Icon(Icons.chevron_right),
                onTap: () {
                  if (!isPremium) {
                    Navigator.push(context,
                        MaterialPageRoute(builder: (_) => const PremiumScreen()));
                    return;
                  }
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const UpiQrScreen()),
                  );
                },
              ),
              const _Divider(),
              ListTile(
                leading: const Icon(Icons.receipt_long_outlined, color: AppColors.primary),
                title: Row(
                  children: [
                    Flexible(child: Text(loc.t('billsInvoices'))),
                    if (!isPremium) ...[const SizedBox(width: 8), _proBadge()],
                  ],
                ),
                subtitle: Text(loc.t('billsInvoicesDesc')),
                trailing: const Icon(Icons.chevron_right),
                onTap: () {
                  if (!isPremium) {
                    Navigator.push(context,
                        MaterialPageRoute(builder: (_) => const PremiumScreen()));
                    return;
                  }
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const BillsScreen()),
                  );
                },
              ),
              const _Divider(),
              ListTile(
                leading: const Icon(Icons.bar_chart_outlined, color: AppColors.primary),
                title: Row(
                  children: [
                    Flexible(child: Text(loc.t('reportsAnalytics'))),
                    if (!isPremium) ...[const SizedBox(width: 8), _proBadge()],
                  ],
                ),
                subtitle: Text(loc.t('reportsDesc')),
                trailing: const Icon(Icons.chevron_right),
                onTap: () {
                  if (!isPremium) {
                    Navigator.push(context,
                        MaterialPageRoute(builder: (_) => const PremiumScreen()));
                    return;
                  }
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const ReportsScreen()),
                  );
                },
              ),
            ],
          ),

          // ===== 6. DATA & BACKUP =====
          _sectionHeader(
            icon: Icons.cloud_done_outlined,
            title: loc.t('backupRestore'),
            color: AppColors.success,
          ),

          // Last backup info card
          Consumer<StorageService>(
            builder: (context, storage, child) {
              final lastBackup = BackupService.getLastBackupString(storage);
              return _infoCard(
                isDark: isDark,
                icon: Icons.cloud_done,
                iconColor: lastBackup != null ? AppColors.success : AppColors.danger,
                title: loc.t('lastBackup'),
                value: lastBackup ?? loc.t('neverBackedUp'),
                valueColor: lastBackup != null ? AppColors.success : AppColors.danger,
                trailing: loc.t('autoBackupInfo'),
              );
            },
          ),

          _settingsCard(
            isDark: isDark,
            children: [
              ListTile(
                leading: const Icon(Icons.backup_outlined, color: AppColors.success),
                title: Text(loc.t('backupData')),
                subtitle: Text(loc.t('backupSubtitle')),
                trailing: const Icon(Icons.chevron_right),
                onTap: _backupData,
              ),
              const _Divider(),
              ListTile(
                leading: const Icon(Icons.restore, color: AppColors.success),
                title: Text(loc.t('restoreData')),
                subtitle: Text(loc.t('restoreSubtitle')),
                trailing: const Icon(Icons.chevron_right),
                onTap: _restoreData,
              ),
              const _Divider(),
              ListTile(
                leading: const Icon(Icons.history, color: AppColors.success),
                title: Text(loc.t('localBackups')),
                subtitle: Text(loc.t('restoreFromLocal')),
                trailing: const Icon(Icons.chevron_right),
                onTap: _showLocalBackups,
              ),
              const _Divider(),
              ListTile(
                leading: const Icon(Icons.file_download_outlined, color: AppColors.success),
                title: Text(loc.t('exportToExcel')),
                subtitle: Text(loc.t('exportSubtitle')),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => _showExportMenu(),
              ),
            ],
          ),

          // ===== 7. RATE & FEEDBACK =====
          _sectionHeader(
            icon: Icons.star_outline,
            title: loc.t('rateFeedbackSection'),
            color: AppColors.warning,
          ),
          _settingsCard(
            isDark: isDark,
            children: [
              ListTile(
                leading: const Icon(Icons.star, color: AppColors.warning),
                title: Text(loc.t('rateUs')),
                subtitle: Text(loc.t('rateOnPlayStore')),
                trailing: const Icon(Icons.chevron_right),
                onTap: _rateApp,
              ),
              const _Divider(),
              ListTile(
                leading: const Icon(Icons.share_outlined, color: AppColors.warning),
                title: Text(loc.t('shareApp')),
                subtitle: Text(loc.t('shareWithFriends')),
                trailing: const Icon(Icons.chevron_right),
                onTap: _shareApp,
              ),
              const _Divider(),
              ListTile(
                leading: const Icon(Icons.feedback_outlined, color: AppColors.warning),
                title: Text(loc.t('sendFeedback')),
                subtitle: Text(loc.t('emailSuggestions')),
                trailing: const Icon(Icons.chevron_right),
                onTap: _sendFeedback,
              ),
            ],
          ),

          // ===== 8. ABOUT =====
          _sectionHeader(
            icon: Icons.info_outline,
            title: loc.t('about'),
            color: AppColors.textSecondary,
          ),
          _settingsCard(
            isDark: isDark,
            children: [
              ListTile(
                leading: const Icon(Icons.info_outline, color: AppColors.textSecondary),
                title: Text(loc.t('appInfo')),
                subtitle: Text(
                  _packageInfo != null
                      ? '${_packageInfo!.appName} v${_packageInfo!.version} (build ${_packageInfo!.buildNumber})'
                      : 'Note Counter Pro v${AppConstants.appVersion} (vc${AppConstants.appVersionCode})',
                ),
              ),
              const _Divider(),
              ListTile(
                leading: const Icon(Icons.privacy_tip_outlined, color: AppColors.textSecondary),
                title: Text(loc.t('privacyPolicy')),
                trailing: const Icon(Icons.open_in_new),
                onTap: _openPrivacyPolicy,
              ),
              const _Divider(),
              ListTile(
                leading: Icon(
                  Icons.email_outlined,
                  color: isPremium ? AppColors.success : AppColors.textSecondary,
                ),
                title: Row(
                  children: [
                    Flexible(child: Text(loc.t('supportEmail'))),
                    if (isPremium) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppColors.success,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Text('PRIORITY',
                            style: TextStyle(fontSize: 9, color: Colors.white, fontWeight: FontWeight.bold)),
                      ),
                    ],
                  ],
                ),
                subtitle: Text(isPremium
                    ? '${AppConstants.supportEmail}\n(Priority support — faster response)'
                    : AppConstants.supportEmail),
                isThreeLine: isPremium,
                trailing: const Icon(Icons.chevron_right),
                onTap: _sendFeedback,
              ),
            ],
          ),

          // ===== 9. DANGER ZONE =====
          _sectionHeader(
            icon: Icons.warning_amber_outlined,
            title: loc.t('dangerZone'),
            color: AppColors.danger,
          ),
          _settingsCard(
            isDark: isDark,
            danger: true,
            children: [
              ListTile(
                leading: const Icon(Icons.delete_forever, color: AppColors.danger),
                title: Text(loc.t('clearAllData'),
                    style: const TextStyle(color: AppColors.danger, fontWeight: FontWeight.w600)),
                subtitle: Text(loc.t('deleteAllEntries')),
                trailing: const Icon(Icons.chevron_right, color: AppColors.danger),
                onTap: _showClearDataDialog,
              ),
            ],
          ),

          const SizedBox(height: 24),
          Center(
            child: Column(
              children: [
                Text(
                  loc.t('madeInIndia'),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '© 2026 Lokhnath Technical',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: AppColors.textSecondary,
                    fontSize: 10,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  /// Premium status header card at the top of settings
  Widget _buildPremiumHeader(bool isPremium, bool isDark) {
    final loc = context.loc;
    return AnimatedContainer(
      duration: Duration.zero,
      curve: Curves.easeInOut,
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: isPremium
            ? const LinearGradient(
                colors: [Color(0xFFD4AF37), Color(0xFFB8941F)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              )
            : LinearGradient(
                colors: isDark
                    ? [const Color(0xFF16213E), const Color(0xFF1A1A2E)]
                    : [Colors.white, const Color(0xFFF9FAFB)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isPremium
              ? const Color(0xFFD4AF37)
              : const Color(0xFFD4AF37).withOpacity(0.3),
          width: isPremium ? 2 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: isDark ? Colors.black.withOpacity(0.3) : Colors.black.withOpacity(0.08),
            blurRadius: 6,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: isPremium
                  ? Colors.white.withOpacity(0.2)
                  : const Color(0xFFD4AF37).withOpacity(0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              isPremium ? Icons.workspace_premium : Icons.person,
              color: isPremium ? Colors.white : const Color(0xFFD4AF37),
              size: 28,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isPremium ? loc.t('premiumStatus') : loc.t('freeUser'),
                  style: TextStyle(
                    fontFamily: 'KhataHandwriting',
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: isPremium ? Colors.white : null,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  isPremium
                      ? loc.t('premiumActiveSub')
                      : loc.t('removeAdsForever'),
                  style: TextStyle(
                    fontSize: 11,
                    color: isPremium
                        ? Colors.white.withOpacity(0.9)
                        : AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          if (!isPremium)
            TextButton.icon(
              onPressed: () async {
                await Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const PremiumScreen()),
                );
                _premiumNotifier.value = PremiumService().isPremium;
              },
              icon: const Icon(Icons.arrow_forward, size: 16),
              label: Text(loc.t('goPremium')),
              style: TextButton.styleFrom(
                foregroundColor: const Color(0xFFD4AF37),
                backgroundColor: const Color(0xFFD4AF37).withOpacity(0.1),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              ),
            ),
        ],
      ),
    );
  }

  /// Section header with icon + handwritten title (matches khata screen style)
  Widget _sectionHeader({
    required IconData icon,
    required String title,
    required Color color,
  }) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 22, 4, 8),
      child: Row(
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 8),
          Text(
            title.toUpperCase(),
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.bold,
              fontSize: 12,
              letterSpacing: 0.8,
              fontFamily: 'KhataHandwriting',
            ),
          ),
        ],
      ),
    );
  }

  /// Card wrapper for grouped settings items — matches khata card style
  Widget _settingsCard({
    required bool isDark,
    required List<Widget> children,
    bool danger = false,
  }) {
    // AnimatedContainer smoothly transitions the card's background
    // color, border, and shadow when dark mode is toggled — instead
    // of an instant color jump that looks like flashing.
    return AnimatedContainer(
      duration: Duration.zero,
      curve: Curves.easeInOut,
      margin: const EdgeInsets.symmetric(vertical: 4),
      decoration: BoxDecoration(
        color: danger
            ? (isDark
                ? AppColors.danger.withOpacity(0.08)
                : AppColors.danger.withOpacity(0.04))
            : (isDark
                ? const Color(0xFF16213E)
                : Colors.white),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: danger
              ? AppColors.danger.withOpacity(0.3)
              : const Color(0xFFD4AF37).withOpacity(0.2),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: isDark ? Colors.black.withOpacity(0.25) : Colors.black.withOpacity(0.04),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: children,
      ),
    );
  }

  /// Info card for last backup status (no chevron, just info)
  Widget _infoCard({
    required bool isDark,
    required IconData icon,
    required Color iconColor,
    required String title,
    required String value,
    required Color valueColor,
    String? trailing,
  }) {
    return AnimatedContainer(
      duration: Duration.zero,
      curve: Curves.easeInOut,
      margin: const EdgeInsets.symmetric(vertical: 4),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF16213E) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: iconColor.withOpacity(0.3),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: isDark ? Colors.black.withOpacity(0.2) : Colors.black.withOpacity(0.04),
            blurRadius: 3,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Icon(icon, color: iconColor, size: 24),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: valueColor,
                  ),
                ),
              ],
            ),
          ),
          if (trailing != null)
            Flexible(
              child: Text(
                trailing,
                style: const TextStyle(
                  fontSize: 9,
                  color: AppColors.textSecondary,
                  fontStyle: FontStyle.italic,
                ),
                textAlign: TextAlign.end,
              ),
            ),
        ],
      ),
    );
  }

  /// Small "PRO" badge for premium-gated features
  Widget _proBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: const Color(0xFFD4AF37),
        borderRadius: BorderRadius.circular(4),
      ),
      child: const Text(
        'PRO',
        style: TextStyle(
          fontSize: 9,
          color: Colors.white,
          fontWeight: FontWeight.bold,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  /// Show a rewarded video ad. On successful completion, grant 1 day of
  /// premium trial. Updates the _premiumNotifier so the UI refreshes.
  ///
  /// If the ad isn't loaded yet, shows a loading dialog and polls every
  /// second for up to 10 seconds before giving up. This fixes the UX
  /// issue where the user taps "Extend" right after watching a previous
  /// ad (when the new ad hasn't finished preloading yet) and just sees
  /// an unhelpful "try again a moment" snackbar.
  Future<void> _watchRewardedAd() async {
    final loc = context.loc;

    // If ad already loaded, show immediately.
    if (AdMobService.isRewardedAdReady) {
      _doShowRewardedAd(loc);
      return;
    }

    // Otherwise preload + show loading dialog with auto-retry.
    AdMobService.preloadRewardedAd();
    final ready = await _showRewardedAdLoadingDialog(loc);
    if (!ready || !mounted) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(loc.t('adNotReadyMsg')),
            backgroundColor: AppColors.warning,
          ),
        );
      }
      return;
    }
    _doShowRewardedAd(loc);
  }

  void _doShowRewardedAd(AppLocalizations loc) {
    AdMobService.showRewardedAd(
      onRewardEarned: () async {
        await PremiumService().grantRewardedTrialDays(1);
        if (mounted) {
          _premiumNotifier.value = PremiumService().isPremium;
          setState(() {}); // rebuild UI
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(loc.t('rewardGrantedMsg')),
              backgroundColor: AppColors.success,
              duration: const Duration(seconds: 4),
            ),
          );
        }
      },
    );
  }

  /// Show a loading dialog while waiting for the rewarded ad to preload.
  /// Returns true if the ad became ready within 10 seconds, false otherwise.
  Future<bool> _showRewardedAdLoadingDialog(AppLocalizations loc) async {
    int attempts = 0;
    const maxAttempts = 10;

    if (!mounted) return false;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        content: Row(
          children: [
            const CircularProgressIndicator(),
            const SizedBox(width: 20),
            Expanded(child: Text(loc.t('adLoadingMsg'))),
          ],
        ),
      ),
    );

    while (attempts < maxAttempts) {
      await Future.delayed(const Duration(seconds: 1));
      if (AdMobService.isRewardedAdReady) {
        if (mounted) Navigator.of(context, rootNavigator: true).pop();
        return true;
      }
      attempts++;
    }

    if (mounted) Navigator.of(context, rootNavigator: true).pop();
    return false;
  }

  /// Show export menu (entries / customers / both) — replaces 3 separate tiles
  void _showExportMenu() {
    final loc = context.loc;
    showModalBottomSheet(
      context: context,
      backgroundColor: Theme.of(context).brightness == Brightness.dark
          ? const Color(0xFF16213E)
          : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                loc.t('exportToExcel'),
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  fontFamily: 'KhataHandwriting',
                ),
              ),
            ),
            const Divider(height: 1),
            ListTile(
              leading: const Icon(Icons.file_download, color: AppColors.success),
              title: Text(loc.t('exportEntries')),
              subtitle: Text(loc.t('exportToExcelSheets')),
              onTap: () {
                Navigator.pop(context);
                _exportCsv('entries');
              },
            ),
            ListTile(
              leading: const Icon(Icons.people_alt, color: AppColors.success),
              title: Text(loc.t('exportCustomers')),
              subtitle: Text(loc.t('exportToExcelSheets')),
              onTap: () {
                Navigator.pop(context);
                _exportCsv('customers');
              },
            ),
            ListTile(
              leading: const Icon(Icons.download, color: AppColors.primary),
              title: Text(loc.t('exportAllData')),
              subtitle: Text(loc.t('exportBothEntriesCustomers')),
              onTap: () {
                Navigator.pop(context);
                _exportCsv('both');
              },
            ),
            const SizedBox(height: 8),
          ],
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

/// Lightweight divider widget for inside settings cards
class _Divider extends StatelessWidget {
  const _Divider();

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Divider(
      height: 1,
      thickness: 0.5,
      indent: 56,
      color: isDark
          ? Colors.white.withOpacity(0.08)
          : Colors.black.withOpacity(0.06),
    );
  }
}
