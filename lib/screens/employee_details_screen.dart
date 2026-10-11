import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../models/employee.dart';
import '../services/storage_service.dart';
import '../design/tokens.dart';
import '../design/app_theme.dart';
import '../design/widgets.dart';

/// تفاصيل الموظف — Premium Employee Detail Screen
/// يعرض ملف الموظف الكامل مع الإحصائيات والتسجيلات والجدول الزمني.
class EmployeeDetailsScreen extends StatefulWidget {
  final Employee employee;
  const EmployeeDetailsScreen({super.key, required this.employee});

  @override
  State<EmployeeDetailsScreen> createState() => _S();
}

class _S extends State<EmployeeDetailsScreen> {
  late Employee e;

  @override
  void initState() {
    super.initState();
    e = widget.employee;
  }

  bool get _hasHistory => e.advances.isNotEmpty || e.attendance.isNotEmpty;

  List<MapEntry<DateTime, _ActivityItem>> get _timeline {
    final items = <MapEntry<DateTime, _ActivityItem>>[];
    for (final a in e.advances) {
      items.add(MapEntry(a.date, _ActivityItem(
        icon: Icons.account_balance_wallet_outlined,
        label: 'سلفة جديدة',
        detail: '${a.amount.toStringAsFixed(0)} ج',
        color: AppColors.warning,
      )));
    }
    for (final d in e.attendance) {
      final parsed = DateTime.tryParse(d);
      if (parsed != null) items.add(MapEntry(parsed, _ActivityItem(
        icon: Icons.check_circle_outline,
        label: 'تسجيل حضور',
        detail: _formatDate(parsed),
        color: AppColors.success,
      )));
    }
    items.sort((a, b) => b.key.compareTo(a.key));
    return items;
  }

