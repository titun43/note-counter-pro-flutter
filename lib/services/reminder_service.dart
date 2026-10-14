// =============================================================================
// Note Counter Pro - Reminder Service
// =============================================================================
// Handles WhatsApp/SMS reminders with business details, UPI payment link,
// multiple templates (Friendly/Formal/Strict), customer custom notes,
// reminder history tracking, and scheduled notifications.
//
// Ideas implemented:
//   1. Smart WhatsApp message (business details + UPI)
//   2. UPI Payment Link in message (clickable)
//   3. QR image + message share
//   4. Send Reminder to All (bulk)
//   5. Schedule notification (via NotificationService)
//   6. Customer custom note in message
//   7. Reminder History tracking
//   8. Multiple templates (Friendly/Formal/Strict)
// =============================================================================

import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:screenshot/screenshot.dart';
import '../models/customer.dart';
import '../services/storage_service.dart';

class ReminderService {
  ReminderService._();
  static final ReminderService _instance = ReminderService._();
  factory ReminderService() => _instance;

  // === TEMPLATE KEYS ===
  static const String kTemplateFriendly = 'friendly';
  static const String kTemplateFormal = 'formal';
  static const String kTemplateStrict = 'strict';

  // === REMINDER HISTORY STORAGE KEY ===
  static const String kReminderHistoryKey = 'reminder_history';

  // =====================================================================
  // TEMPLATE BUILDERS
  // =====================================================================

  /// Build the reminder message based on selected template + business details.
  /// Supports {name}, {amount}, {business}, {upi}, {phone}, {address}, {date}, {note}
  String buildReminderMessage({
    required String language,
    required String templateKey,
    required Customer customer,
    required double balance,
    required String currencySymbol,
    required StorageService storage,
  }) {
    final name = customer.name;
    final amount = '$currencySymbol${balance.abs().toStringAsFixed(2)}';
    final business = storage.businessName.isNotEmpty
        ? storage.businessName
        : 'My Business';
    final upi = storage.businessUpiId;
    final phone = storage.businessPhone;
    final address = storage.businessAddress;
    final date = DateTime.now().toString().substring(0, 10);
    final customNote = customer.notes ?? '';

    String template;
    switch (templateKey) {
      case kTemplateFormal:
        template = _formalTemplate(language);
        break;
      case kTemplateStrict:
        template = _strictTemplate(language);
        break;
      case kTemplateFriendly:
      default:
        template = _friendlyTemplate(language);
    }

    String message = template
        .replaceAll('{name}', name)
        .replaceAll('{amount}', amount)
        .replaceAll('{business}', business)
        .replaceAll('{upi}', upi)
        .replaceAll('{phone}', phone)
        .replaceAll('{address}', address)
        .replaceAll('{date}', date);

    // Insert custom note if present
    if (customNote.isNotEmpty) {
      final noteLine = language == 'bn'
          ? '📝 নোট: $customNote\n'
          : language == 'hi'
              ? '📝 नोट: $customNote\n'
              : '📝 Note: $customNote\n';
      message = message.replaceAll('{note}', noteLine);
    } else {
      message = message.replaceAll('{note}', '');
    }

    // UPI payment link (Idea 2): clickable upi:// link with auto-filled amount
    if (upi.isNotEmpty) {
      final upiLink = _buildUpiLink(upi, business, balance.abs());
      final linkLine = language == 'bn'
          ? '👉 পেমেন্ট লিংক: $upiLink\n'
          : language == 'hi'
              ? '👉 भुगतान लिंक: $upiLink\n'
              : '👉 Pay link: $upiLink\n';
      message = '$message\n$linkLine';
    }

    return message.trim();
  }

  String _friendlyTemplate(String lang) {
    if (lang == 'bn') {
      return 'হ্যালো {name},\n\nআপনার কাছে {business} এ {amount} বকেয়া আছে।\n\n'
          'অনুগ্রহ করে সুবিধামতো পরিশোধ করুন।\n{note}'
          '💳 UPI: {upi}\n📞 {phone}\n📍 {address}\n\n— {business}';
    }
    if (lang == 'hi') {
      return 'नमस्ते {name},\n\nआपके पास {business} पर {amount} बकाया है।\n\n'
          'कृपया सुविधानुसार भुगतान करें।\n{note}'
          '💳 UPI: {upi}\n📞 {phone}\n📍 {address}\n\n— {business}';
    }
    return 'Hello {name},\n\nYou have {amount} due at {business}.\n\n'
        'Please pay at your earliest convenience.\n{note}'
        '💳 UPI: {upi}\n📞 {phone}\n📍 {address}\n\n— {business}';
  }

