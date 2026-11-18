import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import '../models/models.dart';

class NotificationService {
  NotificationService._();
  static final NotificationService instance = NotificationService._();

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();
  bool _initialized = false;

  Future<void> init() async {
    if (_initialized) return;
    try {
      tz.initializeTimeZones();
      String timeZoneName = 'Asia/Manila';
      try {
        final info = await FlutterTimezone.getLocalTimezone();
        timeZoneName = info.identifier;
      } catch (_) {
        timeZoneName = 'Asia/Manila';
      }
      try {
        tz.setLocalLocation(tz.getLocation(timeZoneName));
      } catch (_) {
        tz.setLocalLocation(tz.getLocation('Asia/Manila'));
      }

      const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
      const darwinInit = DarwinInitializationSettings();
      const initSettings = InitializationSettings(
        android: androidInit,
        iOS: darwinInit,
        macOS: darwinInit,
      );

      await _plugin.initialize(settings: initSettings);
      _initialized = true;
    } catch (e) {
      debugPrint('NotificationService init skipped: $e');
    }
  }

  int billDueNotificationId(String billId) => billId.hashCode & 0x3FFFFFFF;
  int billAdvanceNotificationId(String billId) =>
      (billId.hashCode & 0x3FFFFFFF) + 1;
  int birthdayNotificationId(String dayId) =>
      (dayId.hashCode & 0x3FFFFFFF) + 2;

  DateTime _clampDayInMonth(int year, int month, int dueDay, int hour) {
    final lastDayOfMonth = DateTime(year, month + 1, 0).day;
    final clampedDay = dueDay.clamp(1, lastDayOfMonth);
    return DateTime(year, month, clampedDay, hour, 0);
  }

  DateTime nextBillDueDate(int dueDay, {bool forceNextMonth = false}) {
    final now = DateTime.now();
    var candidate = _clampDayInMonth(now.year, now.month, dueDay, 9);
    if (forceNextMonth || candidate.isBefore(now)) {
      final nextMonth = DateTime(now.year, now.month + 1, 1);
      candidate = _clampDayInMonth(nextMonth.year, nextMonth.month, dueDay, 9);
    }
    return candidate;
  }

  Future<void> scheduleMonthlyBillReminder(
    RecurringBill bill, {
    bool forceNextMonth = false,
  }) async {
    if (!_initialized) return;
    try {
      final due = nextBillDueDate(bill.dueDay, forceNextMonth: forceNextMonth);
      final dueTz = tz.TZDateTime.from(due, tz.local);

      const details = NotificationDetails(
        android: AndroidNotificationDetails(
          'bills_channel',
          'Bill Reminders',
          channelDescription: 'Monthly recurring bill alerts',
          importance: Importance.high,
          priority: Priority.high,
        ),
        iOS: DarwinNotificationDetails(),
      );

      await _plugin.zonedSchedule(
        id: billDueNotificationId(bill.id),
        title: 'Bill Due Today: ${bill.title}',
        body: 'Amount: ₱${bill.amount.toStringAsFixed(2)}',
        scheduledDate: dueTz,
        notificationDetails: details,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      );

      if (bill.notifyDaysBefore > 0) {
        final advance = due.subtract(Duration(days: bill.notifyDaysBefore));
        if (advance.isAfter(DateTime.now())) {
          await _plugin.zonedSchedule(
            id: billAdvanceNotificationId(bill.id),
            title: 'Upcoming Bill: ${bill.title}',
            body:
                'Due in ${bill.notifyDaysBefore} day(s) • ₱${bill.amount.toStringAsFixed(2)}',
            scheduledDate: tz.TZDateTime.from(advance, tz.local),
            notificationDetails: details,
            androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
          );
        }
      }
    } catch (e) {
      debugPrint('scheduleMonthlyBillReminder error: $e');
    }
  }

  Future<void> scheduleBirthdayReminder(SpecialDay day) async {
    if (!_initialized || !day.notifyDayBefore) return;
    try {
      final now = DateTime.now();
      DateTime eventDate;
      if (day.recurrence == 'monthly') {
        eventDate = _clampDayInMonth(now.year, now.month, day.day, 8);
        if (eventDate.subtract(const Duration(days: 1)).isBefore(now)) {
          final next = DateTime(now.year, now.month + 1, 1);
          eventDate = _clampDayInMonth(next.year, next.month, day.day, 8);
        }
      } else if (day.recurrence == 'weekly') {
        final anchor = DateTime(day.year ?? now.year, day.month, day.day, 8);
        eventDate = anchor;
        while (eventDate.subtract(const Duration(days: 1)).isBefore(now)) {
          eventDate = eventDate.add(const Duration(days: 7));
        }
      } else {
        eventDate = _clampDayInMonth(now.year, day.month, day.day, 8);
        if (day.recurrence != 'once' &&
            eventDate.subtract(const Duration(days: 1)).isBefore(now)) {
          eventDate = _clampDayInMonth(now.year + 1, day.month, day.day, 8);
        }
      }
      final reminderDate = eventDate.subtract(const Duration(days: 1));
      if (reminderDate.isBefore(now)) return;

      const details = NotificationDetails(
        android: AndroidNotificationDetails(
          'special_days_channel',
          'Birthdays & Special Days',
          channelDescription: '1-day advance alerts for birthdays and events',
          importance: Importance.high,
          priority: Priority.high,
        ),
        iOS: DarwinNotificationDetails(),
      );

      final prefix = day.type == 'birthday' ? '🎂' : '📅';
      await _plugin.zonedSchedule(
        id: birthdayNotificationId(day.id),
        title: '$prefix Tomorrow: ${day.title}',
        body: 'Reminder set 1 day before (${eventDate.month}/${eventDate.day})',
        scheduledDate: tz.TZDateTime.from(reminderDate, tz.local),
        notificationDetails: details,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      );
    } catch (e) {
      debugPrint('scheduleBirthdayReminder error: $e');
    }
  }

  Future<void> cancelNotification(int notificationId) async {
    if (!_initialized) return;
    try {
      await _plugin.cancel(id: notificationId);
    } catch (e) {
      debugPrint('cancelNotification error: $e');
    }
  }

  Future<void> cancelBillNotifications(String billId) async {
    await cancelNotification(billDueNotificationId(billId));
    await cancelNotification(billAdvanceNotificationId(billId));
  }
}
