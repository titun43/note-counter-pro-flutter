import 'package:flutter/material.dart';

class AppColors {
  // Primary brand colors
  static const Color primary = Color(0xFFFBBF24);      // Amber 400
  static const Color primaryDark = Color(0xFFF59E0B);  // Amber 500
  static const Color primaryLight = Color(0xFFFDE68A); // Amber 200
  
  // Background
  static const Color bgDark = Color(0xFF1A1A2E);
  static const Color bgDarker = Color(0xFF0A0A1A);
  static const Color bgLight = Color(0xFFF9FAFB);
  static const Color bgCard = Color(0xFFFFFFFF);
  static const Color bgCardDark = Color(0xFF16213E);
  
  // Text
  static const Color textPrimary = Color(0xFF1F2937);
  static const Color textPrimaryDark = Color(0xFFF9FAFB);
  static const Color textSecondary = Color(0xFF6B7280);
  static const Color textSecondaryDark = Color(0xFF9CA3AF);
  
  // Status
  static const Color success = Color(0xFF10B981);
  static const Color danger = Color(0xFFEF4444);
  static const Color warning = Color(0xFFF59E0B);
  static const Color info = Color(0xFF3B82F6);
  
  // Currencies
  static const Map<String, Color> currencyColors = {
    'INR': Color(0xFF6B7280),    // Gray
    'USD': Color(0xFF10B981),    // Green
    'EUR': Color(0xFF3B82F6),    // Blue
    'GBP': Color(0xFF8B5CF6),    // Purple
    'BDT': Color(0xFF06B6D4),    // Cyan
    'NPR': Color(0xFFEC4899),    // Pink
  };
}

class AppConstants {
  static const String appName = 'Note Counter Pro';
  static const String appVersion = '3.0.0';
  static const int appVersionCode = 30;
  
  static const String packageName = 'com.lokhnathtechnical.notecounterpro';
  static const String playStoreUrl = 'https://play.google.com/store/apps/details?id=com.lokhnathtechnical.notecounterpro';
  static const String privacyPolicyUrl = 'https://titun43.github.io/privacy-policy/';
  static const String supportEmail = 'lokhnathtechnical43@gmail.com';
  
  // AdMob
  static const String admobAppId = 'ca-app-pub-1742730064755213~6546486804';
  static const String admobBannerAdUnitId = 'ca-app-pub-1742730064755213/3078015084';
  static const String admobInterstitialAdUnitId = 'ca-app-pub-1742730064755213/1816904301';
  static const String admobAppOpenAdUnitId = 'ca-app-pub-1742730064755213/7754649667';
  static const String admobRewardedAdUnitId = 'ca-app-pub-1742730064755213/3923215864';
  
  // Currencies
  static const List<Map<String, String>> currencies = [
    {'code': 'INR', 'name': 'Indian Rupee', 'symbol': '₹', 'country': 'India'},
    {'code': 'USD', 'name': 'US Dollar', 'symbol': '\$', 'country': 'USA'},
    {'code': 'EUR', 'name': 'Euro', 'symbol': '€', 'country': 'Europe'},
    {'code': 'GBP', 'name': 'British Pound', 'symbol': '£', 'country': 'UK'},
    {'code': 'BDT', 'name': 'Bangladeshi Taka', 'symbol': '৳', 'country': 'Bangladesh'},
    {'code': 'NPR', 'name': 'Nepalese Rupee', 'symbol': 'रू', 'country': 'Nepal'},
  ];
  
  // Get currency symbol by code
  static String getCurrencySymbol(String code) {
    final currency = currencies.firstWhere(
      (c) => c['code'] == code,
      orElse: () => {'symbol': '₹'},
    );
    return currency['symbol']!;
  }
  
  // Get currency name by code
  static String getCurrencyName(String code) {
    final currency = currencies.firstWhere(
      (c) => c['code'] == code,
      orElse: () => {'name': 'Indian Rupee'},
    );
    return currency['name']!;
  }
  
