import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import '../utils/constants.dart';

class AdMobService {
  static bool _initialized = false;
  static InterstitialAd? _interstitialAd;
  static int _interstitialLoadAttempts = 0;

  /// TEST MODE: Set to false when user says "real ads on"
  /// When true, uses Google's official test ad unit IDs (always serve ads)
  /// When false, uses real AdMob ad unit IDs from AppConstants
  ///
  /// Currently: TEST MODE ON (real ads OFF)
  /// Developer will test the build, then ask to turn real ads ON.
  static const bool useTestAds = true;

  /// Google's official test ad unit IDs (always serve, safe for testing)
  static const String _testBannerAdUnitId =
      'ca-app-pub-3940256099942544/6300978111';
  static const String _testInterstitialAdUnitId =
      'ca-app-pub-3940256099942544/1033173712';

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

  /// Initialize AdMob - safe, won't crash app
  static Future<void> initialize() async {
    if (_initialized) return;

    try {
      debugPrint('AdMob: initializing (test mode: $useTestAds)');
      await MobileAds.instance.initialize();
      _initialized = true;
      _loadInterstitialAd();
      debugPrint('AdMob: initialized successfully');
    } catch (e) {
      debugPrint('AdMob init failed (non-fatal): $e');
    }
  }

  static bool get isInitialized => _initialized;

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
}
