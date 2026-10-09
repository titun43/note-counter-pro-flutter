import 'package:google_mobile_ads/google_mobile_ads.dart';
import '../utils/constants.dart';

class AdMobService {
  static bool _initialized = false;
  static BannerAd? _bannerAd;
  static InterstitialAd? _interstitialAd;
  static int _interstitialLoadAttempts = 0;
  
  static Future<void> initialize() async {
    if (_initialized) return;
    await MobileAds.instance.initialize();
    _initialized = true;
    _loadBannerAd();
    _loadInterstitialAd();
  }
  
  static void _loadBannerAd() {
    _bannerAd = BannerAd(
      adUnitId: AppConstants.admobBannerAdUnitId,
      size: AdSize.banner,
      request: const AdRequest(),
      listener: BannerAdListener(
        onAdLoaded: (_) {},
        onAdFailedToLoad: (ad, err) {
          ad.dispose();
        },
      ),
    );
    _bannerAd?.load();
  }
  
  static BannerAd? get bannerAd => _bannerAd;
  
  static void _loadInterstitialAd() {
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
