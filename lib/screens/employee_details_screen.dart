import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';
import '../models/employee.dart';
import '../services/storage_service.dart';
import '../design/tokens.dart';
import '../design/app_theme.dart';
import '../design/widgets.dart';
import '../design/format.dart';

/// ملف العامل الحقيقي (To Accio §3) — قابل للتحرير، بصورته وبياناته،
/// وسجل حضور بوقت دخول/خروج حقيقي (§5)، وكل حركة مالية بمسارها الصحيح.
class EmployeeDetailsScreen extends StatefulWidget {
  final Employee employee;
  const EmployeeDetailsScreen({super.key, required this.employee});

  @override
  State<EmployeeDetailsScreen> createState() => _S();
}

class _S extends State<EmployeeDetailsScreen> {
  late Employee e;
  int _tab = 0; // 0=النشاط 1=الحضور 2=المالية 3=البيانات

  @override
  void initState() {
    super.initState();
    e = widget.employee;
  }

  // ───────────────────────── أفعال ─────────────────────────

  Future<void> _save({String? msg}) async {
    await StorageService.saveEmployee(e);
    if (mounted) setState(() {});
    if (msg != null && mounted) _snack(msg);
  }

  void _snack(String m) {
    final s = ScaffoldMessenger.of(context);
    s.hideCurrentSnackBar();
    s.showSnackBar(SnackBar(content: Text(m)));
  }

  Future<void> _markAttendance() async {
    if (e.isPresentToday) {
      _snack('${e.name} مسجل حاضر النهاردة بالفعل');
      return;
    }
    e.markAttendance(DateTime.now());
    await _save(msg: 'تم تسجيل حضور ${e.name} — ${clockTime(DateTime.now())}');
  }

  Future<void> _markCheckout() async {
    final entry = e.todayEntry;
    if (entry == null) {
      _snack('سجّل الحضور الأول');
      return;
    }
    if (entry.checkOut != null) {
      _snack('الانصراف مسجل بالفعل النهاردة');
      return;
    }
    e.markCheckout(DateTime.now());
    await _save(msg: 'تم تسجيل انصراف ${e.name} — ${clockTime(DateTime.now())}');
  }

  Future<void> _pickPhoto() async {
    try {
      final picked = await ImagePicker().pickImage(source: ImageSource.gallery, maxWidth: 800);
      if (picked == null) return;
      // نحفظ نسخة داخل مجلد التطبيق حتى لا تُفقد عند تفريغ الكاش.
      final dir = await getApplicationDocumentsDirectory();
      final photosDir = Directory('${dir.path}/employee_photos');
      if (!photosDir.existsSync()) photosDir.createSync(recursive: true);
      final dest = '${photosDir.path}/${e.id}_${DateTime.now().millisecondsSinceEpoch}.jpg';
      await File(picked.path).copy(dest);
      e.photoPath = dest;
      await _save(msg: 'تم تحديث صورة ${e.name}');
    } catch (err) {
      if (mounted) _snack('تعذّر اختيار الصورة');
    }
  }

  Future<void> _removePhoto() async {
    e.photoPath = '';
    await _save(msg: 'تم حذف الصورة');
  }

  // ───────────────────────── نماذج مالية ─────────────────────────

