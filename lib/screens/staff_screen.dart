import 'package:flutter/material.dart';
import '../models/employee.dart';
import '../services/storage_service.dart';
import '../services/app_state.dart';
import '../design/tokens.dart';
import '../design/app_theme.dart';
import '../design/widgets.dart';
import 'employee_details_screen.dart';

/// الموظفون — Premium Employee Management Screen
/// يعرض قائمة احترافية بالموظفين مع مؤشرات الحضور والتصفية والبحث.
class StaffScreen extends StatefulWidget {
  const StaffScreen({super.key});

  @override
  State<StaffScreen> createState() => _S();
}

class _S extends State<StaffScreen> {
  String _filter = 'active';
  final _search = TextEditingController();
  bool _searching = false;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: ListenableBuilder(
        listenable: AppState.instance,
        builder: (context, _) => _buildBody(context),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _add,
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        child: const Icon(Icons.person_add),
      ),
    );
  }

  Widget _buildBody(BuildContext context) {
    final now = DateTime.now();
    final todayStr = DateTime(now.year, now.month, now.day).toIso8601String().substring(0, 10);

    final all = StorageService.employees();
    final filtered = switch (_filter) {
      'archived' => all.where((e) => e.archived).toList(),
      'all' => all,
      _ => all.where((e) => !e.archived).toList(),
    };

    final query = _search.text.trim().toLowerCase();
    final employees = query.isEmpty
        ? filtered
        : filtered.where((e) => e.name.toLowerCase().contains(query)).toList();

    final active = all.where((e) => !e.archived).toList();
    final attendedToday = active.where((e) => e.attendance.contains(todayStr)).length;
    final totalAdvances = active.fold<double>(0, (s, e) => s + e.totalAdvances);
    final totalDue = active.fold<double>(0, (s, e) => s + e.remainingSalary);

    return CustomScrollView(
      slivers: [
        // Summary header
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.all(AppSpace.x4),
            child: Row(
              children: [
                Expanded(
                  child: _SummaryTile(
                    label: 'الحضور اليوم',
                    value: '$attendedToday/${active.length}',
                    icon: Icons.check_circle_outline,
                    color: attendedToday == active.length && active.isNotEmpty
                        ? AppColors.success
                        : AppColors.warning,
                  ),
                ),
                const SizedBox(width: AppSpace.x3),
                Expanded(
                  child: _SummaryTile(
                    label: 'إجمالي السلف',
                    value: '${totalAdvances.toStringAsFixed(0)} ج',
                    icon: Icons.account_balance_wallet_outlined,
                    color: totalAdvances > 0 ? AppColors.warning : AppColors.textSecondary,
                  ),
                ),
                const SizedBox(width: AppSpace.x3),
                Expanded(
                  child: _SummaryTile(
                    label: 'مستحق للمرتبات',
                    value: '${totalDue.toStringAsFixed(0)} ج',
                    icon: Icons.payments_outlined,
                    color: totalDue > 0 ? AppColors.accent : AppColors.success,
                  ),
                ),
              ],
            ),
          ),
        ),

        // Search bar
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpace.x4, 0, AppSpace.x4, AppSpace.x3,
            ),
            child: TextField(
              controller: _search,
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                hintText: 'ابحث باسم الموظف...',
                prefixIcon: const Icon(Icons.search, size: AppIconSize.md),
                suffixIcon: _search.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, size: AppIconSize.md),
                        onPressed: () {
                          _search.clear();
                          setState(() {});
                        },
                      )
                    : null,
              ),
            ),
          ),
        ),

        // Filter chips
        SliverToBoxAdapter(
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.fromLTRB(
              AppSpace.x4, 0, AppSpace.x4, AppSpace.x3,
            ),
            child: Row(
              children: [
                _FilterChip(
                  label: 'نشط',
                  count: all.where((e) => !e.archived).length,
                  isSelected: _filter == 'active',
                  onTap: () => setState(() => _filter = 'active'),
                ),
                const SizedBox(width: AppSpace.x2),
                _FilterChip(
                  label: 'مؤرشف',
                  count: all.where((e) => e.archived).length,
                  isSelected: _filter == 'archived',
                  onTap: () => setState(() => _filter = 'archived'),
                ),
                const SizedBox(width: AppSpace.x2),
                _FilterChip(
                  label: 'الكل',
                  count: all.length,
                  isSelected: _filter == 'all',
                  onTap: () => setState(() => _filter = 'all'),
                ),
              ],
            ),
          ),
        ),

        // Employee list
        if (employees.isEmpty)
          SliverFillRemaining(
            hasScrollBody: false,
            child: AppEmptyState(
              icon: Icons.people_outline,
              title: _search.text.isNotEmpty ? 'لا يوجد نتائج' : 'لا يوجد موظفون',
              subtitle: _search.text.isNotEmpty
                  ? 'ابحث باسم مختلف'
                  : 'مثال: "أحمد بدأ شغل يوم 4 ومرتبه 4000"',
            ),
          )
        else
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(
              AppSpace.x4, 0, AppSpace.x4, AppSpace.x16,
            ),
            sliver: SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, i) => _EmployeeCard(
                  employee: employees[i],
                  todayStr: todayStr,
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => EmployeeDetailsScreen(employee: employees[i]),
                    ),
                  ).then((_) => setState(() {})),
                  onEdit: () => _editDialog(employees[i]),
                  onArchive: () async {
                    employees[i].archived = !employees[i].archived;
                    await StorageService.saveEmployee(employees[i]);
                    setState(() {});
                  },
                ),
                childCount: employees.length,
              ),
            ),
          ),
      ],
    );
  }

  void _add() {
    final n = TextEditingController();
    final r = TextEditingController(text: 'عامل');
    final s = TextEditingController();

    showAppBottomSheet(
      context: context,
      title: 'إضافة موظف',
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(
          AppSpace.x4, AppSpace.x2, AppSpace.x4, AppSpace.x4,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: n,
              decoration: const InputDecoration(
                labelText: 'الاسم',
                hintText: 'اسم الموظف',
              ),
              textCapitalization: TextCapitalization.words,
            ),
            const SizedBox(height: AppSpace.x3),
            TextField(
              controller: r,
              decoration: const InputDecoration(
                labelText: 'الوظيفة',
                hintText: 'مثال: محاسب، عامل، سائق',
              ),
            ),
            const SizedBox(height: AppSpace.x3),
            TextField(
              controller: s,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'المرتب الشهري (ج)',
                hintText: 'مثال: 4000',
              ),
            ),
            const SizedBox(height: AppSpace.x6),
            FilledButton(
              onPressed: () async {
                if (n.text.trim().isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('من فضلك أدخل اسم الموظف')),
                  );
                  return;
                }
                final sal = double.tryParse(s.text) ?? 0;
                await StorageService.saveEmployee(Employee(
                  id: DateTime.now().millisecondsSinceEpoch.toString(),
                  name: n.text.trim(),
                  role: r.text.trim(),
                  startDate: DateTime.now(),
                  salaryMonthly: sal,
                  advances: [],
                  attendance: [],
                  archived: false,
                ));
                if (mounted) Navigator.pop(context);
              },
              child: const Text('إضافة'),
            ),
          ],
        ),
      ),
    );
  }

  void _editDialog(Employee e) {
    final n = TextEditingController(text: e.name);
    final r = TextEditingController(text: e.role);
    final s = TextEditingController(text: e.salaryMonthly.toStringAsFixed(0));

    showAppBottomSheet(
      context: context,
      title: 'تعديل ${e.name}',
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(
          AppSpace.x4, AppSpace.x2, AppSpace.x4, AppSpace.x4,
        ),
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
              },
              child: const Text('حفظ'),
            ),
          ],
        ),
      ),
    );
  }
}

