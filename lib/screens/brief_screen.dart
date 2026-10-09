import 'package:flutter/material.dart';
import '../services/storage_service.dart';
import '../services/app_state.dart';
import '../design/tokens.dart';
import '../design/widgets.dart';
import 'staff_screen.dart';
import 'suppliers_screen.dart';

/// بريف الأسبوع — ملخص تشغيلي حي، مش تقرير ثابت.
/// كل رقم مهم يفتح المصدر بتاعه مباشرة.
class BriefScreen extends StatefulWidget {
  const BriefScreen({super.key});
  @override
  State<BriefScreen> createState() => _BriefScreenState();
}

class _BriefScreenState extends State<BriefScreen> {
  @override
  Widget build(BuildContext c) {
    return Scaffold(
      appBar: AppBar(title: const Text('بريف الأسبوع')),
      body: ListenableBuilder(
        listenable: AppState.instance,
        builder: (context, _) {
          final cs = StorageService.commitments();
          final allEmployees = StorageService.employees();
          final allSuppliers = StorageService.suppliers();
          final es = allEmployees.where((e) => !e.archived).toList();
          final ss = allSuppliers.where((s) => !s.archived).toList();

          final overdue = cs
              .where((x) => x.status == 'pending' && x.type == 'debt_to_collect' && x.dueDate.isBefore(DateTime.now()))
              .fold(0.0, (s, x) => s + (x.amount ?? 0));
          final adv = es.fold(0.0, (s, e) => s + e.totalAdvances);
          final suppliersDue = ss.fold(0.0, (s, e) => s + e.balanceDue);
          final pendingDeliveries = ss.fold<int>(0, (s, e) => s + e.pendingDeliveries.length);

          final archivedSuppliersWithBalance = allSuppliers.where((s) => s.archived && s.balanceDue > 0).toList();
          final archivedSuppliersBalance = archivedSuppliersWithBalance.fold(0.0, (s, x) => s + x.balanceDue);
          final archivedEmployeesWithBalance = allEmployees.where((e) => e.archived && e.remainingSalary > 0).toList();
          final archivedEmployeesBalance = archivedEmployeesWithBalance.fold(0.0, (s, x) => s + x.remainingSalary);

          final now = DateTime.now();
          final today = DateTime(now.year, now.month, now.day);
          final todayStr = today.toIso8601String().substring(0, 10);
          final absent = es.where((e) => !e.attendance.contains(todayStr)).toList();
          final pendingCommitments = cs.where((x) => x.status == 'pending').toList();
          final overdueCommitments = pendingCommitments.where((x) => x.dueDate.isBefore(today)).toList();

          return ListView(
            padding: const EdgeInsets.all(AppSpace.x4),
            children: [
              // ملخص مختصر
              Row(children: [
                Expanded(child: _StatCard('${cs.length}', 'التزامات', AppStatusKind.info, onTap: () {})),
                const SizedBox(width: AppSpace.x2),
                Expanded(child: _StatCard('${es.length}', 'عاملين', AppStatusKind.info, onTap: () {})),
                const SizedBox(width: AppSpace.x2),
                Expanded(child: _StatCard('${ss.length}', 'موردين', AppStatusKind.info, onTap: () {})),
              ]),

              const SizedBox(height: AppSpace.x4),

              // الوضع المالي
              const AppSectionHeader('الوضع المالي'),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(AppSpace.x4),
                  child: Column(children: [
                    _row('متأخرات عند العملاء', '${overdue.toStringAsFixed(0)} ج',
                        overdue > 0 ? AppStatusKind.danger : AppStatusKind.success,
                        onTap: overdue > 0 ? () => _showDebtorsDialog(context, overdueCommitments) : null),
                    _row('سلف العاملين', '${adv.toStringAsFixed(0)} ج', AppStatusKind.info,
                        onTap: es.isNotEmpty ? () => _navigateTo(context, const StaffScreen()) : null),
                    _row('مستحق للموردين', '${suppliersDue.toStringAsFixed(0)} ج',
                        suppliersDue > 0 ? AppStatusKind.warning : AppStatusKind.success,
                        onTap: ss.isNotEmpty ? () => _navigateTo(context, const SuppliersScreen()) : null),
                    _row('توريدات متوقعة', '$pendingDeliveries', AppStatusKind.info),
                  ]),
                ),
              ),

              // العاملون
              if (es.isNotEmpty) ...[
                const SizedBox(height: AppSpace.x4),
                AppSectionHeader(
                  'العاملين',
                  trailing: TextButton(
                    onPressed: () => _navigateTo(context, const StaffScreen()),
                    child: const Text('عرض الكل →'),
                  ),
                ),
                _InfoRow(
                  icon: absent.isNotEmpty ? Icons.warning_amber_rounded : Icons.check_circle,
                  iconColor: absent.isNotEmpty ? AppColors.warning : AppColors.success,
                  label: absent.isNotEmpty
                      ? '${absent.length} من ${es.length} لسه ما سجلوش حضور النهارده'
                      : 'كل العاملين سجلوا حضورهم ✅',
                  onTap: absent.isNotEmpty ? () => _showAbsentDialog(context, absent) : null,
                ),
              ],

              // المؤرشفين
              if (archivedSuppliersWithBalance.isNotEmpty || archivedEmployeesWithBalance.isNotEmpty) ...[
                const SizedBox(height: AppSpace.x4),
                const AppSectionHeader('مؤرشفين وعليهم مستحقات قديمة'),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(AppSpace.x4),
                    child: Column(children: [
                      if (archivedSuppliersWithBalance.isNotEmpty)
                        _row('موردين مؤرشفين (${archivedSuppliersWithBalance.length})',
                            '${archivedSuppliersBalance.toStringAsFixed(0)} ج', AppStatusKind.warning,
                            onTap: () => _navigateTo(context, const SuppliersScreen())),
                      if (archivedEmployeesWithBalance.isNotEmpty)
                        _row('عاملين مؤرشفين (${archivedEmployeesWithBalance.length})',
                            '${archivedEmployeesBalance.toStringAsFixed(0)} ج', AppStatusKind.warning,
                            onTap: () => _navigateTo(context, const StaffScreen())),
                    ]),
                  ),
                ),
              ],

              const SizedBox(height: AppSpace.x4),
              const Text('هذا ملخص حسابي من البيانات المحلية المسجلة على جهازك.', style: AppText.bodyMuted),
            ],
          );
        },
      ),
    );
  }

  Widget _row(String label, String value, AppStatusKind kind, {VoidCallback? onTap}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.sm),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpace.x1),
        child: Row(children: [
          Expanded(child: Text(label, style: AppText.body)),
          if (onTap != null) const Icon(Icons.chevron_left, size: 18, color: AppColors.textSecondary),
          const SizedBox(width: AppSpace.x1),
          AppBadge(value, kind: kind),
        ]),
      ),
    );
  }

  void _navigateTo(BuildContext context, Widget screen) {
    Navigator.push(context, MaterialPageRoute(builder: (_) => screen));
  }

  void _showDebtorsDialog(BuildContext context, List<dynamic> debtors) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('متأخرات العملاء'),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView(
            shrinkWrap: true,
            children: debtors.map<Widget>((c) => ListTile(
              title: Text('${c.person}${c.amount == null ? '' : ' - ${(c.amount as double).toStringAsFixed(0)} ج'}'),
              subtitle: Text('منذ ${c.dueDate.toString().substring(0, 10)}'),
              leading: const Icon(Icons.person_outline),
            )).toList(),
          ),
        ),
        actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('إغلاق'))],
      ),
    );
  }

  void _showAbsentDialog(BuildContext context, List<dynamic> absent) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('لم يسجلوا حضور'),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView(
            shrinkWrap: true,
            children: absent.map<Widget>((e) => ListTile(
              title: Text('${e.name} — ${e.role}'),
              leading: const Icon(Icons.person_outline),
            )).toList(),
          ),
        ),
        actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('إغلاق'))],
      ),
    );
  }
}

