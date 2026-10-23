import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;

import '../models/reminders.dart';

/// Schedules reminders on the device itself. No server or push key is
/// involved: the app works out the text from the tasks it already has and
/// re-plans whenever they change.
abstract class ReminderScheduler {
  /// Reminders are iPhone-only for now.
  bool get supported;

  /// Asks for notification permission. True if allowed.
  Future<bool> requestPermission();

  /// Replaces every pending reminder with [reminders].
  Future<void> schedule(List<PlannedReminder> reminders);

  Future<void> cancelAll();
}

class LocalReminderScheduler implements ReminderScheduler {
  final _plugin = FlutterLocalNotificationsPlugin();
  bool _ready = false;

  @override
  bool get supported => !kIsWeb && defaultTargetPlatform == TargetPlatform.iOS;

  Future<void> _init() async {
    if (_ready) return;
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
  Future<void> schedule(List<PlannedReminder> reminders) async {
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
    for (var i = 0; i < reminders.length; i++) {
      final r = reminders[i];
      // `when` is a local wall-clock time; as an absolute instant in UTC it
      // fires at exactly that moment, so no time-zone database is needed.
      await _plugin.zonedSchedule(
        i,
        r.title,
        r.body,
        tz.TZDateTime.from(r.when.toUtc(), tz.UTC),
        details,
        androidScheduleMode: AndroidScheduleMode.inexact,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
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
  List<PlannedReminder> scheduled = const [];

  @override
  Future<bool> requestPermission() async => grant;
  @override
  Future<void> schedule(List<PlannedReminder> reminders) async => scheduled = reminders;
  @override
  Future<void> cancelAll() async => scheduled = const [];
}
