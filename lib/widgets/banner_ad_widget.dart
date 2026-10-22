import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../services/admob_service.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

class BannerAdWidget extends StatefulWidget {
  const BannerAdWidget({super.key});

  @override
  State<BannerAdWidget> createState() => _BannerAdWidgetState();
}

class _BannerAdWidgetState extends State<BannerAdWidget> {
  BannerAd? _bannerAd;
  bool _isLoaded = false;

  @override
  void initState() {
    super.initState();
    _loadAd();
  }

  void _loadAd() {
    if (!AdMobService.isInitialized) {
      // Try again in 2 seconds if AdMob not ready yet
      Future.delayed(const Duration(seconds: 2), _loadAd);
      return;
    }

    _bannerAd = BannerAd(
      adUnitId: AdMobService.bannerAdUnitId,
      size: AdSize.banner,
      request: const AdRequest(),
      listener: BannerAdListener(
        onAdLoaded: (_) {
          debugPrint('BannerAd: loaded successfully');
          setState(() {
            _isLoaded = true;
          });
        },
        onAdFailedToLoad: (ad, err) {
          debugPrint('BannerAd: failed to load: ${err.message}');
          ad.dispose();
        },
      ),
    );
    _bannerAd?.load();
  }

  @override
  void dispose() {
    _bannerAd?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Premium users never see banner ads
    if (!AdMobService.shouldShowAds) {
      return const SizedBox.shrink();
    }
    if (!_isLoaded || _bannerAd == null) {
      return const SizedBox(height: 50);
    }
    return SizedBox(
      width: double.infinity,
      height: 50,
      child: AdWidget(ad: _bannerAd!),
    );
  }
}
