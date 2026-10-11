import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import '../services/admob_service.dart';
import '../utils/constants.dart';

/// Banner Ad Widget
///
/// Behavior:
/// - When ad is NOT loaded: shows nothing (SizedBox.shrink), no loading spinner
/// - When ad IS loaded: shows the banner ad
/// - Retries silently in the background until ad loads or max retries reached
///
/// This avoids the "infinite loading spinner" UX issue where users see
/// a spinner forever when ads fail to load (e.g., no internet, ad blocker,
/// or AdMob not yet initialized).
class BannerAdWidget extends StatefulWidget {
  const BannerAdWidget({super.key});

  @override
  State<BannerAdWidget> createState() => _BannerAdWidgetState();
}

class _BannerAdWidgetState extends State<BannerAdWidget>
    with WidgetsBindingObserver {
  BannerAd? _bannerAd;
  bool _isLoaded = false;
  Timer? _retryTimer;
  int _retryCount = 0;
  static const int _maxRetries = 20;
  static const Duration _retryInterval = Duration(seconds: 3);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // Start loading after a short delay to allow AdMob to initialize
    _retryTimer = Timer(const Duration(seconds: 1), _loadAd);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Reload ad when app resumes (ad may have been disposed by system)
    if (state == AppLifecycleState.resumed && !_isLoaded) {
      _retryCount = 0;
      _loadAd();
    }
  }

  void _loadAd() {
    // Check if AdMob is initialized
    if (!AdMobService.isInitialized) {
      _retryCount++;
      if (_retryCount < _maxRetries) {
        _retryTimer = Timer(_retryInterval, _loadAd);
      }
      return;
    }

    // Dispose previous ad if any
    _bannerAd?.dispose();

    _bannerAd = BannerAd(
      adUnitId: AppConstants.admobBannerAdUnitId,
      size: AdSize.banner,
      request: const AdRequest(),
      listener: BannerAdListener(
        onAdLoaded: (_) {
          if (mounted) {
            setState(() {
              _isLoaded = true;
            });
          }
        },
        onAdFailedToLoad: (ad, err) {
          ad.dispose();
          _isLoaded = false;
          _retryCount++;
          if (_retryCount < _maxRetries && mounted) {
            _retryTimer = Timer(_retryInterval, _loadAd);
          }
        },
      ),
    );
    _bannerAd?.load();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _retryTimer?.cancel();
    _bannerAd?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // If ad is not loaded, show nothing (no spinner!)
    if (!_isLoaded || _bannerAd == null) {
      return const SizedBox.shrink();
    }
    // Ad is loaded, show it
    return SizedBox(
      width: double.infinity,
      height: 50,
      child: AdWidget(ad: _bannerAd!),
    );
  }
}
