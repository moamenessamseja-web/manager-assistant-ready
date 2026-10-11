import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../models/supplier.dart';
import '../services/storage_service.dart';
import '../services/app_state.dart';
import '../design/tokens.dart';
import '../design/app_theme.dart';
import '../design/widgets.dart';
import '../design/format.dart';

/// مساران منفصلان بوضوح (To Accio §2):
///  • تسجيل توريد بقيمة (بضاعة مستلمة) → يزوّد "إجمالي البضاعة".
///  • تسجيل دفعة (نقد مدفوع) → يزوّد "إجمالي المدفوع".
/// خلط الاثنين كان أصل الخلل، فالفصل هنا هو الإصلاح.

/// تسجيل توريد بقيمة. يرجع true لو اتسجل فعلاً.
Future<bool> showAddPurchaseSheet(BuildContext context, Supplier s) async {
  final item = TextEditingController(text: s.itemType);
  final qty = TextEditingController();
  final unit = TextEditingController();
  final unitPrice = TextEditingController();
  final total = TextEditingController();
  final note = TextEditingController();

  final res = await showAppBottomSheet<bool>(
    context: context,
    title: 'تسجيل توريد بقيمة',
    body: StatefulBuilder(
      builder: (ctx, setSheet) => SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpace.x4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              padding: const EdgeInsets.all(AppSpace.x3),
              decoration: BoxDecoration(
                color: AppColors.infoTint,
                borderRadius: BorderRadius.circular(AppRadius.md),
              ),
              child: Row(children: [
                const Icon(Icons.inventory_2_outlined, size: 18, color: AppColors.info),
                const SizedBox(width: AppSpace.x2),
                Expanded(
                  child: Text(
                    'قيمة البضاعة تُسجَّل كدين على المحل — مش دفعة نقدية.',
                    style: AppText.caption.copyWith(color: AppColors.info),
                  ),
                ),
              ]),
            ),
            const SizedBox(height: AppSpace.x4),
            TextField(
              controller: item,
              decoration: const InputDecoration(labelText: 'الصنف', hintText: 'بن، لبن، حديد…'),
            ),
            const SizedBox(height: AppSpace.x3),
            Row(children: [
              Expanded(
                child: TextField(
                  controller: qty,
                  keyboardType: TextInputType.number,
                  onChanged: (_) => setSheet(() {}),
                  decoration: const InputDecoration(labelText: 'الكمية'),
                ),
              ),
              const SizedBox(width: AppSpace.x3),
              Expanded(
                child: TextField(
                  controller: unit,
                  decoration: const InputDecoration(labelText: 'الوحدة', hintText: 'كيلو، كرتونة'),
                ),
              ),
            ]),
            const SizedBox(height: AppSpace.x3),
            TextField(
              controller: unitPrice,
              keyboardType: TextInputType.number,
              onChanged: (_) => setSheet(() {}),
              decoration: const InputDecoration(labelText: 'سعر الوحدة (ج)', hintText: 'اختياري'),
            ),
            const SizedBox(height: AppSpace.x3),
            TextField(
              controller: total,
              keyboardType: TextInputType.number,
              onChanged: (_) => setSheet(() {}),
              decoration: const InputDecoration(
                labelText: 'الإجمالي (ج)',
                hintText: 'اتركه فاضي لو محسوب من الكمية × السعر',
              ),
            ),
            const SizedBox(height: AppSpace.x2),
            Text(
              _preview(qty.text, unitPrice.text, total.text),
              style: AppText.caption.copyWith(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: AppSpace.x3),
            TextField(
              controller: note,
              maxLines: 2,
              decoration: const InputDecoration(labelText: 'ملاحظات (اختياري)'),
            ),
            const SizedBox(height: AppSpace.x6),
            FilledButton(
              onPressed: () async {
                final t = _resolveTotal(qty.text, unitPrice.text, total.text);
                if (t <= 0) {
                  _snack(context, 'محتاج قيمة التوريد أو الكمية وسعر الوحدة');
                  return;
                }
                final q = double.tryParse(qty.text.trim());
                final up = double.tryParse(unitPrice.text.trim()) ?? 0;
                s.purchases.add(SupplierPurchase(
                  id: const Uuid().v4(),
                  item: item.text.trim().isEmpty ? s.itemType : item.text.trim(),
                  quantity: q,
                  unit: unit.text.trim(),
                  unitPrice: up > 0 ? up : (q != null && q > 0 ? t / q : 0),
                  total: t,
                  date: DateTime.now(),
                  note: note.text.trim(),
                ));
                await StorageService.saveSupplier(s);
                if (context.mounted) Navigator.pop(context, true);
              },
              child: const Text('تسجيل التوريد'),
            ),
          ],
        ),
      ),
    ),
  );
  return res ?? false;
}

