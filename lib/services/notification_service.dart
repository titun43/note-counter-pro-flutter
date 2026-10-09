// =============================================================================
// Note Counter Pro - Notification Service
// =============================================================================
// Handles local notifications for scheduled reminders (Idea 5).
// Uses flutter_local_notifications for scheduling + display.
// =============================================================================

import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'package:shared_preferences/shared_preferences.dart';

class NotificationService {
  NotificationService._();
  static final NotificationService _instance = NotificationService._();
  factory NotificationService() => _instance;

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  bool _initialized = false;

  // Notification channel for reminders
  static const String _channelId = 'reminder_channel';
  static const String _channelName = 'Reminders';
  static const String _channelDesc = 'Payment reminder notifications';

  // Scheduled notification IDs
  static const int _reminderNotificationId = 1001;

  Future<void> init() async {
    if (_initialized) return;
    try {
      // Initialize timezone data
      tz.initializeTimeZones();
      final String timeZoneName = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(timeZoneName));

      // Android settings
      const androidSettings = AndroidInitializationSettings(
        '@mipmap/ic_launcher',
      );
      const iosSettings = DarwinInitializationSettings(
        requestAlertPermission: true,
        requestBadgePermission: true,
        requestSoundPermission: true,
      );
      const settings = InitializationSettings(
        android: androidSettings,
        iOS: iosSettings,
      );

      await _plugin.initialize(
        settings,
        onDidReceiveNotificationResponse: _onNotificationTap,
      );

      // Create Android channel
      await _plugin
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>()
          ?.createNotificationChannel(const AndroidNotificationChannel(
        _channelId,
        _channelName,
        description: _channelDesc,
        importance: Importance.high,
      ));

      _initialized = true;
      debugPrint('NotificationService initialized');
    } catch (e) {
      debugPrint('NotificationService init failed (non-fatal): $e');
    }
  }

  /// Request notification permission (Android 13+).
  Future<bool> requestPermissions() async {
    try {
      await init();
      final android = _plugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
      final granted = await android?.requestNotificationsPermission();
      return granted ?? false;
    } catch (_) {
      return false;
    }
  }

  /// Handle notification tap.
  void _onNotificationTap(NotificationResponse response) {
    debugPrint('Notification tapped: ${response.payload}');
    // App will open. User will see pending customers list.
  }

  /// Schedule next reminder based on user's settings.
  /// [frequency] = 'daily' | 'weekly' | 'monthly'
  /// [day] = day of week (1-7) for weekly, day of month (1-28) for monthly
  /// [hour] = 0-23
  /// [minute] = 0-59
  Future<void> scheduleReminder({
    required String frequency,
    required int day,
    required int hour,
    required int minute,
    required int pendingCount,
    required double totalPending,
  }) async {
    try {
      await init();
      await cancelReminder();

      final now = tz.TZDateTime.now(tz.local);
      tz.TZDateTime scheduledDate;

      switch (frequency) {
        case 'daily':
          scheduledDate = _nextDaily(now, hour, minute);
          break;
        case 'monthly':
          scheduledDate = _nextMonthly(now, day, hour, minute);
          break;
        case 'weekly':
        default:
          scheduledDate = _nextWeekly(now, day, hour, minute);
          break;
      }

      // Build notification body
      final body = pendingCount > 0
          ? '$pendingCount customers have pending balances. Total: ₹${totalPending.toStringAsFixed(2)}. Send reminders now?'
          : 'No pending balances today. Have a great day!';

      const androidDetails = AndroidNotificationDetails(
        _channelId,
        _channelName,
        channelDescription: _channelDesc,
        importance: Importance.high,
        priority: Priority.high,
        icon: '@mipmap/ic_launcher',
        actions: [
          AndroidNotificationAction('send_now', 'Send Now'),
          AndroidNotificationAction('snooze', 'Snooze 30 min'),
        ],
      );
      const iosDetails = DarwinNotificationDetails();
      const details = NotificationDetails(
        android: androidDetails,
        iOS: iosDetails,
      );

      await _plugin.zonedSchedule(
        _reminderNotificationId,
        '⏰ Reminder Time!',
        body,
        scheduledDate,
        details,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        matchDateTimeComponents: frequency == 'daily'
            ? DateTimeComponents.time
            : frequency == 'weekly'
                ? DateTimeComponents.dayOfWeekAndTime
                : DateTimeComponents.dayOfMonthAndTime,
      );

      // Save next reminder time
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
          'next_reminder_time', scheduledDate.toIso8601String());

      debugPrint('Reminder scheduled for: $scheduledDate');
    } catch (e) {
      debugPrint('scheduleReminder failed (non-fatal): $e');
    }
  }

  /// Cancel any scheduled reminder.
  Future<void> cancelReminder() async {
    try {
      await _plugin.cancel(_reminderNotificationId);
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('next_reminder_time');
    } catch (e) { debugPrint('NotificationService failed: $e'); }
  }

  /// Get next scheduled reminder time (null if not scheduled).
  Future<DateTime?> getNextReminderTime() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final s = prefs.getString('next_reminder_time');
      if (s == null) return null;
      return DateTime.parse(s);
    } catch (_) {
      return null;
    }
  }

  /// Show immediate test notification.
  Future<void> showTestNotification() async {
    try {
      await init();
      const androidDetails = AndroidNotificationDetails(
        _channelId,
        _channelName,
        channelDescription: _channelDesc,
        importance: Importance.high,
        priority: Priority.high,
      );
      const iosDetails = DarwinNotificationDetails();
      const details = NotificationDetails(
        android: androidDetails,
        iOS: iosDetails,
      );
      await _plugin.show(
        0,
        '✅ Test Notification',
        'Reminders are working! You will receive payment reminders on schedule.',
        details,
      );
    } catch (e) {
      debugPrint('showTestNotification failed: $e');
    }
  }

  /// Schedule a one-time bill reminder notification (#49).
  /// Shows a notification at the given [scheduledDate] with the bill
  /// number and remaining amount. Uses a unique notification ID derived
  /// from the bill ID hash so multiple bill reminders can coexist.
  Future<bool> scheduleBillReminder({
    required String billId,
    required String billNumber,
    required double remainingAmount,
    required String currencySymbol,
    required DateTime scheduledDate,
  }) async {
    try {
      await init();
      // Generate a stable notification ID from the bill ID.
      final notifId = billId.hashCode.abs() % 100000 + 2000;

      final tz.TZDateTime tzScheduled = tz.TZDateTime.from(scheduledDate, tz.local);
      if (!tzScheduled.isAfter(tz.TZDateTime.now(tz.local))) {
        debugPrint('scheduleBillReminder: scheduled date is in the past');
        return false;
      }

      const androidDetails = AndroidNotificationDetails(
        _channelId,
        _channelName,
        channelDescription: _channelDesc,
        importance: Importance.high,
        priority: Priority.high,
      );
      const iosDetails = DarwinNotificationDetails();
      const details = NotificationDetails(
        android: androidDetails,
        iOS: iosDetails,
      );

      await _plugin.zonedSchedule(
        notifId,
        '📋 $billNumber — Payment Due',
        '$currencySymbol${remainingAmount.toStringAsFixed(2)} remaining. Tap to view bill.',
        tzScheduled,
        details,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
      );

      debugPrint('Bill reminder scheduled for $billNumber at $tzScheduled');
      return true;
    } catch (e) {
      debugPrint('scheduleBillReminder failed: $e');
      return false;
    }
  }

  /// Cancel a specific bill reminder by bill ID.
  Future<void> cancelBillReminder(String billId) async {
    try {
      final notifId = billId.hashCode.abs() % 100000 + 2000;
      await _plugin.cancel(notifId);
    } catch (e) {
      debugPrint('cancelBillReminder failed: $e');
    }
  }

  // =====================================================================
  // HELPERS — calculate next scheduled date
  // =====================================================================

  tz.TZDateTime _nextDaily(tz.TZDateTime now, int hour, int minute) {
    final today = tz.TZDateTime(tz.local, now.year, now.month, now.day, hour, minute);
    return today.isAfter(now) ? today : today.add(const Duration(days: 1));
  }

  tz.TZDateTime _nextWeekly(tz.TZDateTime now, int dayOfWeek, int hour, int minute) {
    // dayOfWeek: 1=Monday ... 7=Sunday (ISO)
    int currentDay = now.weekday;
    int diff = (dayOfWeek - currentDay) % 7;
    if (diff < 0) diff += 7;
    var scheduled = tz.TZDateTime(
        tz.local, now.year, now.month, now.day, hour, minute);
    scheduled = scheduled.add(Duration(days: diff));
    if (!scheduled.isAfter(now)) {
      scheduled = scheduled.add(const Duration(days: 7));
    }
    return scheduled;
  }

  tz.TZDateTime _nextMonthly(tz.TZDateTime now, int dayOfMonth, int hour, int minute) {
    var scheduled = tz.TZDateTime(
        tz.local, now.year, now.month, dayOfMonth, hour, minute);
    if (!scheduled.isAfter(now)) {
      // next month
      scheduled = tz.TZDateTime(
          tz.local, now.year, now.month + 1, dayOfMonth, hour, minute);
    }
    return scheduled;
  }
}
