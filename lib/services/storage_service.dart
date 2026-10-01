import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/commitment.dart';
import '../models/employee.dart';
import '../models/supplier.dart';
import '../models/rule.dart';

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
  }

  static Employee? findEmployee(String name) {
    for (final e in employees()) {
      if (e.name.contains(name) || name.contains(e.name)) return e;
    }
    return null;
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
  }

  static Supplier? findSupplier(String name) {
    for (final s in suppliers()) {
      if (s.name.contains(name) || name.contains(s.name)) return s;
    }
    return null;
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
  }

  static Future<void> deleteRule(String id) async {
    final x = rules()..removeWhere((a) => a.id == id);
    await _p.setStringList('rules', x.map((a) => jsonEncode(a.toJson())).toList());
  }

  // ---------------- Settings ----------------
  static String get apiKey => _p.getString('gemini_api_key') ?? '';
  static Future<void> setApiKey(String v) => _p.setString('gemini_api_key', v);
}