/// تسجيل دفعة نقدية فعلية.
Future<bool> showAddPaymentSheet(BuildContext context, Supplier s) async {
  final amount = TextEditingController();
  final note = TextEditingController();
  var method = 'كاش';

  final res = await showAppBottomSheet<bool>(
    context: context,
    title: 'تسجيل دفعة',
    body: StatefulBuilder(
      builder: (ctx, setSheet) => SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpace.x4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              padding: const EdgeInsets.all(AppSpace.x3),
              decoration: BoxDecoration(
                color: AppColors.accentTint,
                borderRadius: BorderRadius.circular(AppRadius.md),
              ),
              child: Row(children: [
                const Icon(Icons.info_outline, size: 18, color: AppColors.accentStrong),
                const SizedBox(width: AppSpace.x2),
                Expanded(
                  child: Text(
                    'المتبقي الحالي للمورد: ${money(s.balanceDue)}',
                    style: AppText.caption.copyWith(color: AppColors.accentStrong),
                  ),
                ),
              ]),
            ),
            const SizedBox(height: AppSpace.x4),
            TextField(
              controller: amount,
              autofocus: true,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'المبلغ المدفوع (ج)', hintText: '500'),
            ),
            const SizedBox(height: AppSpace.x3),
            Wrap(
              spacing: AppSpace.x2,
              children: [
                for (final m in ['كاش', 'تحويل', 'شيك'])
                  ChoiceChip(
                    label: Text(m),
                    selected: method == m,
                    onSelected: (_) => setSheet(() => method = m),
                  ),
              ],
            ),
            const SizedBox(height: AppSpace.x3),
            TextField(
              controller: note,
              maxLines: 2,
              decoration: const InputDecoration(labelText: 'ملاحظات (اختياري)'),
            ),
            const SizedBox(height: AppSpace.x6),
            FilledButton(
              onPressed: () async {
                final amt = double.tryParse(amount.text.trim()) ?? 0;
                if (amt <= 0) {
                  _snack(context, 'أدخل مبلغًا صحيحًا');
                  return;
                }
                s.payments.add(SupplierPayment(
                  id: const Uuid().v4(),
                  amount: amt,
                  date: DateTime.now(),
                  note: note.text.trim(),
                  method: method,
                ));
                await StorageService.saveSupplier(s);
                if (context.mounted) Navigator.pop(context, true);
              },
              child: const Text('تسجيل الدفعة'),
            ),
          ],
        ),
      ),
    ),
  );
  return res ?? false;
}

/// أرشفة / إلغاء أرشفة — العملية الافتراضية للمورد اللي عنده تاريخ.
Future<void> archiveSupplier(BuildContext context, Supplier s) async {
  final next = !s.archived;
  if (next) {
    final ok = await _confirm(context,
        title: 'أرشفة المورد؟',
        message: 'هيتخفى من القوائم النشطة، وكل السجلات المالية تفضل محفوظة.',
        confirmLabel: 'أرشفة');
    if (ok != true) return;
  }
  s.archived = next;
  await StorageService.saveSupplier(s);
  if (context.mounted) {
    _snack(context, next ? 'تم أرشفة ${s.name}' : 'تم إلغاء أرشفة ${s.name}');
  }
}

/// حذف نهائي — مسموح فقط لمورد بلا أي سجل تاريخي (To Accio §2/§4).
Future<bool> deleteSupplierSafely(BuildContext context, Supplier s) async {
  if (s.hasHistory) {
    await _info(context,
        title: 'لا يمكن الحذف النهائي',
        message: 'المورد ${s.name} عنده سجلات مالية/تاريخية. استخدم الأرشفة للحفاظ على التاريخ.');
    return false;
  }
  final ok = await _confirm(context,
      title: 'حذف المورد نهائيًا؟',
      message: 'لا يوجد سجلات مرتبطة، فالحذف آمن — لكن لا يمكن التراجع.',
      confirmLabel: 'حذف',
      destructive: true);
  if (ok != true) return false;
  await StorageService.deleteSupplier(s.id);
  if (context.mounted) _snack(context, 'تم حذف ${s.name}');
  return true;
}

// ───────────────────────── التقارير التفصيلية ─────────────────────────

enum SupplierReportKind { purchases, payments, balance }

/// تقرير تفصيلي حقيقي لأحد أرقام المورد، مع فلاتر، وكل سطر بتاريخه.
class SupplierReportScreen extends StatefulWidget {
  final Supplier supplier;
  final SupplierReportKind kind;
  const SupplierReportScreen({super.key, required this.supplier, required this.kind});

  @override
  State<SupplierReportScreen> createState() => _SupplierReportScreenState();
}

class _SupplierReportScreenState extends State<SupplierReportScreen> {
  int _period = 0; // 0=الكل 1=آخر 7 أيام 2=هذا الشهر 3=آخر 3 شهور
  int _settle = 0; // 0=الكل 1=غير مسدّد (للمستحقات فقط)

