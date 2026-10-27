import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import '../utils/constants.dart';
import 'premium_service.dart';

class AdMobService {
  static bool _initialized = false;
  static InterstitialAd? _interstitialAd;
  static int _interstitialLoadAttempts = 0;

  /// Interstitial frequency control (AdMob policy compliance + UX).
  /// AdMob policy: minimum 60 seconds between consecutive interstitials.
  /// We also enforce a per-session cap (5) and a per-day cap (20).
  static DateTime? _lastInterstitialShownTime;
  static const Duration _interstitialCooldown = Duration(seconds: 60);
  static int _interstitialShownThisSession = 0;
  static int _interstitialShownToday = 0;
  static DateTime _interstitialDay = DateTime.now();
  static const int _maxInterstitialsPerSession = 5;
  static const int _maxInterstitialsPerDay = 20;

  /// Rewarded ad — 1-hour ad removal option.
  /// When user watches a rewarded ad, we set this timestamp to now + 1 hour.
  /// During this window, shouldShowAds returns false.
  static DateTime? _adRemovalExpiry;

  // App Open ad state
  static AppOpenAd? _appOpenAd;
  static int _appOpenLoadAttempts = 0;
  static DateTime? _appOpenLoadTime;
  static bool _isShowingAppOpen = false;

  /// Wall-clock time when the app-open ad was last SHOWN to the user.
  /// Used to enforce a minimum cooldown between app-open ad impressions
  /// so users don't get bombarded when frequently backgrounding/foregrounding.
  static DateTime? _lastAppOpenAdShownTime;

  /// Minimum time between consecutive app-open ad impressions.
  /// 30 minutes — industry standard for app-open ads.
  /// Set to 0 to disable cooldown entirely.
  static const Duration _appOpenAdCooldown = Duration(minutes: 30);

  // Rewarded ad state
  static RewardedAd? _rewardedAd;
  static int _rewardedLoadAttempts = 0;

  /// TEST MODE flag — controls whether test or real ad unit IDs are used.
  ///
  /// When true:  uses Google's official test ad unit IDs (always serve ads,
  ///             safe for development).
  /// When false: uses real AdMob ad unit IDs from AppConstants.
  ///
  /// Currently: TEST ADS ON — for user testing on mobile before Play Store update.
  /// All 4 ad formats (Banner, Interstitial, App Open, Rewarded) use
  /// Google's official test ad unit IDs.
  ///
  /// TODO: Set to `false` before Play Store production release.
  static const bool useTestAds = true;

  /// Google's official test ad unit IDs (always serve, safe for testing)
  static const String _testBannerAdUnitId =
      'ca-app-pub-3940256099942544/6300978111';
  static const String _testInterstitialAdUnitId =
      'ca-app-pub-3940256099942544/1033173712';
  static const String _testAppOpenAdUnitId =
      'ca-app-pub-3940256099942544/9257395921';
  static const String _testRewardedAdUnitId =
      'ca-app-pub-3940256099942544/5224354917';

  /// Get banner ad unit ID (test or real based on useTestAds flag)
  static String get bannerAdUnitId {
    if (useTestAds) return _testBannerAdUnitId;
    return AppConstants.admobBannerAdUnitId;
  }

  /// Get interstitial ad unit ID (test or real based on useTestAds flag)
  static String get interstitialAdUnitId {
    if (useTestAds) return _testInterstitialAdUnitId;
    return AppConstants.admobInterstitialAdUnitId;
  }

  /// Get app open ad unit ID (test or real based on useTestAds flag)
  static String get appOpenAdUnitId {
    if (useTestAds) return _testAppOpenAdUnitId;
    return AppConstants.admobAppOpenAdUnitId;
  }

  /// Get rewarded ad unit ID (test or real based on useTestAds flag)
  static String get rewardedAdUnitId {
    if (useTestAds) return _testRewardedAdUnitId;
    return AppConstants.admobRewardedAdUnitId;
  }

