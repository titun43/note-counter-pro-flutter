# 📌 Note Counter Pro — Project Memory (Working Guidelines)

> **প্রতিটি কাজে এই checklist মেনে চলা বাধ্যতামূলক:**

## ✅ মনে রাখার তালিকা (প্রতি কাজে)

| # | Rule | Description |
|---|------|-------------|
| 1 | **Fresh clone from GitHub** | প্রতি কাজের শুরুতে `git fetch flutter && git reset --hard flutter/main` দিয়ে fresh state এ আসতে হবে। তারপর change apply করতে হবে। |
| 2 | **3 languages (en/bn/hi)** | সব নতুন user-facing string `lib/utils/app_localizations.dart` এ তিন ভাষায় যোগ করতে হবে — English (line ~194-), Bengali (line ~677-), Hindi (line ~1160-)। হার্ডকোডেড স্ট্রিং নয়। |
| 3 | **Dark/Light mode** | প্রতিটি UI component এ `final isDark = theme.brightness == Brightness.dark;` check করতে হবে। দুটো মোডেই কালার/গ্রেডিয়েন্ট/শ্যাডো সঠিক দেখাতে হবে। |
| 4 | **Ads (interstitial + banner, AdMob policy)** | `BannerAdWidget` top এ থাকবে। Interstitial শুধুমাত্র user action (button tap) এর পরে দেখাবে — কখনো automatic নয়। AdMob policy compliant। |

---

## 🗂️ Project Structure (Critical — ভুল করবেন না)

### সঠিক Flutter project root:
```
/home/z/my-project/          ← Flutter project (lib/, android/, pubspec.yaml)
├── lib/
│   ├── main.dart            ← MainScaffold with 5 tabs + top BannerAd
│   ├── screens/
│   │   ├── smart_pay_screen.dart    ← ⚠️ DEAD FILE (ব্যবহৃত হয় না)
│   │   ├── upi_tools_screen.dart    ← ✅ আসল Smart Pay UI (premium user দেখে)
│   │   ├── upi_tab_screen.dart      ← Smart Pay tab wrapper (premium gate → UpiToolsScreen)
│   │   ├── calculator_screen.dart   ← Calculator screen (Tools থেকে open)
│   │   ├── standard_calculator.dart
│   │   ├── scientific_calculator.dart
│   │   ├── programmer_calculator.dart
│   │   ├── emi_calculator.dart
│   │   ├── gst_calculator.dart
│   │   ├── date_calculator.dart
│   │   ├── tools_tab_screen.dart    ← Tools tab (Calculator, EMI, GST, Date, QR, etc.)
│   │   └── ...
│   ├── services/
│   │   ├── admob_service.dart       ← AdMob (interstitial + banner + rewarded)
│   │   ├── premium_service.dart     ← Premium subscription check
│   │   ├── storage_service.dart     ← SharedPreferences (UPI scan history, etc.)
│   │   └── ...
│   ├── utils/
│   │   ├── app_localizations.dart   ← 3 ভাষার string (en/bn/hi)
│   │   ├── constants.dart           ← AppColors, AppConstants
│   │   └── themes.dart              ← Light/Dark theme
│   ├── widgets/
│   │   ├── banner_ad_widget.dart    ← Banner ad (top of every screen)
│   │   ├── glass_nav_bar.dart       ← Bottom nav (5 tabs: Counter, Khata, UPI/Smart Pay, Tools, Settings)
│   │   └── ...
│   ├── models/
│   └── main.dart                    ← NoteCounterProApp + MainScaffold
├── android/
├── pubspec.yaml                     ← version: 3.36.2+164
└── .github/workflows/build-flutter.yml  ← GitHub Actions (push to main → APK+AAB build → Release)
```

### ⚠️ ভুল করবেন না (আগে হয়েছে):
- `smart_pay_screen.dart` edit করলে কিছু হবে না — এটা dead file।
- Smart Pay UI আসলে `upi_tools_screen.dart` তে আছে।
- Edit করার আগে `grep -rn "ClassName" lib/` দিয়ে verify করুন কোন file ব্যবহৃত হচ্ছে।

---

## 🌿 Git Workflow

### Remote:
```
flutter  →  https://github.com/titun43/note-counter-pro-flutter.git  (origin equivalent)
branch   →  main
```

