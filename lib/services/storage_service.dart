import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/commitment.dart';
import '../models/employee.dart';
import '../models/supplier.dart';
import '../models/rule.dart';
import '../models/reminder.dart';
import 'app_state.dart';

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

  static Employee? findEmployee(String name) {
    for (final e in employees()) {
      if (e.name.contains(name) || name.contains(e.name)) return e;
    }
    return null;
  }

  /// كل الموظفين اللي اسمهم يطابق الاسم المذكور — تُستخدم لاكتشاف الالتباس
  /// (أكتر من موظف بنفس الاسم) بدل تخمين الأول اللي يتطابق.
  static Future<void> deleteEmployee(String id) async {
    final x = employees()..removeWhere((e) => e.id == id);
    await _p.setStringList('employees', x.map((e) => jsonEncode(e.toJson())).toList());
    AppState.instance.notify();
  }

  static List<Employee> employeesMatching(String name) =>
      employees().where((e) => e.name.contains(name) || name.contains(e.name)).toList();

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

  static Supplier? findSupplier(String name) {
    for (final s in suppliers()) {
      if (s.name.contains(name) || name.contains(s.name)) return s;
    }
    return null;
  }

  static Future<void> deleteSupplier(String id) async {
    final x = suppliers()..removeWhere((s) => s.id == id);
    await _p.setStringList('suppliers', x.map((s) => jsonEncode(s.toJson())).toList());
    AppState.instance.notify();
  }

  static List<Supplier> suppliersMatching(String name) =>
      suppliers().where((s) => s.name.contains(name) || name.contains(s.name)).toList();

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
