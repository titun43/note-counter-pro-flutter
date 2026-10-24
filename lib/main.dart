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
import 'screens/customers_screen.dart';
import 'screens/khata_screen.dart';
import 'screens/bills_screen.dart';
import 'screens/reports_screen.dart';
import 'screens/settings_screen.dart';
import 'screens/lock_screen.dart';
import 'screens/splash_screen.dart';
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
  
  // Initialize AdMob 3 seconds after app starts (non-blocking, safe)
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
    return Consumer<StorageService>(
      builder: (context, storage, child) {
        return LocalizationProvider(
          languageCode: storage.languageCode,
          child: MaterialApp(
            title: 'Note Counter Pro',
            debugShowCheckedModeBanner: false,
            theme: AppThemes.lightTheme,
            darkTheme: AppThemes.darkTheme,
            themeMode: storage.isDarkMode ? ThemeMode.dark : ThemeMode.light,
            home: const _AppEntry(),
          ),
        );
      },
    );
  }
}

/// Entry point — shows splash screen first, then transitions to MainScaffold.
class _AppEntry extends StatefulWidget {
  const _AppEntry();

  @override
  State<_AppEntry> createState() => _AppEntryState();
}

class _AppEntryState extends State<_AppEntry> {
  bool _showSplash = true;

  @override
  Widget build(BuildContext context) {
    final storage = context.watch<StorageService>();

    if (_showSplash) {
      return SplashScreen(
        onDone: () {
          setState(() => _showSplash = false);
        },
      );
    }

    // After splash — check app lock
    if (storage.appLockEnabled) {
      return const AppLockWrapper();
    }
    return const MainScaffold();
  }
}

class AppLockWrapper extends StatefulWidget {
  const AppLockWrapper({super.key});

  @override
  State<AppLockWrapper> createState() => _AppLockWrapperState();
}

class _AppLockWrapperState extends State<AppLockWrapper> {
  bool _unlocked = false;

  @override
  Widget build(BuildContext context) {
    if (_unlocked) {
      return const MainScaffold();
    }
    return LockScreen(
      onUnlocked: () {
        setState(() {
          _unlocked = true;
        });
      },
    );
  }
}

class MainScaffold extends StatefulWidget {
  const MainScaffold({super.key});

  @override
  State<MainScaffold> createState() => _MainScaffoldState();
}

class _MainScaffoldState extends State<MainScaffold> {
  int _currentIndex = 0;
  int _pageChangeCount = 0; // For interstitial ad timing
  
  @override
  void initState() {
    super.initState();
    _checkForUpdate();
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
            onPressed: () {
              Navigator.of(ctx).pop(true);
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