### প্রতি কাজের workflow:
```bash
# ১. Fresh state এ আসুন
cd /home/z/my-project
git fetch flutter
git reset --hard flutter/main

# ২. Code edit করুন (lib/...)
# ৩. Localization যোগ করুন (3 ভাষায়)
# ৪. Dark/Light দুটো মোডে verify করুন
# ৫. AdMob policy check করুন
# ৬. Commit করুন
git add <files>
git commit -m "feat/fix: <description>"

# ৭. Push করুন (GitHub Actions auto-trigger হবে)
git push flutter main
```

### Commit message convention:
- `feat:` — new feature
- `fix:` — bug fix
- `refactor:` — code restructure
- `docs:` — documentation

---

## 🏗️ Build & Release

### GitHub Actions workflow:
- File: `.github/workflows/build-flutter.yml`
- Trigger: push to `main`
- Steps: `flutter pub get` → `flutter analyze` → `flutter build apk` + `aab` → GitHub Release
- Flutter version: 3.47.8 (Dart 3.13.7)
- Target: android-arm64, android-x64
- Build time: ~5-10 minutes

### Release:
- APK: `note-counter-pro.apk` (~70 MB)
- AAB: `note-counter-pro.aab` (~58 MB, signed — Play Store ready)
- Release page: https://github.com/titun43/note-counter-pro-flutter/releases/latest
- Tag format: `v{version}-flutter` (e.g., `v3.36.2-flutter`)

### Build status check:
```bash
# Authenticated API call (rate limit safe)
TOKEN=$(git remote get-url flutter | sed -n 's|https://[^:]*:\([^@]*\)@.*|\1|p')
curl -s -H "Authorization: token $TOKEN" \
  "https://api.github.com/repos/titun43/note-counter-pro-flutter/actions/runs?per_page=5" \
  | python3 -c "import json,sys; [print(f\"{r['id']} | {r['status']} | {r['conclusion']} | {r['head_sha'][:7]} | {r['head_commit']['message'].split(chr(10))[0][:60]}\") for r in json.load(sys.stdin).get('workflow_runs',[])[:5]]"
```

---

## 🎨 Design System (Smart Pay style — gold/dark accent)

### Colors:
| Token | Light | Dark |
|-------|-------|------|
| `AppColors.primary` | Gold/Dark yellow | Gold |
| `AppColors.bgLight` / `AppColors.bgDark` | #F5F5F5 / dark | dark |
| `AppColors.bgCard` / `AppColors.bgCardDark` | white / dark grey | dark grey |
| `AppColors.success` | Green | Green |
| `AppColors.danger` | Red | Red |
| `AppColors.info` | Blue | Blue |
| `AppColors.warning` | Orange | Orange |
| Gold accent | `Color(0xFFD4AF37)` | `Color(0xFFD4AF37)` |

### Gradient (gold):
```dart
LinearGradient(
  begin: Alignment.topLeft,
  end: Alignment.bottomRight,
  colors: [Color(0xFFD4AF37), Color(0xFFB8941F)],
)
```

### Avatar gradient palette (Smart Pay history):
```dart
static const List<List<Color>> _avatarGradients = [
  [Color(0xFF667EEA), Color(0xFF764BA2)],  // purple
  [Color(0xFFF093FB), Color(0xFFF5576C)],  // pink
  [Color(0xFF4FACFE), Color(0xFF00F2FE)],  // blue
  [Color(0xFF43E97B), Color(0xFF38F9D7)],  // green
  [Color(0xFFFA709A), Color(0xFFFEE140)],  // orange
];
```

---

## 📱 5-Tabs Layout (MainScaffold)

| # | Tab | Screen | Notes |
|---|-----|--------|-------|
| 0 | Counter | `HomeScreen` | Note counting (main feature) |
| 1 | Khata | `KhataScreen` | Customer ledger |
| 2 | UPI (Smart Pay) | `UpiTabScreen` → `UpiToolsScreen` | Premium-only — scan QR from gallery |
| 3 | Tools | `ToolsTabScreen` | Calculator, EMI, GST, Date, QR, etc. |
| 4 | Settings | `SettingsScreen` | App settings |

**Top:** `BannerAdWidget` (SafeArea top) — সব tab এ দেখায় (premium user ছাড়া)
**Bottom:** `GlassNavBar` — 5 tabs

---

## 🔒 Premium Features

