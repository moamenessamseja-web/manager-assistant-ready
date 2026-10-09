import 'package:flutter/material.dart';
import '../services/storage_service.dart';
import '../services/app_state.dart';
import '../design/tokens.dart';
import '../design/widgets.dart';
import 'staff_screen.dart';
import 'suppliers_screen.dart';

/// الذاكرة — مركز معلومات العمل الحي.
/// لما مفيش بحث: ملخص تشغيلي + خط زمني للنشاط الأخير.
/// لما فيه بحث: نتائج من جميع الكيانات مع تنقل مباشر.
/// تستمع لـ AppState عشان تتحدث تلقائيًا.
class MemoryScreen extends StatefulWidget {
  const MemoryScreen({super.key});
  @override
  State<MemoryScreen> createState() => _MemoryScreenState();
}

class _MemoryScreenState extends State<MemoryScreen> {
  final _q = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _q.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('الذاكرة')),
      body: Column(children: [
        // شريط البحث
        Padding(
          padding: const EdgeInsets.all(AppSpace.x3),
          child: TextField(
            controller: _q,
            decoration: InputDecoration(
              prefixIcon: const Icon(Icons.search),
              hintText: 'ابحث باسم عميل / مورد / موظف...',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadius.md)),
              contentPadding: const EdgeInsets.symmetric(horizontal: AppSpace.x4, vertical: AppSpace.x3),
            ),
            onChanged: (v) => setState(() => _query = v.trim()),
          ),
        ),
        // المحتوى
        Expanded(
          child: ListenableBuilder(
            listenable: AppState.instance,
            builder: (context, _) {
              if (_query.isEmpty) {
                return _buildOverview(context);
              }
              return _buildSearchResults();
            },
          ),
        ),
      ]),
    );
  }

  /// ملخص تشغيلي حي عند عدم وجود بحث.
  Widget _buildOverview(BuildContext context) {
    final employees = StorageService.employees();
    final suppliers = StorageService.suppliers();
    final reminders = StorageService.reminders();
    final commitments = StorageService.commitments();

    final activeEmps = employees.where((e) => !e.archived).toList();
    final activeSupps = suppliers.where((s) => !s.archived).toList();
    final overdueReminders = reminders.where((r) => r.enabled && r.status != 'cancelled' && r.dueAt.isBefore(DateTime.now())).toList();
    final pendingCommitments = commitments.where((c) => c.status == 'pending').toList();
    final totalAdvances = activeEmps.fold(0.0, (s, e) => s + e.totalAdvances);
    final totalSuppliersDue = activeSupps.fold(0.0, (s, sup) => s + sup.balanceDue);

    // خط زمني للنشاط الأخير
    final activities = _buildActivityTimeline(employees, suppliers, reminders);

    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: AppSpace.x4),
      children: [
        // بطاقات الملخص
        Row(children: [
          Expanded(child: _MiniStatCard(
            icon: Icons.people,
            label: 'العاملين',
            value: '${activeEmps.length}',
            sub: totalAdvances > 0 ? 'سلف: ${totalAdvances.toStringAsFixed(0)} ج' : null,
            color: AppColors.primary,
            onTap: () => _navigateTo(context, const StaffScreen()),
          )),
          const SizedBox(width: AppSpace.x2),
          Expanded(child: _MiniStatCard(
            icon: Icons.local_shipping,
            label: 'الموردين',
            value: '${activeSupps.length}',
            sub: totalSuppliersDue > 0 ? 'مستحق: ${totalSuppliersDue.toStringAsFixed(0)} ج' : null,
            color: AppColors.info,
            onTap: () => _navigateTo(context, const SuppliersScreen()),
          )),
        ]),
        const SizedBox(height: AppSpace.x2),
        Row(children: [
          Expanded(child: _MiniStatCard(
            icon: Icons.schedule,
            label: 'التزامات',
            value: '${pendingCommitments.length}',
            sub: 'قائمة',
            color: AppColors.warning,
            onTap: null,
          )),
          const SizedBox(width: AppSpace.x2),
          Expanded(child: _MiniStatCard(
            icon: overdueReminders.isNotEmpty ? Icons.warning_amber_rounded : Icons.notifications,
            label: 'تذكيرات',
            value: '${overdueReminders.length}',
            sub: overdueReminders.isNotEmpty ? 'متأخرة' : 'سليمة',
            color: overdueReminders.isNotEmpty ? AppColors.danger : AppColors.success,
            onTap: null,
          )),
        ]),

        // خط النشاط الأخير
        if (activities.isNotEmpty) ...[
          const SizedBox(height: AppSpace.x6),
          const AppSectionHeader('النشاط الأخير'),
          ...activities.take(15).map((a) => _ActivityTile(activity: a)),
        ] else ...[
          const SizedBox(height: AppSpace.x8),
          const AppEmptyState(
            icon: Icons.history,
            title: 'لا يوجد نشاط بعد',
            subtitle: 'سجل حضور، سلفة، أو شراء من الشات وهيجاد هنا',
          ),
        ],
        const SizedBox(height: AppSpace.x8),
      ],
    );
  }

  /// نتائج البحث: تفلتر من جميع الكيانات.
  Widget _buildSearchResults() {
    final commitments = StorageService.commitments().where((c) => c.person.contains(_query)).toList()
      ..sort((a, b) => b.dueDate.compareTo(a.dueDate));
    final suppliers = StorageService.suppliers().where((s) => s.name.contains(_query)).toList();
    final employees = StorageService.employees().where((e) => e.name.contains(_query)).toList();

    final hasResults = commitments.isNotEmpty || suppliers.isNotEmpty || employees.isNotEmpty;

    if (!hasResults) {
      return Center(
        child: AppEmptyState(
          icon: Icons.search_off,
          title: 'مفيش نتائج بـ"$_query"',
          subtitle: 'جرب اسم مختلف',
        ),
      );
    }

    return ListView(
      children: [
        if (employees.isNotEmpty) ...[
          AppSectionHeader(
            'العاملين (${employees.length})',
            trailing: TextButton(
              onPressed: () => _navigateTo(context, const StaffScreen()),
              child: const Text('عرض الكل →'),
            ),
          ),
          ...employees.map((e) => ListTile(
                leading: const Icon(Icons.person, color: AppColors.primary),
                title: Text(e.name),
                subtitle: Text('المتبقي: ${e.remainingSalary.toStringAsFixed(0)} ج | سلف: ${e.totalAdvances.toStringAsFixed(0)} ج'),
                trailing: e.archived ? const AppBadge('مؤرشف', kind: AppStatusKind.warning) : null,
                onTap: () => _navigateTo(context, const StaffScreen()),
              )),
        ],
        if (suppliers.isNotEmpty) ...[
          AppSectionHeader(
            'الموردين (${suppliers.length})',
            trailing: TextButton(
              onPressed: () => _navigateTo(context, const SuppliersScreen()),
              child: const Text('عرض الكل →'),
            ),
          ),
          ...suppliers.map((s) => ListTile(
                leading: const Icon(Icons.local_shipping, color: AppColors.info),
                title: Text(s.name),
                subtitle: Text('المستحق: ${s.balanceDue.toStringAsFixed(0)} ج'),
                trailing: s.archived ? const AppBadge('مؤرشف', kind: AppStatusKind.warning) : null,
                onTap: () => _navigateTo(context, const SuppliersScreen()),
              )),
        ],
        if (commitments.isNotEmpty) ...[
          AppSectionHeader('الالتزامات (${commitments.length})'),
          ...commitments.map((c) => ListTile(
                leading: Icon(
                  c.status == 'done' ? Icons.check_circle : Icons.schedule,
                  color: c.status == 'done' ? AppColors.success : AppColors.warning,
                ),
                title: Text('${c.person}${c.amount == null ? '' : ' - ${c.amount!.toStringAsFixed(0)} ج'}'),
                subtitle: Text('${c.textOriginal}\n${c.dueDate.toString().substring(0, 10)} — ${c.status == 'done' ? 'تم' : 'قائمة'}'),
                isThreeLine: true,
              )),
        ],
        const SizedBox(height: AppSpace.x8),
      ],
    );
  }

  /// بناء خط زمني من آخر النشاطات.
  List<_Activity> _buildActivityTimeline(
    List<dynamic> employees,
    List<dynamic> suppliers,
    List<dynamic> reminders,
  ) {
    final activities = <_Activity>[];

    // التزامات
    for (final c in StorageService.commitments()) {
      activities.add(_Activity(
        icon: c.status == 'done' ? Icons.check_circle : Icons.schedule,
        iconColor: c.status == 'done' ? AppColors.success : AppColors.warning,
        title: '${c.person}${c.amount == null ? '' : ' - ${(c.amount as double).toStringAsFixed(0)} ج'}',
        subtitle: c.textOriginal,
        date: c.dueDate,
        badge: c.status == 'done' ? 'تم' : 'قائمة',
        badgeKind: c.status == 'done' ? AppStatusKind.success : AppStatusKind.warning,
      ));
    }

    // سلف وم出勤 الموظفين
    for (final e in employees) {
      for (final adv in (e.advances as List<dynamic>)) {
        activities.add(_Activity(
          icon: Icons.payments,
          iconColor: AppColors.warning,
          title: 'سلفة ${e.name}',
          subtitle: '${(adv.amount as double).toStringAsFixed(0)} ج',
          date: adv.date as DateTime,
          badge: 'سلفة',
          badgeKind: AppStatusKind.warning,
        ));
      }
      for (final day in (e.attendance as List<String>)) {
        activities.add(_Activity(
          icon: Icons.login,
          iconColor: AppColors.success,
          title: 'حضور ${e.name}',
          subtitle: day,
          date: DateTime.tryParse(day) ?? DateTime.now(),
          badge: 'حضور',
          badgeKind: AppStatusKind.success,
        ));
      }
    }

    // مدفوعات الموردين
    for (final s in suppliers) {
      for (final p in (s.payments as List<dynamic>)) {
        activities.add(_Activity(
          icon: Icons.payments,
          iconColor: AppColors.success,
          title: 'دفعة ${s.name}',
          subtitle: '${(p.amount as double).toStringAsFixed(0)} ج',
          date: p.date as DateTime,
          badge: 'دفعة',
          badgeKind: AppStatusKind.success,
        ));
      }
    }

    // تذكيرات
    for (final r in reminders) {
      activities.add(_Activity(
        icon: r.enabled ? Icons.notifications_active : Icons.notifications_off,
        iconColor: r.status == 'cancelled' ? AppColors.textDisabled : AppColors.info,
        title: r.title,
        subtitle: r.body,
        date: r.dueAt,
        badge: r.status,
        badgeKind: AppStatusKind.info,
      ));
    }

    // ترتيب بالأحدث
    activities.sort((a, b) => b.date.compareTo(a.date));
    return activities;
  }

  void _navigateTo(BuildContext context, Widget screen) {
    Navigator.push(context, MaterialPageRoute(builder: (_) => screen));
  }
}

