import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import '../utils/constants.dart';

class AdMobService {
  static bool _initialized = false;
  static bool _initializing = false;
  static BannerAd? _bannerAd;
  static InterstitialAd? _interstitialAd;
  static int _interstitialLoadAttempts = 0;
  
  /// Initialize AdMob with lazy loading and error handling
  /// This won't crash the app even if AdMob fails
  static Future<void> initialize() async {
    if (_initialized || _initializing) return;
    _initializing = true;
    
    try {
      await MobileAds.instance.initialize();
      _initialized = true;
      _loadBannerAd();
      _loadInterstitialAd();
    } catch (e) {
      debugPrint('AdMob init failed (non-fatal): $e');
      _initialized = false;
    } finally {
      _initializing = false;
    }
  }
  
  static void _loadBannerAd() {
    try {
      _bannerAd = BannerAd(
        adUnitId: AppConstants.admobBannerAdUnitId,
        size: AdSize.banner,
        request: const AdRequest(),
        listener: BannerAdListener(
          onAdLoaded: (_) {
            debugPrint('Banner ad loaded');
          },
          onAdFailedToLoad: (ad, err) {
            debugPrint('Banner ad failed: $err');
            ad.dispose();
          },
        ),
      );
      _bannerAd?.load();
    } catch (e) {
      debugPrint('Banner ad load failed: $e');
    }
  }
  
  static BannerAd? get bannerAd => _bannerAd;
  static bool get isInitialized => _initialized;
  
  static void _loadInterstitialAd() {
    try {
      InterstitialAd.load(
        adUnitId: AppConstants.admobInterstitialAdUnitId,
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
    }
  }
}