/// Summary tile in header
class _SummaryTile extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  const _SummaryTile({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return AppCard(
      elevated: true,
      padding: const EdgeInsets.all(AppSpace.x3),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: AppIconSize.md, color: color),
          const SizedBox(height: AppSpace.x2),
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
    );
  }
}

/// Filter chip
class _FilterChip extends StatelessWidget {
  final String label;
  final int count;
  final bool isSelected;
  final VoidCallback onTap;

  const _FilterChip({
    required this.label,
    required this.count,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: isSelected ? AppColors.primaryTint : AppColors.surface,
      borderRadius: BorderRadius.circular(AppRadius.full),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.full),
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpace.x3,
            vertical: AppSpace.x2,
          ),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadius.full),
            border: Border.all(
              color: isSelected ? AppColors.primary : AppColors.border,
              width: 1,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                style: AppText.label.copyWith(
                  fontSize: 13,
                  color: isSelected ? AppColors.primary : AppColors.textSecondary,
                ),
              ),
              const SizedBox(width: 4),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                decoration: BoxDecoration(
                  color: isSelected
                      ? AppColors.primary.withValues(alpha: 0.15)
                      : AppColors.surfaceMuted,
                  borderRadius: BorderRadius.circular(AppRadius.full),
                ),
                child: Text(
                  '$count',
                  style: TextStyle(
                    fontFamily: 'Tajawal',
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: isSelected ? AppColors.primary : AppColors.textSecondary,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Premium employee card
class _EmployeeCard extends StatelessWidget {
  final Employee employee;
  final String todayStr;
  final VoidCallback onTap;
  final VoidCallback onEdit;
  final VoidCallback onArchive;

  const _EmployeeCard({
    required this.employee,
    required this.todayStr,
    required this.onTap,
    required this.onEdit,
    required this.onArchive,
  });

  bool get _attendedToday => employee.attendance.contains(todayStr);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpace.x3),
      child: AppCard(
        onTap: onTap,
        padding: const EdgeInsets.all(AppSpace.x4),
        child: Column(
          children: [
            Row(
              children: [
                // Avatar
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: AppColors.primaryTint,
                    borderRadius: BorderRadius.circular(AppRadius.md),
                  ),
                  child: Center(
                    child: Text(
                      employee.name.isNotEmpty ? employee.name[0].toUpperCase() : '?',
                      style: AppText.titleMedium.copyWith(
                        fontSize: 20,
                        color: AppColors.primary,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: AppSpace.x3),
                // Name + role
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              employee.name,
                              style: AppText.titleMedium.copyWith(fontSize: 16),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (employee.archived)
                            AppBadge(
                              label: 'مؤرشف',
                              kind: BadgeKind.neutral,
                              compact: true,
                            ),
                        ],
                      ),
                      Text(
                        employee.role.isEmpty ? 'بدون وظيفة' : employee.role,
                        style: AppText.bodyMuted,
                      ),
                    ],
                  ),
                ),
                // Attendance indicator
                Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    color: _attendedToday ? AppColors.success : AppColors.danger,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: (_attendedToday ? AppColors.success : AppColors.danger)
                            .withValues(alpha: 0.4),
                        blurRadius: 4,
                        spreadRadius: 1,
                      ),
                    ],
                  ),
                ),
                // More menu
                PopupMenuButton<String>(
                  icon: const Icon(Icons.more_vert, size: AppIconSize.md),
                  onSelected: (v) {
                    if (v == 'edit') onEdit();
                    if (v == 'archive') onArchive();
                  },
                  itemBuilder: (_) => [
                    const PopupMenuItem(value: 'edit', child: Text('تعديل')),
                    PopupMenuItem(
                      value: 'archive',
                      child: Text(employee.archived ? 'إلغاء الأرشفة' : 'أرشفة'),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: AppSpace.x3),
            // Stats row
            Row(
              children: [
                _StatChip(
                  icon: Icons.calendar_today_outlined,
                  value: '${employee.attendance.length}',
                  label: 'حضور',
                  color: AppColors.success,
                ),
                const SizedBox(width: AppSpace.x2),
                _StatChip(
                  icon: Icons.account_balance_wallet_outlined,
                  value: '${employee.totalAdvances.toStringAsFixed(0)} ج',
                  label: 'سلف',
                  color: employee.totalAdvances > 0
                      ? AppColors.warning
                      : AppColors.textSecondary,
                ),
                const SizedBox(width: AppSpace.x2),
                _StatChip(
                  icon: Icons.payments_outlined,
                  value: '${employee.remainingSalary.toStringAsFixed(0)} ج',
                  label: 'متبقي',
                  color: employee.remainingSalary > 0
                      ? AppColors.accent
                      : AppColors.success,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Small stat chip inside employee card
class _StatChip extends StatelessWidget {
  final IconData icon;
  final String value;
  final String label;
  final Color color;

  const _StatChip({
    required this.icon,
    required this.value,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpace.x2,
          vertical: AppSpace.x2,
        ),
        decoration: BoxDecoration(
          color: AppColors.surfaceMuted,
          borderRadius: BorderRadius.circular(AppRadius.sm),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 12, color: color),
            const SizedBox(width: 4),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    value,
                    style: TextStyle(
                      fontFamily: 'Tajawal',
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: color,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    label,
                    style: const TextStyle(
                      fontFamily: 'Tajawal',
                      fontSize: 9,
                      color: AppColors.textDisabled,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
