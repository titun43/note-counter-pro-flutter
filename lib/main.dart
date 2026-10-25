import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'services/storage_service.dart';
import 'services/admob_service.dart';
import 'services/notification_service.dart';
import 'services/premium_service.dart';
import 'services/cloud_backup_service.dart';
import 'services/referral_service.dart';
import 'utils/themes.dart';
import 'utils/app_localizations.dart';
import 'widgets/banner_ad_widget.dart';
import 'screens/home_screen.dart';
import 'screens/calculator_screen.dart';
import 'screens/khata_screen.dart';
import 'screens/settings_screen.dart';
import 'screens/lock_screen.dart';
import 'package:flutter/services.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  SharedPreferences? prefs;
  try {
    prefs = await SharedPreferences.getInstance();
  } catch (e) {
    debugPrint('SharedPreferences init failed: $e');
  }
  
  // Run app immediately - no waiting for AdMob
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => StorageService(prefs)),
      ],
      child: const NoteCounterProApp(),
    ),
  );
  
  // Initialize AdMob 3 seconds after app starts (non-blocking, safe).
  // IMPORTANT: We do NOT show the app-open ad on cold start anymore.
  // The lifecycle observer in MainScaffold shows it when the user
  // RETURNS to the app from background. On a true cold start, the user
  // just opened the app and we want them to actually USE it first.
  // AdMob policy: app-open ads should appear on app foreground events
  // (when the user comes back), not on the initial launch.
  Future.delayed(const Duration(seconds: 3), () {
    AdMobService.initialize().catchError((e) {
      debugPrint('AdMob init failed: $e');
    });
  });

  // Initialize notification service for scheduled reminders (v3.15.0)
  Future.delayed(const Duration(seconds: 5), () {
    NotificationService().init().catchError((e) {
      debugPrint('NotificationService init failed: $e');
    });
  });

  // Initialize Premium service (In-App Purchase) — restore previous purchases
  // Premium must init BEFORE AdMob so shouldShowAds returns correct value.
  Future.delayed(const Duration(seconds: 2), () {
    PremiumService().init().catchError((e) {
      debugPrint('PremiumService init failed: $e');
    });
  });

  // Initialize Cloud Backup service (Google Drive) — premium feature
  Future.delayed(const Duration(seconds: 4), () {
    CloudBackupService().init();
  });

  // Initialize Referral service — generate/load unique code
  Future.delayed(const Duration(seconds: 6), () {
    ReferralService().init().catchError((e) {
      debugPrint('ReferralService init failed: $e');
    });
  });
}

class NoteCounterProApp extends StatelessWidget {
  const NoteCounterProApp({super.key});

  @override
  Widget build(BuildContext context) {
    // Selector watches ONLY isDarkMode + languageCode. Other storage
    // changes (appLockEnabled toggle, currency change, etc.) do NOT
    // rebuild the MaterialApp — preventing the flashing caused by the
    // previous Consumer<StorageService> rebuilding the entire widget
    // tree (including all BannerAdWidgets) on every storage change.
    return Selector<StorageService, ({bool isDarkMode, String languageCode})>(
      selector: (_, s) => (isDarkMode: s.isDarkMode, languageCode: s.languageCode),
      builder: (context, state, child) {
        return LocalizationProvider(
          languageCode: state.languageCode,
          child: MaterialApp(
            title: 'Note Counter Pro',
            debugShowCheckedModeBanner: false,
            theme: AppThemes.lightTheme,
            darkTheme: AppThemes.darkTheme,
            themeMode: state.isDarkMode ? ThemeMode.dark : ThemeMode.light,
            // Home is ALWAYS MainScaffold. App Lock is handled inside
            // MainScaffold via Navigator.push on initial launch only —
            // toggling the App Lock switch no longer kicks the user out
            // of their current screen.
            home: const MainScaffold(),
          ),
        );
      },
    );
  }
}

/// Old AppLockWrapper removed — MainScaffold now handles the lock screen
/// via a one-time Navigator.push on cold start (see _showAppLockIfEnabled).

class MainScaffold extends StatefulWidget {
  const MainScaffold({super.key});

  @override
  State<MainScaffold> createState() => _MainScaffoldState();
}

class _MainScaffoldState extends State<MainScaffold> with WidgetsBindingObserver {
  int _currentIndex = 0;
  int _pageChangeCount = 0; // For interstitial ad timing

