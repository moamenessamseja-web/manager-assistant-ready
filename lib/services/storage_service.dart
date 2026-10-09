import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/commitment.dart';
import '../models/employee.dart';
import '../models/supplier.dart';
import '../models/rule.dart';
import '../models/reminder.dart';
import 'app_state.dart';

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

class StorageService {
  static late SharedPreferences _p;

  static Future<void> init() async {
    _p = await SharedPreferences.getInstance();
  }

  // ---------------- Commitments ----------------
  static List<Commitment> commitments() => (_p.getStringList('commitments') ?? [])
      .map((s) => Commitment.fromJson(jsonDecode(s)))
      .toList();

  static Future<void> saveCommitment(Commitment c) async {
    final x = commitments()
      ..removeWhere((e) => e.id == c.id)
      ..add(c);
    await _p.setStringList('commitments', x.map((e) => jsonEncode(e.toJson())).toList());
    AppState.instance.notify();
  }

  // ---------------- Employees ----------------
  static List<Employee> employees() => (_p.getStringList('employees') ?? [])
      .map((s) => Employee.fromJson(jsonDecode(s)))
      .toList();

  static Future<void> saveEmployee(Employee e) async {
    final x = employees()
      ..removeWhere((a) => a.id == e.id)
      ..add(e);
    await _p.setStringList('employees', x.map((a) => jsonEncode(a.toJson())).toList());
    AppState.instance.notify();
  }

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

  /// كل الموظفين اللي اسمهم يطابق الاسم المذكور — تُستخدم لاكتشاف الالتباس
  /// (أكتر من موظف بنفس الاسم) بدل تخمين الأول اللي يتطابق.
  /// تستخدم المطابقة الطبيعية لتفادي فشل المطابقة بسبب التشكيل.
  static Future<void> deleteEmployee(String id) async {
    final x = employees()..removeWhere((e) => e.id == id);
    await _p.setStringList('employees', x.map((e) => jsonEncode(e.toJson())).toList());
    AppState.instance.notify();
  }

  static List<Employee> employeesMatching(String name) {
    if (name.trim().isEmpty) return [];
    final normalized = normalizeArabic(name);
    return employees().where((e) {
      final eNorm = normalizeArabic(e.name);
      return eNorm.contains(normalized) || normalized.contains(eNorm);
    }).toList();
  }

  // ---------------- Suppliers ----------------
  static List<Supplier> suppliers() => (_p.getStringList('suppliers') ?? [])
      .map((s) => Supplier.fromJson(jsonDecode(s)))
      .toList();

  static Future<void> saveSupplier(Supplier s) async {
    final x = suppliers()
      ..removeWhere((a) => a.id == s.id)
      ..add(s);
    await _p.setStringList('suppliers', x.map((a) => jsonEncode(a.toJson())).toList());
    AppState.instance.notify();
  }

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

  static Future<void> deleteSupplier(String id) async {
    final x = suppliers()..removeWhere((s) => s.id == id);
    await _p.setStringList('suppliers', x.map((s) => jsonEncode(s.toJson())).toList());
    AppState.instance.notify();
  }

  static List<Supplier> suppliersMatching(String name) {
    if (name.trim().isEmpty) return [];
    final normalized = normalizeArabic(name);
    return suppliers().where((s) {
      final sNorm = normalizeArabic(s.name);
      return sNorm.contains(normalized) || normalized.contains(sNorm);
    }).toList();
  }

  // ---------------- Rules ----------------
  static List<FollowUpRule> rules() => (_p.getStringList('rules') ?? [])
      .map((s) => FollowUpRule.fromJson(jsonDecode(s)))
      .toList();

  static Future<void> saveRule(FollowUpRule r) async {
    final x = rules()
      ..removeWhere((a) => a.id == r.id)
      ..add(r);
    await _p.setStringList('rules', x.map((a) => jsonEncode(a.toJson())).toList());
    AppState.instance.notify();
  }

  static Future<void> deleteRule(String id) async {
    final x = rules()..removeWhere((a) => a.id == id);
    await _p.setStringList('rules', x.map((a) => jsonEncode(a.toJson())).toList());
    AppState.instance.notify();
  }

  // ---------------- Reminders (Reminder entity — مستقلة عن Task/Commitment) ----------------
  static List<Reminder> reminders() => (_p.getStringList('reminders') ?? [])
      .map((s) => Reminder.fromJson(jsonDecode(s)))
      .toList();

  static Future<void> saveReminder(Reminder r) async {
    final x = reminders()
      ..removeWhere((a) => a.id == r.id)
      ..add(r);
    await _p.setStringList('reminders', x.map((a) => jsonEncode(a.toJson())).toList());
    AppState.instance.notify();
  }

  static Future<void> deleteReminder(String id) async {
    final x = reminders()..removeWhere((a) => a.id == id);
    await _p.setStringList('reminders', x.map((a) => jsonEncode(a.toJson())).toList());
    AppState.instance.notify();
  }

  static List<Reminder> remindersForEntity(String entityId) =>
      reminders().where((r) => r.relatedEntityId == entityId).toList();

  // ---------------- Settings ----------------
  static String get apiKey => _p.getString('gemini_api_key') ?? '';
  static Future<void> setApiKey(String v) => _p.setString('gemini_api_key', v);
}
