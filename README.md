# Note Counter Pro - Flutter

Professional Cash Note Counter App - Rebuilt from scratch with Flutter.

## 🎯 About

This is a complete rewrite of Note Counter Pro in Flutter. The original app was a Capacitor + Next.js hybrid app, but this Flutter version provides:
- Full source code control
- Native performance
- Better maintainability
- iOS support (future)
- All features customizable

## ✨ Features

- **Note Counter** - Multi-currency cash counting with denomination tracking
- **Calculator** - Built-in calculator with history
- **Customer Management** - Track customers with credit/debit
- **Khata** - Lend/borrow tracking with balance summary
- **Bills** - Create and manage bills with GST support
- **Reports** - Weekly, monthly, and all-time statistics
- **UPI QR Code** - Generate UPI payment QR codes
- **CSV Export** - Export entries and customers to Excel/Sheets
- **Rate & Share** - Rate on Play Store, share with friends
- **Settings** - Full app customization
- **AdMob** - Banner and interstitial ads
- **Dark/Light Theme** - Toggle dark mode
- **Multi-language** - 8 languages supported

## 🛠️ Tech Stack

- **Framework**: Flutter 3.24+
- **Language**: Dart 3.0+
- **State Management**: Provider
- **Local Storage**: SharedPreferences + JSON
- **Ads**: google_mobile_ads
- **QR Code**: qr_flutter
- **Share**: share_plus
- **URL Launcher**: url_launcher

## 📱 Build Info

- **Package**: `com.lokhnathtechnical.notecounterpro`
- **Version**: 3.0.0 (versionCode: 30)
- **Min SDK**: 24 (Android 7.0)
- **Target SDK**: 34 (Android 14)

## 🚀 Getting Started

```bash
# Install dependencies
flutter pub get

# Run in debug mode
flutter run

# Build APK
flutter build apk --release

# Build AAB
flutter build appbundle --release
```

## 📁 Project Structure

```
lib/
├── main.dart                      # App entry point
├── models/
│   ├── entry.dart                 # Entry model
│   ├── customer.dart              # Customer model
│   └── bill.dart                  # Bill + BillItem models
├── services/
│   ├── storage_service.dart       # Local storage (SharedPreferences)
│   └── admob_service.dart         # AdMob integration
├── screens/
│   ├── home_screen.dart           # Note Counter
│   ├── calculator_screen.dart     # Calculator
│   ├── customers_screen.dart      # Customer list
│   ├── customer_detail_screen.dart # Customer detail
│   ├── khata_screen.dart          # Lend/Borrow
│   ├── bills_screen.dart          # Bills
│   ├── reports_screen.dart        # Reports
│   ├── settings_screen.dart       # Settings
│   └── upi_qr_screen.dart         # UPI QR generator
├── utils/
│   ├── constants.dart             # App constants
│   └── themes.dart                # Light/Dark themes
└── widgets/                       # Reusable widgets
```

## 📝 License

Proprietary - All rights reserved.

## 👨‍💻 Developer

**Titun Das**
- Email: lokhnathtechnical43@gmail.com
- GitHub: [@titun43](https://github.com/titun43)