  // All currency denominations
  static const Map<String, List<Map<String, dynamic>>> denominations = {
    'INR': [
      {'value': 500, 'name': '₹500', 'color': 0xFF10B981},
      {'value': 200, 'name': '₹200', 'color': 0xFFF59E0B},
      {'value': 100, 'name': '₹100', 'color': 0xFF3B82F6},
      {'value': 50, 'name': '₹50', 'color': 0xFF06B6D4},
      {'value': 20, 'name': '₹20', 'color': 0xFFEC4899},
      {'value': 10, 'name': '₹10', 'color': 0xFF6B7280},
      {'value': 5, 'name': '₹5', 'color': 0xFF8B5CF6},
      {'value': 2, 'name': '₹2', 'color': 0xFF10B981},
      {'value': 1, 'name': '₹1', 'color': 0xFFF59E0B},
    ],
    'USD': [
      {'value': 100, 'name': '\$100', 'color': 0xFF10B981},
      {'value': 50, 'name': '\$50', 'color': 0xFF3B82F6},
      {'value': 20, 'name': '\$20', 'color': 0xFFF59E0B},
      {'value': 10, 'name': '\$10', 'color': 0xFF8B5CF6},
      {'value': 5, 'name': '\$5', 'color': 0xFF06B6D4},
      {'value': 2, 'name': '\$2', 'color': 0xFFEC4899},
      {'value': 1, 'name': '\$1', 'color': 0xFF6B7280},
    ],
    'EUR': [
      {'value': 500, 'name': '€500', 'color': 0xFF8B5CF6},
      {'value': 200, 'name': '€200', 'color': 0xFF10B981},
      {'value': 100, 'name': '€100', 'color': 0xFF3B82F6},
      {'value': 50, 'name': '€50', 'color': 0xFFF59E0B},
      {'value': 20, 'name': '€20', 'color': 0xFF06B6D4},
      {'value': 10, 'name': '€10', 'color': 0xFFEC4899},
      {'value': 5, 'name': '€5', 'color': 0xFF6B7280},
      {'value': 2, 'name': '€2', 'color': 0xFF8B5CF6},
      {'value': 1, 'name': '€1', 'color': 0xFF10B981},
    ],
    'GBP': [
      {'value': 50, 'name': '£50', 'color': 0xFF8B5CF6},
      {'value': 20, 'name': '£20', 'color': 0xFF10B981},
      {'value': 10, 'name': '£10', 'color': 0xFF3B82F6},
      {'value': 5, 'name': '£5', 'color': 0xFFF59E0B},
      {'value': 2, 'name': '£2', 'color': 0xFF06B6D4},
      {'value': 1, 'name': '£1', 'color': 0xFFEC4899},
    ],
    'BDT': [
      {'value': 1000, 'name': '৳1000', 'color': 0xFF8B5CF6},
      {'value': 500, 'name': '৳500', 'color': 0xFF10B981},
      {'value': 200, 'name': '৳200', 'color': 0xFFF59E0B},
      {'value': 100, 'name': '৳100', 'color': 0xFF3B82F6},
      {'value': 50, 'name': '৳50', 'color': 0xFF06B6D4},
      {'value': 20, 'name': '৳20', 'color': 0xFFEC4899},
      {'value': 10, 'name': '৳10', 'color': 0xFF6B7280},
      {'value': 5, 'name': '৳5', 'color': 0xFF8B5CF6},
      {'value': 2, 'name': '৳2', 'color': 0xFF10B981},
      {'value': 1, 'name': '৳1', 'color': 0xFFF59E0B},
    ],
    'NPR': [
      {'value': 1000, 'name': 'रू1000', 'color': 0xFF8B5CF6},
      {'value': 500, 'name': 'रू500', 'color': 0xFF10B981},
      {'value': 100, 'name': 'रू100', 'color': 0xFF3B82F6},
      {'value': 50, 'name': 'रू50', 'color': 0xFFF59E0B},
      {'value': 20, 'name': 'रू20', 'color': 0xFF06B6D4},
      {'value': 10, 'name': 'रू10', 'color': 0xFFEC4899},
      {'value': 5, 'name': 'रू5', 'color': 0xFF6B7280},
      {'value': 2, 'name': 'रू2', 'color': 0xFF8B5CF6},
      {'value': 1, 'name': 'रू1', 'color': 0xFF10B981},
    ],
  };
  
  // Get denominations for a currency (fallback to INR)
  static List<Map<String, dynamic>> getDenominations(String currencyCode) {
    return denominations[currencyCode] ?? denominations['INR']!;
  }
  
  // Indian currency denominations (kept for backward compat)
  static const List<Map<String, dynamic>> inrDenominations = [
    {'value': 500, 'name': '₹500', 'color': 0xFF10B981},
    {'value': 200, 'name': '₹200', 'color': 0xFFF59E0B},
    {'value': 100, 'name': '₹100', 'color': 0xFF3B82F6},
    {'value': 50, 'name': '₹50', 'color': 0xFF06B6D4},
    {'value': 20, 'name': '₹20', 'color': 0xFFEC4899},
    {'value': 10, 'name': '₹10', 'color': 0xFF6B7280},
    {'value': 5, 'name': '₹5', 'color': 0xFF8B5CF6},
    {'value': 2, 'name': '₹2', 'color': 0xFF10B981},
    {'value': 1, 'name': '₹1', 'color': 0xFFF59E0B},
  ];
  
  // Languages (only these 3 are supported with full translations)
  static const List<Map<String, String>> languages = [
    {'code': 'en', 'name': 'English'},
    {'code': 'bn', 'name': 'বাংলা (Bengali)'},
    {'code': 'hi', 'name': 'हिंदी (Hindi)'},
  ];
}

class AppRoutes {
  static const String home = '/';
  static const String calculator = '/calculator';
  static const String customers = '/customers';
  static const String customerDetail = '/customer-detail';
  static const String khata = '/khata';
  static const String bills = '/bills';
  static const String billDetail = '/bill-detail';
  static const String reports = '/reports';
  static const String settings = '/settings';
  static const String upiQr = '/upi-qr';
  static const String exportData = '/export-data';
  static const String about = '/about';
}
