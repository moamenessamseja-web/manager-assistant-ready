import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../design/app_theme.dart';
import '../design/format.dart';
import '../design/tokens.dart';
import '../design/widgets.dart';
import '../models/shift.dart';
import '../services/app_state.dart';
import '../services/closing_service.dart';
import '../services/storage_service.dart';
import 'form_sheet.dart';
import 'receivables_screen.dart' show parseMoney;

String _m(double v) => money(v);

/// إقفال الشيفت والإقفال اليومي. كل شيفت له إقفاله المستقل؛ «إقفال اليوم» اختياري
/// بيجمّع لقطات شيفتات نفس اليوم التشغيلي من غير ما يلغيها.
class ShiftsScreen extends StatefulWidget {
  const ShiftsScreen({super.key});
  @override
  State<ShiftsScreen> createState() => _ShiftsScreenState();
}

class _ShiftsScreenState extends State<ShiftsScreen> {
  static const _kDayStart = 'business_day_start_hour';

  int get _startHour =>
      StorageService.prefs.getInt(_kDayStart) ?? ClosingService.defaultDayStartHour;

  // مصادر الحركات (كل السجلات بما فيها المؤرشفة)
  get _emps => StorageService.employees();
  get _sups => StorageService.suppliers();
  get _custs => StorageService.customers();

  ShiftTotals _live(Shift s) => ClosingService.totalsOfShift(s,
      now: DateTime.now(), employees: _emps, suppliers: _sups, customers: _custs);

