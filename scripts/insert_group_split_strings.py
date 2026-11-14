#!/usr/bin/env python3
# Insert Group Split localization strings into en/bn/hi sections of
# app_localizations.dart, right before each section's closing brace.
# Idempotent: only inserts once (checks for 'groupSplit' anchor).

import re
from pathlib import Path

PATH = Path('/home/z/my-project/lib/utils/app_localizations.dart')

# 3-language string table: key -> (en, bn, hi)
STRINGS = {
    'groupSplit': ('Group Split', 'গ্রুপ স্প্লিট', 'ग्रुप स्प्लिट'),
    'groupSplitDesc': ('Split expenses with friends & family', 'বন্ধু ও পরিবারের সাথে খরচ ভাগ করুন', 'दोस्तों और परिवार के साथ खर्च बांटें'),
    'groupSplitSection': ('Group Split', 'গ্রুপ স্প্লিট', 'ग्रुप स्प्लिट'),
    'newGroup': ('New Group', 'নতুন গ্রুপ', 'नया ग्रुप'),
    'groupName': ('Group Name', 'গ্রুপের নাম', 'ग्रुप का नाम'),
    'groupNameHint': ('e.g. Trip to Guwahati', 'যেমন: গুয়াহাটি ভ্রমণ', 'जैसे: गुवाहाटी यात्रा'),
    'members': ('Members', 'সদস্য', 'सदस्य'),
    'addMember': ('Add Member', 'সদস্য যোগ করুন', 'सदस्य जोड़ें'),
    'memberName': ('Member Name', 'সদস্যের নাম', 'सदस्य का नाम'),
    'upiIdOptional': ('UPI ID (optional)', 'UPI আইডি (ঐচ্ছিক)', 'UPI आईडी (वैकल्पिक)'),
    'addExpense': ('Add Expense', 'খরচ যোগ করুন', 'खर्च जोड़ें'),
    'whoPaid': ('Who Paid?', 'কে দিল?', 'किसने दिया?'),
    'amountLabel': ('Amount', 'পরিমাণ', 'राशि'),
    'descriptionLabel': ('Description', 'বিবরণ', 'विवरण'),
    'categoryLabel': ('Category', 'ক্যাটাগরি', 'श्रेणी'),
    'settlement': ('Settlement', 'হিসাব', 'हिसाब'),
    'totalExpense': ('Total Expense', 'মোট খরচ', 'कुल खर्च'),
    'perPerson': ('Per Person', 'প্রতি জন', 'प्रति व्यक्ति'),
    'shareImage': ('Share Image', 'ছবি শেয়ার করুন', 'छवि शेयर करें'),
    'shareSms': ('Share SMS', 'SMS শেয়ার করুন', 'SMS शेयर करें'),
    'exportPdf': ('Export PDF', 'PDF রপ্তানি', 'PDF निर्यात'),
    'noGroups': ('No groups yet', 'এখনও কোনো গ্রুপ নেই', 'अभी कोई ग्रुप नहीं'),
    'noGroupsDesc': ('Create a group to start splitting expenses', 'খরচ ভাগ করতে একটি গ্রুপ তৈরি করুন', 'खर्च बांटने के लिए ग्रुप बनाएं'),
    'noExpenses': ('No expenses yet', 'এখনও কোনো খরচ নেই', 'अभी कोई खर्च नहीं'),
    'noExpensesDesc': ('Add an expense to see settlement', 'হিসাব দেখতে খরচ যোগ করুন', 'हिसाब देखने के लिए खर्च जोड़ें'),
    'settled': ('Everyone is settled!', 'সবাই সমান!', 'सब बराबर है!'),
    'deleteGroup': ('Delete Group', 'গ্রুপ মুছুন', 'ग्रुप हटाएं'),
    'editGroup': ('Edit Group', 'গ্রুপ সম্পাদনা', 'ग्रुप संपादित करें'),
    'deleteExpense': ('Delete Expense', 'খরচ মুছুন', 'खर्च हटाएं'),
    'editExpense': ('Edit Expense', 'খরচ সম্পাদনা', 'खर्च संपादित करें'),
    'confirmDeleteGroup': ('Delete this group and all its expenses?', 'এই গ্রুপ ও সব খরচ মুছে ফেলবেন?', 'यह ग्रुप और सब खर्च हटाएं?'),
    'confirmDeleteExpense': ('Delete this expense?', 'এই খরচ মুছে ফেলবেন?', 'यह खर्च हटाएं?'),
    'cancel': ('Cancel', 'বাতিল', 'रद्द करें'),
    'deleteBtn': ('Delete', 'মুছুন', 'हटाएं'),
    'saveBtn': ('Save', 'সংরক্ষণ', 'सहेजें'),
    'memberCount': ('members', 'সদস্য', 'सदस्य'),
    'yourShare': ('Your share', 'আপনার ভাগ', 'आपका हिस्सा'),
    'owes': ('owes', 'দিতে হবে', 'देना है'),
    'gets': ('gets', 'পাবে', 'मिलेगा'),
    'paidLbl': ('paid', 'দিয়েছে', 'दिया'),
    'groupCategory_food': ('Food', 'খাওয়া', 'खाना'),
    'groupCategory_transport': ('Transport', 'যাতায়াত', 'यातायात'),
    'groupCategory_accommodation': ('Stay', 'থাকা', 'रुकना'),
    'groupCategory_shopping': ('Shopping', 'কেনাকাটা', 'खरीदारी'),
    'groupCategory_entertainment': ('Fun', 'মজা', 'मनोरंजन'),
    'groupCategory_misc': ('Other', 'অন্যান্য', 'अन्य'),
    'selectMember': ('Select a member', 'একজন সদস্য নির্বাচন করুন', 'सदस्य चुनें'),
    'enterAmount': ('Enter amount', 'পরিমাণ লিখুন', 'राशि दर्ज करें'),
    'enterDescription': ('What was it for?', 'কী জন্য?', 'किसलिए?'),
    'scanToPay': ('Scan to Pay', 'স্ক্যান করে দিন', 'स्कैन करके दें'),
    'settlementSummary': ('Settlement Summary', 'হিসাব সারসংক্ষেপ', 'हिसाब सारांश'),
    'noSettlementNeeded': ('No settlement needed — everyone paid equally', 'কোনো হিসাব লাগবে না — সবাই সমান দিয়েছে', 'कोई हिसाब नहीं — सबने बराबर दिया'),
    'minMembers': ('Add at least one member', 'অন্তত একজন সদস্য যোগ করুন', 'कम से कम एक सदस्य जोड़ें'),
    'nameRequired': ('Name is required', 'নাম আবশ্যক', 'नाम आवश्यक'),
    'duplicateMember': ('This member is already added', 'এই সদস্য আগেই যোগ হয়েছে', 'यह सदस्य पहले जोड़ा गया'),
    'expenseAdded': ('Expense added', 'খরচ যোগ হয়েছে', 'खर्च जोड़ा गया'),
    'groupCreated': ('Group created', 'গ্রুপ তৈরি হয়েছে', 'ग्रुप बनाया गया'),
    'groupDeleted': ('Group deleted', 'গ্রুপ মুছে ফেলা হয়েছে', 'ग्रुप हटाया गया'),
    'groupUpdated': ('Group updated', 'গ্রুপ আপডেট হয়েছে', 'ग्रुप अपडेट हुआ'),
    'pdfGenerated': ('PDF generated', 'PDF তৈরি হয়েছে', 'PDF बनाया गया'),
    'calculatedBy': ('Calculated by Note Counter Pro', 'Note Counter Pro দ্বারা গণনা', 'Note Counter Pro द्वारा गणना'),
    'newExpenseNotif': ('New Expense Added!', 'নতুন খরচ যোগ হয়েছে!', 'नया खर्च जोड़ा गया!'),
}