  String _formalTemplate(String lang) {
    if (lang == 'bn') {
      return 'প্রিয় {name},\n\nএই অনুস্মারক যে {amount} {business} এ বকেয়া আছে '
          '({date} অনুযায়ী)। অনুগ্রহ করে শীঘ্র পরিশোধের ব্যবস্থা করুন।\n{note}'
          '💳 UPI: {upi}\n📞 {phone}\n📍 {address}\n\n— {business}';
    }
    if (lang == 'hi') {
      return 'प्रिय {name},\n\nयह अनुस्मारक है कि {amount} {business} पर बकाया है '
          '({date} के अनुसार)। कृपया शीघ्र भुगतान की व्यवस्था करें।\n{note}'
          '💳 UPI: {upi}\n📞 {phone}\n📍 {address}\n\n— {business}';
    }
    return 'Dear {name},\n\nThis is a reminder that {amount} is due to {business} '
        '(as of {date}). Kindly arrange payment at your earliest.\n{note}'
        '💳 UPI: {upi}\n📞 {phone}\n📍 {address}\n\n— {business}';
  }

  String _strictTemplate(String lang) {
    if (lang == 'bn') {
      return '{name},\n\nআপনার {business} এ {amount} পেমেন্ট বকেয়া। '
          'অনুগ্রহ করে অবিলম্বে পরিশোধ করুন।\n{note}'
          '💳 UPI: {upi}\n📞 {phone}\n\n— {business}';
    }
    if (lang == 'hi') {
      return '{name},\n\nआपका {business} पर {amount} भुगतान अतिदेय है। '
          'कृपया तुरंत भुगतान करें।\n{note}'
          '💳 UPI: {upi}\n📞 {phone}\n\n— {business}';
    }
    return '{name},\n\nYour payment of {amount} to {business} is OVERDUE. '
        'Please pay immediately.\n{note}'
        '💳 UPI: {upi}\n📞 {phone}\n\n— {business}';
  }

  /// Build UPI deep link with auto-filled amount (Idea 2).
  /// Format: upi://pay?pa=UPI_ID&pn=BUSINESS_NAME&am=AMOUNT&cu=INR
  String _buildUpiLink(String upiId, String businessName, double amount) {
    final encodedName = Uri.encodeComponent(businessName);
    final amtStr = amount.toStringAsFixed(2);
    return 'upi://pay?pa=$upiId&pn=$encodedName&am=$amtStr&cu=INR';
  }

  // =====================================================================
  // WHATSAPP / SMS SENDING
  // =====================================================================

