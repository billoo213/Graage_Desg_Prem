import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

class NotificationService {
  NotificationService._();
  static final NotificationService instance = NotificationService._();
  final FlutterLocalNotificationsPlugin _plugin = FlutterLocalNotificationsPlugin();
  bool _initialized = false;

  Future<void> initialize() async {
    if (_initialized) return;
    tz_data.initializeTimeZones();
    // Fuseau utilisé par défaut pour l'installation en Algérie.
    tz.setLocalLocation(tz.getLocation('Africa/Algiers'));
    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    await _plugin.initialize(const InitializationSettings(android: android));
    _initialized = true;
  }

  Future<bool> requestPermission() async {
    await initialize();
    final android = _plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    return await android?.requestNotificationsPermission() ?? false;
  }

  Future<void> showTestNotification() async {
    await initialize();
    await _plugin.show(900000, 'MON GARAGE', 'Les notifications sont activées.', _details());
  }

  Future<void> scheduleReminder({required int id, required String title,
    required String vehicleName, required DateTime date}) async {
    await initialize();
    final scheduled = tz.TZDateTime(tz.local, date.year, date.month, date.day, 9);
    if (scheduled.isBefore(tz.TZDateTime.now(tz.local))) {
      final now = tz.TZDateTime.now(tz.local);
      if (date.year == now.year && date.month == now.month && date.day == now.day) {
        await showDueReminder(id: id, title: title, vehicleName: vehicleName);
      }
      return;
    }
    await _plugin.zonedSchedule(
      id, 'Rappel : $title', 'Véhicule : $vehicleName', scheduled, _details(),
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      payload: 'reminder:$id',
    );
  }


  Future<void> showDueReminder({required int id, required String title, required String vehicleName}) async {
    await initialize();
    await _plugin.show(id, 'Échéance atteinte : $title', 'Véhicule : $vehicleName', _details());
  }

  Future<void> cancelReminder(int id) async {
    await initialize();
    await _plugin.cancel(id);
  }

  NotificationDetails _details() => const NotificationDetails(
    android: AndroidNotificationDetails(
      'mon_garage_reminders', 'Rappels MON GARAGE',
      channelDescription: 'Échéances d’entretien et rappels automobiles',
      importance: Importance.high, priority: Priority.high,
    ),
  );
}