  static const _periods = ['الكل', 'آخر 7 أيام', 'هذا الشهر', 'آخر 3 شهور'];

  String get _title => switch (widget.kind) {
        SupplierReportKind.purchases => 'إجمالي البضاعة',
        SupplierReportKind.payments => 'إجمالي المدفوع',
        SupplierReportKind.balance => 'المستحقات',
      };

  DateTime? get _since {
    final now = DateTime.now();
    return switch (_period) {
      1 => now.subtract(const Duration(days: 7)),
      2 => DateTime(now.year, now.month, 1),
      3 => DateTime(now.year, now.month - 3, 1),
      _ => null,
    };
  }

  bool _inPeriod(DateTime d) {
    final s = _since;
    return s == null || !d.isBefore(s);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: Text('$_title — ${widget.supplier.name}')),
      body: ListenableBuilder(
        listenable: AppState.instance,
        builder: (context, _) {
          final s = StorageService.suppliers()
              .where((x) => x.id == widget.supplier.id)
              .toList();
          final sup = s.isEmpty ? widget.supplier : s.first;
          return ListView(
            padding: const EdgeInsets.all(AppSpace.x4),
            children: switch (widget.kind) {
              SupplierReportKind.purchases => _purchasesTab(sup),
              SupplierReportKind.payments => _paymentsTab(sup),
              SupplierReportKind.balance => _balanceTab(sup),
            },
          );
        },
      ),
    );
  }

  List<Widget> _purchasesTab(Supplier s) {
    final rows = s.purchases.where((p) => _inPeriod(p.date)).toList()
      ..sort((a, b) => b.date.compareTo(a.date));
    final total = rows.fold<double>(0, (t, p) => t + p.total);
    return [
      _header('${rows.length} توريد', money(total), AppColors.info),
      _periodFilter(),
      if (rows.isEmpty)
        const AppEmptyState(
          icon: Icons.inventory_2_outlined,
          title: 'لا توجد توريدات',
          subtitle: 'أول توريد بقيمة سيظهر هنا.',
        )
      else
        for (final p in rows)
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpace.x2),
            child: AppCard(
              padding: const EdgeInsets.all(AppSpace.x3),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    Expanded(
                      child: Text(p.item.isEmpty ? 'توريد' : p.item,
                          style: AppText.label.copyWith(fontWeight: FontWeight.w700)),
                    ),
                    Text(money(p.total),
                        style: AppText.label.copyWith(
                            fontWeight: FontWeight.w700, color: AppColors.info)),
                  ]),
                  const SizedBox(height: 4),
                  Wrap(spacing: AppSpace.x3, runSpacing: 2, children: [
                    if (p.quantityLabel.isNotEmpty) _meta(Icons.scale_outlined, p.quantityLabel),
                    if (p.unitPriceLabel.isNotEmpty) _meta(Icons.sell_outlined, p.unitPriceLabel),
                    _meta(Icons.schedule, arabicDateTime(p.date)),
                  ]),
                  if (p.note.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(p.note, style: AppText.caption),
                    ),
                ],
              ),
            ),
          ),
      const SizedBox(height: AppSpace.x8),
    ];
  }

  List<Widget> _paymentsTab(Supplier s) {
    final rows = s.payments.where((p) => _inPeriod(p.date)).toList()
      ..sort((a, b) => b.date.compareTo(a.date));
    final total = rows.fold<double>(0, (t, p) => t + p.amount);
    return [
      _header('${rows.length} دفعة', money(total), AppColors.success),
      _periodFilter(),
      if (rows.isEmpty)
        const AppEmptyState(
          icon: Icons.payments_outlined,
          title: 'لا توجد دفعات',
          subtitle: 'الدفعات النقدية الفعلية ستظهر هنا.',
        )
      else
        for (final p in rows)
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpace.x2),
            child: AppCard(
              padding: const EdgeInsets.all(AppSpace.x3),
              child: Row(children: [
                const Icon(Icons.payments_outlined, size: AppIconSize.md, color: AppColors.success),
                const SizedBox(width: AppSpace.x3),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(money(p.amount),
                        style: AppText.label.copyWith(
                            fontWeight: FontWeight.w700, color: AppColors.success)),
                    Text(
                      '${arabicDateTime(p.date)}${p.method.isEmpty ? '' : ' · ${p.method}'}',
                      style: AppText.caption,
                    ),
                    if (p.note.isNotEmpty) Text(p.note, style: AppText.caption),
                  ]),
                ),
              ]),
            ),
          ),
      const SizedBox(height: AppSpace.x8),
    ];
  }

  List<Widget> _balanceTab(Supplier s) {
    var rows = s.allocatePayments();
    if (_settle == 1) rows = rows.where((r) => !r.isSettled).toList();
    final totalRemaining = rows.fold<double>(0, (t, r) => t + r.remaining);
    return [
      _header('${rows.length} بند', money(totalRemaining), AppColors.accent),
      Padding(
        padding: const EdgeInsets.only(bottom: AppSpace.x3),
        child: Wrap(spacing: AppSpace.x2, children: [
          for (int i = 0; i < 2; i++)
            ChoiceChip(
              label: Text(i == 0 ? 'الكل' : 'غير مسدّد'),
              selected: _settle == i,
              onSelected: (_) => setState(() => _settle = i),
            ),
        ]),
      ),
      if (rows.isEmpty)
        const AppEmptyState(
          icon: Icons.check_circle_outline,
          title: 'لا توجد مستحقات',
          subtitle: 'كل التوريدات مسدَّدة.',
        )
      else
        for (final r in rows)
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpace.x2),
            child: AppCard(
              padding: const EdgeInsets.all(AppSpace.x3),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Expanded(
                    child: Text(
                      r.isLegacy
                          ? 'رصيد قديم (بدون تفاصيل)'
                          : (r.purchase!.item.isEmpty ? 'توريد' : r.purchase!.item),
                      style: AppText.label.copyWith(fontWeight: FontWeight.w700),
                    ),
                  ),
                  if (r.isSettled)
                    const AppBadge(kind: BadgeKind.success, label: 'مسدَّد', compact: true)
                  else
                    Text(money(r.remaining),
                        style: AppText.label.copyWith(
                            fontWeight: FontWeight.w700, color: AppColors.accent)),
                ]),
                const SizedBox(height: 4),
                Text(
                  'القيمة ${money(r.total)} · مدفوع ${money(r.paid)} · '
                  '${r.isLegacy ? 'تاريخ غير متوفر' : arabicDateTime(r.date)}',
                  style: AppText.caption,
                ),
                if (r.purchase != null && r.purchase!.quantityLabel.isNotEmpty)
                  Text(r.purchase!.quantityLabel, style: AppText.caption),
              ]),
            ),
          ),
      const SizedBox(height: AppSpace.x8),
    ];
  }

  Widget _periodFilter() => Padding(
        padding: const EdgeInsets.only(bottom: AppSpace.x3),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(children: [
            for (int i = 0; i < _periods.length; i++) ...[
              if (i > 0) const SizedBox(width: AppSpace.x2),
              ChoiceChip(
                label: Text(_periods[i]),
                selected: _period == i,
                onSelected: (_) => setState(() => _period = i),
              ),
            ],
          ]),
        ),
      );

  Widget _header(String countLabel, String totalLabel, Color color) => Padding(
        padding: const EdgeInsets.only(bottom: AppSpace.x3),
        child: AppCard(
          padding: const EdgeInsets.all(AppSpace.x4),
          child: Row(children: [
            Expanded(child: Text(countLabel, style: AppText.bodyMuted)),
            Text(totalLabel, style: AppText.h1.copyWith(fontSize: 20, color: color)),
          ]),
        ),
      );

  Widget _meta(IconData icon, String text) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: AppColors.textSecondary),
          const SizedBox(width: 4),
          Text(text, style: AppText.caption),
        ],
      );
}

