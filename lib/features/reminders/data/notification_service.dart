import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import '../domain/reminder_plan.dart';

/// The shared notification service. Tests replace it with [FakeNotificationService].
final notificationServiceProvider = Provider<NotificationService>(
  (ref) => LocalNotificationService(),
);

/// Shows reminders on the phone.
abstract class NotificationService {
  /// Asks the player for permission to show notifications. True when allowed.
  Future<bool> requestPermission();

  /// Whether notifications are allowed right now, without asking.
  Future<bool> isAllowed();

  /// Throws away every scheduled reminder and schedules [reminders] instead.
  Future<void> replaceAll(List<PlannedReminder> reminders);
}

/// Used by tests: remembers what it was asked to schedule.
class FakeNotificationService implements NotificationService {
  FakeNotificationService({this.allowed = true});

  /// Whether the fake player allows notifications.
  bool allowed;

  /// How many times permission was asked for.
  int asked = 0;

  /// What is scheduled now.
  List<PlannedReminder> scheduled = const [];

  @override
  Future<bool> requestPermission() async {
    asked++;
    return allowed;
  }

  @override
  Future<bool> isAllowed() async => allowed;

  @override
  Future<void> replaceAll(List<PlannedReminder> reminders) async {
    scheduled = reminders;
  }
}

/// The real thing, on `flutter_local_notifications`. Reminders fire at about
/// the planned time: they are scheduled as inexact, so the phone may move them
/// a little to save battery, and no special alarm permission is needed.
class LocalNotificationService implements NotificationService {
  final _plugin = FlutterLocalNotificationsPlugin();
  bool _ready = false;

  Future<void> _init() async {
    if (_ready) return;
    tzdata.initializeTimeZones();
    try {
      final zone = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(zone.identifier));
    } catch (_) {
      // Falls back to UTC; reminders then land at the wrong local hour, but
      // nothing breaks.
    }
    await _plugin.initialize(
      settings: const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
        iOS: DarwinInitializationSettings(
          requestAlertPermission: false,
          requestBadgePermission: false,
          requestSoundPermission: false,
        ),
      ),
    );
    _ready = true;
  }

  @override
  Future<bool> requestPermission() async {
    try {
      await _init();
      final android = _plugin
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >();
      if (android != null) {
        return await android.requestNotificationsPermission() ?? false;
      }
      final ios = _plugin
          .resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin
          >();
      return await ios?.requestPermissions(alert: true, sound: true) ?? false;
    } catch (e) {
      debugPrint('Notification permission failed: $e');
      return false;
    }
  }

  @override
  Future<bool> isAllowed() async {
    try {
      await _init();
      final android = _plugin
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >();
      if (android != null) {
        return await android.areNotificationsEnabled() ?? false;
      }
      final ios = _plugin
          .resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin
          >();
      final options = await ios?.checkPermissions();
      return options?.isEnabled ?? false;
    } catch (_) {
      return false;
    }
  }

  @override
  Future<void> replaceAll(List<PlannedReminder> reminders) async {
    try {
      await _init();
      await _plugin.cancelAllPendingNotifications();
      for (final reminder in reminders) {
        await _plugin.zonedSchedule(
          id: reminder.id,
          title: reminder.title,
          body: reminder.body,
          scheduledDate: tz.TZDateTime.from(reminder.at, tz.local),
          notificationDetails: const NotificationDetails(
            android: AndroidNotificationDetails(
              'walks',
              'Walk reminders',
              channelDescription: 'A nudge from your cat to go for a walk',
              importance: Importance.defaultImportance,
              priority: Priority.defaultPriority,
            ),
            iOS: DarwinNotificationDetails(),
          ),
          androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        );
      }
    } catch (e) {
      debugPrint('Scheduling reminders failed: $e');
    }
  }
}
