// =============================================================================
// Note Counter Pro — Widget Service
// =============================================================================
//
// Bridges Flutter app data to the Android Home Screen Widget.
// Uses platform channels to write SharedPreferences that the Kotlin
// CounterWidgetProvider reads, then triggers a widget update broadcast.
//
// Data synced:
//   - Counter quantities (₹2000, ₹500, ₹200, ₹100)
//   - Today's cash in/out summary
//
// Deep links (handled by main.dart):
//   - notecounterpro://counter  → Home Screen (counter tab)
//   - notecounterpro://smartpay → Smart Pay screen
//   - notecounterpro://khata    → Khata ledger
//   - notecounterpro://bill     → Bill maker
// =============================================================================

import 'dart:io';
import 'package:flutter/services.dart';

class WidgetService {
  static const MethodChannel _channel = MethodChannel('com.lokhnathtechnical.notecounterpro/widget');

  static const String _prefsName = 'NoteCounterWidgetPrefs';

  /// SharedPreferences keys (must match Kotlin CounterWidgetProvider)
  static const String keyQty2000 = 'widget_qty_2000';
  static const String keyQty500 = 'widget_qty_500';
  static const String keyQty200 = 'widget_qty_200';
  static const String keyQty100 = 'widget_qty_100';
  static const String keyTodayIn = 'widget_today_in';
  static const String keyTodayOut = 'widget_today_out';

  /// Update the widget with counter quantities and today's summary.
  /// Call this whenever the user saves a counting session or adds an entry.
  ///
  /// [qty2000] - quantity of ₹2000 notes
  /// [qty500]  - quantity of ₹500 notes
  /// [qty200]  - quantity of ₹200 notes
  /// [qty100]  - quantity of ₹100 notes
  /// [todayIn] - total cash IN today (in rupees)
  /// [todayOut] - total cash OUT today (in rupees)
  static Future<void> updateWidget({
    int qty2000 = 0,
    int qty500 = 0,
    int qty200 = 0,
    int qty100 = 0,
    int todayIn = 0,
    int todayOut = 0,
  }) async {
    if (!Platform.isAndroid) return;

    try {
      await _channel.invokeMethod('updateWidget', {
        'prefsName': _prefsName,
        'data': {
          keyQty2000: qty2000,
          keyQty500: qty500,
          keyQty200: qty200,
          keyQty100: qty100,
          keyTodayIn: todayIn,
          keyTodayOut: todayOut,
        },
      });
    } catch (e) {
      // Silently fail — widget update is non-critical
      debugPrint('WidgetService: updateWidget failed: $e');
    }
  }

  /// Update only the counter quantities (without today's summary).
  /// Called when user opens the app with a saved counting session.
  static Future<void> updateCounterQuantities({
    required int qty2000,
    required int qty500,
    required int qty200,
    required int qty100,
  }) async {
    if (!Platform.isAndroid) return;

    try {
      await _channel.invokeMethod('updateWidgetData', {
        'prefsName': _prefsName,
        'key': keyQty2000,
        'value': qty2000,
      });
      await _channel.invokeMethod('updateWidgetData', {
        'prefsName': _prefsName,
        'key': keyQty500,
        'value': qty500,
      });
      await _channel.invokeMethod('updateWidgetData', {
        'prefsName': _prefsName,
        'key': keyQty200,
        'value': qty200,
      });
      await _channel.invokeMethod('updateWidgetData', {
        'prefsName': _prefsName,
        'key': keyQty100,
        'value': qty100,
      });
      await _triggerWidgetUpdate();
    } catch (e) {
      debugPrint('WidgetService: updateCounterQuantities failed: $e');
    }
  }

  /// Update only today's cash summary.
  /// Called when user adds a new entry (cash in/out).
  static Future<void> updateTodaySummary({
    required int todayIn,
    required int todayOut,
  }) async {
    if (!Platform.isAndroid) return;

    try {
      await _channel.invokeMethod('updateWidgetData', {
        'prefsName': _prefsName,
        'key': keyTodayIn,
        'value': todayIn,
      });
      await _channel.invokeMethod('updateWidgetData', {
        'prefsName': _prefsName,
        'key': keyTodayOut,
        'value': todayOut,
      });
      await _triggerWidgetUpdate();
    } catch (e) {
      debugPrint('WidgetService: updateTodaySummary failed: $e');
    }
  }

  /// Trigger a widget visual update broadcast.
  static Future<void> _triggerWidgetUpdate() async {
    try {
      await _channel.invokeMethod('triggerWidgetUpdate');
    } catch (e) {
      debugPrint('WidgetService: triggerWidgetUpdate failed: $e');
    }
  }

  /// Parse a deep link URI and return the target screen route.
  /// Returns null if the URI is not a valid Note Counter Pro deep link.
  ///
  /// Supported deep links:
  ///   notecounterpro://counter  → '/counter'
  ///   notecounterpro://smartpay → '/smartpay'
  ///   notecounterpro://khata    → '/khata'
  ///   notecounterpro://bill     → '/bill'
  static String? parseDeepLink(Uri uri) {
    if (uri.scheme != 'notecounterpro') return null;

    switch (uri.host) {
      case 'counter':
        return '/counter';
      case 'smartpay':
        return '/smartpay';
      case 'khata':
        return '/khata';
      case 'bill':
        return '/bill';
      default:
        return null;
    }
  }
}
