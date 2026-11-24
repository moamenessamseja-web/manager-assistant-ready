import 'dart:convert';
import 'package:manager_assistant/models/audit_entry.dart';
import 'package:manager_assistant/models/commitment.dart';
import 'package:manager_assistant/models/customer.dart';
import 'package:manager_assistant/models/employee.dart';
import 'package:manager_assistant/models/reminder.dart';
import 'package:manager_assistant/models/rule.dart';
import 'package:manager_assistant/models/shift.dart';
import 'package:manager_assistant/models/shortage.dart';
import 'package:manager_assistant/models/supplier.dart';

List<String> enc(List<Map<String, dynamic>> l) => l.map(jsonEncode).toList();

/// بيانات كافيه كاملة: كل نوع سجل + أرصدة معروفة.
Map<String, dynamic> sampleData() {
  final emp = Employee(
      id: 'e1', name: 'أحمد', role: 'عامل', startDate: DateTime(2026, 11, 1), salaryMonthly: 3000,
      photoPath: '/data/user/0/app/employee_photos/e1_1.jpg')
    ..advances.add(Advance(id: 'a1', amount: 200, date: DateTime(2026, 11, 20), note: 'سلفة'))
    ..payments.add(EmployeePayment(id: 'ep1', amount: 900, date: DateTime(2026, 11, 21)))
    ..deductions.add(EmployeeDeduction(id: 'd1', amount: 50, reason: 'تأخير', date: DateTime(2026, 11, 21)))
    ..tips.add(EmployeeTip(id: 't1', amount: 30, date: DateTime(2026, 11, 21)))
    ..attendance.addAll(['2026-11-20', '2026-11-21']);
  final emp2 = Employee(
      id: 'e2', name: 'منى', role: 'كاشير', startDate: DateTime(2026, 11, 2), salaryMonthly: 2500);
  final sup = Supplier(id: 's1', name: 'جمال', itemType: 'لبن');
  sup.purchases.add(SupplierPurchase(id: 'pu1', item: 'لبن', total: 1000, date: DateTime(2026, 11, 20)));
  sup.payments.add(SupplierPayment(id: 'sp1', amount: 400, date: DateTime(2026, 11, 21)));
  final c1 = Customer(id: 'c1', name: 'حموده')
    ..addSale(CreditSale(id: 'o1', item: 'رصيد سابق', total: 500, date: DateTime(2026, 11, 1), opening: true))
    ..addSale(CreditSale(id: 's1', item: 'طلبات', total: 300, date: DateTime(2026, 11, 20, 12)))
    ..addPayment(CustomerPayment(id: 'p1', amount: 100, date: DateTime(2026, 11, 21)));
  final c2 = Customer(id: 'c2', name: 'جمال العميل')
    ..addPayment(CustomerPayment(id: 'po', amount: 80, date: DateTime(2026, 11, 1), opening: true));
  final promise = Commitment(
      id: 'promise_1', textOriginal: 'فكرني حموده هيدفع', person: 'حموده', type: 'customer_promise',
      amount: 400, dueDate: DateTime(2026, 11, 25, 17), remindAt: DateTime(2026, 11, 25, 17), customerId: 'c1');
  final rem = Reminder(
      id: 'r1', title: 'وعد دفع', body: 'x', dueAt: DateTime(2026, 11, 25, 17),
      createdAt: DateTime(2026, 11, 21), updatedAt: DateTime(2026, 11, 21));
  final rule = FollowUpRule(
      id: 'ru1', text: 'كل أول الشهر الإيجار', frequency: 'monthly', anchor: 1, amount: 8000,
      nextDue: DateTime(2026, 12, 1));
  final shift = Shift(
      id: 'sh1', businessDate: '2026-11-21', name: 'صباحي', openedAt: DateTime(2026, 11, 21, 8),
      closedAt: DateTime(2026, 11, 21, 16), openingCash: 100, cashSales: 700,
      snapshot: const ShiftTotals(cashSales: 700, collections: 100));
  final daily = DailyClosing(
      id: 'dc1', businessDate: '2026-11-21', closedAt: DateTime(2026, 11, 21, 17), shiftIds: ['sh1'],
      totals: const ShiftTotals(cashSales: 700, collections: 100));
  final shortage = ShortageItem(
      id: 'n1', item: 'بن', quantity: 5, unit: 'كيلو', supplierId: 's1', supplierName: 'جمال',
      createdAt: DateTime(2026, 11, 21))
    ..setStatus(ShortageItem.ordered, DateTime(2026, 11, 22));
  final audit = AuditEntry(
      id: 'au1', at: DateTime(2026, 11, 22), action: 'void', ownerType: 'employee', ownerId: 'e1',
      ownerName: 'أحمد', recordType: 'advance', recordId: 'a0', summary: 'سلفة 100', amount: 100,
      reason: 'غلطة', original: {'id': 'a0', 'amount': 100});
  Map<String, dynamic> sl(List<Map<String, dynamic>> l) => {'t': 'sl', 'v': enc(l)};
  return {
    'employees': sl([emp.toJson(), emp2.toJson()]),
    'suppliers': sl([sup.toJson()]),
    'customers': sl([c1.toJson(), c2.toJson()]),
    'commitments': sl([promise.toJson()]),
    'reminders': sl([rem.toJson()]),
    'rules': sl([rule.toJson()]),
    'shifts': sl([shift.toJson()]),
    'daily_closings': sl([daily.toJson()]),
    'shortages': sl([shortage.toJson()]),
    'audit_log': sl([audit.toJson()]),
    'pref_theme_mode': {'t': 's', 'v': 'dark'},
    'notif_cat_rules': {'t': 'b', 'v': false},
    'notif_lead_minutes': {'t': 'i', 'v': 15},
    'cafe_name': {'t': 's', 'v': 'كافيه النيل'},
    'cafe_logo_path': {'t': 's', 'v': '/data/user/0/app/cafe_logo/logo_1.jpg'},
    'business_day_start_hour': {'t': 'i', 'v': 5},
  };
}

