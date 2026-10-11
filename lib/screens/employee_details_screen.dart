import 'dart:io';
import 'package:flutter/material.dart';
import '../models/employee.dart';
import '../services/storage_service.dart';
import '../services/app_state.dart';
import '../design/tokens.dart';
import '../design/app_theme.dart';
import '../design/widgets.dart';
import '../design/format.dart';
import 'employee_forms.dart';

/// ملف العامل — صفحة حقيقية قابلة للتحرير مع سجل حضور ونشاط وماليات.
class EmployeeDetailsScreen extends StatefulWidget {
  final Employee employee;
  const EmployeeDetailsScreen({super.key, required this.employee});

  @override
  State<EmployeeDetailsScreen> createState() => _S();
}

class _S extends State<EmployeeDetailsScreen> {
  late Employee e;
  int _tab = 0;

  @override
  void initState() {
    super.initState();
    e = widget.employee;
  }

  Future<void> _run(Future<void> Function() action) async {
    await action();
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(e.name),
        actions: [
          IconButton(
            tooltip: 'تعديل',
            icon: const Icon(Icons.edit_outlined),
            onPressed: () => _run(() => showEditEmployeeSheet(context, e)),
          ),
          PopupMenuButton<String>(
            onSelected: (v) async {
              if (v == 'archive') {
                await archiveEmployee(context, e);
                if (mounted) setState(() {});
              } else if (v == 'delete') {
                if (await deleteEmployeeSafely(context, e) && context.mounted) Navigator.pop(context);
              }
            },
            itemBuilder: (_) => [
              PopupMenuItem(value: 'archive', child: Text(e.archived ? 'إلغاء الأرشفة' : 'أرشفة')),
              if (!e.hasHistory) const PopupMenuItem(value: 'delete', child: Text('حذف نهائي')),
            ],
          ),
        ],
      ),
      body: ListenableBuilder(
        listenable: AppState.instance,
        builder: (context, _) {
          final fresh = StorageService.employees().where((x) => x.id == e.id).toList();
          if (fresh.isNotEmpty) e = fresh.first;
          return ListView(
            padding: const EdgeInsets.all(AppSpace.x4),
            children: [
              _header(),
              const SizedBox(height: AppSpace.x3),
              _summary(),
              const SizedBox(height: AppSpace.x3),
              _quickActions(),
              const SizedBox(height: AppSpace.x4),
              AppSegmented(
                labels: const ['النشاط', 'الحضور', 'المالية', 'البيانات'],
                selectedIndex: _tab,
                onSelected: (i) => setState(() => _tab = i),
              ),
              const SizedBox(height: AppSpace.x3),
              if (_tab == 0) ..._activityTab(),
              if (_tab == 1) ..._attendanceTab(),
              if (_tab == 2) ..._financeTab(),
              if (_tab == 3) ..._dataTab(),
              const SizedBox(height: AppSpace.x16),
            ],
          );
        },
      ),
    );
  }

  Widget _header() {
    final hasPhoto = e.photoPath.isNotEmpty && File(e.photoPath).existsSync();
    return AppCard(
      padding: const EdgeInsets.all(AppSpace.x4),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          GestureDetector(
            onTap: () => _run(() async {
              if (await pickEmployeePhoto(e)) {
                if (context.mounted) showAppSnack(context, 'تم تحديث صورة ${e.name}');
              }
            }),
            child: Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: AppColors.primaryTint,
                borderRadius: BorderRadius.circular(AppRadius.md),
                border: Border.all(color: AppColors.border),
              ),
              clipBehavior: Clip.antiAlias,
              child: hasPhoto
                  ? Image.file(File(e.photoPath), fit: BoxFit.cover)
                  : const Icon(Icons.person_outline, size: 30, color: AppColors.primary),
            ),
          ),
          const SizedBox(width: AppSpace.x3),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(e.name, style: AppText.h2.copyWith(fontSize: 20)),
              Text(e.role.isEmpty ? 'عامل' : e.role, style: AppText.bodyMuted),
              if (e.phone.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Row(children: [
                    const Icon(Icons.phone_outlined, size: 12, color: AppColors.textSecondary),
                    const SizedBox(width: 4),
                    Text(e.phone, style: AppText.caption),
                  ]),
                ),
            ]),
          ),
          AppStatusIndicator(
            label: e.isPresentToday ? 'حاضر اليوم' : 'لم يسجّل حضور',
            color: e.isPresentToday ? AppColors.success : AppColors.warning,
          ),
        ]),
        if (e.archived) ...[
          const SizedBox(height: AppSpace.x3),
          const AppBadge(kind: BadgeKind.neutral, label: 'مؤرشف'),
        ],
      ]),
    );
  }

  Widget _summary() {
    return Column(children: [
      Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Expanded(
          child: AppStatTile(
            label: 'الراتب الشهري',
            value: money(e.salaryMonthly),
            icon: Icons.payments_outlined,
            color: AppColors.primary,
            onTap: () => setState(() => _tab = 2),
          ),
        ),
        const SizedBox(width: AppSpace.x3),
        Expanded(
          child: AppStatTile(
            label: 'أيام الحضور',
            value: '${e.attendance.length}',
            sub: 'غياب ${e.absenceDays} يوم',
            icon: Icons.event_available_outlined,
            color: AppColors.info,
            onTap: () => setState(() => _tab = 1),
          ),
        ),
      ]),
      const SizedBox(height: AppSpace.x3),
      Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Expanded(
          child: AppStatTile(
            label: 'السلف',
            value: money(e.totalAdvances),
            icon: Icons.account_balance_wallet_outlined,
            color: AppColors.warning,
            onTap: () => setState(() => _tab = 2),
          ),
        ),
        const SizedBox(width: AppSpace.x3),
        Expanded(
          child: AppStatTile(
            label: 'المتبقي من الراتب',
            value: money(e.remainingSalary),
            icon: Icons.savings_outlined,
            color: AppColors.success,
            onTap: () => setState(() => _tab = 2),
          ),
        ),
      ]),
    ]);
  }

  Widget _quickActions() {
    return Column(children: [
      Row(children: [
        Expanded(
          child: _Action(
            icon: e.checkedOutToday ? Icons.check_circle_outline : Icons.login,
            label: e.isPresentToday ? (e.checkedOutToday ? 'انصرف' : 'تسجيل انصراف') : 'تسجيل حضور',
            color: AppColors.success,
            onTap: () => _run(() => showAttendanceSheet(context, e)),
          ),
        ),
        const SizedBox(width: AppSpace.x2),
        Expanded(
          child: _Action(
            icon: Icons.account_balance_wallet_outlined,
            label: 'سلفة',
            color: AppColors.warning,
            onTap: () => _run(() => showAdvanceSheet(context, e)),
          ),
        ),
        const SizedBox(width: AppSpace.x2),
        Expanded(
          child: _Action(
            icon: Icons.payments_outlined,
            label: 'دفعة',
            color: AppColors.success,
            onTap: () => _run(() => showPaymentSheet(context, e)),
          ),
        ),
      ]),
      const SizedBox(height: AppSpace.x2),
      Row(children: [
        Expanded(
          child: _Action(
            icon: Icons.remove_circle_outline,
            label: 'خصم',
            color: AppColors.danger,
            onTap: () => _run(() => showDeductionSheet(context, e)),
          ),
        ),
        const SizedBox(width: AppSpace.x2),
        Expanded(
          child: _Action(
            icon: Icons.add_circle_outline,
            label: 'مكافأة',
            color: AppColors.info,
            onTap: () => _run(() => showBonusSheet(context, e)),
          ),
        ),
        const SizedBox(width: AppSpace.x2),
        Expanded(
          child: _Action(
            icon: Icons.notes_outlined,
            label: 'ملاحظة',
            color: AppColors.primary,
            onTap: () => _run(() => showNoteSheet(context, e)),
          ),
        ),
      ]),
    ]);
  }

  // ── النشاط ──────────────────────────────────────────────────
  List<Widget> _activityTab() {
    final events = e.timeline;
    if (events.isEmpty) {
      return [
        const AppEmptyState(
          icon: Icons.history,
          title: 'لا يوجد نشاط بعد',
          subtitle: 'الحضور والسلف والرواتب هتظهر هنا.',
        ),
      ];
    }
    return [
      AppSectionHeader(title: 'سجل النشاط', trailing: Text('${events.length} حركة', style: AppText.caption)),
      AppCard(
        padding: const EdgeInsets.all(AppSpace.x4),
        child: Column(
          children: [
            for (var i = 0; i < events.length; i++) _eventRow(events[i], i == events.length - 1),
          ],
        ),
      ),
    ];
  }

  Widget _eventRow(EmployeeEvent ev, bool isLast) {
    switch (ev.kind) {
      case 'advance':
        final a = ev.payload as Advance;
        return AppTimelineItem(
          title: 'سلفة',
          subtitle: a.note,
          trailing: money(a.amount),
          dateText: arabicDateTime(a.date),
          icon: Icons.account_balance_wallet_outlined,
          color: AppColors.warning,
          isLast: isLast,
        );
      case 'payment':
        final p = ev.payload as EmployeePayment;
        return AppTimelineItem(
          title: 'دفعة راتب',
          subtitle: p.note,
          trailing: money(p.amount),
          dateText: arabicDateTime(p.date),
          icon: Icons.payments_outlined,
          color: AppColors.success,
          isLast: isLast,
        );
      case 'deduction':
        final d = ev.payload as EmployeeDeduction;
        return AppTimelineItem(
          title: 'خصم',
          subtitle: d.reason,
          trailing: money(d.amount),
          dateText: arabicDateTime(d.date),
          icon: Icons.remove_circle_outline,
          color: AppColors.danger,
          isLast: isLast,
        );
      case 'bonus':
        final b = ev.payload as EmployeeBonus;
        return AppTimelineItem(
          title: 'مكافأة',
          subtitle: b.reason,
          trailing: money(b.amount),
          dateText: arabicDateTime(b.date),
          icon: Icons.add_circle_outline,
          color: AppColors.info,
          isLast: isLast,
        );
      case 'note':
        final n = ev.payload as EmployeeNote;
        return AppTimelineItem(
          title: 'ملاحظة',
          subtitle: n.text,
          dateText: arabicDateTime(n.date),
          icon: Icons.notes_outlined,
          color: AppColors.textSecondary,
          isLast: isLast,
        );
      default:
        final a = ev.payload as AttendanceEntry;
        final t = a.worked;
        return AppTimelineItem(
          title: 'حضور',
          subtitle: t == null ? 'الوقت غير متوفر' : 'مدة العمل ${t.inHours}س ${t.inMinutes % 60}د',
          dateText: arabicDateTime(a.checkIn ?? DateTime.parse(a.day)),
          icon: Icons.event_available_outlined,
          color: AppColors.primary,
          isLast: isLast,
        );
    }
  }

  // ── الحضور ──────────────────────────────────────────────────
  List<Widget> _attendanceTab() {
    final logged = {...e.attendanceLog.map((a) => a.day)};
    final legacyDays = e.attendance.where((d) => !logged.contains(d)).toList();
    final entries = List<AttendanceEntry>.from(e.attendanceLog)
      ..sort((a, b) => b.day.compareTo(a.day));

    return [
      AppSectionHeader(
        title: 'سجل الحضور',
        trailing: Text('${e.attendance.length} يوم', style: AppText.caption),
      ),
      AppCard(
        padding: const EdgeInsets.symmetric(vertical: AppSpace.x2),
        child: Column(children: [
          if (entries.isEmpty && legacyDays.isEmpty)
            Padding(
              padding: const EdgeInsets.all(AppSpace.x4),
              child: Text('لا يوجد حضور مسجّل', style: AppText.bodyMuted),
            ),
          for (var i = 0; i < entries.length; i++)
            _attendanceRow(
              day: entries[i].day,
              inT: entries[i].checkIn,
              outT: entries[i].checkOut,
              isLast: i == entries.length - 1 && legacyDays.isEmpty,
            ),
          for (var i = 0; i < legacyDays.length; i++)
            _attendanceRow(
              day: legacyDays[i],
              inT: null,
              outT: null,
              isLast: i == legacyDays.length - 1,
            ),
        ]),
      ),
      const SizedBox(height: AppSpace.x3),
      FilledButton.icon(
        onPressed: () => _run(() => showAttendanceSheet(context, e)),
        icon: const Icon(Icons.login),
        label: const Text('تسجيل حضور / انصراف'),
      ),
    ];
  }

  Widget _attendanceRow({
    required String day,
    required DateTime? inT,
    required DateTime? outT,
    required bool isLast,
  }) {
    final times = inT == null
        ? 'وقت غير متوفر (سجل قديم)'
        : 'دخول ${clockTime(inT)}${outT == null ? ' · لم يسجّل انصراف' : ' · خروج ${clockTime(outT)}'}';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppSpace.x4, vertical: AppSpace.x3),
      decoration: BoxDecoration(
        border: isLast ? null : const Border(bottom: BorderSide(color: AppColors.border, width: 0.5)),
      ),
      child: Row(children: [
        Icon(
          outT != null ? Icons.check_circle : (inT != null ? Icons.schedule : Icons.help_outline),
          size: AppIconSize.md,
          color: outT != null
              ? AppColors.success
              : (inT != null ? AppColors.warning : AppColors.textDisabled),
        ),
        const SizedBox(width: AppSpace.x3),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(arabicDate(DateTime.parse(day)), style: AppText.label.copyWith(fontWeight: FontWeight.w600)),
            Text(times, style: AppText.caption),
          ]),
        ),
      ]),
    );
  }

  // ── المالية ─────────────────────────────────────────────────
  List<Widget> _financeTab() {
    return [
      AppSectionHeader(title: 'الملخص المالي'),
      AppCard(
        padding: const EdgeInsets.symmetric(horizontal: AppSpace.x4, vertical: AppSpace.x2),
        child: Column(children: [
          AppInfoRow(label: 'الراتب الشهري', value: money(e.salaryMonthly)),
          AppInfoRow(label: 'المستحق حسب الحضور', value: money(e.salaryDue)),
          AppInfoRow(label: 'إجمالي السلف', value: money(e.totalAdvances)),
          AppInfoRow(label: 'إجمالي المدفوعات', value: money(e.totalPayments)),
          AppInfoRow(label: 'إجمالي الخصومات', value: money(e.totalDeductions)),
          AppInfoRow(label: 'إجمالي المكافآت', value: money(e.totalBonuses)),
          const Divider(height: AppSpace.x5),
          AppInfoRow(
            label: 'صافي المستحق',
            valueWidget: Text(
              money(e.netPayable),
              style: AppText.label.copyWith(fontWeight: FontWeight.w700, color: AppColors.primary),
            ),
          ),
        ]),
      ),
      const SizedBox(height: AppSpace.x4),
      _listSection('السلف', e.advances.length, [
        for (final a in e.advances.reversed)
          AppInfoRow(label: arabicDateTime(a.date), value: money(a.amount)),
      ], emptyText: 'لا توجد سلف'),
      _listSection('الدفعات', e.payments.length, [
        for (final p in e.payments.reversed) AppInfoRow(label: arabicDateTime(p.date), value: money(p.amount)),
      ], emptyText: 'لا توجد دفعات'),
      _listSection('الخصومات', e.deductions.length, [
        for (final d in e.deductions.reversed)
          AppInfoRow(label: '${d.reason.isEmpty ? arabicDateTime(d.date) : d.reason}', value: money(d.amount)),
      ], emptyText: 'لا توجد خصومات'),
      _listSection('المكافآت', e.bonuses.length, [
        for (final b in e.bonuses.reversed)
          AppInfoRow(label: '${b.reason.isEmpty ? arabicDateTime(b.date) : b.reason}', value: money(b.amount)),
      ], emptyText: 'لا توجد مكافآت'),
      _listSection('الملاحظات', e.notes.length, [
        for (final n in e.notes.reversed) AppInfoRow(label: arabicDateTime(n.date), value: n.text),
      ], emptyText: 'لا توجد ملاحظات'),
    ];
  }

  Widget _listSection(String title, int count, List<Widget> rows, {required String emptyText}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpace.x3),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        AppSectionHeader(title: title, trailing: Text('$count', style: AppText.caption)),
        if (rows.isEmpty)
          AppCard(
            padding: const EdgeInsets.all(AppSpace.x4),
            child: Text(emptyText, style: AppText.bodyMuted),
          )
        else
          AppCard(
            padding: const EdgeInsets.symmetric(horizontal: AppSpace.x4, vertical: AppSpace.x2),
            child: Column(children: rows),
          ),
      ]),
    );
  }

  // ── البيانات ────────────────────────────────────────────────
  List<Widget> _dataTab() {
    return [
      AppSectionHeader(
        title: 'بيانات العامل',
        trailing: TextButton(
          onPressed: () => _run(() => showEditEmployeeSheet(context, e)),
          child: const Text('تعديل'),
        ),
      ),
      AppCard(
        padding: const EdgeInsets.symmetric(horizontal: AppSpace.x4, vertical: AppSpace.x2),
        child: Column(children: [
          AppInfoRow(label: 'الاسم', value: e.name),
          AppInfoRow(label: 'الوظيفة', value: e.role.isEmpty ? '—' : e.role),
          AppInfoRow(label: 'الهاتف', value: e.phone.isEmpty ? '—' : e.phone),
          AppInfoRow(label: 'رقم الهوية', value: e.idNumber.isEmpty ? '—' : e.idNumber),
          AppInfoRow(label: 'العنوان', value: e.address.isEmpty ? '—' : e.address),
          AppInfoRow(label: 'بداية العمل', value: arabicDate(e.startDate)),
          AppInfoRow(label: 'الحالة', value: e.archived ? 'مؤرشف' : 'نشط'),
        ]),
      ),
      const SizedBox(height: AppSpace.x3),
      if (!e.hasHistory)
        OutlinedButton.icon(
          onPressed: () async {
            if (await deleteEmployeeSafely(context, e) && context.mounted) Navigator.pop(context);
          },
          icon: const Icon(Icons.delete_outline, color: AppColors.danger),
          label: const Text('حذف نهائي', style: TextStyle(color: AppColors.danger)),
          style: OutlinedButton.styleFrom(minimumSize: const Size(0, AppTouch.min)),
        )
      else
        AppStatusBanner(
          kind: BannerKind.info,
          icon: Icons.lock_outline,
          message: 'العامل عنده سجلات، فالحذف النهائي متوقف — استخدم الأرشفة للحفاظ على التاريخ.',
        ),
    ];
  }
}

class _Action extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback? onTap;
  const _Action({required this.icon, required this.label, required this.color, this.onTap});

  @override
  Widget build(BuildContext context) {
    final c = onTap != null ? color : AppColors.textDisabled;
    return Material(
      color: c.withValues(alpha: 0.08),
      borderRadius: BorderRadius.circular(AppRadius.md),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.md),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: AppSpace.x3, horizontal: AppSpace.x1),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadius.md),
            border: Border.all(color: c.withValues(alpha: 0.25)),
          ),
          child: Column(children: [
            Icon(icon, size: AppIconSize.lg, color: c),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(fontFamily: 'Tajawal', fontSize: 11, fontWeight: FontWeight.w600, color: c),
              textAlign: TextAlign.center,
              maxLines: 2,
            ),
          ]),
        ),
      ),
    );
  }
}