# fix the accidental tuple-via-comma entries above
STRINGS['addMember'] = ('Add Member', 'সদস্য যোগ করুন', 'सदस्य जोड़ें')
STRINGS['gets'] = ('gets', 'পাবে', 'मिलेगा')
STRINGS['imageShared'] = ('Image shared', 'ছবি শেয়ার হয়েছে', 'छवि शेयर हुई')

def dart_string(s: str) -> str:
    # escape backslash and single quote
    return s.replace('\\', '\\\\').replace("'", "\\'")

def build_block(lang_index: int) -> str:
    lines = []
    lines.append("      // === Group Split (v3.60.0) ===")
    for key, vals in STRINGS.items():
        lines.append(f"      '{key}': '{dart_string(vals[lang_index])}',")
    return "\n".join(lines)

src = PATH.read_text(encoding='utf-8')

if "'groupSplit':" in src:
    print("Already inserted — aborting to avoid duplicate.")
    raise SystemExit(0)

# Anchor: the closing of each language section. Each section ends with the
# 'widgetAddedMsg' line followed by '    },'. The en/bn/hi variants differ, so
# each anchor is unique.
ANCHORS = [
    (
        "      'widgetAddedMsg': 'Check your home screen. You can resize the widget by long-pressing it.',\n    },\n    'bn': {",
        "en",
    ),
    (
        "      'widgetAddedMsg': 'আপনার হোম স্ক্রিন চেক করুন। লং-প্রেস করে উইজেট রিসাইজ করতে পারবেন।',\n    },\n    'hi': {",
        "bn",
    ),
    (
        "      'widgetAddedMsg': 'अपनी होम स्क्रीन देखें। लॉन्ग-प्रेस करके विजेट को रीसाइज़ कर सकते हैं।',\n    },\n  };",
        "hi",
    ),
]

for anchor, lang in ANCHORS:
    if anchor not in src:
        print(f"ANCHOR NOT FOUND for {lang}")
        raise SystemExit(1)

idx = {'en': 0, 'bn': 1, 'hi': 2}
for anchor, lang in ANCHORS:
    block = build_block(idx[lang])
    # Insert block right before the '    },\n    'next': {' or '    },\n  };'
    # We keep the 'widgetAddedMsg' line, then our block, then '    },'
    before, after = anchor.split("      'widgetAddedMsg':", 1)
    # Reconstruct: before + 'widgetAddedMsg' line + our block + the '    },...'
    wmsg_line = "      'widgetAddedMsg':" + after.split("\n    },", 1)[0]
    tail = "\n    }," + after.split("\n    },", 1)[1]
    replacement = before + wmsg_line + "\n" + block + tail
    src = src.replace(anchor, replacement, 1)

PATH.write_text(src, encoding='utf-8')
print(f"Inserted {len(STRINGS)} strings × 3 languages into {PATH}")
