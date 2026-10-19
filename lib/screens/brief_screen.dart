import 'package:flutter/material.dart';
import '../services/storage_service.dart';
import '../services/app_state.dart';
import '../design/tokens.dart';
import '../design/app_theme.dart';
import '../design/widgets.dart';
import '../design/format.dart';
import 'staff_screen.dart';
import 'suppliers_screen.dart';
import 'ask_assistant.dart';

/// بريف الأسبوع — ملخص تشغيلي حي.
/// كل رقم مهم يفتح المصدر بتاعه مباشرة.
class BriefScreen extends StatefulWidget {
  const BriefScreen({super.key});

  @override
  State<BriefScreen> createState() => _BriefScreenState();
}

class _BriefScreenState extends State<BriefScreen> {
  @override
  Widget build(BuildContext context) {
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
              .where((x) =>
                  x.status == 'pending' &&
                  x.type == 'debt_to_collect' &&
                  x.dueDate.isBefore(DateTime.now()))
              .fold(0.0, (s, x) => s + (x.amount ?? 0));
          final adv = es.fold(0.0, (s, e) => s + e.totalAdvances);
          final suppliersDue = ss.fold(0.0, (s, e) => s + e.balanceDue);
          final pendingDeliveries =
              ss.fold<int>(0, (s, e) => s + e.pendingDeliveries.length);

          final archivedSuppliersWithBalance =
              allSuppliers.where((s) => s.archived && s.balanceDue > 0).toList();
          final archivedSuppliersBalance = archivedSuppliersWithBalance
              .fold(0.0, (s, x) => s + x.balanceDue);
          final archivedEmployeesWithBalance =
              allEmployees.where((e) => e.archived && e.remainingSalary > 0).toList();
          final archivedEmployeesBalance = archivedEmployeesWithBalance
              .fold(0.0, (s, x) => s + x.remainingSalary);

          final now = DateTime.now();
          final today = DateTime(now.year, now.month, now.day);
          final todayStr = today.toIso8601String().substring(0, 10);
          final absent = es.where((e) => !e.attendance.contains(todayStr)).toList();
          final pendingCommitments = cs.where((x) => x.status == 'pending').toList();
          final overdueCommitments =
              pendingCommitments.where((x) => x.dueDate.isBefore(today)).toList();

          return ListView(
            padding: const EdgeInsets.all(AppSpace.x4),
            children: [
              // اسأل المساعد — من البريف مباشرة
              const AskAssistantBar(),
              const SizedBox(height: AppSpace.x3),
              // Summary cards row
              Row(
                children: [
                  Expanded(
                    child: _StatCard(
                      '${cs.length}',
                      'التزامات',
                      BadgeKind.info,
                    ),
                  ),
                  const SizedBox(width: AppSpace.x2),
                  Expanded(
                    child: _StatCard(
                      '${es.length}',
                      'عاملين',
                      BadgeKind.info,
                    ),
                  ),
                  const SizedBox(width: AppSpace.x2),
                  Expanded(
                    child: _StatCard(
                      '${ss.length}',
                      'موردين',
                      BadgeKind.info,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: AppSpace.x4),

              // Financial situation
              AppSectionHeader(
                title: 'الوضع المالي',
                trailing: Text(
                  '${(overdue + adv + suppliersDue).toStringAsFixed(0)} ج إجمالى',
                  style: AppText.caption,
                ),
              ),
              AppCard(
                padding: const EdgeInsets.all(AppSpace.x4),
                child: Column(
                  children: [
                    _Row(
                      label: 'متأخرات عند العملاء',
                      value: '${overdue.toStringAsFixed(0)} ج',
                      badgeKind: overdue > 0 ? BadgeKind.danger : BadgeKind.success,
                      onTap: overdue > 0
                          ? () => _showDebtorsDialog(context, overdueCommitments)
                          : null,
                    ),
                    const SizedBox(height: AppSpace.x3),
                    _Row(
                      label: 'سلف العاملين',
                      value: '${adv.toStringAsFixed(0)} ج',
                      badgeKind: BadgeKind.info,
                      onTap: es.isNotEmpty
                          ? () => _navigateTo(context, const StaffScreen())
                          : null,
                    ),
                    const SizedBox(height: AppSpace.x3),
                    _Row(
                      label: 'مستحق للموردين',
                      value: '${suppliersDue.toStringAsFixed(0)} ج',
                      badgeKind:
                          suppliersDue > 0 ? BadgeKind.warning : BadgeKind.success,
                      onTap: ss.isNotEmpty
                          ? () => _navigateTo(context, const SuppliersScreen())
                          : null,
                    ),
                    const SizedBox(height: AppSpace.x3),
                    _Row(
                      label: 'توريدات متوقعة',
                      value: '$pendingDeliveries',
                      badgeKind: BadgeKind.accent,
                    ),
                  ],
                ),
              ),

              // Employees
              if (es.isNotEmpty) ...[
                const SizedBox(height: AppSpace.x4),
                AppSectionHeader(
                  title: 'العاملين',
                  trailing: TextButton(
                    onPressed: () => _navigateTo(context, const StaffScreen()),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'عرض الكل',
                          style: TextStyle(
                            fontFamily: 'Tajawal',
                            fontSize: 13,
                            color: AppColors.primary,
                          ),
                        ),
                        const SizedBox(width: 2),
                        const Icon(Icons.arrow_forward, size: 14, color: AppColors.primary),
                      ],
                    ),
                  ),
                ),
                AppCard(
                  padding: const EdgeInsets.all(AppSpace.x3),
                  child: _InfoRow(
                    icon: absent.isNotEmpty
                        ? Icons.warning_amber_rounded
                        : Icons.check_circle,
                    iconColor: absent.isNotEmpty ? AppColors.warning : AppColors.success,
                    label: absent.isNotEmpty
                        ? '${absent.length} من ${es.length} لسه ما سجلوش حضور النهارده'
                        : 'كل العاملين سجلوا حضورهم ✅',
                    onTap:
                        absent.isNotEmpty ? () => _showAbsentDialog(context, absent) : null,
                  ),
                ),
              ],

              // Archived
              if (archivedSuppliersWithBalance.isNotEmpty ||
                  archivedEmployeesWithBalance.isNotEmpty) ...[
                const SizedBox(height: AppSpace.x4),
                AppSectionHeader(title: 'مؤرشفين وعليهم مستحقات قديمة'),
                AppCard(
                  padding: const EdgeInsets.all(AppSpace.x4),
                  child: Column(
                    children: [
                      if (archivedSuppliersWithBalance.isNotEmpty) ...[
                        _Row(
                          label:
                              'موردين مؤرشفين (${archivedSuppliersWithBalance.length})',
                          value: '${archivedSuppliersBalance.toStringAsFixed(0)} ج',
                          badgeKind: BadgeKind.warning,
                          onTap: () =>
                              _navigateTo(context, const SuppliersScreen()),
                        ),
                        if (archivedEmployeesWithBalance.isNotEmpty)
                          const SizedBox(height: AppSpace.x3),
                      ],
                      if (archivedEmployeesWithBalance.isNotEmpty)
                        _Row(
                          label:
                              'عاملين مؤرشفين (${archivedEmployeesWithBalance.length})',
                          value: '${archivedEmployeesBalance.toStringAsFixed(0)} ج',
                          badgeKind: BadgeKind.warning,
                          onTap: () => _navigateTo(context, const StaffScreen()),
                        ),
                    ],
                  ),
                ),
              ],

              const SizedBox(height: AppSpace.x6),
              Text(
                'هذا ملخص من البيانات المحلية على جهازك.',
                style: AppText.bodyMuted,
              ),
              const SizedBox(height: AppSpace.x16),
            ],
          );
        },
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
            children: debtors
                .map<Widget>((c) => ListTile(
                      title: Text(
                          '${c.person}${c.amount == null ? '' : ' - ${(c.amount as double).toStringAsFixed(0)} ج'}'),
                      subtitle: Text('منذ ${arabicDate(c.dueDate)}'),
                      leading: const Icon(Icons.person_outline),
                    ))
                .toList(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('إغلاق'),
          ),
        ],
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
            children: absent
                .map<Widget>((e) => ListTile(
                      title: Text('${e.name} — ${e.role}'),
                      leading: const Icon(Icons.person_outline),
                    ))
                .toList(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('إغلاق'),
          ),
        ],
      ),
    );
  }
}