// ───────────────────────── مساعدات ─────────────────────────

double _resolveTotal(String qty, String unitPrice, String total) {
  final t = double.tryParse(total.trim()) ?? 0;
  if (t > 0) return t;
  final q = double.tryParse(qty.trim());
  final up = double.tryParse(unitPrice.trim()) ?? 0;
  if (q != null && q > 0 && up > 0) return q * up;
  return 0;
}

String _preview(String qty, String unitPrice, String total) {
  final t = _resolveTotal(qty, unitPrice, total);
  return t <= 0 ? 'الإجمالي هيظهر هنا' : 'الإجمالي: ${money(t)}';
}

void _snack(BuildContext context, String message) {
  final m = ScaffoldMessenger.of(context);
  m.hideCurrentSnackBar();
  m.showSnackBar(SnackBar(content: Text(message)));
}

Future<bool?> _confirm(
  BuildContext context, {
  required String title,
  required String message,
  required String confirmLabel,
  bool destructive = false,
}) {
  return showDialog<bool>(
    context: context,
    builder: (_) => AlertDialog(
      title: Text(title),
      content: Text(message),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('إلغاء')),
        TextButton(
          onPressed: () => Navigator.pop(context, true),
          child: Text(confirmLabel,
              style: TextStyle(color: destructive ? AppColors.danger : AppColors.primary)),
        ),
      ],
    ),
  );
}

Future<void> _info(BuildContext context,
    {required String title, required String message}) async {
  await showDialog<void>(
    context: context,
    builder: (_) => AlertDialog(
      title: Text(title),
      content: Text(message),
      actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('تمام'))],
    ),
  );
}
