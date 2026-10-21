import 'dart:async';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/commitment.dart';
import '../models/employee.dart';
import '../models/supplier.dart';
import '../models/rule.dart';
import '../models/reminder.dart';
import 'app_state.dart';
import 'app_error_service.dart';
import '../models/customer.dart';

/// تطبيع النص العربي: إزالة التشكيل، توحيد الألفات، تاء مربوطة، ياء.
/// يُستخدم لمطابقة الأسماء في assistant_controller.dart بدل المقارنة الخام
/// التي تفشل عند اختلاف التشكيل أو نوع الألف.
/// لا يحوّل الاسم الأصلي — يُستخدم فقط للمطابقة.
String normalizeArabic(String value) {
  return value
      .trim()
      // إزالة التشكيل العربي (حركات النص)
      .replaceAll(RegExp(r'[ًٌٍَُِّْـ]'), '')
      // توحيد الألف همزة (أ، إ، آ → ا)
      .replaceAll('أ', 'ا')
      .replaceAll('إ', 'ا')
      .replaceAll('آ', 'ا')
      // تاء مربوطة → هاء (محمدَه → محمده)
      .replaceAll('ة', 'ه')
      // ياء أكبر → ياء صغيرة (علىًى → علىي)
      .replaceAll('ى', 'ي')
      // مسافة خالية (Arabic Zero-Width Space)
      .replaceAll('\u200b', '')
      // نوعة فارسية محتملة
      .replaceAll('ه', 'ه');
}

/// التخزين المحلي (§6).
///
/// قواعد السلامة المطبَّقة هنا:
/// - **قراءة متسامحة:** سجل JSON تالف واحد لا يُسقط القائمة كلها ولا يُنهي
///   التطبيق — يُتخطّى ويُسجَّل في سجل التشخيص، و**لا تُمسح البيانات الأصلية**.
/// - **كتابة مُتحقَّق منها:** نجاح `setStringList` لازم يكون مؤكدًا؛ لو رجع
///   false بنرمي [StorageException] عشان مفيش مسار يعرض نجاحًا وهميًا.
/// - **تسلسل الكتابات:** كل عملية (قراءة → تعديل → كتابة) بتتنفّذ واحدة ورا
///   التانية، فمافيش تعديل بيضيع لو حصلت كتابتان متزامنتان.
///
/// الترحيل إضافي فقط: مفاتيح JSON الجديدة بتتجاهلها النسخ الأقدم، فمفيش هدم
/// للبيانات عند تحديث التطبيق أو الرجوع لنسخة أقدم.
class StorageService {
  static late SharedPreferences _p;

  /// عدد السجلات التالفة اللي اتخطّيناها في آخر قراءة — للتشخيص فقط.
  static int lastCorruptCount = 0;

  static Future<void> init() async {
    _p = await SharedPreferences.getInstance();
    _gate = Future<void>.value(); // سلسلة كتابة جديدة (مفيش كتابة قديمة معلّقة)
    await purgeLegacyApiKey();
  }

  // ═════════════════= أدوات داخلية ═════════════════

  /// بوابة تسلسل: كل عملية كتابة بتستنى اللي قبلها تخلّص.
  static Future<void> _gate = Future<void>.value();

  static Future<T> _serialize<T>(Future<T> Function() action) {
    final completer = Completer<T>();
    _gate = _gate.then((_) async {
      try {
        completer.complete(await action());
      } catch (e, s) {
        completer.completeError(e, s);
      }
    });
    return completer.future;
  }

  /// قراءة قائمة كيانات مع تحمّل السجلات التالفة (بدون مسح أي بيانات).
  static List<T> _read<T>(String key, T Function(Map<String, dynamic>) parse) {
    final raw = _p.getStringList(key) ?? const <String>[];
    final out = <T>[];
    var corrupt = 0;
    for (final s in raw) {
      try {
        final j = jsonDecode(s);
        if (j is Map) {
          out.add(parse(Map<String, dynamic>.from(j)));
        } else {
          corrupt++;
        }
      } catch (e) {
        corrupt++;
        AppErrorService.log('storage.read($key)', e);
      }
    }
    lastCorruptCount = corrupt;
    if (corrupt > 0) {
      AppErrorService.log(
        'storage.read($key)',
        'تخطّينا $corrupt سجلًا تالفًا من أصل ${raw.length} — البيانات الأصلية لم تُمسح.',
      );
    }
    return out;
  }

