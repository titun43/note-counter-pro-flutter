# Note Counter Pro — Listing vs Code Audit

**Source:** Fresh clone from GitHub (`titun43/note-counter-pro-flutter`, HEAD `eae8ec5`, v3.62.5+241)
**Audited:** 2026-11-16
**Method:** grep + code inspection of all 40+ screens in `lib/screens/`

> Goal: verify every claim in the current Play Store listing against what the
> code actually contains. FALSE claims risk Google suspension / listing rejection.

---

## ✅ VERIFIED TRUE (keep in listing)

| Claim | Evidence |
|------|---------|
| Note counter with all INR denominations (2000/500/200/100/50/20/10/5/2/1) | `home_screen.dart` denomination switch |
| Multi-currency support | `constants.dart` → 6 currencies: INR, USD, EUR, GBP, BDT, NPR |
| Professional billing / invoice maker | `bill_form_screen.dart`: bill number, customer, items, GST, discount, due date, real-time totals |
| Digital khata (ledger) with udhaar tracking | `khata_screen.dart`, `customers_screen.dart`, `customer_detail_screen.dart` |
| SMS / WhatsApp payment reminders | `khata_screen.dart`: `url_launcher`, `_openWhatsApp()`, `_sendReminderToAll()`, WhatsApp channel |
| Google Drive backup & restore (premium) | `cloud_backup_screen.dart`, `cloud_backup_service.dart`; pubspec: `googleapis`, `google_sign_in`, `googleapis_auth` |
| Works offline (no internet for core) | SharedPreferences-based storage; no Firebase for core |
| Free with optional premium upgrade | `premium_screen.dart` |
| Lightweight & fast | confirmed (small asset footprint) |

---

## ❌ FALSE / INACCURATE (must fix — suspension risk)

| Claim | Reality | Severity |
|------|---------|---------|
| **"25+ Indian languages"** | Only **3** languages: English, Bengali, Hindi (`AppConstants.languages` in `constants.dart`) | 🔴 HIGH — clear false claim, policy violation |
| **"Business mode to track who gave which amount"** | No such counter mode exists. "business" only appears as business NAME / UPI ID profile, not a counting mode | 🔴 HIGH — misleading feature claim |
| **"Calculator with memory functions (M+, M-, MR, MC)"** | Standard calculator has only AC / ⌫ / + − × ÷ % = ( ). No memory keys anywhere | 🔴 HIGH — false feature claim |
| **"AED" currency** | Not supported. Only INR/USD/EUR/GBP/BDT/NPR (6, not "and more") | 🟡 MEDIUM — minor inaccuracy |
| **"major world currencies… and more"** | Only 6 currencies total | 🟡 LOW — wording |

---

## 🟡 MISSING from listing (app is FAR bigger than listed)

The listing does NOT mention these real, working features:

| Feature | Screen(s) |
|--------|----------|
| **Bill Split** (group split, settle up) | `group_split_screen.dart`, `group_detail_screen.dart` |
| **UPI tools** (generate UPI QR, saved UPI, send money, UPI tab) | `upi_generate_screen.dart`, `upi_qr_screen.dart`, `saved_upi_screen.dart`, `send_money_screen.dart`, `upi_tools_screen.dart`, `upi_tab_screen.dart` |
| **Inventory Manager** (products, stock adjust) | `inventory_screen.dart`, `stock_adjust_screen.dart`, `product_form_screen.dart` |
| **Currency Converter** | `converter_screen.dart` |
| **EMI / GST / Date calculators** | `emi_calculator.dart`, `gst_calculator.dart`, `date_calculator.dart` |
| **Scientific + Programmer calculators** | `scientific_calculator.dart`, `programmer_calculator.dart` |
| **App Lock** (security) | `lock_screen.dart` |
| **Printer support** | `printer_screen.dart` |
| **QR Generator + QR Scanner + Barcode Generator** | `qr_generator_screen.dart`, `qr_scanner_screen.dart`, `barcode_generator_screen.dart` |
| **Refer & Earn** (referral program) | `refer_earn_screen.dart` |
| **Reports** | `reports_screen.dart` |

---

## 📊 Screen count: 40+ screens

The app has **40+ screens** — it is a full business tool suite, not just a note counter.
The current listing describes maybe 40% of what the app actually does.

---

## 🎯 Recommended actions (priority order)

1. **IMMEDIATE — fix false claims** (suspension risk):
   - "25+ Indian languages" → "Available in English, Bengali & Hindi"
   - Remove "Business mode to track who gave which amount" entirely
   - Remove "memory functions (M+, M-, MR, MC)" from calculator section
   - Remove "AED" from currency list

2. **Add the Split feature** to listing (name/short/full desc) — it's the unique selling point.

3. **Add UPI tools + Inventory** to full description — huge value, currently invisible to searchers.

4. **Keep**: Google Drive backup, billing, khata, reminders, multi-currency — all verified true.

---

*Audit script: `/home/z/my-project/scripts/audit_features.sh`*