  /// Premium users never see ads. Check this before showing any ad.
  /// Also returns false during the 1-hour ad-removal rewarded-ad window.
  static bool get shouldShowAds {
    if (PremiumService().isPremium) return false;
    // If a 1-hour ad-removal window is active, hide ads
    if (_adRemovalExpiry != null && DateTime.now().isBefore(_adRemovalExpiry!)) {
      return false;
    }
    return true;
  }

  /// Whether the 1-hour ad-removal window is currently active.
  static bool get isAdRemovalActive {
    return _adRemovalExpiry != null && DateTime.now().isBefore(_adRemovalExpiry!);
  }

  /// Remaining time (seconds) in the current ad-removal window, or 0.
  static int get adRemovalRemainingSeconds {
    if (_adRemovalExpiry == null) return 0;
    final diff = _adRemovalExpiry!.difference(DateTime.now());
    return diff.isNegative ? 0 : diff.inSeconds;
  }

  /// Grant 1 hour of ad-free experience (called after watching a rewarded ad).
  static void grantAdRemovalFor1Hour() {
    _adRemovalExpiry = DateTime.now().add(const Duration(hours: 1));
    debugPrint('AdMob: 1-hour ad removal granted. Expires at $_adRemovalExpiry');
  }

  /// Initialize AdMob - safe, won't crash app
  static Future<void> initialize() async {
    if (_initialized) return;

    try {
      debugPrint('AdMob: initializing (test mode: $useTestAds)');
      await MobileAds.instance.initialize();
      _initialized = true;
      _loadInterstitialAd();
      _loadAppOpenAd();
      _loadRewardedAd();
      debugPrint('AdMob: initialized successfully');
    } catch (e) {
      debugPrint('AdMob init failed (non-fatal): $e');
    }
  }

  static bool get isInitialized => _initialized;

  // =========================================================================
  // INTERSTITIAL
  // =========================================================================

  static void _loadInterstitialAd() {
    try {
      InterstitialAd.load(
        adUnitId: interstitialAdUnitId,
        request: const AdRequest(),
        adLoadCallback: InterstitialAdLoadCallback(
          onAdLoaded: (ad) {
            _interstitialAd = ad;
            _interstitialLoadAttempts = 0;
            debugPrint('AdMob: interstitial loaded');
          },
          onAdFailedToLoad: (err) {
            _interstitialLoadAttempts++;
            _interstitialAd = null;
            debugPrint('AdMob: interstitial failed to load (attempt $_interstitialLoadAttempts): ${err.message}');
            if (_interstitialLoadAttempts < 3) {
              _loadInterstitialAd();
            }
          },
        ),
      );
    } catch (e) {
      debugPrint('Interstitial ad load failed: $e');
    }
  }

  static void showInterstitial() {
    // Premium users never see ads
    if (!shouldShowAds) return;

    // AdMob policy: minimum 60 seconds between consecutive interstitials
    final now = DateTime.now();
    if (_lastInterstitialShownTime != null) {
      final elapsed = now.difference(_lastInterstitialShownTime!);
      if (elapsed < _interstitialCooldown) {
        debugPrint('AdMob: interstitial skipped — cooldown '
            '(${elapsed.inSeconds}s < ${_interstitialCooldown.inSeconds}s)');
        return;
      }
    }

    // Per-day reset (if day rolled over, reset counters)
    if (now.day != _interstitialDay.day ||
        now.month != _interstitialDay.month ||
        now.year != _interstitialDay.year) {
      _interstitialDay = now;
      _interstitialShownToday = 0;
    }

    // Session cap (max 5 interstitials per session)
    if (_interstitialShownThisSession >= _maxInterstitialsPerSession) {
      debugPrint('AdMob: interstitial skipped — session cap reached '
          '($_interstitialShownThisSession/$_maxInterstitialsPerSession)');
      return;
    }
    // Daily cap (max 20 interstitials per day)
    if (_interstitialShownToday >= _maxInterstitialsPerDay) {
      debugPrint('AdMob: interstitial skipped — daily cap reached '
          '($_interstitialShownToday/$_maxInterstitialsPerDay)');
      return;
    }

    if (_interstitialAd != null) {
      _interstitialAd!.fullScreenContentCallback = FullScreenContentCallback(
        onAdDismissedFullScreenContent: (ad) {
          ad.dispose();
          _loadInterstitialAd();
        },
        onAdFailedToShowFullScreenContent: (ad, err) {
          ad.dispose();
          _loadInterstitialAd();
        },
      );
      _interstitialAd!.show();
      _interstitialAd = null;
      // Update cooldown + caps
      _lastInterstitialShownTime = now;
      _interstitialShownThisSession++;
      _interstitialShownToday++;
      debugPrint('AdMob: interstitial shown '
          '(session: $_interstitialShownThisSession/$_maxInterstitialsPerSession, '
          'day: $_interstitialShownToday/$_maxInterstitialsPerDay)');
    } else {
      // Try to load if not loaded
      _loadInterstitialAd();
    }
  }

