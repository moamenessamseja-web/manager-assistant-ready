import 'package:flutter/material.dart';
import '../models/supplier.dart';
import '../services/app_state.dart';
import '../design/tokens.dart';
import '../design/app_theme.dart';
import '../design/widgets.dart';
import '../design/format.dart';

enum SupplierReportKind { purchases, payments, balance }

/// تقرير تفصيلي حقيقي لأحد أرقام المورد:
/// المشتريات (قيمة البضاعة) / المدفوعات (النقد) / المستحقات (توزيع لكل توريد).
/// كل سطر قابل للفتح، وفيه تاريخ ووقت.
class SupplierReportScreen extends StatefulWidget {
  final Supplier supplier;
  final SupplierReportKind kind;
  const SupplierReportScreen({super.key, required this.supplier, required this.kind});

  @override
  State<SupplierReportScreen> createState() => _SupplierReportScreenState();
}

class _SupplierReportScreenState extends State<SupplierReportScreen> {
  int _period = 0; // 0=الكل 1=7 أيام 2=هذا الشهر 3=آخر 3 شهور
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
    final s = widget.supplier;
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: Text('$_title — ${s.name}')),
      body: ListenableBuilder(
        listenable: AppState.instance,
        builder: (context, _) {
          final body = switch (widget.kind) {
            SupplierReportKind.purchases => _purchases(s),
            SupplierReportKind.payments => _payments(s),
            SupplierReportKind.balance => _balance(s),
          };
          return ListView(
            padding: const EdgeInsets.all(AppSpace.x4),
            children: body,
          );
        },
      ),
    );
  }

  // ── المشتريات (قيمة البضاعة) ───────────────────────────────
  List<Widget> _purchases(Supplier s) {
    final rows = s.purchases.where((p) => _inPeriod(p.date)).toList()
      ..sort((a, b) => b.date.compareTo(a.date));
    final total = rows.fold<double>(0, (t, p) => t + p.total);
    return [
      _header('${rows.length} توريد', money(total), AppColors.info),
      _periodChips(),
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
                      child: Text(
                        p.item.isEmpty ? 'توريد' : p.item,
                        style: AppText.label.copyWith(fontWeight: FontWeight.w700),
                      ),
                    ),
                    Text(money(p.total),
                        style: AppText.label.copyWith(fontWeight: FontWeight.w700, color: AppColors.info)),
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

  // ── المدفوعات (النقد) ───────────────────────────────────────
  List<Widget> _payments(Supplier s) {
    final rows = s.payments.where((p) => _inPeriod(p.date)).toList()
      ..sort((a, b) => b.date.compareTo(a.date));
    final total = rows.fold<double>(0, (t, p) => t + p.amount);
    return [
      _header('${rows.length} دفعة', money(total), AppColors.success),
      _periodChips(),
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
                        style: AppText.label.copyWith(fontWeight: FontWeight.w700, color: AppColors.success)),
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

  // ── المستحقات: توزيع الدفعات على كل توريد ───────────────────
  List<Widget> _balance(Supplier s) {
    var rows = s.allocatePayments();
    if (_settle == 1) rows = rows.where((r) => !r.isSettled).toList();
    final totalRemaining = rows.fold<double>(0, (t, r) => t + r.remaining);
    return [
      _header('${rows.length} بند', money(totalRemaining), AppColors.accent),
      Padding(
        padding: const EdgeInsets.only(bottom: AppSpace.x2),
        child: AppSegmented(
          labels: const ['الكل', 'غير مسدّد'],
          selectedIndex: _settle,
          onSelected: (i) => setState(() => _settle = i),
        ),
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
                      r.isLegacy ? 'رصيد قديم (بدون تفاصيل)' : (r.purchase!.item.isEmpty ? 'توريد' : r.purchase!.item),
                      style: AppText.label.copyWith(fontWeight: FontWeight.w700),
                    ),
                  ),
                  if (r.isSettled)
                    const AppBadge(kind: BadgeKind.success, label: 'مسدَّد', compact: true)
                  else
                    Text(money(r.remaining),
                        style: AppText.label.copyWith(fontWeight: FontWeight.w700, color: AppColors.accent)),
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

  Widget _periodChips() => Padding(
        padding: const EdgeInsets.only(bottom: AppSpace.x2),
        child: AppFilterChips(
          labels: _periods,
          selectedIndex: _period,
          onSelected: (i) => setState(() => _period = i),
          padding: EdgeInsets.zero,
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

  Widget _meta(IconData icon, String text) => Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 12, color: AppColors.textSecondary),
        const SizedBox(width: 4),
        Text(text, style: AppText.caption),
      ]);
}
