import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import '../models/commitment.dart';

class NotificationService {
  static final plugin = FlutterLocalNotificationsPlugin();

  static Future<void> init() async {
    const a = AndroidInitializationSettings('@mipmap/ic_launcher');
    await plugin.initialize(const InitializationSettings(android: a));
  }

  static Future<void> scheduleAt(int id, String title, String body, DateTime when) async {
    final tzWhen = tz.TZDateTime.from(when, tz.local);
    if (tzWhen.isBefore(tz.TZDateTime.now(tz.local))) return;
    await plugin.zonedSchedule(
      id,
      title,
      body,
      tzWhen,
      const NotificationDetails(
        android: AndroidNotificationDetails('manager_reminders', 'تذكيرات الإدارة',
            importance: Importance.max, priority: Priority.high),
      ),
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
    );
  }

  static Future<void> scheduleCommitment(Commitment c) =>
      scheduleAt(c.id.hashCode, 'تذكير: ${c.person}', c.textOriginal, c.remindAt);

  // اسم قديم محتفظ به للتوافق مع الكود الحالي
  static Future<void> schedule(Commitment c) => scheduleCommitment(c);

  static Future<void> cancel(String id) => plugin.cancel(id.hashCode);
}
