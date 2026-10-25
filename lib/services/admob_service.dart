import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import '../utils/constants.dart';
import 'premium_service.dart';

class AdMobService {
  static bool _initialized = false;
  static InterstitialAd? _interstitialAd;
  static int _interstitialLoadAttempts = 0;

  // App Open ad state
  static AppOpenAd? _appOpenAd;
  static int _appOpenLoadAttempts = 0;
  static DateTime? _appOpenLoadTime;
  static bool _isShowingAppOpen = false;

  // Rewarded ad state
  static RewardedAd? _rewardedAd;
  static int _rewardedLoadAttempts = 0;

  /// TEST MODE flag — controls whether test or real ad unit IDs are used.
  ///
  /// When true:  uses Google's official test ad unit IDs (always serve ads,
  ///             safe for development).
  /// When false: uses real AdMob ad unit IDs from AppConstants.
  ///
  /// Currently: TEST MODE ON — developer is testing before Play Store release.
  /// Workflow:
  ///   1. Developer asks agent to "test mode on" → useTestAds = true
  ///   2. Developer tests the build (sees test ads with "Test Ad" label)
  ///   3. Developer says "ready for Play Store, real ads on"
  ///   4. Agent sets useTestAds = false, commits, pushes
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
  static bool get shouldShowAds => !PremiumService().isPremium;

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
  /// Returns true if the ad was shown.
  static bool showAppOpenAd() {
    if (!shouldShowAds) return false;
    if (_isShowingAppOpen) return false;
    if (!_isAppOpenAdAvailable) {
      _loadAppOpenAd();
      return false;
    }

    try {
      _isShowingAppOpen = true;
      _appOpenAd!.fullScreenContentCallback = FullScreenContentCallback(
        onAdDismissedFullScreenContent: (ad) {
          ad.dispose();
          _appOpenAd = null;
          _appOpenLoadTime = null;
          _isShowingAppOpen = false;
          _loadAppOpenAd();
        },
        onAdFailedToShowFullScreenContent: (ad, err) {
          ad.dispose();
          _appOpenAd = null;
          _appOpenLoadTime = null;
          _isShowingAppOpen = false;
          _loadAppOpenAd();
        },
      );
      _appOpenAd!.show();
      return true;
    } catch (e) {
      debugPrint('App open ad show failed: $e');
      _isShowingAppOpen = false;
      return false;
    }
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
          },
          onAdFailedToLoad: (err) {
            _rewardedLoadAttempts++;
            _rewardedAd = null;
            debugPrint('AdMob: rewarded ad failed to load (attempt $_rewardedLoadAttempts): ${err.message}');
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
  static bool showRewardedAd({
    required VoidCallback onRewardEarned,
    VoidCallback? onAdDismissed,
  }) {
    if (!shouldShowAds) return false;

    if (_rewardedAd == null) {
      _loadRewardedAd();
      return false;
    }

    try {
      _rewardedAd!.fullScreenContentCallback = FullScreenContentCallback(
        onAdDismissedFullScreenContent: (ad) {
          ad.dispose();
          _rewardedAd = null;
          _loadRewardedAd();
          onAdDismissed?.call();
        },
        onAdFailedToShowFullScreenContent: (ad, err) {
          ad.dispose();
          _rewardedAd = null;
          _loadRewardedAd();
        },
      );
      _rewardedAd!.show(
        onUserEarnedReward: (ad, reward) {
          debugPrint('AdMob: user earned reward: ${reward.amount} ${reward.type}');
          onRewardEarned();
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
}
