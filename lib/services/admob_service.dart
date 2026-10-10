// AdMob Service - disabled
// google_mobile_ads causing native crash after initialization
// Will be re-enabled later with a different approach

class AdMobService {
  static bool get isInitialized => false;
  
  static Future<void> initialize() async {
    // Disabled - no-op
  }
  
  static void showInterstitial() {
    // Disabled - no-op
  }
}
