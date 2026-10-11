@Tags(['live'])
library;

import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:manager_assistant/models/employee.dart';
import 'package:manager_assistant/models/supplier.dart';
import 'package:manager_assistant/services/assistant_controller.dart';
import 'package:manager_assistant/services/storage_service.dart';

/// اختبار تكامل حقيقي من الطرف للطرف مع Gemini (To Accio §0: "اختبر التطبيق").
/// ينشئ بيانات، ينفّذ أوامر عربية عبر نفس مسار التطبيق، ثم يتحقّق من قاعدة البيانات.
///
/// المفتاح **لا** يُخزَّن في المستودع: يُقرأ من `GEMINI_API_KEY`،
/// ولو غير موجود يُتخطّى الاختبار فلا يكسر أي بيئة أو CI.
///
/// التشغيل: GEMINI_API_KEY=... flutter test test/gemini_live_test.dart
void main() {
  final key = Platform.environment['GEMINI_API_KEY'] ?? '';
  final skip = key.isEmpty ? 'GEMINI_API_KEY غير موجود — تم تخطّي الاختبار الحقيقي' : null;

  setUp(() async {
    if (key.isEmpty) return;
    SharedPreferences.setMockInitialValues({});
    await StorageService.init();
    await StorageService.setApiKey(key);
    await StorageService.saveSupplier(
        Supplier(id: 'sup1', name: 'محمود', itemType: 'بن'));
    await StorageService.saveEmployee(Employee(
        id: 'e1', name: 'علي', role: 'عامل',
        startDate: DateTime(2026, 10, 1), salaryMonthly: 6000));
    await StorageService.saveEmployee(Employee(
        id: 'e2', name: 'حسن', role: 'عامل',
        startDate: DateTime(2026, 10, 1), salaryMonthly: 6000));
  });

  test('توريد بقيمة: يزوّد البضاعة وميعملش دفعة (§2)', () async {
    final reply = await AssistantController.handle('سلمني بن من محمود 20 كيلو بـ 2000');
    final s = StorageService.suppliers().first;
    expect(s.purchases.length, 1, reason: reply);
    expect(s.goodsTotal, 2000, reason: reply);
    expect(s.totalPaid, 0, reason: reply);
    expect(s.balanceDue, 2000, reason: reply);
    expect(s.purchases.first.quantity, 20);
    expect(s.purchases.first.unit, 'كيلو');
  }, skip: skip);

  test('دفعة نقدية: تزوّد المدفوع وتقلّل المتبقي فقط (§2)', () async {
    await AssistantController.handle('سلمني بن من محمود 20 كيلو بـ 2000');
    final reply = await AssistantController.handle('دفعت لمحمود 500 جنيه');
    final s = StorageService.suppliers().first;
    expect(s.goodsTotal, 2000, reason: reply);
    expect(s.totalPaid, 500, reason: reply);
    expect(s.balanceDue, 1500, reason: reply);
  }, skip: skip);

  test('أمر بأكثر من اسم يُنفَّذ على كل الأسماء (§9)', () async {
    await AssistantController.handle('سجل حضور علي وحسن');
    final emps = StorageService.employees();
    final present = emps.where((e) => e.attendance.isNotEmpty).map((e) => e.name).toList();
    expect(present, containsAll(['علي', 'حسن']));
  }, skip: skip);
}
