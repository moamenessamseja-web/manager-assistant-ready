import 'package:flutter/material.dart';
import '../services/storage_service.dart';
import '../design/tokens.dart';
import '../design/widgets.dart';

class BriefScreen extends StatelessWidget {
  const BriefScreen({super.key});
  @override
  Widget build(BuildContext c) {
    final cs = StorageService.commitments();
    final allEmployees = StorageService.employees();
    final allSuppliers = StorageService.suppliers();
    final es = allEmployees.where((e) => !e.archived).toList();
    final ss = allSuppliers.where((s) => !s.archived).toList();

    // الملخص المالي النشط لازم يحسب "متأخرات العملاء" فقط، مش كل أنواع
    // الالتزامات (موردين/قواعد/مهام) اللي كانت بتتجمع كلها قبل كده تحت
    // نفس الرقم بالغلط.
    final overdue = cs
        .where((x) => x.status == 'pending' && x.type == 'debt_to_collect' && x.dueDate.isBefore(DateTime.now()))
        .fold(0.0, (s, x) => s + (x.amount ?? 0));
    final adv = es.fold(0.0, (s, e) => s + e.totalAdvances);
    final suppliersDue = ss.fold(0.0, (s, e) => s + e.balanceDue);
    final pendingDeliveries = ss.fold<int>(0, (s, e) => s + e.pendingDeliveries.length);

    // أرشفة مورد/موظف وعليه مستحقات ما تماثلوش — الرقم بيفضل محفوظ تاريخيًا
    // وبيتعرض هنا بوضوح كـ"مؤرشف" بدل ما يختفي بصمت من الملخص.
    final archivedSuppliersWithBalance = allSuppliers.where((s) => s.archived && s.balanceDue > 0).toList();
    final archivedSuppliersBalance = archivedSuppliersWithBalance.fold(0.0, (s, x) => s + x.balanceDue);
    final archivedEmployeesWithBalance = allEmployees.where((e) => e.archived && e.remainingSalary > 0).toList();
    final archivedEmployeesBalance = archivedEmployeesWithBalance.fold(0.0, (s, x) => s + x.remainingSalary);

    return Scaffold(
      appBar: AppBar(title: const Text('بريف الأسبوع')),
      body: ListView(
        padding: const EdgeInsets.all(AppSpace.x4),
        children: [
          Row(children: [
            Expanded(child: AppBadge('${cs.length} التزامات', kind: AppStatusKind.info)),
            const SizedBox(width: AppSpace.x2),
            Expanded(child: AppBadge('${es.length} عاملين', kind: AppStatusKind.info)),
            const SizedBox(width: AppSpace.x2),
            Expanded(child: AppBadge('${ss.length} موردين', kind: AppStatusKind.info)),
          ]),
          const AppSectionHeader('الوضع المالي'),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(AppSpace.x4),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                _row('متأخرات عند العملاء', '${overdue.toStringAsFixed(0)} ج', overdue > 0 ? AppStatusKind.danger : AppStatusKind.success),
                _row('سلف العاملين', '${adv.toStringAsFixed(0)} ج', AppStatusKind.info),
                _row('مستحق للموردين', '${suppliersDue.toStringAsFixed(0)} ج', suppliersDue > 0 ? AppStatusKind.warning : AppStatusKind.success),
                _row('توريدات متوقعة', '$pendingDeliveries', AppStatusKind.info),
              ]),
            ),
          ),
          if (archivedSuppliersWithBalance.isNotEmpty || archivedEmployeesWithBalance.isNotEmpty) ...[
            const AppSectionHeader('مؤرشفين وعليهم مستحقات قديمة'),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(AppSpace.x4),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  if (archivedSuppliersWithBalance.isNotEmpty)
                    _row('موردين مؤرشفين (${archivedSuppliersWithBalance.length})',
                        '${archivedSuppliersBalance.toStringAsFixed(0)} ج', AppStatusKind.warning),
                  if (archivedEmployeesWithBalance.isNotEmpty)
                    _row('عاملين مؤرشفين (${archivedEmployeesWithBalance.length})',
                        '${archivedEmployeesBalance.toStringAsFixed(0)} ج', AppStatusKind.warning),
                ]),
              ),
            ),
          ],
          const SizedBox(height: AppSpace.x4),
          const Text('هذا ملخص حسابي من البيانات المحلية المسجلة على جهازك.', style: AppText.bodyMuted),
        ],
      ),
    );
  }

  Widget _row(String label, String value, AppStatusKind kind) => Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpace.x1),
        child: Row(children: [
          Expanded(child: Text(label, style: AppText.body)),
          AppBadge(value, kind: kind),
        ]),
      );
}