  void _snack(String m) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));

  Future<void> _setDayStart(int h) async {
    await StorageService.prefs.setInt(_kDayStart, h);
    AppState.instance.notify();
  }

  Future<void> _consolidate(String date, DailyClosing? existing) async {
    try {
      final d = ClosingService.consolidate(
        StorageService.shifts(),
        date,
        existing: existing,
        newId: const Uuid().v4(),
        now: DateTime.now(),
        startHour: _startHour,
        employees: _emps,
        suppliers: _sups,
        customers: _custs,
      );
      await StorageService.saveDailyClosing(d);
      _snack(existing == null ? 'تم إقفال اليوم $date' : 'تم تحديث الإقفال اليومي');
    } on ClosingException catch (e) {
      _snack(e.message);
    }
  }

  // ───────────────────────── عرض تفاصيل ─────────────────────────

  void _shiftDetail(Shift s) {
    final totals = s.isClosed ? (s.snapshot ?? _live(s)) : _live(s);
    final drift = s.isClosed
        ? ClosingService.driftOf(s,
            now: DateTime.now(), employees: _emps, suppliers: _sups, customers: _custs)
        : null;
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpace.x4),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Text('${s.name} — ${s.businessDate}', style: Theme.of(context).textTheme.titleLarge),
          Text(
              '${arabicDateTime(s.openedAt)}${s.closedAt == null ? ' (مفتوح)' : ' ← ${arabicDateTime(s.closedAt!)}'}',
              style: AppText.caption),
          const SizedBox(height: AppSpace.x3),
          TotalsView(totals: totals, shift: s),
          if (drift != null) ...[
            const SizedBox(height: AppSpace.x3),
            AppCard(
              backgroundColor: AppColors.warning.withValues(alpha: 0.12),
              child: Text(
                '⚠️ فيه حركات اتغيّرت بعد إقفال الشيفت ده (إلغاء أو تسجيل بتاريخ سابق). '
                'الأرقام فوق هي اللقطة وقت الإقفال. الأرقام الحالية: داخل ${_m(drift.cashIn)} · خارج ${_m(drift.cashOut)}.',
                style: AppText.caption,
              ),
            ),
          ],
          if (s.note.isNotEmpty) ...[const SizedBox(height: AppSpace.x2), Text('ملاحظة: ${s.note}')],
        ]),
      ),
    );
  }

  void _dailyDetail(DailyClosing d) {
    final shifts = ClosingService.shiftsOfDay(StorageService.shifts(), d.businessDate);
    final out = d.outsideShifts;
    final hasOutside = out.cashIn != 0 ||
        out.cashOut != 0 ||
        out.creditSales != 0 ||
        out.supplierPurchases != 0;
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpace.x4),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Text('الإقفال اليومي — ${d.businessDate}', style: Theme.of(context).textTheme.titleLarge),
          Text(
              'اتقفل ${arabicDateTime(d.closedAt)}${d.updatedAt == null ? '' : ' · اتحدّث ${arabicDateTime(d.updatedAt!)}'}',
              style: AppText.caption),
          const SizedBox(height: AppSpace.x3),
          Text('الشيفتات (${shifts.length})', style: AppText.label),
          for (final s in shifts)
            ListTile(
              dense: true,
              title: Text(s.name),
              subtitle: Text(s.isClosed ? '${_m(s.snapshot?.netCashMovement ?? 0)} صافي حركة الكاش' : 'مفتوح'),
              trailing: Text(s.isClosed ? 'مقفول' : 'مفتوح'),
              onTap: () => _shiftDetail(s),
            ),
          const Divider(),
          Text('إجمالي اليوم (مجموع لقطات الشيفتات)', style: AppText.label),
          const SizedBox(height: AppSpace.x2),
          TotalsView(totals: d.totals),
          if (hasOutside) ...[
            const SizedBox(height: AppSpace.x3),
            AppCard(
              backgroundColor: AppColors.warning.withValues(alpha: 0.12),
              child: Text(
                'حركات وقعت خارج أي شيفت في اليوم ده (مش داخلة في الإجمالي فوق): '
                'داخل ${_m(out.cashIn)} · خارج ${_m(out.cashOut)} · بيع آجل ${_m(out.creditSales)} · توريد بالأجل ${_m(out.supplierPurchases)}.',
                style: AppText.caption,
              ),
            ),
          ],
        ]),
      ),
    );
  }

  // ───────────────────────── نماذج ─────────────────────────

  Future<void> _startShift() => showFormSheet<void>(context, _StartForm(startHour: _startHour));

  Future<void> _closeShift(Shift s) =>
      showFormSheet<void>(context, _CloseForm(shift: s, live: _live(s)));

  Future<void> _addEntry(Shift s, String kind) =>
      showFormSheet<void>(context, _EntryForm(shift: s, kind: kind));

  Future<void> _editCashSales(Shift s) =>
      showFormSheet<void>(context, _CashSalesForm(shift: s));

  // ───────────────────────── بناء ─────────────────────────

  Widget _openCard(Shift s) {
    final t = _live(s);
    return AppCard(
      elevated: true,
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Text('شيفت مفتوح: ${s.name}', style: AppText.titleMedium),
        Text('بدأ ${arabicDateTime(s.openedAt)} · اليوم التشغيلي ${s.businessDate}', style: AppText.caption),
        const SizedBox(height: AppSpace.x3),
        TotalsView(totals: t, shift: s),
        const SizedBox(height: AppSpace.x3),
        Wrap(spacing: AppSpace.x2, runSpacing: AppSpace.x2, children: [
          OutlinedButton(onPressed: () => _editCashSales(s), child: const Text('مبيعات الكاش')),
          OutlinedButton(onPressed: () => _addEntry(s, 'income'), child: const Text('+ دخل نقدي آخر')),
          OutlinedButton(onPressed: () => _addEntry(s, 'expense'), child: const Text('− مصروف نقدي')),
        ]),
        const SizedBox(height: AppSpace.x3),
        FilledButton.icon(
          onPressed: () => _closeShift(s),
          icon: const Icon(Icons.lock_outline),
          label: const Text('إقفال الشيفت'),
        ),
      ]),
    );
  }

  Widget _dayCard(String date, List<Shift> all, List<DailyClosing> dailies) {
    final shifts = ClosingService.shiftsOfDay(all, date);
    final daily = dailies.where((d) => d.businessDate == date).toList();
    final d = daily.isEmpty ? null : daily.first;
    final anyOpen = shifts.any((s) => !s.isClosed);
    final stale = d != null && ClosingService.isDailyStale(d, all);
    final status = d == null
        ? (anyOpen ? 'فيه شيفت مفتوح' : 'شيفتات مقفولة — لسه ما اتجمّعش')
        : (stale ? 'الإقفال اليومي قديم (اتغيّرت الشيفتات)' : 'تم الإقفال اليومي');
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpace.x3),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('يوم $date', style: AppText.titleMedium),
          Text(status,
              style: AppText.caption.copyWith(color: stale || anyOpen ? AppColors.warning : AppColors.success)),
          const SizedBox(height: AppSpace.x2),
          for (final s in shifts)
            ListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              leading: Icon(s.isClosed ? Icons.lock_outline : Icons.lock_open, size: 18),
              title: Text(s.name),
              subtitle: Text(s.isClosed
                  ? 'صافي حركة الكاش ${_m(s.snapshot?.netCashMovement ?? 0)}${s.variance(s.snapshot ?? const ShiftTotals()) == null ? '' : ' · الفرق ${_m(s.variance(s.snapshot ?? const ShiftTotals())!)}'}'
                  : 'مفتوح'),
              trailing: s.isClosed &&
                      ClosingService.driftOf(s,
                              now: DateTime.now(), employees: _emps, suppliers: _sups, customers: _custs) !=
                          null
                  ? const Icon(Icons.warning_amber, color: AppColors.warning, size: 18)
                  : null,
              onTap: () => _shiftDetail(s),
            ),
          Wrap(spacing: AppSpace.x2, children: [
            if (d != null) OutlinedButton(onPressed: () => _dailyDetail(d), child: const Text('عرض الإقفال اليومي')),
            if (!anyOpen && shifts.isNotEmpty && (d == null || stale))
              FilledButton(
                onPressed: () => _consolidate(date, d),
                child: Text(d == null ? 'إقفال اليوم (اختياري)' : 'تحديث الإقفال اليومي'),
              ),
          ]),
        ]),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: AppState.instance,
      builder: (context, _) {
        final shifts = StorageService.shifts();
        final dailies = StorageService.dailyClosings();
        final open = ClosingService.openShiftOf(shifts);
        final dates = shifts.map((s) => s.businessDate).toSet().toList()..sort((a, b) => b.compareTo(a));
        return Scaffold(
          appBar: AppBar(title: const Text('إقفال الشيفت')),
          body: ListView(
            padding: const EdgeInsets.all(AppSpace.x4),
            children: [
              Text(
                'كل شيفت بيتقفل لوحده. «إقفال اليوم» اختياري وبيجمّع شيفتات نفس اليوم من غير ما يلغيها. '
                'الأرقام دي حركة كاش مسجّلة وأرصدة — مش صافي ربح.',
                style: AppText.caption,
              ),
              const SizedBox(height: AppSpace.x3),
              if (open != null)
                _openCard(open)
              else
                AppCard(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                    const Text('مفيش شيفت مفتوح'),
                    const SizedBox(height: AppSpace.x2),
                    FilledButton.icon(
                      onPressed: _startShift,
                      icon: const Icon(Icons.play_arrow),
                      label: const Text('ابدأ شيفت'),
                    ),
                  ]),
                ),
              const SizedBox(height: AppSpace.x4),
              AppSectionHeader(title: 'الأيام والشيفتات'),
              if (dates.isEmpty)
                const AppEmptyState(
                    icon: Icons.point_of_sale, title: 'لسه ما فيش شيفتات', subtitle: 'ابدأ أول شيفت من فوق.')
              else
                for (final d in dates.take(30)) _dayCard(d, shifts, dailies),
              const SizedBox(height: AppSpace.x4),
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('بداية اليوم التشغيلي'),
                subtitle: const Text('الحركات قبل الساعة دي بتتبع اليوم اللي فات (للشيفتات اللي بتعدّي نص الليل)'),
                trailing: DropdownButton<int>(
                  value: _startHour,
                  items: [for (final h in [0, 3, 4, 5, 6, 7]) DropdownMenuItem(value: h, child: Text('$h:00'))],
                  onChanged: open != null ? null : (v) => _setDayStart(v ?? 5),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// عرض أرقام فترة: حركة الكاش (داخل/خارج) منفصلة عن الأرصدة (مش كاش).
class TotalsView extends StatelessWidget {
  final ShiftTotals totals;
  final Shift? shift;
  const TotalsView({super.key, required this.totals, this.shift});

  Widget _line(String label, double v, {bool bold = false, Color? color}) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Row(children: [
          Expanded(child: Text(label, style: bold ? AppText.label : AppText.body.copyWith(fontSize: 14))),
          Text(_m(v),
              style: (bold ? AppText.label : AppText.body.copyWith(fontSize: 14))
                  .copyWith(color: color, fontWeight: bold ? FontWeight.w700 : null)),
        ]),
      );

  @override
  Widget build(BuildContext context) {
    final t = totals;
    final s = shift;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Text('كاش داخل', style: AppText.caption),
      _line('مبيعات كاش', t.cashSales),
      _line('دخل نقدي آخر', t.otherIncome),
      _line('تحصيل ديون عملاء قدامى', t.collections),
      _line('إجمالي الداخل', t.cashIn, bold: true, color: AppColors.success),
      const SizedBox(height: AppSpace.x2),
      Text('كاش خارج', style: AppText.caption),
      _line('سداد موردين', t.supplierPayments),
      _line('سلف عاملين', t.advances),
      _line('مرتبات مدفوعة', t.salaries),
      _line('مصروفات تشغيل', t.expenses),
      _line('إجمالي الخارج', t.cashOut, bold: true, color: AppColors.danger),
      const Divider(),
      _line('صافي حركة الكاش المسجّلة', t.netCashMovement, bold: true),
      if (s != null) ...[
        _line('كاش افتتاحي', s.openingCash),
        _line('المتوقع في الدرج', s.expectedCash(t), bold: true),
        if (s.countedCash != null) _line('المعدود فعليًا', s.countedCash!),
        if (s.variance(t) != null)
          _line('الفرق (المعدود − المتوقع)', s.variance(t)!,
              bold: true, color: s.variance(t)!.abs() < 0.005 ? AppColors.success : AppColors.warning),
      ],
      const Divider(),
      Text('أرصدة (مش كاش)', style: AppText.caption),
      _line('بيع آجل للعملاء (زوّد المستحقات)', t.creditSales),
      _line('توريد بالأجل (زوّد المستحق للموردين)', t.supplierPurchases),
    ]);
  }
}