  String _formatDate(DateTime d) {
    return '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final todayStr = DateTime(now.year, now.month, now.day).toIso8601String().substring(0, 10);
    final attendedToday = e.attendance.contains(todayStr);
    final monthStart = DateTime(now.year, now.month, 1);
    final attendanceThisMonth = e.attendance
        .map((d) => DateTime.tryParse(d))
        .where((d) => d != null && d.isAfter(monthStart.subtract(const Duration(days: 1))))
        .length;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(e.name),
        actions: [
          PopupMenuButton<String>(
            onSelected: (v) async {
              if (v == 'edit') _editDialog();
              else if (v == 'archive') {
                e.archived = !e.archived;
                await StorageService.saveEmployee(e);
                setState(() {});
              }
            },
            itemBuilder: (_) => [
              const PopupMenuItem(value: 'edit', child: Text('تعديل')),
              PopupMenuItem(
                value: 'archive',
                child: Text(e.archived ? 'إلغاء الأرشفة' : 'أرشفة'),
              ),
            ],
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(AppSpace.x4),
        children: [
          // ── Profile Header ─────────────────────────────────
          AppCard(
            elevated: true,
            padding: const EdgeInsets.all(AppSpace.x5),
            child: Column(
              children: [
                Row(
                  children: [
                    // Avatar
                    Container(
                      width: 64,
                      height: 64,
                      decoration: BoxDecoration(
                        color: AppColors.primaryTint,
                        borderRadius: BorderRadius.circular(AppRadius.lg),
                      ),
                      child: Center(
                        child: Text(
                          e.name.isNotEmpty ? e.name[0].toUpperCase() : '?',
                          style: AppText.h1.copyWith(
                            fontSize: 28,
                            color: AppColors.primary,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: AppSpace.x4),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(e.name, style: AppText.titleMedium),
                          const SizedBox(height: 2),
                          Text(
                            e.role.isEmpty ? 'بدون وظيفة' : e.role,
                            style: AppText.bodyMuted,
                          ),
                          const SizedBox(height: AppSpace.x2),
                          Row(
                            children: [
                              Container(
                                width: 8,
                                height: 8,
                                decoration: BoxDecoration(
                                  color: attendedToday
                                      ? AppColors.success
                                      : AppColors.danger,
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 6),
                              Text(
                                attendedToday ? 'حاضر اليوم' : 'غائب اليوم',
                                style: AppText.caption.copyWith(
                                  color: attendedToday
                                      ? AppColors.success
                                      : AppColors.danger,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpace.x4),
                // Stats row
                Row(
                  children: [
                    _DetailStat(
                      label: 'المرتب',
                      value: '${e.salaryMonthly.toStringAsFixed(0)} ج',
                      color: AppColors.primary,
                    ),
                    _DetailStat(
                      label: 'حضور الشهر',
                      value: '$attendanceThisMonth يوم',
                      color: AppColors.success,
                    ),
                    _DetailStat(
                      label: 'إجمالي الحضور',
                      value: '${e.attendance.length}',
                      color: AppColors.info,
                    ),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: AppSpace.x3),

          // ── Financial Summary ────────────────────────────────
          AppCard(
            padding: const EdgeInsets.all(AppSpace.x4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'الموقف المالي',
                  style: AppText.titleMedium.copyWith(fontSize: 15),
                ),
                const SizedBox(height: AppSpace.x3),
                Row(
                  children: [
                    Expanded(
                      child: _FinanceTile(
                        label: 'المرتب الشهري',
                        value: '${e.salaryMonthly.toStringAsFixed(0)} ج',
                        icon: Icons.payments_outlined,
                        color: AppColors.primary,
                      ),
                    ),
                    const SizedBox(width: AppSpace.x3),
                    Expanded(
                      child: _FinanceTile(
                        label: 'إجمالي السلف',
                        value: '${e.totalAdvances.toStringAsFixed(0)} ج',
                        icon: Icons.account_balance_wallet_outlined,
                        color: e.totalAdvances > 0 ? AppColors.warning : AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpace.x3),
                Row(
                  children: [
                    Expanded(
                      child: _FinanceTile(
                        label: 'المتبقي من المرتب',
                        value: '${e.remainingSalary.toStringAsFixed(0)} ج',
                        icon: Icons.savings_outlined,
                        color: e.remainingSalary > 0 ? AppColors.accent : AppColors.success,
                      ),
                    ),
                    const SizedBox(width: AppSpace.x3),
                    Expanded(
                      child: Container(),
                    ),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: AppSpace.x3),

          // ── Quick Actions ────────────────────────────────────
          Row(
            children: [
              Expanded(
                child: _ActionButton(
                  icon: Icons.check_circle_outline,
                  label: 'تسجيل حضور',
                  color: AppColors.success,
                  onTap: attendedToday ? null : () => _recordAttendance(),
                ),
              ),
              const SizedBox(width: AppSpace.x3),
              Expanded(
                child: _ActionButton(
                  icon: Icons.account_balance_wallet_outlined,
                  label: 'إضافة سلفة',
                  color: AppColors.warning,
                  onTap: () => _addAdvance(),
                ),
              ),
              const SizedBox(width: AppSpace.x3),
              Expanded(
                child: _ActionButton(
                  icon: Icons.payments_outlined,
                  label: 'سداد سلفة',
                  color: AppColors.info,
                  onTap: e.totalAdvances <= 0 ? null : () => _payAdvance(),
                ),
              ),
            ],
          ),

          const SizedBox(height: AppSpace.x4),

          // ── Activity Timeline ────────────────────────────────
          if (_hasHistory) ...[
            AppSectionHeader(
              title: 'النشاط الأخير',
              trailing: Text(
                '${_timeline.length} سجل',
                style: AppText.caption,
              ),
            ),
            const SizedBox(height: AppSpace.x2),
            AppCard(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpace.x4,
                vertical: AppSpace.x2,
              ),
              child: Column(
                children: [
                  for (var i = 0; i < _timeline.length; i++) ...[
                    _TimelineRow(
                      item: _timeline[i].value,
                      date: _timeline[i].key,
                      isLast: i == _timeline.length - 1,
                    ),
                  ],
                ],
              ),
            ),
          ],

          // ── Attendance History ────────────────────────────────
          if (e.attendance.isNotEmpty) ...[
            const SizedBox(height: AppSpace.x4),
            AppSectionHeader(
              title: 'سجل الحضور',
              trailing: Text('${e.attendance.length} يوم', style: AppText.caption),
            ),
            const SizedBox(height: AppSpace.x2),
            AppCard(
              padding: EdgeInsets.zero,
              child: Column(
                children: [
                  for (var i = 0; i < e.attendance.length && i < 20; i++)
                    _RecordRow(
                      icon: Icons.check_circle_outline,
                      label: 'حضور',
                      date: e.attendance[i],
                      color: AppColors.success,
                      onDelete: () async {
                        e.attendance.remove(e.attendance[i]);
                        await StorageService.saveEmployee(e);
                        setState(() {});
                      },
                    ),
                  if (e.attendance.length > 20)
                    Padding(
                      padding: const EdgeInsets.all(AppSpace.x3),
                      child: Text(
                        '+ ${e.attendance.length - 20} أخرى',
                        style: AppText.bodyMuted,
                        textAlign: TextAlign.center,
                      ),
                    ),
                ],
              ),
            ),
          ],

          // ── Advances History ─────────────────────────────────
          if (e.advances.isNotEmpty) ...[
            const SizedBox(height: AppSpace.x4),
            AppSectionHeader(
              title: 'سجل السلف',
              trailing: Text(
                '${e.totalAdvances.toStringAsFixed(0)} ج إجمالي',
                style: AppText.caption,
              ),
            ),
            const SizedBox(height: AppSpace.x2),
            AppCard(
              padding: EdgeInsets.zero,
              child: Column(
                children: [
                  for (var i = 0; i < e.advances.length; i++)
                    _RecordRow(
                      icon: Icons.account_balance_wallet_outlined,
                      label: '${e.advances[i].amount.toStringAsFixed(0)} ج — سلفة',
                      date: e.advances[i].date.toString().substring(0, 10),
                      color: AppColors.warning,
                      onDelete: () async {
                        e.advances.removeAt(i);
                        await StorageService.saveEmployee(e);
                        setState(() {});
                      },
                    ),
                ],
              ),
            ),
          ],

          const SizedBox(height: AppSpace.x16),
        ],
      ),
    );
  }

  void _recordAttendance() async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day).toIso8601String().substring(0, 10);
    if (!e.attendance.contains(today)) {
      e.attendance.add(today);
      await StorageService.saveEmployee(e);
      setState(() {});
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('تم تسجيل الحضور ✅')),
        );
      }
    }
  }

  void _addAdvance() {
    final a = TextEditingController();
    showAppBottomSheet(
      context: context,
      title: 'إضافة سلفة',
      body: Padding(
        padding: const EdgeInsets.all(AppSpace.x4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: a,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'المبلغ (ج)',
                hintText: 'مثال: 500',
              ),
              autofocus: true,
            ),
            const SizedBox(height: AppSpace.x4),
            FilledButton(
              onPressed: () async {
                final amount = double.tryParse(a.text);
                if (amount == null || amount <= 0) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('من فضلك أدخل مبلغ صحيح')),
                  );
                  return;
                }
                e.advances.add(Advance(
                  id: const Uuid().v4(),
                  amount: amount,
                  date: DateTime.now(),
                  note: '',
                ));
                await StorageService.saveEmployee(e);
                if (mounted) Navigator.pop(context);
                setState(() {});
              },
              child: const Text('إضافة'),
            ),
          ],
        ),
      ),
    );
  }

  void _payAdvance() {
    final a = TextEditingController(text: e.totalAdvances.toStringAsFixed(0));
    showAppBottomSheet(
      context: context,
      title: 'سداد سلفة',
      body: Padding(
        padding: const EdgeInsets.all(AppSpace.x4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'إجمالي السلف: ${e.totalAdvances.toStringAsFixed(0)} ج',
              style: AppText.bodyMuted,
            ),
            const SizedBox(height: AppSpace.x3),
            TextField(
              controller: a,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'المبلغ المسدد (ج)',
              ),
              autofocus: true,
            ),
            const SizedBox(height: AppSpace.x4),
            FilledButton(
              onPressed: () async {
                final amount = double.tryParse(a.text);
                if (amount == null || amount <= 0) return;
                final paid = amount > e.totalAdvances ? e.totalAdvances : amount;
                // Remove oldest advances first
                var remaining = paid;
                while (remaining > 0 && e.advances.isNotEmpty) {
                  if (e.advances.first.amount <= remaining) {
                    remaining -= e.advances.first.amount;
                    e.advances.removeAt(0);
                  } else {
                    e.advances.first.amount -= remaining;
                    remaining = 0;
                  }
                }
                await StorageService.saveEmployee(e);
                if (mounted) Navigator.pop(context);
                setState(() {});
              },
              child: const Text('تسجيل السداد'),
            ),
          ],
        ),
      ),
    );
  }

  void _editDialog() {
    final n = TextEditingController(text: e.name);
    final r = TextEditingController(text: e.role);
    final s = TextEditingController(text: e.salaryMonthly.toStringAsFixed(0));
    showAppBottomSheet(
      context: context,
      title: 'تعديل ${e.name}',
      body: Padding(
        padding: const EdgeInsets.all(AppSpace.x4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: n,
              decoration: const InputDecoration(labelText: 'الاسم'),
            ),
            const SizedBox(height: AppSpace.x3),
            TextField(
              controller: r,
              decoration: const InputDecoration(labelText: 'الوظيفة'),
            ),
            const SizedBox(height: AppSpace.x3),
            TextField(
              controller: s,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'المرتب الشهري (ج)'),
            ),
            const SizedBox(height: AppSpace.x6),
            FilledButton(
              onPressed: () async {
                e.name = n.text.trim();
                e.role = r.text.trim();
                e.salaryMonthly = double.tryParse(s.text) ?? e.salaryMonthly;
                await StorageService.saveEmployee(e);
                if (mounted) Navigator.pop(context);
                setState(() {});
              },
              child: const Text('حفظ'),
            ),
          ],
        ),
      ),
    );
  }
}

