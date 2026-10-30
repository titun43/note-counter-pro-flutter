import 'dart:io';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'services/storage_service.dart';
import 'services/admob_service.dart';
import 'services/notification_service.dart';
import 'services/premium_service.dart';
import 'services/cloud_backup_service.dart';
import 'services/referral_service.dart';
import 'services/saved_upi_service.dart';
import 'utils/themes.dart';
import 'utils/app_localizations.dart';
import 'widgets/banner_ad_widget.dart';
import 'widgets/glass_nav_bar.dart';
import 'screens/home_screen.dart';
import 'screens/calculator_screen.dart';
import 'screens/khata_screen.dart';
import 'screens/upi_tab_screen.dart';
import 'screens/tools_tab_screen.dart';
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
    // Restore any active 1-hour ad-removal window from prefs (survives restart)
    AdMobService.loadAdRemovalFromPrefs().catchError((e) {
      debugPrint('AdMob loadAdRemoval failed: $e');
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

  // Initialize Saved UPI service — load saved UPI IDs from prefs
  Future.delayed(const Duration(seconds: 7), () {
    SavedUpiService().init().catchError((e) {
      debugPrint('SavedUpiService init failed: $e');
    });
  });
}

class NoteCounterProApp extends StatelessWidget {
  const NoteCounterProApp({super.key});

  @override
  Widget build(BuildContext context) {
    // CRITICAL FIX for dark-mode flashing:
    // The previous implementation used Consumer<StorageService> (and
    // later Selector) which subscribed to the WHOLE StorageService.
    // When setDarkMode() was called, it triggered notifyListeners(),
    // which rebuilt MaterialApp AND every screen that used
    // context.watch<StorageService> (HomeScreen, KhataScreen,
    // SettingsScreen) — visibly flashing the UI and reloading
    // BannerAdWidgets.
    //
    // Now we use a dedicated themeNotifier (ValueNotifier<bool>) on
    // StorageService. setDarkMode() only updates this notifier — it
    // does NOT call notifyListeners() on the StorageService. So:
    //   - MaterialApp rebuilds (theme change)
    //   - But the screens that watch StorageService do NOT rebuild
    //   - BannerAdWidgets stay alive → no flash
    //
    // The language code is read once at startup via context.select
    // (language changes are rare and a rebuild is acceptable there).
    final storage = context.read<StorageService>();
    final languageCode = context.select<StorageService, String>(
      (s) => s.languageCode,
    );

    return ValueListenableBuilder<bool>(
      valueListenable: storage.themeNotifier,
      builder: (context, isDarkMode, _) {
        return LocalizationProvider(
          languageCode: languageCode,
          child: MaterialApp(
            title: 'Note Counter Pro',
            debugShowCheckedModeBanner: false,
            theme: AppThemes.lightTheme,
            darkTheme: AppThemes.darkTheme,
            themeMode: isDarkMode ? ThemeMode.dark : ThemeMode.light,
            // Smooth dark/light theme transition — 350ms curve.
            // MaterialApp uses AnimatedTheme internally; this duration
            // controls how long the cross-fade takes when the user
            // toggles dark mode. Default is 200ms which can feel abrupt;
            // 350ms with easeInOut feels more polished.
            themeAnimationDuration: Duration.zero,
            themeAnimationCurve: Curves.easeInOut,
            // Home is ALWAYS MainScaffold. App Lock is handled inside
            // MainScaffold via Navigator.push on initial launch only —
            // toggling the App Lock switch no longer kicks the user out
            // of their current screen.
            // Home is MainScaffold with SplashOverlay on top.
            // MainScaffold loads immediately, splash shows as overlay
            // for 1 second then fades away — no navigation issues.
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

  /// Whether the splash overlay is currently visible.
  /// Splash shows on top of MainScaffold for 1 sec, then fades away.
  bool _showSplash = true;

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

    // Splash overlay: show for 3 seconds (text needs time to read),
    // then fade away. Was 1s — too fast, user couldn't read the text.
    Future.delayed(const Duration(seconds: 3), () {
      if (mounted) {
        setState(() => _showSplash = false);
      }
    });
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
    // CRITICAL FIX for the dark-mode flashing issue:
    // Previously this used context.watch<StorageService>() which caused
    // MainScaffold to rebuild on EVERY storage change — including dark
    // mode toggles. That rebuild recreated the _screens list, which in
    // turn caused IndexedStack to rebuild every screen (HomeScreen,
    // KhataScreen, SettingsScreen) — visibly flashing the UI and
    // reloading BannerAdWidgets.
    //
    // Now we use context.read() inside a Selector that watches ONLY
    // the currency code (the only thing the screens list depends on).
    // Dark mode toggle no longer rebuilds MainScaffold — the theme
    // change is handled by the Selector in NoteCounterProApp which
    // just updates MaterialApp.themeMode without rebuilding screens.
    final currencyCode = context.select<StorageService, String>(
      (s) => s.defaultCurrency,
    );
    final loc = context.loc;

    // Cache the screens list so it doesn't get recreated on every build.
    // We rebuild only when currencyCode changes.
    //
    // 5-tab navigation (v3.26.0):
    //   0. Counter  — note counting (main)
    //   1. Khata    — customer ledger (with quick access to Bills & Reports)
    //   2. UPI      — UPI Tools (premium-locked for free users)
    //   3. Tools    — Calculator, Converter, Date Calc, Printer
    //   4. Settings — app settings (cleaned up)
    final List<Widget> screens = [
      const HomeScreen(),
      const KhataScreen(),
      const UpiTabScreen(),
      ToolsTabScreen(currencyCode: currencyCode),
      const SettingsScreen(),
    ];

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        _showExitDialog(context);
      },
      child: Stack(
        children: [
          Scaffold(
            body: Column(
              children: [
                // Banner ad at top
                SafeArea(
                  bottom: false,
                  child: const BannerAdWidget(),
                ),
                // Main content
                Expanded(
                  child: IndexedStack(
                    index: _currentIndex,
                    children: screens,
                  ),
                ),
              ],
            ),
            bottomNavigationBar: GlassNavBar(
              currentIndex: _currentIndex,
              onDestinationSelected: _onPageChanged,
            ),
          ),
          // Splash overlay — shows on top of everything for 1 sec, then gone
          if (_showSplash)
            const Positioned.fill(
              child: _SplashOverlay(),
            ),
        ],
      ),
    );
  }

  void _showExitDialog(BuildContext context) {
    final loc = context.loc;
    showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withOpacity(0.3),
      builder: (ctx) {
        return ClipRRect(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
            child: Container(
              margin: const EdgeInsets.all(16),
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
              decoration: BoxDecoration(
                color: const Color(0xFF16213E).withOpacity(0.85),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                  color: const Color(0xFFD4AF37).withOpacity(0.2),
                  width: 1,
                ),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Drag handle
                  Container(
                    width: 40,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(
                      color: Colors.white24,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  // Warning icon
                  Container(
                    width: 56,
                    height: 56,
                    margin: const EdgeInsets.only(bottom: 12),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: const Color(0xFFD4AF37).withOpacity(0.15),
                    ),
                    child: const Icon(
                      Icons.warning_amber_rounded,
                      color: Color(0xFFD4AF37),
                      size: 32,
                    ),
                  ),
                  // Title
                  Text(
                    loc.t('exitTitle'),
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 8),
                  // Message
                  Text(
                    loc.t('exitMessage'),
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.white.withOpacity(0.7),
                    ),
                  ),
                  const SizedBox(height: 24),
                  // Buttons
                  Row(
                    children: [
                      // No button
                      Expanded(
                        child: SizedBox(
                          height: 48,
                          child: TextButton(
                            onPressed: () => Navigator.of(ctx).pop(false),
                            style: TextButton.styleFrom(
                              backgroundColor: Colors.white.withOpacity(0.1),
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: Text(
                              loc.t('exitNo'),
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      // Yes button
                      Expanded(
                        child: SizedBox(
                          height: 48,
                          child: FilledButton(
                            onPressed: () async {
                              Navigator.of(ctx).pop(true);
                              await Future.delayed(
                                  const Duration(milliseconds: 300));
                              // Kill app completely so reopen = fresh start
                              // SystemNavigator.pop() only backgrounds the app.
                              // exit(0) kills the process — reopen shows splash.
                              exit(0);
                            },
                            style: FilledButton.styleFrom(
                              backgroundColor: Colors.red,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: Text(
                              loc.t('exitYes'),
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

// =============================================================================
// _SplashOverlay — shows on top of MainScaffold for 1 sec, then removed.
// Uses Flutter Text widgets = crystal clear. No navigation issues.
// =============================================================================
class _SplashOverlay extends StatefulWidget {
  const _SplashOverlay();

  @override
  State<_SplashOverlay> createState() => _SplashOverlayState();
}

class _SplashOverlayState extends State<_SplashOverlay>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );
    _fadeAnimation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeIn,
    );
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xFF0A0A1A),
      child: SafeArea(
        child: FadeTransition(
          opacity: _fadeAnimation,
          child: Column(
            children: [
              const Spacer(flex: 2),
              // App icon with gold glow (center visual)
              Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: const LinearGradient(
                    colors: [Color(0xFFD4AF37), Color(0xFFFFD700)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFFD4AF37).withOpacity(0.3),
                      blurRadius: 20,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Padding(
                  padding: const EdgeInsets.all(8),
                  child: ClipOval(
                    child: Image.asset(
                      'assets/icons/app_logo.png',
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              const Text(
                'Note Counter Pro',
                style: TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                  fontFamily: 'Inter',
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(height: 8),
              Container(
                width: 200,
                height: 2,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFFD4AF37), Color(0xFFFFD700)],
                  ),
                  borderRadius: BorderRadius.circular(1),
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'Professional Cash Manager',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                  color: Color(0xFFD4AF37),
                  fontFamily: 'Inter',
                ),
              ),
              const Spacer(flex: 4),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: const [
                  Icon(Icons.lock, color: Color(0xFFD4AF37), size: 20),
                  SizedBox(width: 8),
                  Text(
                    '100% Secure',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFFD4AF37),
                      fontFamily: 'Inter',
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              const Text(
                'Lokhnath Technical',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w400,
                  color: Colors.white70,
                  fontFamily: 'Inter',
                ),
              ),
              const Spacer(flex: 1),
            ],
          ),
        ),
      ),
    );
  }
}