  // =========================================================================
  // APP OPEN AD
  // =========================================================================
  //
  // Shown when user opens/returns to the app. Highest eCPM of all formats.
  // We cache the ad and only show it if:
  //   - it's loaded
  //   - it was loaded < 4 hours ago (AdMob policy)
  //   - the app is not currently showing another ad

  static void _loadAppOpenAd() {
    try {
      AppOpenAd.load(
        adUnitId: appOpenAdUnitId,
        request: const AdRequest(),
        orientation: AppOpenAd.orientationPortrait,
        adLoadCallback: AppOpenAdLoadCallback(
          onAdLoaded: (ad) {
            _appOpenAd = ad;
            _appOpenLoadTime = DateTime.now();
            _appOpenLoadAttempts = 0;
            debugPrint('AdMob: app open ad loaded');
          },
          onAdFailedToLoad: (err) {
            _appOpenLoadAttempts++;
            _appOpenAd = null;
            _appOpenLoadTime = null;
            debugPrint('AdMob: app open ad failed to load (attempt $_appOpenLoadAttempts): ${err.message}');
            if (_appOpenLoadAttempts < 3) {
              _loadAppOpenAd();
            }
          },
        ),
      );
    } catch (e) {
      debugPrint('App open ad load failed: $e');
    }
  }

  /// Whether the cached app open ad is still valid (< 4 hours old).
  static bool get _isAppOpenAdAvailable {
    if (_appOpenAd == null || _appOpenLoadTime == null) return false;
    // AdMob policy: app open ads expire after 4 hours
    return DateTime.now().difference(_appOpenLoadTime!) <
        const Duration(hours: 4);
  }

  /// Try to show the app open ad. Called on app open / resume.
  ///
  /// Cooldown logic:
  ///   - Skips if a previous app-open ad was shown less than
  ///     [_appOpenAdCooldown] (30 min) ago. This prevents user fatigue
  ///     when they rapidly background/foreground the app.
  ///   - If the ad is not yet loaded, schedules a one-shot retry: polls
  ///     every 1 second for up to 6 seconds, and shows the ad as soon
  ///     as it becomes available (still respecting cooldown).
  ///
  /// Returns true if the ad was shown immediately.
  static bool showAppOpenAd() {
    if (!shouldShowAds) return false;
    if (_isShowingAppOpen) return false;

    // Cooldown check — don't bombard the user.
    if (_lastAppOpenAdShownTime != null) {
      final elapsed = DateTime.now().difference(_lastAppOpenAdShownTime!);
      if (elapsed < _appOpenAdCooldown) {
        debugPrint('App open ad: skipping — cooldown '
            '(${elapsed.inMinutes}m ${elapsed.inSeconds % 60}s elapsed, '
            'need ${_appOpenAdCooldown.inMinutes}m)');
        return false;
      }
    }

    if (!_isAppOpenAdAvailable) {
      // Ad not loaded yet — kick off a load and poll until it's ready.
      _loadAppOpenAd();
      _scheduleAppOpenAdRetry(attempt: 0);
      return false;
    }

    return _doShowAppOpenAd();
  }