| Feature | Screen | Premium? |
|---------|--------|----------|
| Smart Pay (Scan QR) | `upi_tools_screen.dart` | ✅ Yes |
| Generate QR | `qr_generator_screen.dart` | ✅ Yes |
| Send Money | `send_money_screen.dart` | ✅ Yes |
| Saved UPI | `saved_upi_screen.dart` | ✅ Yes |
| Printer | `printer_screen.dart` | ✅ Yes |
| Calculator (all modes) | `calculator_screen.dart` | ❌ Free |
| EMI/GST/Date Calc | `emi_calculator.dart` etc. | ❌ Free |
| Currency Converter | `converter_screen.dart` | ❌ Free |

`PremiumService().isPremium` — check করতে হবে premium feature এ ঢোকার আগে।

---

## 🌍 Localization (3 languages)

### File: `lib/utils/app_localizations.dart`

### Languages:
1. **English (en)** — line ~180-450
2. **Bengali (bn)** — line ~660-960
3. **Hindi (hi)** — line ~1140-1450

### Usage:
```dart
final loc = context.loc;
loc.t('keyName')  // returns localized string
```

### Add new key — 3 places এ যোগ করতে হবে:
1. English block (~line 386-394 area)
2. Bengali block (~line 869-877 area)
3. Hindi block (~line 1352-1360 area)

---

## 🚨 Common Pitfalls (যা এড়াতে হবে)

### ১. Dead file edit করা
- ❌ `smart_pay_screen.dart` — dead file, edit করলে কিছু হবে না
- ✅ `upi_tools_screen.dart` — এটাই আসল Smart Pay UI
- **Verify:** `grep -rn "ClassName" lib/` দিয়ে দেখুন কোথায় ব্যবহৃত হচ্ছে

### ২. Hardcoded string
- ❌ `Text('Hello')`
- ✅ `Text(loc.t('helloKey'))` + 3 ভাষায় key যোগ করুন

### ৩. Light mode তে শুধু test করা
- সবসময় `isDark` check করুন, দুটো মোডে verify করুন

### ৪. Auto interstitial ad
- ❌ `initState` এ বা page load এ interstitial
- ✅ User action (button tap) এর পরে interstitial — AdMob policy

### ৫. Calculator `standalone` confusion
- `CalculatorScreen` সবসময় standalone (Navigator.push দিয়ে open হয়)
- Tab হিসেবে MainScaffold এ নেই
- `standalone = true` সবসময়

---

## 📝 Recent Commits (reference)

```
cd95685 fix: apply Smart Pay redesign to the ACTUAL screen (upi_tools_screen.dart)
2972080 feat: Smart Pay redesign — 5 improvements + 3 languages (⚠️ wrong file)
b6eb9db fix: Tools tab calculator title bar overlapping status bar
4f2fc8f Revert "feat: add banner ad to calculator tab mode" (wrong fix)
f0588c2 feat: add banner ad to calculator tab mode (wrong fix)
53efc51 fix: add flutter clean before build — Gradle cache issue
534eeb8 fix: calculator content stuck at top — SizedBox.expand
```

---

## 🎯 Smart Pay Design (5 Improvements — completed)

1. **Limit box** — soft gold shadow + rounded 20px + modern icon badges (red info circle + green check badge)
2. **Segmented Pill Control** — Gallery/Camera tabs, active = gold gradient + shadow
3. **Gallery button** — gradient bg + gold border + icon badge + "Browse from Device" gold button
4. **History cards** — Avatar/Initials badge (5 gradient palette cycle)
5. **Delete icon** — muted grey + confirmation dialog (Cancel/Delete)

---

## 🔄 পরবর্তী session এ যা করবেন:

১. এই file টা পড়ুন — `/home/z/my-project/PROJECT_MEMORY.md`
২. `git log --oneline -5` দিয়ে latest state দেখুন
৩. User এর নতুন requirement শুনুন
৪. Checklist মেনে চলুন:
   - ✅ Fresh clone
   - ✅ 3 languages
   - ✅ Dark/Light mode
   - ✅ Ads (AdMob policy)
৫. সঠিক file identify করে edit করুন (dead file নয়)
৬. Commit + push → GitHub Actions build → APK release

---

**Last updated:** 2026-10-31 (commit `cd95685`)
**Project:** Note Counter Pro (Flutter) v3.36.2+164
**Owner:** titun43
**Repo:** https://github.com/titun43/note-counter-pro-flutter