  /// كتابة قائمة مؤكدة — ترمي [StorageException] لو الحفظ فشل.
  static Future<void> _write(String key, List<String> values) async {
    bool ok;
    try {
      ok = await _p.setStringList(key, values);
    } catch (e, s) {
      AppErrorService.log('storage.write($key)', e, s);
      throw StorageException('فشل حفظ البيانات ($key)', e);
    }
    if (!ok) {
      AppErrorService.log('storage.write($key)', 'setStringList رجع false');
      throw StorageException('فشل حفظ البيانات ($key)');
    }
  }

  // ---------------- Commitments ----------------
  static List<Commitment> commitments() =>
      _read('commitments', (j) => Commitment.fromJson(j));

  static Future<void> saveCommitment(Commitment c) => _serialize(() async {
        final x = commitments()
          ..removeWhere((e) => e.id == c.id)
          ..add(c);
        await _write(
            'commitments', x.map((e) => jsonEncode(e.toJson())).toList());
        AppState.instance.notify();
      });

  // ---------------- Employees ----------------
  static List<Employee> employees() =>
      _read('employees', (j) => Employee.fromJson(j));

  static Future<void> saveEmployee(Employee e) => _serialize(() async {
        final x = employees()
          ..removeWhere((a) => a.id == e.id)
          ..add(e);
        await _write(
            'employees', x.map((a) => jsonEncode(a.toJson())).toList());
        AppState.instance.notify();
      });

  /// البحث عن موظف بالاسم — يستخدم المطابقة الطبيعية لتجاوز اختلافات التشكيل.
  static Employee? findEmployee(String name) {
    if (name.trim().isEmpty) return null;
    final normalized = normalizeArabic(name);
    for (final e in employees()) {
      final eNorm = normalizeArabic(e.name);
      if (eNorm.contains(normalized) || normalized.contains(eNorm)) return e;
    }
    return null;
  }

  static Future<void> deleteEmployee(String id) => _serialize(() async {
        final x = employees()..removeWhere((e) => e.id == id);
        await _write(
            'employees', x.map((e) => jsonEncode(e.toJson())).toList());
        AppState.instance.notify();
      });

  /// كل الموظفين اللي اسمهم يطابق الاسم المذكور — تُستخدم لاكتشاف الالتباس
  /// (أكتر من موظف بنفس الاسم) بدل تخمين الأول اللي يتطابق.
  static List<Employee> employeesMatching(String name) {
    if (name.trim().isEmpty) return [];
    final normalized = normalizeArabic(name);
    return employees().where((e) {
      final eNorm = normalizeArabic(e.name);
      return eNorm.contains(normalized) || normalized.contains(eNorm);
    }).toList();
  }

  // ---------------- Suppliers ----------------
  static List<Supplier> suppliers() =>
      _read('suppliers', (j) => Supplier.fromJson(j));

  static Future<void> saveSupplier(Supplier s) => _serialize(() async {
        final x = suppliers()
          ..removeWhere((a) => a.id == s.id)
          ..add(s);
        await _write(
            'suppliers', x.map((a) => jsonEncode(a.toJson())).toList());
        AppState.instance.notify();
      });

  /// البحث عن مورد بالاسم — يستخدم المطابقة الطبيعية.
  static Supplier? findSupplier(String name) {
    if (name.trim().isEmpty) return null;
    final normalized = normalizeArabic(name);
    for (final s in suppliers()) {
      final sNorm = normalizeArabic(s.name);
      if (sNorm.contains(normalized) || normalized.contains(sNorm)) return s;
    }
    return null;
  }

  static Future<void> deleteSupplier(String id) => _serialize(() async {
        final x = suppliers()..removeWhere((s) => s.id == id);
        await _write(
            'suppliers', x.map((s) => jsonEncode(s.toJson())).toList());
        AppState.instance.notify();
      });