/// Detail stat inside profile header
class _DetailStat extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _DetailStat({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          Text(
            value,
            style: AppText.titleMedium.copyWith(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
          Text(label, style: AppText.caption),
        ],
      ),
    );
  }
}

/// Finance tile inside financial summary
class _FinanceTile extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  const _FinanceTile({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpace.x3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: color.withValues(alpha: 0.2), width: 1),
      ),
      child: Row(
        children: [
          Icon(icon, size: AppIconSize.md, color: color),
          const SizedBox(width: AppSpace.x2),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  style: AppText.titleMedium.copyWith(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: color,
                  ),
                ),
                Text(label, style: AppText.caption),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Action button row
class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback? onTap;

  const _ActionButton({
    required this.icon,
    required this.label,
    required this.color,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;
    final c = enabled ? color : AppColors.textDisabled;

    return Material(
      color: enabled ? c.withValues(alpha: 0.1) : AppColors.surfaceMuted,
      borderRadius: BorderRadius.circular(AppRadius.md),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.md),
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpace.x2,
            vertical: AppSpace.x3,
          ),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadius.md),
            border: Border.all(
              color: enabled ? c.withValues(alpha: 0.3) : AppColors.border,
              width: 1,
            ),
          ),
          child: Column(
            children: [
              Icon(icon, size: AppIconSize.lg, color: c),
              const SizedBox(height: 4),
              Text(
                label,
                style: TextStyle(
                  fontFamily: 'Tajawal',
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: c,
                ),
                textAlign: TextAlign.center,
                maxLines: 2,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Activity item data class
class _ActivityItem {
  final IconData icon;
  final String label;
  final String detail;
  final Color color;

  const _ActivityItem({
    required this.icon,
    required this.label,
    required this.detail,
    required this.color,
  });
}

/// Timeline row
class _TimelineRow extends StatelessWidget {
  final _ActivityItem item;
  final DateTime date;
  final bool isLast;

  const _TimelineRow({
    required this.item,
    required this.date,
    required this.isLast,
  });

  String get _dateStr =>
      '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Timeline dot + line
          SizedBox(
            width: 36,
            child: Column(
              children: [
                Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    color: item.color.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(AppRadius.sm),
                  ),
                  child: Icon(item.icon, size: 14, color: item.color),
                ),
                if (!isLast)
                  Expanded(
                    child: Container(
                      width: 1,
                      color: AppColors.border,
                    ),
                  ),
              ],
            ),
          ),
          // Content
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: AppSpace.x3),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(item.label, style: AppText.body.copyWith(fontSize: 14)),
                        Text(item.detail, style: AppText.caption),
                      ],
                    ),
                  ),
                  Text(_dateStr, style: AppText.caption),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Record row (attendance or advance)
