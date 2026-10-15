import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

/// خطأ تخزين — يُرمى لو فشلت كتابة البيانات فعليًا، عشان مفيش مسار يعرض
/// «نجاح» من غير ما يكون الحفظ اتأكد (§6).
class StorageException implements Exception {
  final String message;
  final Object? cause;
  StorageException(this.message, [this.cause]);
  @override
  String toString() => 'StorageException: $message';
}

/// فئة الخطأ المفهومة — بنصنّف الخطأ بدل ما نعرض نص الاستثناء الخام للمستخدم.
enum AppErrorKind { storage, network, notification, input, unexpected }

/// طبقة موحّدة لمعالجة الأخطاء (§8).
///
/// مسؤولياتها:
/// - تسجيل التفاصيل التقنية في سجل تشخيص محلي (بدون أي مفاتيح أو بيانات حساسة).
/// - تصنيف الخطأ إلى فئة مفهومة.
/// - إرجاع رسالة عربية مناسبة للمستخدم النهائي.
///
/// **قاعدة صريحة:** مفيش أي دالة هنا ترجّع نجاحًا. الخطأ يفضل خطأً، ومش بيتحوّل
/// لرسالة نجاح ولا لرسالة «لم أفهم» عامة.
class AppErrorService {
  AppErrorService._();

  static SharedPreferences? _p;
  static const String _kLog = 'diagnostics_log';
  static const int _maxEntries = 60;
  static final List<String> _buffer = <String>[];

  static Future<void> init() async {
    _p ??= await SharedPreferences.getInstance();
    if (_buffer.isEmpty) {
      final raw = _p!.getString(_kLog);
      if (raw != null && raw.isNotEmpty) {
        try {
          _buffer.addAll(List<String>.from(jsonDecode(raw) as List));
        } catch (_) {
          // سجل تالف لا يمنع تشغيل التطبيق — نبدأ سجلًا جديدًا.
        }
      }
    }
  }

  /// يسجّل تفاصيل تقنية **محليًا فقط** — بعد إخفاء أي مفتاح أو رمز سري.
  static void log(String context, Object error, [StackTrace? st]) {
    final entry =
        '${DateTime.now().toIso8601String()} | $context | ${_sanitize(error)}';
    _buffer.add(entry);
    while (_buffer.length > _maxEntries) {
      _buffer.removeAt(0);
    }
    _persist();
  }

  /// أحدث الإدخالات أولاً — للعرض في شاشة التشخيص فقط.
  static List<String> entries() => List.unmodifiable(_buffer.reversed.toList());

  static Future<void> clear() async {
    _buffer.clear();
    await _p?.remove(_kLog);
  }

  static Future<void> _persist() async {
    try {
      await _p?.setString(_kLog, jsonEncode(_buffer));
    } catch (_) {
      // لو حتى السجل فشل، ممنوع نكسر التطبيق.
    }
  }

  /// إخفاء أي شيء يشبه مفتاحًا أو رمزًا سريًا قبل التسجيل.
  static String _sanitize(Object error) {
    var s = error.toString();
    s = s.replaceAll(RegExp(r'AIza[0-9A-Za-z_\-]{10,}'), '[redacted]');
    s = s.replaceAll(
      RegExp(
          r'(api[_-]?key|apikey|key|token|authorization|bearer)["\s:=]+[^\s",}]+',
          caseSensitive: false),
      r'$1=[redacted]',
    );
    return s.length > 300 ? '${s.substring(0, 300)}…' : s;
  }

  static AppErrorKind classify(Object error) {
    if (error is StorageException) return AppErrorKind.storage;
    final s = error.toString().toLowerCase();
    if (s.contains('socket') ||
        s.contains('timeout') ||
        s.contains('connection') ||
        s.contains('network') ||
        s.contains('http') ||
        s.contains('unreachable')) {
      return AppErrorKind.network;
    }
    if (s.contains('notification') || s.contains('schedule')) {
      return AppErrorKind.notification;
    }
    if (s.contains('format') || s.contains('parse') || s.contains('invalid')) {
      return AppErrorKind.input;
    }
    return AppErrorKind.unexpected;
  }

  /// رسالة عربية مناسبة للمستخدم — بدون أي تفاصيل تقنية أو أسماء داخلية.
  static String userMessage(Object error) {
    switch (classify(error)) {
      case AppErrorKind.storage:
        return 'لم نتمكن من حفظ العملية. لم يتم تأكيد تسجيلها. حاول مرة أخرى.';
      case AppErrorKind.network:
        return 'تعذر استخدام خدمة المساعدة الإضافية حاليًا، لكن كل العمليات '
            'المدعومة شغالة من غيرها.';
      case AppErrorKind.notification:
        return 'تم تسجيل العملية بنجاح، لكن تعذر ضبط التذكير. تقدر تتابع '
            'إعدادات التنبيهات.';
      case AppErrorKind.input:
        return 'البيانات المدخلة ناقصة أو غير صحيحة. جرّب تصيغ الأمر بشكل أوضح.';
      case AppErrorKind.unexpected:
        return 'حصلت مشكلة غير متوقعة. حاول مرة أخرى.';
    }
  }
}
