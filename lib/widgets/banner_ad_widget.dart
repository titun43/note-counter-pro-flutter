import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import '../services/admob_service.dart';

/// Banner Ad Widget
///
/// Behavior:
/// - Starts loading immediately on initState (don't wait for AdMob isInitialized)
/// - When ad is NOT loaded:
///   - Debug mode: shows a small "Ad" placeholder with tap-to-retry
///   - Release mode: shows nothing (SizedBox.shrink)
/// - When ad IS loaded: shows the banner ad
/// - Retries silently: max 50 attempts, 2s interval (100s total)
/// - Tapping the placeholder triggers immediate reload
class BannerAdWidget extends StatefulWidget {
  const BannerAdWidget({super.key});

  @override
  State<BannerAdWidget> createState() => _BannerAdWidgetState();
}

class _BannerAdWidgetState extends State<BannerAdWidget>
    with WidgetsBindingObserver {
  BannerAd? _bannerAd;
  bool _isLoaded = false;
  bool _isLoading = false;
  Timer? _retryTimer;
  int _retryCount = 0;
  static const int _maxRetries = 50;
  static const Duration _retryInterval = Duration(seconds: 2);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // Start loading immediately
    _loadAd();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Reload ad when app resumes
    if (state == AppLifecycleState.resumed && !_isLoaded) {
      _retryCount = 0;
      _loadAd();
    }
  }

  void _loadAd() {
    if (_isLoading) return;
    _isLoading = true;

    // Dispose previous ad if any
    _bannerAd?.dispose();
    _bannerAd = null;
    _isLoaded = false;

    _bannerAd = BannerAd(
      adUnitId: AdMobService.bannerAdUnitId,
      size: AdSize.banner,
      request: const AdRequest(),
      listener: BannerAdListener(
        onAdLoaded: (_) {
          debugPrint('BannerAd: loaded successfully (attempt $_retryCount)');
          if (mounted) {
            setState(() {
              _isLoaded = true;
              _isLoading = false;
            });
          }
        },
        onAdFailedToLoad: (ad, err) {
          debugPrint('BannerAd: failed to load (attempt $_retryCount): ${err.message}');
          ad.dispose();
          _isLoaded = false;
          _isLoading = false;
          _retryCount++;
          if (_retryCount < _maxRetries && mounted) {
            _retryTimer = Timer(_retryInterval, _loadAd);
          } else if (mounted) {
            setState(() {}); // Update UI to show retry placeholder
          }
        },
      ),
    );
    _bannerAd?.load();
  }

  void _manualRetry() {
    _retryCount = 0;
    _loadAd();
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
    // Ad is loaded, show it
    if (_isLoaded && _bannerAd != null) {
      return Container(
        width: double.infinity,
        height: 50,
        color: Colors.transparent,
        child: AdWidget(ad: _bannerAd!),
      );
    }

    // Ad is not loaded
    // Debug mode: show tap-to-retry placeholder so user/dev can see something is happening
    if (kDebugMode) {
      return GestureDetector(
        onTap: _manualRetry,
        child: Container(
          width: double.infinity,
          height: 50,
          color: Colors.grey[200],
          child: Center(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (_isLoading)
                  const SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                else
                  Icon(Icons.refresh, size: 16, color: Colors.grey[600]),
                const SizedBox(width: 6),
                Text(
                  _retryCount >= _maxRetries
                      ? 'Ad failed - tap to retry'
                      : 'Loading ad... (tap to retry)',
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    // Release mode: show nothing
    return const SizedBox.shrink();
  }
}