/// بطاقة رقم إحصائي مختصر قابلة للضغط.
class _StatCard extends StatelessWidget {
  final String value;
  final String label;
  final AppStatusKind kind;
  final VoidCallback? onTap;

  const _StatCard(this.value, this.label, this.kind, {this.onTap});

  @override
  Widget build(BuildContext context) {
    final (bg, fg) = switch (kind) {
      AppStatusKind.success => (AppColors.successBg, AppColors.success),
      AppStatusKind.warning => (AppColors.warningBg, AppColors.warning),
      AppStatusKind.danger => (AppColors.dangerBg, AppColors.danger),
      AppStatusKind.info => (AppColors.infoBg, AppColors.info),
    };
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.md),
      child: Container(
        padding: const EdgeInsets.all(AppSpace.x3),
        decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(AppRadius.md)),
        child: Column(children: [
          Text(value, style: TextStyle(fontSize: 24, fontWeight: FontWeight.w700, color: fg)),
          const SizedBox(height: 2),
          Text(label, style: AppText.caption.copyWith(color: fg)),
        ]),
      ),
    );
  }
}

/// صف معلومات مختصر مع أيقونة.
class _InfoRow extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String label;
  final VoidCallback? onTap;

  const _InfoRow({required this.icon, required this.iconColor, required this.label, this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.sm),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpace.x2, horizontal: AppSpace.x1),
        child: Row(children: [
          Icon(icon, color: iconColor, size: AppIconSize.md),
          const SizedBox(width: AppSpace.x2),
          Expanded(child: Text(label, style: AppText.body)),
          if (onTap != null) const Icon(Icons.chevron_left, size: 18, color: AppColors.textSecondary),
        ]),
      ),
    );
  }
}