/// Row inside financial card
class _Row extends StatelessWidget {
  final String label;
  final String value;
  final BadgeKind badgeKind;
  final VoidCallback? onTap;

  const _Row({
    required this.label,
    required this.value,
    required this.badgeKind,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.sm),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpace.x1),
        child: Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: AppText.body.copyWith(fontSize: 14),
              ),
            ),
            if (onTap != null)
              const Icon(
                Icons.arrow_forward,
                size: 16,
                color: AppColors.textSecondary,
              ),
            const SizedBox(width: AppSpace.x2),
            AppBadge(label: value, kind: badgeKind, compact: true),
          ],
        ),
      ),
    );
  }
}

/// Stat card
class _StatCard extends StatelessWidget {
  final String value;
  final String label;
  final BadgeKind kind;

  const _StatCard(this.value, this.label, this.kind);

  (Color, Color) get _colors {
    switch (kind) {
      case BadgeKind.success:
        return (AppColors.successTint, AppColors.success);
      case BadgeKind.warning:
        return (AppColors.warningTint, AppColors.warning);
      case BadgeKind.danger:
        return (AppColors.dangerTint, AppColors.danger);
      case BadgeKind.info:
        return (AppColors.infoTint, AppColors.info);
      case BadgeKind.accent:
        return (AppColors.accentTint, AppColors.accent);
      case BadgeKind.neutral:
        return (AppColors.surfaceMuted, AppColors.textSecondary);
    }
  }

  @override
  Widget build(BuildContext context) {
    final (bg, fg) = _colors;
    return AppCard(
      elevated: true,
      padding: const EdgeInsets.all(AppSpace.x3),
      child: Column(
        children: [
          Text(
            value,
            style: TextStyle(
              fontFamily: 'Tajawal',
              fontSize: 24,
              fontWeight: FontWeight.w700,
              color: fg,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: AppText.caption.copyWith(color: fg),
          ),
        ],
      ),
    );
  }
}

/// Info row with icon
class _InfoRow extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String label;
  final VoidCallback? onTap;

  const _InfoRow({
    required this.icon,
    required this.iconColor,
    required this.label,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.sm),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          vertical: AppSpace.x2,
          horizontal: AppSpace.x1,
        ),
        child: Row(
          children: [
            Icon(icon, color: iconColor, size: AppIconSize.md),
            const SizedBox(width: AppSpace.x2),
            Expanded(
              child: Text(
                label,
                style: AppText.body.copyWith(fontSize: 14),
              ),
            ),
            if (onTap != null)
              const Icon(
                Icons.arrow_forward,
                size: 16,
                color: AppColors.textSecondary,
              ),
          ],
        ),
      ),
    );
  }
}