class _StartForm extends StatefulWidget {
  final int startHour;
  const _StartForm({required this.startHour});
  @override
  State<_StartForm> createState() => _StartFormState();
}

class _StartFormState extends State<_StartForm> {
  final _name = TextEditingController(text: 'صباحي');
  late final TextEditingController _cash;
  final String _id = const Uuid().v4();
  String? _error;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final s = ClosingService.suggestedOpeningCash(StorageService.shifts());
    _cash = TextEditingController(text: s == 0 ? '' : s.toStringAsFixed(s == s.roundToDouble() ? 0 : 2));
  }

  @override
  void dispose() {
    _name.dispose();
    _cash.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_saving) return;
    final cash = _cash.text.trim().isEmpty ? 0.0 : parseMoney(_cash.text);
    if (cash == null || cash < 0) {
      setState(() => _error = 'اكتب الكاش الافتتاحي أرقام فقط (أو سيبه فاضي = صفر).');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final s = ClosingService.startShift(StorageService.shifts(),
          id: _id, name: _name.text, openingCash: cash, now: DateTime.now(), startHour: widget.startHour);
      await StorageService.saveShift(s);
      if (mounted) Navigator.pop(context);
    } on ClosingException catch (e) {
      setState(() {
        _error = e.message;
        _saving = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) => FormSheet(
        title: 'ابدأ شيفت',
        error: _error,
        saving: _saving,
        onSave: _save,
        saveLabel: 'ابدأ',
        children: [
          Wrap(spacing: AppSpace.x2, children: [
            for (final n in ['صباحي', 'مسائي', 'ليلي'])
              ActionChip(label: Text(n), onPressed: () => setState(() => _name.text = n)),
          ]),
          TextField(controller: _name, decoration: const InputDecoration(labelText: 'اسم الشيفت')),
          TextField(
              controller: _cash,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'الكاش الافتتاحي في الدرج (جنيه)')),
        ],
      );
}