/// عنصر نشاط واحد في الخط الزمني.
class _Activity {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final DateTime date;
  final String badge;
  final AppStatusKind badgeKind;

  _Activity({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.date,
    required this.badge,
    required this.badgeKind,
  });
}

class _ActivityTile extends StatelessWidget {
  final _Activity activity;
  const _ActivityTile({required this.activity});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpace.x2),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(
          padding: const EdgeInsets.all(AppSpace.x2),
          decoration: BoxDecoration(
            color: activity.iconColor.withAlpha(25),
            borderRadius: BorderRadius.circular(AppRadius.sm),
          ),
          child: Icon(activity.icon, color: activity.iconColor, size: AppIconSize.md),
        ),
        const SizedBox(width: AppSpace.x3),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Expanded(child: Text(activity.title, style: AppText.titleMedium, maxLines: 1, overflow: TextOverflow.ellipsis)),
              AppBadge(activity.badge, kind: activity.badgeKind),
            ]),
            if (activity.subtitle.isNotEmpty)
              Text(activity.subtitle, style: AppText.bodyMuted, maxLines: 1, overflow: TextOverflow.ellipsis),
            Text(_formatDate(activity.date), style: AppText.caption),
          ]),
        ),
      ]),
    );
  }

  String _formatDate(DateTime d) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final date = DateTime(d.year, d.month, d.day);
    if (date == today) return 'اليوم';
    if (date == today.subtract(const Duration(days: 1))) return 'أمس';
    return '${d.day}/${d.month}/${d.year}';
  }
}

/// بطاقة إحصائية مصغرة.
class _MiniStatCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final String? sub;
  final Color color;
  final VoidCallback? onTap;

  const _MiniStatCard({
    required this.icon,
    required this.label,
    required this.value,
    this.sub,
    required this.color,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.md),
      child: Container(
        padding: const EdgeInsets.all(AppSpace.x3),
        decoration: BoxDecoration(
          color: color.withAlpha(20),
          borderRadius: BorderRadius.circular(AppRadius.md),
          border: Border.all(color: color.withAlpha(60)),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Icon(icon, color: color, size: AppIconSize.md),
            const Spacer(),
            if (onTap != null) const Icon(Icons.chevron_left, size: 16, color: AppColors.textSecondary),
          ]),
          const SizedBox(height: AppSpace.x1),
          Text(value, style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: color)),
          Text(label, style: AppText.caption.copyWith(color: color)),
          if (sub != null) Text(sub!, style: AppText.caption.copyWith(fontSize: 11, color: color.withAlpha(180))),
        ]),
      ),
    );
  }
}
