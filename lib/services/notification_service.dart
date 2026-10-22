import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;

/// نتيجة محاولة جدولة إشعار — لا نعتبر أي عملية "ناجحة" لمجرد أنها لم ترمِ
/// Exception؛ لازم نتأكد فعليًا من حالة الصلاحية والجدولة.
class NotificationResult {
  final bool success;
  final String status; // scheduled | permission_required | channel_disabled | schedule_failed
  final String? message; // 'inexact' = اتجدولت لكن النظام مش مدّي صلاحية «منبه دقيق»
  const NotificationResult(this.success, this.status, [this.message]);
}

/// الطبقة اللي بتكلّم أندرويد فعليًا. موجودة كواجهة علشان الاختبارات تحقن
/// بديل بيسجّل اللي اتجدول/اتلغى (الإضافة الحقيقية ماتشتغلش في اختبارات Dart).
abstract class NotificationBackend {
  Future<bool> permissionGranted();
  Future<bool> canScheduleExact();
  Future<bool> requestExact();
  Future<void> schedule(int id, String title, String body, DateTime when,
      {required bool exact});
  Future<void> cancel(int id);
}

class PluginNotificationBackend implements NotificationBackend {
  AndroidFlutterLocalNotificationsPlugin? get _a => NotificationService.plugin
      .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();

  @override
  Future<bool> permissionGranted() async =>
      await _a?.areNotificationsEnabled() ?? true;

  @override
  Future<bool> canScheduleExact() async =>
      await _a?.canScheduleExactNotifications() ?? false;

  @override
  Future<bool> requestExact() async =>
      await _a?.requestExactAlarmsPermission() ?? false;

  @override
  Future<void> schedule(int id, String title, String body, DateTime when,
      {required bool exact}) {
    return NotificationService.plugin.zonedSchedule(
      id,
      title,
      body,
      tz.TZDateTime.from(when, tz.local), // لحظة مطلقة: مش بتتأثر بمنطقة الجهاز
      const NotificationDetails(
        android: AndroidNotificationDetails(
          NotificationService.channelId,
          NotificationService.channelName,
          importance: Importance.max,
          priority: Priority.high,
        ),
      ),
      androidScheduleMode: exact
          ? AndroidScheduleMode.exactAllowWhileIdle
          : AndroidScheduleMode.inexactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
    );
  }

  @override
  Future<void> cancel(int id) => NotificationService.plugin.cancel(id);
}

class NotificationService {
  static final plugin = FlutterLocalNotificationsPlugin();
  static const String channelId = 'manager_reminders';
  static const String channelName = 'تذكيرات الإدارة';

  /// قابل للاستبدال في الاختبارات فقط.
  static NotificationBackend backend = PluginNotificationBackend();

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
  static Future<bool> requestPermission() async {
    final granted = await _android?.requestNotificationsPermission();
    return granted ?? true; // على المنصات/الإصدارات القديمة اللي محتاجاش طلب صريح
  }

  static Future<bool> permissionGranted() => backend.permissionGranted();

  /// هل النظام سامح بمنبهات **دقيقة** (SCHEDULE_EXACT_ALARM)؟ من غيرها أندرويد
  /// ممكن يتأخّر الإشعار دقائق (وضع توفير الطاقة/Doze).
  static Future<bool> exactAlarmsAllowed() => backend.canScheduleExact();

  /// بيفتح شاشة إعدادات النظام لمنح «المنبهات والتذكيرات» (أندرويد 12+).
  static Future<bool> requestExactAlarms() => backend.requestExact();

  /// id إشعار رقم [i] في سلسلة تذكير متكرر (i=0 هو الـ id الأساسي).
  static int seriesId(int base, int i) =>
      i == 0 ? base : ((base * 31 + i) & 0x7fffffff);

  static Future<NotificationResult> scheduleAt(
          int id, String title, String body, DateTime when) =>
      scheduleSeries(id, title, body, [when]);

  /// يجدول إشعار لكل موعد في [times] (المستقبلي فقط). بيستخدم منبه **دقيق** لو
  /// مسموح، وإلا بيرجع لجدولة تقريبية ويعلّم النتيجة بـ message='inexact'.
  /// المواعيد المتعددة = تذكير متكرر بيوصل حتى لو التطبيق ما اتفتحش.
  static Future<NotificationResult> scheduleSeries(
      int baseId, String title, String body, List<DateTime> times) async {
    if (!await permissionGranted()) {
      return const NotificationResult(
          false, 'permission_required', 'صلاحية الإشعارات غير مفعّلة');
    }
    final now = DateTime.now();
    final exact = await backend.canScheduleExact();
    var scheduledAny = false;
    var usedInexact = !exact;
    for (var i = 0; i < times.length; i++) {
      final when = times[i];
      if (!when.isAfter(now)) continue;
      final id = seriesId(baseId, i);
      try {
        try {
          await backend.schedule(id, title, body, when, exact: exact);
        } catch (_) {
          if (!exact) rethrow;
          // الصلاحية اتسحبت بين الفحص والجدولة: نرجع لجدولة تقريبية.
          usedInexact = true;
          await backend.schedule(id, title, body, when, exact: false);
        }
        scheduledAny = true;
      } catch (e) {
        return NotificationResult(false, 'schedule_failed', e.toString());
      }
    }
    if (!scheduledAny) {
      // موعد في الماضي — لا داعي لجدولته، لكنها ليست حالة فشل بالمعنى التقني
      return const NotificationResult(
          true, 'scheduled', 'الموعد في الماضي، لم تتم الجدولة الفعلية');
    }
    return NotificationResult(true, 'scheduled', usedInexact ? 'inexact' : null);
  }

  /// يلغي الإشعار الأساسي وكل مواعيد السلسلة المرتبطة بالتذكير.
  static Future<void> cancel(String reminderId, {int seriesMax = 60}) async {
    final base = reminderId.hashCode;
    for (var i = 0; i < seriesMax; i++) {
      await backend.cancel(seriesId(base, i));
    }
  }

  static Future<List<PendingNotificationRequest>> pending() => plugin.pendingNotificationRequests();
}