class _CloseForm extends StatefulWidget {
  final Shift shift;
  final ShiftTotals live;
  const _CloseForm({required this.shift, required this.live});
  @override
  State<_CloseForm> createState() => _CloseFormState();
}

class _CloseFormState extends State<_CloseForm> {
  final _counted = TextEditingController();
  final _note = TextEditingController();
  String? _error;
  bool _saving = false;

  @override
  void dispose() {
    _counted.dispose();
    _note.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_saving) return;
    double? counted;
    if (_counted.text.trim().isNotEmpty) {
      counted = parseMoney(_counted.text);
      if (counted == null || counted < 0) {
        setState(() => _error = 'الكاش المعدود أرقام فقط.');
        return;
      }
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final s = StorageService.shifts().firstWhere((x) => x.id == widget.shift.id);
      ClosingService.closeShift(s,
          now: DateTime.now(),
          countedCash: counted,
          note: _note.text,
          employees: StorageService.employees(),
          suppliers: StorageService.suppliers(),
          customers: StorageService.customers());
      await StorageService.saveShift(s);
      if (mounted) Navigator.pop(context);
    } on ClosingException catch (e) {
      setState(() {
        _error = e.message;
        _saving = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final expected = widget.shift.expectedCash(widget.live);
    return FormSheet(
      title: 'إقفال الشيفت',
      error: _error,
      saving: _saving,
      onSave: _save,
      saveLabel: 'اقفل الشيفت',
      children: [
        Text('الكاش المتوقع في الدرج: ${_m(expected)}'),
        TextField(
            controller: _counted,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(labelText: 'الكاش المعدود فعليًا (اختياري)')),
        TextField(controller: _note, decoration: const InputDecoration(labelText: 'ملاحظة التسليم (اختياري)')),
        const Text('بعد الإقفال أرقام الشيفت بتتثبّت (لقطة). أي تعديل بعد كده بيظهر كتنبيه.',
            style: TextStyle(fontSize: 12)),
      ],
    );
  }
}

class _EntryForm extends StatefulWidget {
  final Shift shift;
  final String kind;
  const _EntryForm({required this.shift, required this.kind});
  @override
  State<_EntryForm> createState() => _EntryFormState();
}

class _EntryFormState extends State<_EntryForm> {
  final _amount = TextEditingController();
  final _note = TextEditingController();
  final String _id = const Uuid().v4();
  String? _error;
  bool _saving = false;

  @override
  void dispose() {
    _amount.dispose();
    _note.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_saving) return;
    final v = parseMoney(_amount.text);
    if (v == null || v <= 0) {
      setState(() => _error = 'اكتب المبلغ أرقام فقط وأكبر من صفر.');
      return;
    }
    setState(() => _saving = true);
    final s = StorageService.shifts().firstWhere((x) => x.id == widget.shift.id);
    if (s.isClosed) {
      setState(() {
        _error = 'الشيفت اتقفل.';
        _saving = false;
      });
      return;
    }
    if (!s.entries.any((e) => e.id == _id)) {
      s.entries.add(CashEntry(
          id: _id, kind: widget.kind, amount: v, note: _note.text.trim(), date: DateTime.now()));
      await StorageService.saveShift(s);
    }
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) => FormSheet(
        title: widget.kind == 'income' ? 'دخل نقدي آخر' : 'مصروف نقدي (تشغيل)',
        error: _error,
        saving: _saving,
        onSave: _save,
        children: [
          TextField(
              controller: _amount,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'المبلغ (جنيه)')),
          TextField(controller: _note, decoration: const InputDecoration(labelText: 'بيان (مثلًا: ثلج)')),
        ],
      );
}