  /// Internal: actually call .show() on the cached app-open ad.
  static bool _doShowAppOpenAd() {
    try {
      _isShowingAppOpen = true;
      _appOpenAd!.fullScreenContentCallback = FullScreenContentCallback(
        onAdDismissedFullScreenContent: (ad) {
          ad.dispose();
          _appOpenAd = null;
          _appOpenLoadTime = null;
          _isShowingAppOpen = false;
          _lastAppOpenAdShownTime = DateTime.now();
          _loadAppOpenAd();
        },
        onAdFailedToShowFullScreenContent: (ad, err) {
          ad.dispose();
          _appOpenAd = null;
          _appOpenLoadTime = null;
          _isShowingAppOpen = false;
          // Don't update _lastAppOpenAdShownTime on failure — the ad
          // didn't actually show, so cooldown shouldn't apply.
          _loadAppOpenAd();
        },
      );
      _appOpenAd!.show();
      // Mark shown time proactively — if the user dismisses it, the
      // onAdDismissed callback will re-update with the actual dismiss time.
      _lastAppOpenAdShownTime = DateTime.now();
      return true;
    } catch (e) {
      debugPrint('App open ad show failed: $e');
      _isShowingAppOpen = false;
      return false;
    }
  }

  /// One-shot retry loop for showing the app-open ad when it's not yet
  /// loaded at the time showAppOpenAd() was called.
  /// Polls every 1 second, gives up after 6 attempts.
  static Timer? _appOpenRetryTimer;
  static void _scheduleAppOpenAdRetry({required int attempt}) {
    _appOpenRetryTimer?.cancel();
    if (attempt >= 6) {
      debugPrint('App open ad: gave up after 6 retry attempts');
      return;
    }
    _appOpenRetryTimer = Timer(const Duration(seconds: 1), () {
      if (_isShowingAppOpen) return; // already showing
      if (_isAppOpenAdAvailable) {
        debugPrint('App open ad: ready after $attempt retry attempt(s), showing');
        _doShowAppOpenAd();
      } else {
        _scheduleAppOpenAdRetry(attempt: attempt + 1);
      }
    });
  }

  // =========================================================================
  // REWARDED AD
  // =========================================================================
  //
  // User voluntarily watches ad → earns reward (e.g. 1 day premium trial).
  // Highest eCPM of all formats. Uses onUserEarnedReward callback.

  static void _loadRewardedAd() {
    try {
      RewardedAd.load(
        adUnitId: rewardedAdUnitId,
        request: const AdRequest(),
        rewardedAdLoadCallback: RewardedAdLoadCallback(
          onAdLoaded: (ad) {
            _rewardedAd = ad;
            _rewardedLoadAttempts = 0;
            debugPrint('AdMob: rewarded ad loaded');
            _notifyRewardedReadinessChanged();
          },
          onAdFailedToLoad: (err) {
            _rewardedLoadAttempts++;
            _rewardedAd = null;
            debugPrint('AdMob: rewarded ad failed to load (attempt $_rewardedLoadAttempts): ${err.message}');
            _notifyRewardedReadinessChanged();
            if (_rewardedLoadAttempts < 3) {
              _loadRewardedAd();
            }
          },
        ),
      );
    } catch (e) {
      debugPrint('Rewarded ad load failed: $e');
    }
  }

