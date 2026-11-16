#!/usr/bin/env bash
# Audit the freshly-cloned Note Counter Pro repo to verify each Play Store
# listing claim against the actual code. Reads only; writes nothing.
REPO="/tmp/ncp_fresh/repo"
cd "$REPO" || { echo "repo not found"; exit 1; }

section() { echo ""; echo "==================== $1 ===================="; }

section "1. LANGUAGES (claim: 25+ Indian languages)"
echo "-- l10n / arb files --"
find lib -type d -name "l10n" 2>/dev/null
find lib -name "*.arb" 2>/dev/null | head -40
echo "-- count arb files --"
find lib -name "*.arb" 2>/dev/null | wc -l
echo "-- supportedLocales in code --"
grep -rn "supportedLocales" lib/ 2>/dev/null | head -5
echo "-- any locale list / language enum --"
grep -rni "locale(" lib/main.dart lib/utils/ 2>/dev/null | head -10
grep -rni "bengali\|hindi\|tamil\|telugu\|marathi" lib/ 2>/dev/null | head -5

section "2. GOOGLE DRIVE BACKUP (claim: Drive backup & restore)"
echo "-- pubspec drive/google packages --"
grep -niE "drive|googleapis|google_sign_in|firebase|googleapi" pubspec.yaml pubspec.lock 2>/dev/null | head
echo "-- cloud_backup_screen mentions --"
grep -niE "drive|google|firebase|backup|restore" lib/screens/cloud_backup_screen.dart 2>/dev/null | head -15

section "3. CALCULATOR w/ memory (claim: M+, M-, MR, MC)"
grep -niE "M\+|M-|MR|MC|memory|memPlus|memRecall" lib/screens/standard_calculator.dart lib/screens/calculator_screen.dart 2>/dev/null | head -10

section "4. BUSINESS MODE (claim: track who gave which amount)"
grep -rniE "business.?mode|businessMode|who.?gave|givenBy" lib/ 2>/dev/null | head -10

section "5. SMS / WHATSAPP REMINDERS (claim: send reminders via SMS/WhatsApp)"
grep -rniE "whatsapp|wa\.me|sms|url_launcher|sendSms|reminder" lib/screens/reminder_settings_screen.dart lib/screens/reminder_history_screen.dart 2>/dev/null | head -15
echo "-- url_launcher in pubspec --"
grep -niE "url_launcher|share|whatsapp" pubspec.yaml 2>/dev/null | head

section "6. BILLING / INVOICE MAKER"
grep -niE "invoice|bill|tax|discount|customer" lib/screens/bill_form_screen.dart 2>/dev/null | head -12

section "7. SPLIT feature"
grep -niE "split|equal|percentage|settle" lib/screens/group_split_screen.dart lib/screens/group_detail_screen.dart 2>/dev/null | head -10

section "8. DENOMINATIONS / currencies"
grep -rniE "2000|500|200|USD|EUR|GBP|AED|NPR|BDT" lib/screens/home_screen.dart 2>/dev/null | head -8

section "9. Extra screens NOT in listing (potential additions)"
echo "tools_tab / upi screens / inventory / reports / premium / refer / converter / lock / printer / qr"
ls lib/screens/ | grep -iE "tool|upi|invent|report|premium|refer|convert|lock|printer|qr|emi|gst|scientific" | head -30

section "10. pubspec summary (deps + version)"
grep -nE "^name:|^version:|^description:" pubspec.yaml
echo "-- dependency count --"
grep -cE "^\s+[a-z]" pubspec.yaml
