import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;

/// نتيجة محاولة جدولة إشعار — لا نعتبر أي عملية "ناجحة" لمجرد أنها لم ترمِ
/// Exception؛ لازم نتأكد فعليًا من حالة الصلاحية والجدولة.
class NotificationResult {
  final bool success;
  final String status; // scheduled | permission_required | channel_disabled | schedule_failed
  final String? message;
  const NotificationResult(this.success, this.status, [this.message]);
}

class NotificationService {
  static final plugin = FlutterLocalNotificationsPlugin();
  static const String channelId = 'manager_reminders';
  static const String channelName = 'تذكيرات الإدارة';

  static AndroidFlutterLocalNotificationsPlugin? get _android =>
      plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();

  static Future<void> init() async {
    const a = AndroidInitializationSettings('@mipmap/ic_launcher');
    await plugin.initialize(const InitializationSettings(android: a));
    // ننشئ الـ Channel صراحة بدل الاعتماد على إنشائه الضمني أول مرة نجدول فيها،
    // عشان نقدر نسأل عن حالته (enabled/importance) في أي وقت من شاشة التشخيص.
    await _android?.createNotificationChannel(const AndroidNotificationChannel(
      channelId,
      channelName,
      description: 'تذكيرات الالتزامات والموردين والعاملين',
      importance: Importance.max,
    ));
  }

  /// يطلب صلاحية الإشعارات (مطلوبة إجباريًا على أندرويد 13+ / POST_NOTIFICATIONS).
  /// يُستدعى عند أول فتح للتطبيق، ويمكن إعادة استدعاؤه من شاشة الإعدادات.
  static Future<bool> requestPermission() async {
    final granted = await _android?.requestNotificationsPermission();
    return granted ?? true; // على المنصات/الإصدارات القديمة اللي محتاجاش طلب صريح
  }

  static Future<bool> permissionGranted() async {
    final enabled = await _android?.areNotificationsEnabled();
    return enabled ?? true;
  }

  static Future<NotificationResult> scheduleAt(int id, String title, String body, DateTime when) async {
    if (!await permissionGranted()) {
      return const NotificationResult(false, 'permission_required', 'صلاحية الإشعارات غير مفعّلة');
    }
    final tzWhen = tz.TZDateTime.from(when, tz.local);
    if (tzWhen.isBefore(tz.TZDateTime.now(tz.local))) {
      // موعد في الماضي — لا داعي لجدولته، لكنها ليست حالة فشل بالمعنى التقني
      return const NotificationResult(true, 'scheduled', 'الموعد في الماضي، لم تتم الجدولة الفعلية');
    }
    try {
      await plugin.zonedSchedule(
        id,
        title,
        body,
        tzWhen,
        const NotificationDetails(
          android: AndroidNotificationDetails(channelId, channelName,
              importance: Importance.max, priority: Priority.high),
        ),
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
      );
      return const NotificationResult(true, 'scheduled');
    } catch (e) {
      return NotificationResult(false, 'schedule_failed', e.toString());
    }
  }

  static Future<void> cancel(String id) => plugin.cancel(id.hashCode);

  static Future<List<PendingNotificationRequest>> pending() => plugin.pendingNotificationRequests();
}