  /// المؤرشفون **مستبعدون** افتراضيًا: عملية جديدة (دفعة/توريد) ما تتسجلش
  /// على مورد مؤرشف إلا لو [includeArchived] اتطلب صراحةً.
  static List<Supplier> suppliersMatching(String name,
      {bool includeArchived = false}) {
    if (name.trim().isEmpty) return [];
    final normalized = normalizeArabic(name);
    return suppliers().where((s) {
      if (s.archived && !includeArchived) return false;
      final sNorm = normalizeArabic(s.name);
      return sNorm.contains(normalized) || normalized.contains(sNorm);
    }).toList();
  }

  // ---------------- Customers (المستحقات — بيع آجل) ----------------
  static List<Customer> customers() =>
      _read('customers', (j) => Customer.fromJson(j));

  static Future<void> saveCustomer(Customer c) => _serialize(() async {
        final x = customers()
          ..removeWhere((a) => a.id == c.id)
          ..add(c);
        await _write(
            'customers', x.map((a) => jsonEncode(a.toJson())).toList());
        AppState.instance.notify();
      });

  /// المؤرشفون مستبعدون افتراضيًا (عملية جديدة ما تتسجلش على عميل مؤرشف).
  static List<Customer> customersMatching(String name,
      {bool includeArchived = false}) {
    if (name.trim().isEmpty) return [];
    final normalized = normalizeArabic(name);
    return customers().where((c) {
      if (c.archived && !includeArchived) return false;
      final n = normalizeArabic(c.name);
      return n.contains(normalized) || normalized.contains(n);
    }).toList();
  }

  // ---------------- Rules ----------------
  static List<FollowUpRule> rules() =>
      _read('rules', (j) => FollowUpRule.fromJson(j));

  static Future<void> saveRule(FollowUpRule r) => _serialize(() async {
        final x = rules()
          ..removeWhere((a) => a.id == r.id)
          ..add(r);
        await _write('rules', x.map((a) => jsonEncode(a.toJson())).toList());
        AppState.instance.notify();
      });

  static Future<void> deleteRule(String id) => _serialize(() async {
        final x = rules()..removeWhere((a) => a.id == id);
        await _write('rules', x.map((a) => jsonEncode(a.toJson())).toList());
        AppState.instance.notify();
      });

  // ---------------- Reminders (Reminder entity — مستقلة عن Task/Commitment) ----------------
  static List<Reminder> reminders() =>
      _read('reminders', (j) => Reminder.fromJson(j));

  static Future<void> saveReminder(Reminder r) => _serialize(() async {
        final x = reminders()
          ..removeWhere((a) => a.id == r.id)
          ..add(r);
        await _write(
            'reminders', x.map((a) => jsonEncode(a.toJson())).toList());
        AppState.instance.notify();
      });

  static Future<void> deleteReminder(String id) => _serialize(() async {
        final x = reminders()..removeWhere((a) => a.id == id);
        await _write(
            'reminders', x.map((a) => jsonEncode(a.toJson())).toList());
        AppState.instance.notify();
      });

  static List<Reminder> remindersForEntity(String entityId) =>
      reminders().where((r) => r.relatedEntityId == entityId).toList();

  // ---------------- Settings ----------------
  /// مفتاح الخدمة الإضافية الاختيارية. فاضي افتراضيًا، وله حقل في شاشة
  /// الإعدادات لإدخال مفتاح المستخدم نفسه (§8/§9). المحرك المحلي يفضل
  /// شغال بالكامل غيابه، ووجوده بيفتح مسار Gemini كاحتياطي فقط.

  /// مفتاح Gemini القديم (اتشال من التطبيق): بنمسحه من الجهاز عند أول تشغيل،
  /// علشان ما يفضلش مفتاح حساب المستخدم متخزّن على هاتفه بدون استخدام.
  static Future<void> purgeLegacyApiKey() async {
    if (_p.containsKey('gemini_api_key')) {
      await _p.remove('gemini_api_key');
    }
  }
}