  Future<void> _amountSheet({
    required String title,
    required String label,
    required String historyLabel,
    required List<String> entries,
    required void Function(double, String) onAdd,
  }) async {
    final amount = TextEditingController();
    final extra = TextEditingController();
    await showAppBottomSheet<void>(
      context: context,
      title: title,
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpace.x4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: amount,
              autofocus: true,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(labelText: label, hintText: '500'),
            ),
            const SizedBox(height: AppSpace.x3),
            TextField(
              controller: extra,
              decoration: const InputDecoration(labelText: 'السبب / ملاحظة (اختياري)'),
            ),
            const SizedBox(height: AppSpace.x4),
            FilledButton(
              onPressed: () async {
                final v = double.tryParse(amount.text.trim()) ?? 0;
                if (v <= 0) {
                  _snack('من فضلك أدخل مبلغًا صحيحًا');
                  return;
                }
                onAdd(v, extra.text.trim());
                await StorageService.saveEmployee(e);
                if (mounted) Navigator.pop(context);
                if (mounted) setState(() {});
              },
              child: const Text('تسجيل'),
            ),
            if (entries.isNotEmpty) ...[
              const SizedBox(height: AppSpace.x6),
              Text(historyLabel, style: AppText.label),
              const SizedBox(height: AppSpace.x2),
              for (final line in entries)
                Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Row(children: [
                    const Icon(Icons.circle, size: 6, color: AppColors.textDisabled),
                    const SizedBox(width: AppSpace.x2),
                    Expanded(child: Text(line, style: AppText.caption)),
                  ]),
                ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _addAdvance() => _amountSheet(
        title: 'سلفة لـ ${e.name}',
        label: 'المبلغ (ج)',
        historyLabel: 'سجل السلف',
        entries: e.advances.map((a) => '${money(a.amount)} — ${arabicDateTime(a.date)}').toList(),
        onAdd: (v, note) => e.advances
            .add(Advance(id: const Uuid().v4(), amount: v, date: DateTime.now(), note: note)),
      );

  Future<void> _addPayment() => _amountSheet(
        title: 'دفعة راتب لـ ${e.name}',
        label: 'المبلغ المدفوع (ج)',
        historyLabel: 'سجل الدفعات',
        entries: e.payments.map((p) => '${money(p.amount)} — ${arabicDateTime(p.date)}').toList(),
        onAdd: (v, note) => e.payments
            .add(EmployeePayment(id: const Uuid().v4(), amount: v, date: DateTime.now(), note: note)),
      );

  Future<void> _addDeduction() => _amountSheet(
        title: 'خصم على ${e.name}',
        label: 'قيمة الخصم (ج)',
        historyLabel: 'سجل الخصومات',
        entries: e.deductions
            .map((d) => '${money(d.amount)} — ${d.reason} (${arabicDateTime(d.date)})')
            .toList(),
        onAdd: (v, reason) => e.deductions.add(EmployeeDeduction(
            id: const Uuid().v4(), amount: v, reason: reason, date: DateTime.now())),
      );

  Future<void> _addBonus() => _amountSheet(
        title: 'مكافأة لـ ${e.name}',
        label: 'قيمة المكافأة (ج)',
        historyLabel: 'سجل المكافآت',
        entries: e.bonuses
            .map((b) => '${money(b.amount)} — ${b.reason} (${arabicDateTime(b.date)})')
            .toList(),
        onAdd: (v, reason) => e.bonuses.add(EmployeeBonus(
            id: const Uuid().v4(), amount: v, reason: reason, date: DateTime.now())),
      );

  Future<void> _addNote() async {
    final t = TextEditingController();
    await showAppBottomSheet<void>(
      context: context,
      title: 'ملاحظة على ${e.name}',
      body: Padding(
        padding: const EdgeInsets.all(AppSpace.x4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'الملاحظة نص حر ولا تُخصم تلقائيًا من الراتب — الخصم إجراء مالي منفصل.',
              style: AppText.caption,
            ),
            const SizedBox(height: AppSpace.x3),
            TextField(
              controller: t,
              autofocus: true,
              maxLines: 3,
              decoration: const InputDecoration(labelText: 'الملاحظة'),
            ),
            const SizedBox(height: AppSpace.x4),
            FilledButton(
              onPressed: () async {
                if (t.text.trim().isEmpty) return;
                e.notes.add(EmployeeNote(
                    id: const Uuid().v4(), text: t.text.trim(), date: DateTime.now()));
                await StorageService.saveEmployee(e);
                if (mounted) Navigator.pop(context);
                if (mounted) setState(() {});
              },
              child: const Text('إضافة'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _editDialog() async {
    final n = TextEditingController(text: e.name);
    final r = TextEditingController(text: e.role);
    final s = TextEditingController(text: e.salaryMonthly.toStringAsFixed(0));
    final phone = TextEditingController(text: e.phone);
    final addr = TextEditingController(text: e.address);
    final idn = TextEditingController(text: e.idNumber);
    var start = e.startDate;

    await showAppBottomSheet<void>(
      context: context,
      title: 'تعديل ${e.name}',
      body: StatefulBuilder(
        builder: (ctx, setSheet) => SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpace.x4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextField(controller: n, decoration: const InputDecoration(labelText: 'الاسم')),
              const SizedBox(height: AppSpace.x3),
              TextField(controller: r, decoration: const InputDecoration(labelText: 'الوظيفة')),
              const SizedBox(height: AppSpace.x3),
              TextField(
                controller: s,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'المرتب الشهري (ج)'),
              ),
              const SizedBox(height: AppSpace.x3),
              TextField(
                controller: phone,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(labelText: 'رقم التليفون'),
              ),
              const SizedBox(height: AppSpace.x3),
              TextField(controller: addr, decoration: const InputDecoration(labelText: 'العنوان')),
              const SizedBox(height: AppSpace.x3),
              TextField(
                controller: idn,
                decoration: const InputDecoration(labelText: 'الرقم القومي / الهوية'),
              ),
              const SizedBox(height: AppSpace.x3),
              InkWell(
                onTap: () async {
                  final picked = await showDatePicker(
                    context: ctx,
                    initialDate: start,
                    firstDate: DateTime(2000),
                    lastDate: DateTime.now(),
                  );
                  if (picked != null) setSheet(() => start = picked);
                },
                child: InputDecorator(
                  decoration: const InputDecoration(labelText: 'تاريخ بداية العمل'),
                  child: Row(children: [
                    Expanded(child: Text(arabicDate(start))),
                    const Icon(Icons.calendar_today_outlined, size: AppIconSize.sm),
                  ]),
                ),
              ),
              const SizedBox(height: AppSpace.x6),
              FilledButton(
                onPressed: () async {
                  e.name = n.text.trim().isEmpty ? e.name : n.text.trim();
                  e.role = r.text.trim();
                  e.salaryMonthly = double.tryParse(s.text.trim()) ?? e.salaryMonthly;
                  e.phone = phone.text.trim();
                  e.address = addr.text.trim();
                  e.idNumber = idn.text.trim();
                  e.startDate = start;
                  await StorageService.saveEmployee(e);
                  if (mounted) Navigator.pop(context);
                  if (mounted) setState(() {});
                },
                child: const Text('حفظ'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _archive() async {
    e.archived = !e.archived;
    await _save(msg: e.archived ? 'تم أرشفة ${e.name}' : 'تم إلغاء أرشفة ${e.name}');
  }

  Future<void> _safeDelete() async {
    if (e.hasHistory) {
      await showDialog<void>(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text('لا يمكن الحذف النهائي'),
          content: Text('${e.name} عنده سجلات حضور/مالية. استخدم الأرشفة للحفاظ على التاريخ.'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('تمام')),
          ],
        ),
      );
      return;
    }
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('حذف العامل نهائيًا؟'),
        content: const Text('لا يوجد أي سجل مرتبط، فالحذف آمن — لكن لا يمكن التراجع.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('إلغاء')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('حذف', style: TextStyle(color: AppColors.danger)),
          ),
        ],
      ),
    );
    if (ok != true) return;
    await StorageService.deleteEmployee(e.id);
    if (mounted) Navigator.pop(context);
  }

  // ───────────────────────── بناء ─────────────────────────

  @override
  Widget build(BuildContext context) {
    final today = e.todayEntry;
    return Scaffold(
      appBar: AppBar(
        title: Text(e.name),
        actions: [
          PopupMenuButton<String>(
            onSelected: (v) {
              if (v == 'edit') _editDialog();
              else if (v == 'archive') _archive();
              else if (v == 'delete') _safeDelete();
            },
            itemBuilder: (_) => [
              const PopupMenuItem(value: 'edit', child: Text('تعديل الملف')),
              PopupMenuItem(
                  value: 'archive', child: Text(e.archived ? 'إلغاء الأرشفة' : 'أرشفة')),
              if (!e.hasHistory)
                const PopupMenuItem(value: 'delete', child: Text('حذف نهائي')),
            ],
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(AppSpace.x4),
        children: [
          _profileCard(today),
          const SizedBox(height: AppSpace.x3),
          _financialCard(),
          const SizedBox(height: AppSpace.x3),
          _quickActions(),
          const SizedBox(height: AppSpace.x4),
          _segmented(),
          const SizedBox(height: AppSpace.x3),
          ...switch (_tab) {
            0 => _activityTab(),
            1 => _attendanceTab(),
            2 => _moneyTab(),
            _ => _dataTab(),
          },
          const SizedBox(height: AppSpace.x16),
        ],
      ),
    );
  }

  Widget _profileCard(AttendanceEntry? today) {
    final present = e.isPresentToday;
    return AppCard(
      elevated: true,
      padding: const EdgeInsets.all(AppSpace.x5),
      child: Column(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _photoSlot(),
              const SizedBox(width: AppSpace.x4),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(e.name, style: AppText.titleMedium),
                    const SizedBox(height: 2),
                    Text(e.role.isEmpty ? 'بدون وظيفة' : e.role, style: AppText.bodyMuted),
                    const SizedBox(height: AppSpace.x2),
                    Row(children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: present ? AppColors.success : AppColors.danger,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        present
                            ? 'حاضر اليوم${today?.checkIn != null ? ' · ${clockTime(today!.checkIn!)}' : ''}'
                            : 'غائب اليوم',
                        style: AppText.caption.copyWith(
                          color: present ? AppColors.success : AppColors.danger,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      if (today?.checkOut != null) ...[
                        const SizedBox(width: AppSpace.x2),
                        Text('· انصرف ${clockTime(today!.checkOut!)}',
                            style: AppText.caption.copyWith(color: AppColors.info)),
                      ],
                    ]),
                    if (e.phone.isNotEmpty) ...[
                      const SizedBox(height: AppSpace.x2),
                      InkWell(
                        onTap: () {
                          Clipboard.setData(ClipboardData(text: e.phone));
                          _snack('تم نسخ رقم ${e.name}');
                        },
                        child: Row(mainAxisSize: MainAxisSize.min, children: [
                          const Icon(Icons.phone_outlined,
                              size: AppIconSize.sm, color: AppColors.primary),
                          const SizedBox(width: 4),
                          Text(e.phone, style: AppText.caption.copyWith(color: AppColors.primary)),
                          const SizedBox(width: 4),
                          const Icon(Icons.copy, size: 11, color: AppColors.textDisabled),
                        ]),
                      ),
                    ],
                  ],
                ),
              ),
              if (e.archived)
                const AppBadge(label: 'مؤرشف', kind: BadgeKind.neutral, compact: true),
            ],
          ),
          const SizedBox(height: AppSpace.x4),
          Row(children: [
            _stat('المرتب', money(e.salaryMonthly, suffix: ''), AppColors.primary),
            _stat('حضور', '${e.attendance.length} يوم', AppColors.success),
            _stat('السلف', money(e.totalAdvances, suffix: ''), AppColors.warning),
          ]),
        ],
      ),
    );
  }

  Widget _photoSlot() {
    final has = e.photoPath.isNotEmpty && File(e.photoPath).existsSync();
    return InkWell(
      onTap: _pickPhoto,
      onLongPress: has ? _removePhoto : null,
      borderRadius: BorderRadius.circular(AppRadius.lg),
      child: Container(
        width: 72,
        height: 72,
        decoration: BoxDecoration(
          color: AppColors.primaryTint,
          borderRadius: BorderRadius.circular(AppRadius.lg),
          image: has
              ? DecorationImage(image: FileImage(File(e.photoPath)), fit: BoxFit.cover)
              : null,
        ),
        child: has
            ? null
            : Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    e.name.isNotEmpty ? Icons.person_outline : Icons.add_a_photo_outlined,
                    size: AppIconSize.md,
                    color: AppColors.primary,
                  ),
                  const SizedBox(height: 2),
                  Text('لا توجد صورة',
                      style: AppText.caption.copyWith(fontSize: 9),
                      textAlign: TextAlign.center),
                ],
              ),
      ),
    );
  }

  Widget _stat(String label, String value, Color color) => Expanded(
        child: Column(children: [
          Text(value,
              style: AppText.titleMedium
                  .copyWith(fontSize: 16, fontWeight: FontWeight.w700, color: color)),
          Text(label, style: AppText.caption),
        ]),
      );

  Widget _financialCard() {
    return AppCard(
      padding: const EdgeInsets.all(AppSpace.x4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('الموقف المالي', style: AppText.titleMedium.copyWith(fontSize: 15)),
          const SizedBox(height: AppSpace.x3),
          Row(children: [
            _finTile('المستحق حسب الحضور', money(e.attendancePay), Icons.event_available_outlined,
                AppColors.info),
            const SizedBox(width: AppSpace.x3),
            _finTile('المدفوعات', money(e.totalPayments), Icons.payments_outlined,
                AppColors.success),
          ]),
          const SizedBox(height: AppSpace.x3),
          Row(children: [
            _finTile('الخصومات', money(e.totalDeductions), Icons.remove_circle_outline,
                AppColors.danger),
            const SizedBox(width: AppSpace.x3),
            _finTile('المكافآت', money(e.totalBonuses), Icons.card_giftcard_outlined,
                AppColors.accent),
          ]),
          const SizedBox(height: AppSpace.x3),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(AppSpace.x3),
            decoration: BoxDecoration(
              color: e.netPayable > 0 ? AppColors.accentTint : AppColors.successTint,
              borderRadius: BorderRadius.circular(AppRadius.md),
            ),
            child: Row(children: [
              Icon(e.netPayable > 0 ? Icons.savings_outlined : Icons.check_circle_outline,
                  color: e.netPayable > 0 ? AppColors.accentStrong : AppColors.success),
              const SizedBox(width: AppSpace.x3),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('الصافي المستحق (حضور + مكافآت − خصومات − سلف − مدفوعات)',
                      style: AppText.caption),
                  Text(money(e.netPayable),
                      style: AppText.titleMedium.copyWith(
                          fontWeight: FontWeight.w700,
                          color: e.netPayable > 0 ? AppColors.accentStrong : AppColors.success)),
                ]),
              ),
            ]),
          ),
        ],
      ),
    );
  }

  Widget _finTile(String label, String value, IconData icon, Color color) => Expanded(
        child: Container(
          padding: const EdgeInsets.all(AppSpace.x3),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.06),
            borderRadius: BorderRadius.circular(AppRadius.md),
            border: Border.all(color: color.withValues(alpha: 0.2)),
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Icon(icon, size: AppIconSize.md, color: color),
            const SizedBox(height: AppSpace.x1),
            Text(value,
                style: AppText.titleMedium
                    .copyWith(fontSize: 15, fontWeight: FontWeight.w700, color: color)),
            Text(label, style: AppText.caption),
          ]),
        ),
      );

  Widget _quickActions() => Column(children: [
        Row(children: [
          _act(Icons.login, 'حضور', AppColors.success, e.isPresentToday ? null : _markAttendance),
          _act(Icons.logout, 'انصراف', AppColors.info,
              (e.todayEntry?.checkOut != null) ? null : _markCheckout),
          _act(Icons.account_balance_wallet_outlined, 'سلفة', AppColors.warning, _addAdvance),
          _act(Icons.payments_outlined, 'دفعة', AppColors.success, _addPayment),
        ]),
        const SizedBox(height: AppSpace.x3),
        Row(children: [
          _act(Icons.remove_circle_outline, 'خصم', AppColors.danger, _addDeduction),
          _act(Icons.card_giftcard_outlined, 'مكافأة', AppColors.accent, _addBonus),
          _act(Icons.sticky_note_2_outlined, 'ملاحظة', AppColors.info, _addNote),
          _act(Icons.edit_outlined, 'تعديل', AppColors.primary, _editDialog),
        ]),
      ]);

  Widget _act(IconData icon, String label, Color color, VoidCallback? onTap) {
    final enabled = onTap != null;
    final c = enabled ? color : AppColors.textDisabled;
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 3),
        child: Material(
          color: enabled ? c.withValues(alpha: 0.1) : AppColors.surfaceMuted,
          borderRadius: BorderRadius.circular(AppRadius.md),
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(AppRadius.md),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: AppSpace.x3),
              child: Column(children: [
                Icon(icon, size: AppIconSize.md, color: c),
                const SizedBox(height: 4),
                Text(label,
                    style: AppText.caption.copyWith(fontSize: 10, color: c),
                    textAlign: TextAlign.center,
                    maxLines: 1),
              ]),
            ),
          ),
        ),
      ),
    );
  }

  Widget _segmented() => SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(children: [
          for (var i = 0;
              i < ['النشاط', 'الحضور', 'المالية', 'البيانات'].length;
              i++) ...[
            if (i > 0) const SizedBox(width: AppSpace.x2),
            ChoiceChip(
              label: Text(['النشاط', 'الحضور', 'المالية', 'البيانات'][i]),
              selected: _tab == i,
              onSelected: (_) => setState(() => _tab = i),
            ),
          ],
        ]),
      );

  // ── تبويب النشاط ──
  List<Widget> _activityTab() {
    final events = e.timeline;
    if (events.isEmpty) {
      return [
        const AppEmptyState(
          icon: Icons.history,
          title: 'لا يوجد نشاط بعد',
          subtitle: 'أي حضور أو حركة مالية هتظهر هنا بالتاريخ والوقت.',
        ),
      ];
    }
    return [
      AppSectionHeader(title: 'النشاط الأخير', trailing: Text('${events.length} سجل', style: AppText.caption)),
      const SizedBox(height: AppSpace.x2),
      AppCard(
        padding: const EdgeInsets.all(AppSpace.x3),
        child: Column(
          children: [
            for (final ev in events) _timelineRow(ev),
          ],
        ),
      ),
    ];
  }

  Widget _timelineRow(EmployeeEvent ev) {
    final (IconData icon, Color color) = switch (ev.kind) {
      'advance' => (Icons.account_balance_wallet_outlined, AppColors.warning),
      'payment' => (Icons.payments_outlined, AppColors.success),
      'deduction' => (Icons.remove_circle_outline, AppColors.danger),
      'bonus' => (Icons.card_giftcard_outlined, AppColors.accent),
      'note' => (Icons.sticky_note_2_outlined, AppColors.info),
      _ => (Icons.check_circle_outline, AppColors.success),
    };
    final detail = switch (ev.payload) {
      Advance a => a.note,
      EmployeePayment p => p.note,
      EmployeeDeduction d => d.reason,
      EmployeeBonus b => b.reason,
      EmployeeNote n => n.text,
      AttendanceEntry a => a.checkOut != null
          ? 'من ${a.checkIn != null ? clockTime(a.checkIn!) : '—'} إلى ${clockTime(a.checkOut!)}'
          : (a.checkIn != null ? 'دخول ${clockTime(a.checkIn!)}' : 'الوقت غير متوفر'),
      _ => '',
    };
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpace.x2),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(
          width: 30,
          height: 30,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(AppRadius.sm),
          ),
          child: Icon(icon, size: 15, color: color),
        ),
        const SizedBox(width: AppSpace.x3),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Expanded(
                child: Text(
                  ev.kind == 'attendance'
                      ? 'حضور'
                      : (ev.amount > 0 ? '${ev.label} — ${money(ev.amount)}' : ev.label),
                  style: AppText.body.copyWith(fontSize: 14),
                ),
              ),
              Text(arabicDateTime(ev.date), style: AppText.caption),
            ]),
            if (detail.isNotEmpty && detail != 'false')
              Text(detail, style: AppText.caption),
          ]),
        ),
      ]),
    );
  }

  // ── تبويب الحضور ──
  List<Widget> _attendanceTab() {
    final rows = _attendanceRows();
    if (rows.isEmpty) {
      return [
        const AppEmptyState(
          icon: Icons.event_available_outlined,
          title: 'لا يوجد سجل حضور',
          subtitle: 'سجّل الحضور من الأزرار فوق.',
        ),
      ];
    }
    return [
      AppSectionHeader(title: 'سجل الحضور', trailing: Text('${rows.length} يوم', style: AppText.caption)),
      const SizedBox(height: AppSpace.x2),
      AppCard(
        padding: EdgeInsets.zero,
        child: Column(children: [
          for (final r in rows) _attendanceRow(r),
        ]),
      ),
    ];
  }

  List<_AttRow> _attendanceRows() {
    final byDay = {for (final a in e.attendanceLog) a.day: a};
    final rows = [
      for (final day in e.attendance)
        _AttRow(day: day, checkIn: byDay[day]?.checkIn, checkOut: byDay[day]?.checkOut),
    ];
    rows.sort((a, b) => b.day.compareTo(a.day));
    return rows;
  }

  Widget _attendanceRow(_AttRow r) {
    final parsed = DateTime.tryParse(r.day);
    final timeLabel = (r.checkIn == null && r.checkOut == null)
        ? 'الوقت غير متوفر'
        : 'دخول ${r.checkIn != null ? clockTime(r.checkIn!) : '—'}'
            '${r.checkOut != null ? ' · خروج ${clockTime(r.checkOut!)}' : ''}';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppSpace.x4, vertical: AppSpace.x3),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: AppColors.border, width: 0.5)),
      ),
      child: Row(children: [
        const Icon(Icons.check_circle_outline, size: AppIconSize.md, color: AppColors.success),
        const SizedBox(width: AppSpace.x3),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(parsed != null ? relativeDay(parsed) : r.day,
                style: AppText.body.copyWith(fontSize: 14)),
            Text(timeLabel,
                style: AppText.caption.copyWith(
                    color: r.hasTime ? AppColors.textSecondary : AppColors.textDisabled)),
          ]),
        ),
        IconButton(
          icon: const Icon(Icons.delete_outline, size: 18),
          color: AppColors.danger,
          visualDensity: VisualDensity.compact,
          onPressed: () async {
            final ok = await _confirm('حذف سجل الحضور؟', 'لا يمكن التراجع.');
            if (ok != true) return;
            e.attendance.remove(r.day);
            e.attendanceLog.removeWhere((a) => a.day == r.day);
            await _save(msg: 'تم حذف سجل ${r.day}');
          },
        ),
      ]),
    );
  }

  // ── تبويب المالية ──
  List<Widget> _moneyTab() {
    final groups = <({String title, List<({String label, String sub, double amount, Color color, VoidCallback onDelete})> rows})>[
      (
        title: 'السلف (${money(e.totalAdvances)})',
        rows: [
          for (var i = 0; i < e.advances.length; i++)
            (
              label: 'سلفة',
              sub: '${arabicDateTime(e.advances[i].date)}${e.advances[i].note.isEmpty ? '' : ' · ${e.advances[i].note}'}',
              amount: e.advances[i].amount,
              color: AppColors.warning,
              onDelete: () async {
                e.advances.removeAt(i);
                await _save(msg: 'تم حذف السلفة');
              },
            ),
        ]
      ),
      (
        title: 'المدفوعات (${money(e.totalPayments)})',
        rows: [
          for (var i = 0; i < e.payments.length; i++)
            (
              label: 'دفعة راتب',
              sub: '${arabicDateTime(e.payments[i].date)}${e.payments[i].note.isEmpty ? '' : ' · ${e.payments[i].note}'}',
              amount: e.payments[i].amount,
              color: AppColors.success,
              onDelete: () async {
                e.payments.removeAt(i);
                await _save(msg: 'تم حذف الدفعة');
              },
            ),
        ]
      ),
      (
        title: 'الخصومات (${money(e.totalDeductions)})',
        rows: [
          for (var i = 0; i < e.deductions.length; i++)
            (
              label: e.deductions[i].reason.isEmpty ? 'خصم' : e.deductions[i].reason,
              sub: arabicDateTime(e.deductions[i].date),
              amount: e.deductions[i].amount,
              color: AppColors.danger,
              onDelete: () async {
                e.deductions.removeAt(i);
                await _save(msg: 'تم حذف الخصم');
              },
            ),
        ]
      ),
      (
        title: 'المكافآت (${money(e.totalBonuses)})',
        rows: [
          for (var i = 0; i < e.bonuses.length; i++)
            (
              label: e.bonuses[i].reason.isEmpty ? 'مكافأة' : e.bonuses[i].reason,
              sub: arabicDateTime(e.bonuses[i].date),
              amount: e.bonuses[i].amount,
              color: AppColors.accent,
              onDelete: () async {
                e.bonuses.removeAt(i);
                await _save(msg: 'تم حذف المكافأة');
              },
            ),
        ]
      ),
      (
        title: 'الملاحظات (${e.notes.length})',
        rows: [
          for (var i = 0; i < e.notes.length; i++)
            (
              label: e.notes[i].text,
              sub: arabicDateTime(e.notes[i].date),
              amount: 0.0,
              color: AppColors.info,
              onDelete: () async {
                e.notes.removeAt(i);
                await _save(msg: 'تم حذف الملاحظة');
              },
            ),
        ]
      ),
    ];

    return [
      for (final g in groups) ...[
        if (g.rows.isEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpace.x3),
            child: AppCard(
              padding: const EdgeInsets.all(AppSpace.x4),
              child: Row(children: [
                const Icon(Icons.inbox_outlined, size: AppIconSize.md, color: AppColors.textDisabled),
                const SizedBox(width: AppSpace.x3),
                Expanded(child: Text(g.title, style: AppText.bodyMuted)),
              ]),
            ),
          )
        else ...[
          AppSectionHeader(title: g.title),
          const SizedBox(height: AppSpace.x2),
          AppCard(
            padding: EdgeInsets.zero,
            child: Column(children: [
              for (final r in g.rows)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: AppSpace.x4, vertical: AppSpace.x3),
                  decoration: const BoxDecoration(
                    border: Border(bottom: BorderSide(color: AppColors.border, width: 0.5)),
                  ),
                  child: Row(children: [
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(r.label, style: AppText.body.copyWith(fontSize: 14)),
                        Text(r.sub, style: AppText.caption),
                      ]),
                    ),
                    if (r.amount > 0)
                      Text(money(r.amount),
                          style: AppText.label.copyWith(fontWeight: FontWeight.w700, color: r.color)),
                    IconButton(
                      icon: const Icon(Icons.delete_outline, size: 18),
                      color: AppColors.danger,
                      visualDensity: VisualDensity.compact,
                      onPressed: () async {
                        final ok = await _confirm('حذف السجل؟', 'لا يمكن التراجع.');
                        if (ok == true) r.onDelete();
                      },
                    ),
                  ]),
                ),
            ]),
          ),
          const SizedBox(height: AppSpace.x3),
        ],
      ],
    ];
  }

  // ── تبويب البيانات ──
  List<Widget> _dataTab() => [
        AppSectionHeader(title: 'بيانات العامل'),
        const SizedBox(height: AppSpace.x2),
        AppCard(
          padding: const EdgeInsets.all(AppSpace.x4),
          child: Column(children: [
            _infoRow('الاسم', e.name),
            _infoRow('الوظيفة', e.role.isEmpty ? '—' : e.role),
            _infoRow('المرتب الشهري', money(e.salaryMonthly)),
            _infoRow('تاريخ بداية العمل', arabicDate(e.startDate)),
            _infoRow('التليفون', e.phone.isEmpty ? '—' : e.phone),
            _infoRow('العنوان', e.address.isEmpty ? '—' : e.address),
            _infoRow('الرقم القومي', e.idNumber.isEmpty ? '—' : e.idNumber),
            _infoRow('أيام الحضور', '${e.attendance.length} يوم'),
            _infoRow('الحالة', e.archived ? 'مؤرشف' : 'نشط'),
          ]),
        ),
        const SizedBox(height: AppSpace.x4),
        FilledButton.icon(
          onPressed: _editDialog,
          icon: const Icon(Icons.edit_outlined, size: AppIconSize.md),
          label: const Text('تعديل بيانات الملف'),
        ),
        const SizedBox(height: AppSpace.x2),
        OutlinedButton.icon(
          onPressed: _archive,
          icon: Icon(e.archived ? Icons.unarchive_outlined : Icons.archive_outlined,
              size: AppIconSize.md),
          label: Text(e.archived ? 'إلغاء الأرشفة' : 'أرشفة العامل'),
        ),
      ];

  Widget _infoRow(String label, String value) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          SizedBox(width: 120, child: Text(label, style: AppText.caption)),
          Expanded(child: Text(value, style: AppText.body.copyWith(fontSize: 14))),
        ]),
      );

  Future<bool?> _confirm(String title, String message) => showDialog<bool>(
        context: context,
        builder: (_) => AlertDialog(
          title: Text(title),
          content: Text(message),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('إلغاء')),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('حذف', style: TextStyle(color: AppColors.danger)),
            ),
          ],
        ),
      );
}

/// صف حضور مبني على اليوم + أوقات الدخول/الخروج إن وُجدت.
class _AttRow {
  final String day;
  final DateTime? checkIn;
  final DateTime? checkOut;
  const _AttRow({required this.day, this.checkIn, this.checkOut});
  bool get hasTime => checkIn != null || checkOut != null;
}