class _CashSalesForm extends StatefulWidget {
  final Shift shift;
  const _CashSalesForm({required this.shift});
  @override
  State<_CashSalesForm> createState() => _CashSalesFormState();
}

class _CashSalesFormState extends State<_CashSalesForm> {
  late final TextEditingController _v;
  String? _error;

  @override
  void initState() {
    super.initState();
    final c = widget.shift.cashSales;
    _v = TextEditingController(text: c == 0 ? '' : c.toStringAsFixed(c == c.roundToDouble() ? 0 : 2));
  }

  @override
  void dispose() {
    _v.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final v = _v.text.trim().isEmpty ? 0.0 : parseMoney(_v.text);
    if (v == null || v < 0) {
      setState(() => _error = 'اكتب المبلغ أرقام فقط.');
      return;
    }
    final s = StorageService.shifts().firstWhere((x) => x.id == widget.shift.id);
    if (s.isClosed) {
      setState(() => _error = 'الشيفت اتقفل.');
      return;
    }
    s.cashSales = v;
    await StorageService.saveShift(s);
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) => FormSheet(
        title: 'مبيعات الكاش للشيفت',
        error: _error,
        onSave: _save,
        children: [
          const Text('إجمالي اللي اتباع كاش في الشيفت ده (مفيش كاشير في التطبيق، فبتدخله إنت). بيتحدّث لحد الإقفال.',
              style: TextStyle(fontSize: 12)),
          TextField(
              controller: _v,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'إجمالي مبيعات الكاش (جنيه)')),
        ],
      );
}
