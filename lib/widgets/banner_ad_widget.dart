import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../services/admob_service.dart';
import '../services/premium_service.dart';
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
    // CRITICAL: listen to PremiumService so that when a rewarded-ad trial
    // is granted (or any premium state change), this widget immediately
    // disposes the loaded banner ad AND hides itself via setState.
    // Without this listener, the banner stays visible on the current
    // screen until the user navigates away and back.
    PremiumService().addListener(_onPremiumChanged);
  }

  void _onPremiumChanged() {
    if (!mounted) return;
    if (PremiumService().isPremium) {
      // Premium just activated — dispose the banner ad to free memory
      // and hide the widget.
      _bannerAd?.dispose();
      _bannerAd = null;
      setState(() => _isLoaded = false);
    } else {
      // Premium just deactivated — reload the banner ad so it shows.
      if (_bannerAd == null) _loadAd();
    }
  }

  void _loadAd() {
    if (!AdMobService.isInitialized) {
      // Try again in 2 seconds if AdMob not ready yet
      Future.delayed(const Duration(seconds: 2), _loadAd);
      return;
    }

    // Don't load ad if user is premium — saves a network request
    if (!AdMobService.shouldShowAds) return;

    _bannerAd = BannerAd(
      adUnitId: AdMobService.bannerAdUnitId,
      size: AdSize.banner,
      request: const AdRequest(),
      listener: BannerAdListener(
        onAdLoaded: (_) {
          debugPrint('BannerAd: loaded successfully');
          if (mounted) {
            setState(() {
              _isLoaded = true;
            });
          }
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
    PremiumService().removeListener(_onPremiumChanged);
    _bannerAd?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Premium users never see banner ads — this check now triggers an
    // immediate rebuild because we listen to PremiumService changes.
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
