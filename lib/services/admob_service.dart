import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import '../utils/constants.dart';

class AdMobService {
  static bool _initialized = false;
  static bool _initializing = false;
  static InterstitialAd? _interstitialAd;
  static int _interstitialLoadAttempts = 0;
  static int _initRetryCount = 0;
  static const int _maxInitRetries = 5;

  /// Initialize AdMob - safe, won't crash app.
  /// Retries up to 5 times on failure (10s interval).
  static Future<void> initialize() async {
    if (_initialized || _initializing) return;
    _initializing = true;

    try {
      debugPrint('AdMob: initializing...');
      final status = await MobileAds.instance.initialize();
      _initialized = true;
      _initializing = false;
      _initRetryCount = 0;
      debugPrint('AdMob: initialized successfully. Adapters: ${status.adapterStatuses.length}');
      _loadInterstitialAd();
    } catch (e) {
      _initializing = false;
      _initRetryCount++;
      debugPrint('AdMob init failed (attempt $_initRetryCount/$_maxInitRetries): $e');
      if (_initRetryCount < _maxInitRetries) {
        // Retry after 10 seconds
        Timer(const Duration(seconds: 10), initialize);
      }
    }
  }

  /// Get banner ad unit ID — uses Google test ad unit in debug mode
  /// (real AdMob doesn't serve ads to debug builds reliably)
  static String get bannerAdUnitId {
    if (kDebugMode) {
      // Google's official banner test ad unit ID
      return 'ca-app-pub-3940256099942544/6300978111';
    }
    return AppConstants.admobBannerAdUnitId;
  }

  /// Get interstitial ad unit ID — uses Google test ad unit in debug mode
  static String get interstitialAdUnitId {
    if (kDebugMode) {
      // Google's official interstitial test ad unit ID
      return 'ca-app-pub-3940256099942544/1033173712';
    }
    return AppConstants.admobInterstitialAdUnitId;
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
          },
          onAdFailedToLoad: (err) {
            _interstitialLoadAttempts++;
            _interstitialAd = null;
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