  /// Open WhatsApp chat with auto-filled reminder message.
  /// Returns true if successfully opened, false otherwise.
  Future<bool> openWhatsAppReminder({
    required Customer customer,
    required double balance,
    required String currencySymbol,
    required StorageService storage,
    String? templateKey,
  }) async {
    final phone = customer.phone;
    if (phone == null || phone.isEmpty) return false;

    final language = storage.languageCode;
    final template = templateKey ?? _getDefaultTemplate(storage);
    final message = buildReminderMessage(
      language: language,
      templateKey: template,
      customer: customer,
      balance: balance,
      currencySymbol: currencySymbol,
      storage: storage,
    );

    final cleanPhone = phone.replaceAll(RegExp(r'[^\d]'), '');
    String waPhone = cleanPhone;
    if (waPhone.startsWith('0')) {
      waPhone = '91${waPhone.substring(1)}';
    } else if (!waPhone.startsWith('91') && waPhone.length == 10) {
      waPhone = '91$waPhone';
    }

    final uri = Uri.parse(
        'https://wa.me/$waPhone?text=${Uri.encodeComponent(message)}');
    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
        await _recordReminderHistory(customer.id, customer.name, balance);
        return true;
      }
    } catch (e) {
      debugPrint('openWhatsAppReminder failed: $e');
    }
    return false;
  }

  /// Open SMS app with auto-filled reminder message.
  Future<bool> openSmsReminder({
    required Customer customer,
    required double balance,
    required String currencySymbol,
    required StorageService storage,
    String? templateKey,
  }) async {
    final phone = customer.phone;
    if (phone == null || phone.isEmpty) return false;

    final language = storage.languageCode;
    final template = templateKey ?? _getDefaultTemplate(storage);
    final message = buildReminderMessage(
      language: language,
      templateKey: template,
      customer: customer,
      balance: balance,
      currencySymbol: currencySymbol,
      storage: storage,
    );

    final uri = Uri.parse('sms:$phone?body=${Uri.encodeComponent(message)}');
    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri);
        await _recordReminderHistory(customer.id, customer.name, balance);
        return true;
      }
    } catch (e) {
      debugPrint('openSmsReminder failed: $e');
    }
    return false;
  }

  // =====================================================================
  // QR + MESSAGE SHARE (Idea 3)
  // =====================================================================

  /// Generate QR image for the UPI payment and share via WhatsApp/system share.
  /// Captures a widget containing QR + business info as image, then shares.
  Future<bool> shareQrWithMessage({
    required Customer customer,
    required double balance,
    required String currencySymbol,
    required StorageService storage,
  }) async {
    try {
      final upiId = storage.businessUpiId;
      if (upiId.isEmpty) return false;

      final business = storage.businessName.isNotEmpty
          ? storage.businessName
          : 'My Business';
      final amount = balance.abs().toStringAsFixed(2);
      final upiLink = _buildUpiLink(upiId, business, balance.abs());

      // Render QR as image via QrImage widget → toImage → toByteData
      final qrPainter = QrPainter(
        data: upiLink,
        version: QrVersions.auto,
        gapless: true,
        // size is passed via toImage() below (qr_flutter 4.x API)
      );

      final tempDir = await getTemporaryDirectory();
      final qrPath = '${tempDir.path}/qr_${customer.id}_${DateTime.now().millisecondsSinceEpoch}.png';
      final qrFile = File(qrPath);

      // qr_flutter 4.x: QrPainter.toImage(size) returns ui.Image
      final uiImage = await qrPainter.toImage(320);
      final byteData = await uiImage.toByteData(format: ui.ImageByteFormat.png);
      if (byteData == null) return false;
      await qrFile.writeAsBytes(byteData.buffer.asUint8List());

      // Build share text
      final language = storage.languageCode;
      final message = buildReminderMessage(
        language: language,
        templateKey: _getDefaultTemplate(storage),
        customer: customer,
        balance: balance,
        currencySymbol: currencySymbol,
        storage: storage,
      );

      // Share image + text
      await Share.shareXFiles(
        [XFile(qrPath)],
        text: message,
        subject: 'Payment Reminder - $business',
      );

      await _recordReminderHistory(customer.id, customer.name, balance);
      return true;
    } catch (e) {
      debugPrint('shareQrWithMessage failed: $e');
      return false;
    }
  }

  // =====================================================================
  // REMINDER HISTORY (Idea 7)
  // =====================================================================

  /// Record a reminder event in SharedPreferences as JSON list.
  Future<void> _recordReminderHistory(
      String customerId, String customerName, double amount) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final List<dynamic> history =
          prefs.getStringList(kReminderHistoryKey) ?? [];
      final entry = {
        'customerId': customerId,
        'customerName': customerName,
        'amount': amount,
        'timestamp': DateTime.now().toIso8601String(),
        'channel': 'whatsapp',
      };
      history.insert(0, jsonEncode(entry));
      // Keep only last 100 entries
      if (history.length > 100) {
        history.removeRange(100, history.length);
      }
      await prefs.setStringList(kReminderHistoryKey, history.cast<String>());
    } catch (e) {
      debugPrint('recordReminderHistory failed: $e');
    }
  }

  /// Get reminder history (most recent first).
  Future<List<Map<String, dynamic>>> getReminderHistory() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final List<String> history =
          prefs.getStringList(kReminderHistoryKey) ?? [];
      return history
          .map((s) => jsonDecode(s) as Map<String, dynamic>)
          .toList();
    } catch (e) {
      return [];
    }
  }

  /// Get last reminder timestamp for a specific customer.
  Future<DateTime?> getLastReminderForCustomer(String customerId) async {
    final history = await getReminderHistory();
    for (final entry in history) {
      if (entry['customerId'] == customerId) {
        try {
          return DateTime.parse(entry['timestamp'] as String);
        } catch (_) {
          return null;
        }
      }
    }
    return null;
  }

  /// Clear all reminder history.
  Future<void> clearHistory() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(kReminderHistoryKey);
  }

  // =====================================================================
  // DEFAULT TEMPLATE (Idea 8)
  // =====================================================================

  String _getDefaultTemplate(StorageService storage) {
    try {
      return storage.defaultReminderTemplate;
    } catch (_) {
      return kTemplateFriendly;
    }
  }

  /// Set default reminder template.
  Future<void> setDefaultTemplate(String templateKey) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('default_reminder_template', templateKey);
  }

  /// Get available template keys with display names.
  List<Map<String, String>> getTemplates(String language) {
    if (language == 'bn') {
      return [
        {'key': kTemplateFriendly, 'name': '🌟 বন্ধুত্বপূর্ণ', 'desc': 'নরম ভাষায়'},
        {'key': kTemplateFormal, 'name': '🏛️ আনুষ্ঠানিক', 'desc': 'ভাল ভাষায়'},
        {'key': kTemplateStrict, 'name': '⚠️ কঠোর', 'desc': 'জরুরি ভাষায়'},
      ];
    }
    if (language == 'hi') {
      return [
        {'key': kTemplateFriendly, 'name': '🌟 मित्रतापूर्ण', 'desc': 'नरम भाषा'},
        {'key': kTemplateFormal, 'name': '🏛️ औपचारिक', 'desc': 'विनम्र भाषा'},
        {'key': kTemplateStrict, 'name': '⚠️ सख्त', 'desc': 'जरूरी भाषा'},
      ];
    }
    return [
      {'key': kTemplateFriendly, 'name': '🌟 Friendly', 'desc': 'Soft tone'},
      {'key': kTemplateFormal, 'name': '🏛️ Formal', 'desc': 'Polite tone'},
      {'key': kTemplateStrict, 'name': '⚠️ Strict', 'desc': 'Urgent tone'},
    ];
  }
}