  /// Show the rewarded ad. After the user completes viewing, [onRewardEarned]
  /// is called. The caller (UI) is responsible for granting the reward
  /// (e.g. 1 day premium trial via PremiumService).
  ///
  /// Returns false if no ad is currently available (caller can show a
  /// "please try again later" message).
  ///
  /// NOTE: Rewarded ads are EXEMPT from the 1-hour ad-removal window
  /// because they are the mechanism that GRANTS the 1-hour removal.
  /// If we respected shouldShowAds here, the user could never extend
  /// their ad-removal window by watching another rewarded ad.
  static bool showRewardedAd({
    required VoidCallback onRewardEarned,
    VoidCallback? onAdDismissed,
  }) {
    // Rewarded ads bypass the ad-removal window (see NOTE above).
    // We only check true Premium status for rewarded ads.
    if (PremiumService().isPremium) return false;

    if (_rewardedAd == null) {
      _loadRewardedAd();
      return false;
    }

    // Capture the ad reference locally because we null it out in
    // the fullScreenContentCallback before the reward callback may fire.
    final ad = _rewardedAd!;
    bool rewardEarned = false;

    try {
      ad.fullScreenContentCallback = FullScreenContentCallback(
        onAdDismissedFullScreenContent: (dismissedAd) {
          debugPrint('AdMob: rewarded ad dismissed');
          try {
            dismissedAd.dispose();
          } catch (_) {}
          _rewardedAd = null;
          _notifyRewardedReadinessChanged();
          _loadRewardedAd();
          // If reward was earned before dismiss, onRewardEarned already fired.
          // If not, this is a dismiss-without-reward (user closed early).
          onAdDismissed?.call();
        },
        onAdFailedToShowFullScreenContent: (failedAd, err) {
          debugPrint('AdMob: rewarded ad failed to show: ${err.message}');
          try {
            failedAd.dispose();
          } catch (_) {}
          _rewardedAd = null;
          _notifyRewardedReadinessChanged();
          _loadRewardedAd();
        },
      );
      ad.show(
        onUserEarnedReward: (earnedAd, reward) {
          debugPrint('AdMob: user earned reward: ${reward.amount} ${reward.type}');
          rewardEarned = true;
          // Grant the reward immediately — this fires BEFORE
          // onAdDismissedFullScreenContent, which is fine because
          // we already captured the local `ad` reference above.
          try {
            onRewardEarned();
          } catch (e) {
            debugPrint('AdMob: onRewardEarned callback threw: $e');
          }
        },
      );
      return true;
    } catch (e) {
      debugPrint('Rewarded ad show failed: $e');
      return false;
    }
  }

  /// Whether a rewarded ad is currently loaded and ready to show.
  static bool get isRewardedAdReady => _rewardedAd != null;

  // =========================================================================
  // REWARDED AD PRELOAD + READINESS LISTENERS
  // =========================================================================
  //
  // UI widgets (e.g. the Premium screen's "Watch Ad Now" button) want to
  // reflect whether a rewarded ad is ready, and they want to be notified
  // when it becomes ready. We expose a small listener API for this.

  static final List<VoidCallback> _rewardedReadinessListeners = [];

  /// Subscribe to rewarded-ad readiness changes. The listener is called
  /// whenever the ad transitions between loaded/not-loaded states.
  static void addRewardedReadinessListener(VoidCallback fn) {
    if (!_rewardedReadinessListeners.contains(fn)) {
      _rewardedReadinessListeners.add(fn);
    }
  }

  /// Unsubscribe from rewarded-ad readiness changes.
  static void removeRewardedReadinessListener(VoidCallback fn) {
    _rewardedReadinessListeners.remove(fn);
  }

  /// Notify all subscribed listeners that readiness changed.
  static void _notifyRewardedReadinessChanged() {
    for (final fn in List<VoidCallback>.from(_rewardedReadinessListeners)) {
      try {
        fn();
      } catch (e) {
        debugPrint('Rewarded readiness listener error: $e');
      }
    }
  }

  /// Public preload entry point. Call this when the user opens a screen
  /// that will likely show a rewarded ad (e.g. PremiumScreen, Settings
  /// → PRO TOOLS). If the ad is already loaded or already loading, this
  /// is a no-op.
  static void preloadRewardedAd() {
    if (_rewardedAd != null) return; // Already loaded
    _loadRewardedAd();
  }
}