class _RecordRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String date;
  final Color color;
  final VoidCallback onDelete;

  const _RecordRow({
    required this.icon,
    required this.label,
    required this.date,
    required this.color,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpace.x4,
        vertical: AppSpace.x3,
      ),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: AppColors.border, width: 0.5)),
      ),
      child: Row(
        children: [
          Icon(icon, size: AppIconSize.md, color: color),
          const SizedBox(width: AppSpace.x3),
          Expanded(child: Text(label, style: AppText.body.copyWith(fontSize: 14))),
          Text(date, style: AppText.caption),
          const SizedBox(width: AppSpace.x2),
          IconButton(
            icon: const Icon(Icons.delete_outline, size: 18),
            color: AppColors.danger,
            onPressed: () async {
              final confirm = await showDialog<bool>(
                context: context,
                builder: (_) => AlertDialog(
                  title: const Text('حذف السجل؟'),
                  content: const Text('لا يمكن التراجع عن هذا الإجراء.'),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context, false),
                      child: const Text('إلغاء'),
                    ),
                    TextButton(
                      onPressed: () => Navigator.pop(context, true),
                      child: Text(
                        'حذف',
                        style: const TextStyle(color: AppColors.danger),
                      ),
                    ),
                  ],
                ),
              );
              if (confirm == true) onDelete();
            },
            visualDensity: VisualDensity.compact,
          ),
        ],
      ),
    );
  }
}
