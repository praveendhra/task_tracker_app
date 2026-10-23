import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import '../models/reminders.dart';

/// Repeating "check your tasks" notifications, scheduled on the phone.
/// No server or push key is involved.
abstract class ReminderScheduler {
  /// Reminders are iPhone-only for now.
  bool get supported;

  /// Asks for notification permission. True if allowed.
  Future<bool> requestPermission();

  /// Replaces every scheduled reminder with [reminders], repeating daily.
  Future<void> schedule(List<DailyReminder> reminders);

  Future<void> cancelAll();
}

class LocalReminderScheduler implements ReminderScheduler {
  final _plugin = FlutterLocalNotificationsPlugin();
  bool _ready = false;

  @override
  bool get supported => !kIsWeb && defaultTargetPlatform == TargetPlatform.iOS;

  Future<void> _init() async {
    if (_ready) return;
    tzdata.initializeTimeZones();
    try {
      tz.setLocalLocation(tz.getLocation(await FlutterTimezone.getLocalTimezone()));
    } catch (e) {
      debugPrint('Using UTC for reminders: $e');
    }
    await _plugin.initialize(const InitializationSettings(
      iOS: DarwinInitializationSettings(
        requestAlertPermission: false,
        requestBadgePermission: false,
        requestSoundPermission: false,
      ),
    ));
    _ready = true;
  }

  @override
  Future<bool> requestPermission() async {
    if (!supported) return false;
    await _init();
    final ios = _plugin.resolvePlatformSpecificImplementation<
        IOSFlutterLocalNotificationsPlugin>();
    return await ios?.requestPermissions(alert: true, sound: true) ?? false;
  }

  @override
  Future<void> schedule(List<DailyReminder> reminders) async {
    if (!supported) return;
    await _init();
    await _plugin.cancelAll();
    const details = NotificationDetails(
      iOS: DarwinNotificationDetails(
        threadIdentifier: 'reminders',
        presentAlert: true,
        presentBanner: true,
        presentSound: true,
      ),
    );
    final now = tz.TZDateTime.now(tz.local);
    for (final r in reminders) {
      var first = tz.TZDateTime(tz.local, now.year, now.month, now.day, r.hour);
      if (!first.isAfter(now)) first = first.add(const Duration(days: 1));
      await _plugin.zonedSchedule(
        r.hour, // one notification per hour slot
        r.title,
        r.body,
        first,
        details,
        androidScheduleMode: AndroidScheduleMode.inexact,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        matchDateTimeComponents: DateTimeComponents.time, // every day
      );
    }
  }

  @override
  Future<void> cancelAll() async {
    if (!supported) return;
    await _init();
    await _plugin.cancelAll();
  }
}

/// Used by the demo build and tests.
class FakeReminderScheduler implements ReminderScheduler {
  FakeReminderScheduler({this.supported = true, this.grant = true});
  @override
  final bool supported;
  final bool grant;
  List<DailyReminder> scheduled = const [];

  @override
  Future<bool> requestPermission() async => grant;
  @override
  Future<void> schedule(List<DailyReminder> reminders) async => scheduled = reminders;
  @override
  Future<void> cancelAll() async => scheduled = const [];
}
