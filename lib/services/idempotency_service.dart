import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

/// منع التنفيذ المزدوج **الدائم** (بيعدّي إعادة تشغيل التطبيق).
///
/// كل أمر وارد ليه مفتاح ثابت (معرّف رسالة الشات، أو «تأكيد استلام التزام X»).
/// أول مرة بينفّذ بنجاح بنسجّل مفتاحه مع الرد؛ لو نفس المفتاح اتبعت تاني
/// (ضغطة مكررة، إعادة محاولة، إعادة تسليم) بنرجّع الرد المسجّل **من غير ما نكتب
/// أي حاجة**. السجل محدود (آخر ٣٠٠ مفتاح / ٧ أيام) علشان ما يكبرش.
class IdempotencyService {
  IdempotencyService._();

  static const String _k = 'idem_v1';
  static const int maxEntries = 300;
  static const Duration ttl = Duration(days: 7);

  static SharedPreferences? _p;
  static Future<void> _lock = Future.value();

  static Future<void> init() async {
    _p ??= await SharedPreferences.getInstance();
  }

  /// للاختبارات: يعيد القراءة من التخزين (بعد setMockInitialValues).
  static void resetForTest() => _p = null;

  static Map<String, dynamic> _read() {
    final raw = _p?.getString(_k);
    if (raw == null || raw.isEmpty) return {};
    try {
      return Map<String, dynamic>.from(jsonDecode(raw) as Map);
    } catch (_) {
      return {}; // سجل تالف: بيتجاهل (مش بيانات مستخدم، ومش بنكسر بيه التطبيق)
    }
  }

  /// الرد المسجّل لهذا المفتاح لو لسه صالح، وإلا null.
  static String? lookup(String key, {DateTime? now}) {
    final e = _read()[key];
    if (e is! Map) return null;
    final t = DateTime.tryParse((e['t'] ?? '').toString());
    if (t == null) return null;
    if ((now ?? DateTime.now()).difference(t) > ttl) return null;
    return e['r']?.toString();
  }

  /// يسجّل تنفيذًا ناجحًا. تسلسلي (قفل) علشان التسجيلات المتزامنة ما تضيعش.
  static Future<void> remember(String key, String reply, {DateTime? now}) {
    final run = _lock.then((_) async {
      await init();
      final t = now ?? DateTime.now();
      final m = _read();
      m.removeWhere((_, v) {
        if (v is! Map) return true;
        final ts = DateTime.tryParse((v['t'] ?? '').toString());
        return ts == null || t.difference(ts) > ttl;
      });
      m[key] = {'r': reply, 't': t.toIso8601String()};
      if (m.length > maxEntries) {
        final keys = m.keys.toList()
          ..sort((a, b) => (m[a]['t'] as String).compareTo(m[b]['t'] as String));
        for (final k in keys.take(m.length - maxEntries)) {
          m.remove(k);
        }
      }
      await _p!.setString(_k, jsonEncode(m));
    });
    _lock = run.catchError((_) {});
    return run;
  }
}