  /// Whether the app has been backgrounded at least once. Used to ensure
  /// the app-open ad only triggers when the user RETURNS to the app, not on
  /// the very first launch (cold-start app open ads are handled separately).
  bool _isFirstResume = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // Show App Lock screen ONCE on cold start if the user previously
    // enabled it in Settings. We use addPostFrameCallback so the
    // MainScaffold is fully built before the lock screen pushes on top.
    // Toggling the App Lock switch later (from Settings) does NOT
    // trigger this — only the initial app launch does.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _showAppLockIfEnabled();
    });
    _checkForUpdate();
  }

  void _showAppLockIfEnabled() {
    if (!mounted) return;
    final storage = context.read<StorageService>();
    if (storage.appLockEnabled) {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => LockScreen(
            onUnlocked: () => Navigator.of(context).pop(),
          ),
          // Disable swipe-back / system-back to dismiss the lock screen.
          // User MUST authenticate to proceed.
          fullscreenDialog: true,
        ),
      );
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    // Show app-open ad when the user returns to the app from background.
    // Skip the very first transition (cold start handled by app launch flow).
    // The AdMobService.showAppOpenAd() itself enforces a 30-minute cooldown
    // so users who frequently background/foreground the app don't get
    // bombarded.
    if (state == AppLifecycleState.resumed) {
      if (_isFirstResume) {
        _isFirstResume = false;
        return;
      }
      // Slightly longer delay so the UI has time to settle before the ad
      // shows — and so that very brief background trips (notifications,
      // permission dialogs) don't immediately trigger an ad.
      Future.delayed(const Duration(seconds: 1), () {
        if (mounted) AdMobService.showAppOpenAd();
      });
    }
  }
  
  Future<void> _checkForUpdate() async {
    try {
      const platform = MethodChannel('com.lokhnathtechnical.notecounterpro/update');
      final result = await platform.invokeMethod('checkUpdate');
      if (result != null && result['updateAvailable'] == true) {
        if (mounted) {
          showDialog(
            context: context,
            barrierDismissible: false,
            builder: (context) => AlertDialog(
              title: const Text('Update Available'),
              content: const Text('A new version of Note Counter Pro is available. Please update for the best experience.'),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Later'),
                ),
                FilledButton(
                  onPressed: () {
                    Navigator.pop(context);
                    platform.invokeMethod('startUpdate');
                  },
                  child: const Text('Update Now'),
                ),
              ],
            ),
          );
        }
      }
    } catch (e) {
      debugPrint('In-app update check failed: $e');
    }
  }
  
  void _onPageChanged(int index) {
    setState(() {
      _currentIndex = index;
    });
    
    // Show interstitial every 6 page changes (less annoying)
    _pageChangeCount++;
    if (_pageChangeCount >= 6) {
      _pageChangeCount = 0;
      AdMobService.showInterstitial();
    }
  }
  
  @override
  Widget build(BuildContext context) {
    final storage = context.watch<StorageService>();
    final currencyCode = storage.defaultCurrency;
    final loc = context.loc;
    
    final List<Widget> _screens = [
      const HomeScreen(),
      CalculatorScreen(currencyCode: currencyCode),
      const KhataScreen(),
      const SettingsScreen(),
    ];
    
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        _showExitDialog(context);
      },
      child: Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            // Banner ad at top (after SafeArea for proper position)
            const BannerAdWidget(),
            // Main content
            Expanded(
              child: IndexedStack(
                index: _currentIndex,
                children: _screens,
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: _onPageChanged,
        destinations: [
          NavigationDestination(
            icon: const Icon(Icons.calculate_outlined),
            selectedIcon: const Icon(Icons.calculate),
            label: loc.t('counter'),
          ),
          NavigationDestination(
            icon: const Icon(Icons.functions_outlined),
            selectedIcon: const Icon(Icons.functions),
            label: loc.t('calculator'),
          ),
          NavigationDestination(
            icon: const Icon(Icons.account_balance_wallet_outlined),
            selectedIcon: const Icon(Icons.account_balance_wallet),
            label: loc.t('khata'),
          ),
          NavigationDestination(
            icon: const Icon(Icons.settings_outlined),
            selectedIcon: const Icon(Icons.settings),
            label: loc.t('settings'),
          ),
        ],
      ),
      ),
    );
  }

  void _showExitDialog(BuildContext context) {
    final loc = context.loc;
    showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(loc.t('exitTitle')),
        content: Text(loc.t('exitMessage')),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(loc.t('exitNo')),
          ),
          FilledButton(
            onPressed: () async {
              Navigator.of(ctx).pop(true);
              // Wait for dialog to fully close before exiting
              // Prevents dialog from showing on reopen
              await Future.delayed(const Duration(milliseconds: 300));
              SystemNavigator.pop();
            },
            style: FilledButton.styleFrom(
              backgroundColor: Colors.red,
            ),
            child: Text(loc.t('exitYes')),
          ),
        ],
      ),
    );
  }
}
