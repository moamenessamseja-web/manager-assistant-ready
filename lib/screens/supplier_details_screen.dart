import 'package:flutter/material.dart';
import '../models/supplier.dart';
import '../services/storage_service.dart';
import '../design/tokens.dart';
import '../design/app_theme.dart';
import '../design/widgets.dart';
import '../design/format.dart';
import 'supplier_records.dart';

/// تفاصيل المورد — Premium Supplier Detail Screen
class SupplierDetailsScreen extends StatefulWidget {
  final Supplier supplier;
  const SupplierDetailsScreen({super.key, required this.supplier});

  @override
  State<SupplierDetailsScreen> createState() => _SupplierDetailsScreenState();
}

class _SupplierDetailsScreenState extends State<SupplierDetailsScreen> {
  late Supplier s;

  @override
  void initState() {
    super.initState();
    s = widget.supplier;
  }

  bool get _hasHistory =>
      s.deliveries.isNotEmpty || s.payments.isNotEmpty || s.purchases.isNotEmpty;

  /// فتح تقرير تفصيلي حقيقي لأحد أرقام المورد (To Accio §2).
  void _openReport(SupplierReportKind kind) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => SupplierReportScreen(supplier: s, kind: kind)),
    );
  }

  /// تسجيل توريد بقيمة — مسار مستقل عن الدفعات.
  Future<void> _addPurchase() async {
    if (await showAddPurchaseSheet(context, s)) {
      if (mounted) setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: Text(s.name)),
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
                    Container(
                      width: 64,
                      height: 64,
                      decoration: BoxDecoration(
                        color: AppColors.primaryTint,
                        borderRadius: BorderRadius.circular(AppRadius.lg),
                      ),
                      child: const Icon(
                        Icons.local_shipping,
                        size: 32,
                        color: AppColors.primary,
                      ),
                    ),
                    const SizedBox(width: AppSpace.x4),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(s.name, style: AppText.titleMedium),
                          if (s.itemType.isNotEmpty)
                            Text(s.itemType, style: AppText.bodyMuted),
                          if (s.phone.isNotEmpty) ...[
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                const Icon(Icons.phone_outlined,
                                    size: 12, color: AppColors.textSecondary),
                                const SizedBox(width: 4),
                                Text(s.phone, style: AppText.caption),
                              ],
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
                if (s.archived) ...[
                  const SizedBox(height: AppSpace.x3),
                  AppBadge(label: 'مؤرشف', kind: BadgeKind.neutral),
                ],
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
                const SizedBox(height: AppSpace.x4),
                Row(
                  children: [
                    Expanded(
                       child: _FinanceTile(
                         label: 'إجمالي البضاعة',
                         value: money(s.goodsTotal),
                         icon: Icons.inventory_2_outlined,
                         color: AppColors.info,
                         onTap: () => _openReport(SupplierReportKind.purchases),
                       ),
                     ),
                     const SizedBox(width: AppSpace.x3),
                     Expanded(
                       child: _FinanceTile(
                         label: 'إجمالي المدفوع',
                         value: money(s.totalPaid),
                         icon: Icons.payments_outlined,
                         color: AppColors.success,
                         onTap: () => _openReport(SupplierReportKind.payments),
                       ),
                     ),
                  ],
                ),
                const SizedBox(height: AppSpace.x3),
                // Balance due highlight
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(AppSpace.x4),
                  decoration: BoxDecoration(
                    color: s.balanceDue > 0
                        ? AppColors.accentTint
                        : AppColors.successTint,
                    borderRadius: BorderRadius.circular(AppRadius.md),
                    border: Border.all(
                      color: s.balanceDue > 0
                          ? AppColors.accent.withValues(alpha: 0.3)
                          : AppColors.success.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        s.balanceDue > 0
                            ? Icons.account_balance_wallet_outlined
                            : Icons.check_circle_outline,
                        color: s.balanceDue > 0 ? AppColors.accent : AppColors.success,
                      ),
                      const SizedBox(width: AppSpace.x3),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              s.balanceDue > 0 ? 'المستحق عليك الآن' : 'لا يوجد مستحقات',
                              style: AppText.caption,
                            ),
                            Text(
                              '${s.balanceDue.toStringAsFixed(0)} ج',
                              style: AppText.titleMedium.copyWith(
                                fontSize: 20,
                                fontWeight: FontWeight.w700,
                                color: s.balanceDue > 0
                                    ? AppColors.accent
                                    : AppColors.success,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
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
                  icon: Icons.local_shipping_outlined,
                  label: 'توريد متوقع',
                  color: AppColors.info,
                  onTap: _addDelivery,
                ),
              ),
              const SizedBox(width: AppSpace.x3),
              Expanded(
                child: _ActionButton(
                  icon: Icons.payments_outlined,
                  label: 'تسجيل دفعة',
                  color: AppColors.success,
                  onTap: s.balanceDue > 0 ? _addPayment : null,
                ),
              ),
              const SizedBox(width: AppSpace.x3),
              Expanded(
                child: _ActionButton(
                  icon: Icons.edit_outlined,
                   label: 'تعديل',
                   color: AppColors.primary,
                   onTap: _editDialog,
                 ),
               ),
             ],
           ),

           const SizedBox(height: AppSpace.x3),

           // ── مسار التوريد بقيمة (منفصل عن الدفعات) + تقرير المستحقات ──
           Row(
             children: [
               Expanded(
                 child: FilledButton.icon(
                   onPressed: _addPurchase,
                   icon: const Icon(Icons.inventory_2_outlined, size: AppIconSize.md),
                   label: const Text('تسجيل توريد بقيمة'),
                 ),
               ),
               const SizedBox(width: AppSpace.x3),
               Expanded(
                 child: OutlinedButton.icon(
                   onPressed: () => _openReport(SupplierReportKind.balance),
                   icon: const Icon(Icons.account_balance_wallet_outlined, size: AppIconSize.md),
                   label: const Text('تقرير المستحقات'),
                 ),
               ),
             ],
           ),

           const SizedBox(height: AppSpace.x4),

          // ── Deliveries ───────────────────────────────────────
          AppSectionHeader(
            title: 'التوريدات',
            trailing: Text(
              '${s.deliveries.length} توريد',
              style: AppText.caption,
            ),
          ),
          const SizedBox(height: AppSpace.x2),
          if (s.deliveries.isEmpty)
            AppCard(
              padding: const EdgeInsets.all(AppSpace.x6),
              child: Column(
                children: [
                  const Icon(Icons.local_shipping_outlined,
                      size: 32, color: AppColors.textDisabled),
                  const SizedBox(height: AppSpace.x2),
                  Text('لا توجد توريدات', style: AppText.bodyMuted),
                ],
              ),
            )
          else
            AppCard(
              padding: const EdgeInsets.symmetric(vertical: AppSpace.x2),
              child: Column(
                children: [
                  for (var i = 0; i < s.deliveries.length; i++)
                    _DeliveryRow(
                      delivery: s.deliveries[i],
                      onMarkReceived: () async {
                        s.deliveries[i].received = true;
                        s.deliveries[i].receivedDate = DateTime.now();
                        await StorageService.saveSupplier(s);
                        setState(() {});
                      },
                      onDelete: () async {
                        s.deliveries.removeAt(i);
                        await StorageService.saveSupplier(s);
                        setState(() {});
                      },
                      isLast: i == s.deliveries.length - 1,
                    ),
                ],
              ),
            ),

          const SizedBox(height: AppSpace.x4),

          // ── Payments ─────────────────────────────────────────
          AppSectionHeader(
            title: 'سجل الدفعات',
            trailing: Text(
              '${s.payments.length} دفعة',
              style: AppText.caption,
            ),
          ),
          const SizedBox(height: AppSpace.x2),
          if (s.payments.isEmpty)
            AppCard(
              padding: const EdgeInsets.all(AppSpace.x6),
              child: Column(
                children: [
                  const Icon(Icons.payments_outlined,
                      size: 32, color: AppColors.textDisabled),
                  const SizedBox(height: AppSpace.x2),
                  Text('لا توجد دفعات', style: AppText.bodyMuted),
                ],
              ),
            )
          else
            AppCard(
              padding: const EdgeInsets.symmetric(vertical: AppSpace.x2),
              child: Column(
                children: [
                  for (var i = 0; i < s.payments.length; i++)
                    _PaymentRow(
                      payment: s.payments[i],
                      onDelete: () async {
                        s.payments.removeAt(i);
                        await StorageService.saveSupplier(s);
                        setState(() {});
                      },
                      isLast: i == s.payments.length - 1,
                    ),
                ],
              ),
            ),

          const SizedBox(height: AppSpace.x16),
        ],
      ),
    );
  }

  void _addDelivery() {
    final item = TextEditingController(text: s.itemType);
    final qty = TextEditingController();
    final unit = TextEditingController();
    DateTime expected = DateTime.now().add(const Duration(days: 1));

    showAppBottomSheet(
      context: context,
      title: 'توريد متوقع جديد',
      body: StatefulBuilder(
        builder: (ctx, setD) => Padding(
          padding: const EdgeInsets.all(AppSpace.x4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextField(
                controller: item,
                decoration: const InputDecoration(labelText: 'الصنف'),
              ),
              const SizedBox(height: AppSpace.x3),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: qty,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: 'الكمية'),
                    ),
                  ),
                  const SizedBox(width: AppSpace.x3),
                  Expanded(
                    child: TextField(
                      controller: unit,
                      decoration: const InputDecoration(
                        labelText: 'الوحدة',
                        hintText: 'مثال: كيلو، كرتونة',
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpace.x3),
              Container(
                padding: const EdgeInsets.all(AppSpace.x3),
                decoration: BoxDecoration(
                  color: AppColors.surfaceMuted,
                  borderRadius: BorderRadius.circular(AppRadius.md),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.calendar_today_outlined, size: 16),
                    const SizedBox(width: AppSpace.x2),
                    Expanded(
                      child: Text(
                        'متوقع: ${expected.toString().substring(0, 10)}',
                        style: AppText.body,
                      ),
                    ),
                    TextButton(
                      onPressed: () async {
                        final picked = await showDatePicker(
                          context: ctx,
                          initialDate: expected,
                          firstDate: DateTime.now(),
                          lastDate: DateTime.now().add(const Duration(days: 365)),
                        );
                        if (picked != null) setD(() => expected = picked);
                      },
                      child: const Text('تغيير'),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpace.x6),
              FilledButton(
                onPressed: () async {
                  s.deliveries.add(Delivery(
                    id: DateTime.now().millisecondsSinceEpoch.toString(),
                    item: item.text.trim(),
                    quantity: double.tryParse(qty.text),
                    unit: unit.text.trim(),
                    expectedDate: expected,
                  ));
                  await StorageService.saveSupplier(s);
                  if (mounted) Navigator.pop(context);
                  setState(() {});
                },
                child: const Text('إضافة التوريد'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _addPayment() {
    final amount = TextEditingController();

    showAppBottomSheet(
      context: context,
      title: 'تسجيل دفعة',
      body: Padding(
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
              child: Row(
                children: [
                  const Icon(Icons.info_outline, color: AppColors.accent),
                  const SizedBox(width: AppSpace.x2),
                  Expanded(
                    child: Text(
                      'المستحق للمورد: ${s.balanceDue.toStringAsFixed(0)} ج',
                      style: AppText.body.copyWith(color: AppColors.accent),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpace.x4),
            TextField(
              controller: amount,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'المبلغ (ج)',
                hintText: 'مثال: 5000',
              ),
              autofocus: true,
            ),
            const SizedBox(height: AppSpace.x6),
            FilledButton(
              onPressed: () async {
                final amt = double.tryParse(amount.text) ?? 0;
                if (amt <= 0) return;
                s.payments.add(SupplierPayment(
                  id: DateTime.now().millisecondsSinceEpoch.toString(),
                  amount: amt,
                  date: DateTime.now(),
                ));
                await StorageService.saveSupplier(s);
                if (mounted) Navigator.pop(context);
                setState(() {});
              },
              child: const Text('تسجيل'),
            ),
          ],
        ),
      ),
    );
  }

  void _editDialog() {
    final name = TextEditingController(text: s.name);
    final item = TextEditingController(text: s.itemType);
    final phone = TextEditingController(text: s.phone);

    showAppBottomSheet(
      context: context,
      title: 'تعديل ${s.name}',
      body: Padding(
        padding: const EdgeInsets.all(AppSpace.x4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: name,
              decoration: const InputDecoration(labelText: 'اسم المورد'),
            ),
            const SizedBox(height: AppSpace.x3),
            TextField(
              controller: item,
              decoration: const InputDecoration(labelText: 'الصنف'),
            ),
            const SizedBox(height: AppSpace.x3),
            TextField(
              controller: phone,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(labelText: 'التليفون'),
            ),
            const SizedBox(height: AppSpace.x6),
            FilledButton(
              onPressed: () async {
                if (name.text.trim().isEmpty) return;
                s.name = name.text.trim();
                s.itemType = item.text.trim();
                s.phone = phone.text.trim();
                await StorageService.saveSupplier(s);
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

/// Finance tile
class _FinanceTile extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;
  final VoidCallback? onTap;

  const _FinanceTile({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: color.withValues(alpha: 0.06),
      borderRadius: BorderRadius.circular(AppRadius.md),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.md),
        child: Container(
          padding: const EdgeInsets.all(AppSpace.x3),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadius.md),
            border: Border.all(color: color.withValues(alpha: 0.2)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(icon, size: AppIconSize.md, color: color),
                  const Spacer(),
                  if (onTap != null)
                    const Icon(Icons.chevron_left,
                        size: AppIconSize.sm, color: AppColors.textDisabled),
                ],
              ),
              const SizedBox(height: AppSpace.x2),
              Text(value, style: AppText.titleMedium.copyWith(
                fontSize: 16, fontWeight: FontWeight.w700, color: color,
              )),
              Text(label, style: AppText.caption),
            ],
          ),
        ),
      ),
    );
  }
}

/// Action button
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
          padding: const EdgeInsets.symmetric(horizontal: AppSpace.x2, vertical: AppSpace.x3),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadius.md),
            border: Border.all(
              color: enabled ? c.withValues(alpha: 0.3) : AppColors.border,
            ),
          ),
          child: Column(
            children: [
              Icon(icon, size: AppIconSize.lg, color: c),
              const SizedBox(height: 4),
              Text(
                label,
                style: TextStyle(
                  fontFamily: 'Tajawal', fontSize: 11,
                  fontWeight: FontWeight.w600, color: c,
                ),
                textAlign: TextAlign.center, maxLines: 2,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Delivery row
class _DeliveryRow extends StatelessWidget {
  final Delivery delivery;
  final VoidCallback onMarkReceived;
  final VoidCallback onDelete;
  final bool isLast;

  const _DeliveryRow({
    required this.delivery,
    required this.onMarkReceived,
    required this.onDelete,
    required this.isLast,
  });

  @override
  Widget build(BuildContext context) {
    final dateStr = delivery.received
        ? 'استُلم: ${delivery.receivedDate?.toString().substring(0, 10) ?? '-'}'
        : 'متوقع: ${delivery.expectedDate.toString().substring(0, 10)}';

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpace.x4, vertical: AppSpace.x3,
      ),
      decoration: BoxDecoration(
        border: isLast
            ? null
            : const Border(bottom: BorderSide(color: AppColors.border, width: 0.5)),
      ),
      child: Row(
        children: [
          Icon(
            delivery.received ? Icons.check_circle : Icons.schedule,
            size: AppIconSize.md,
            color: delivery.received ? AppColors.success : AppColors.warning,
          ),
          const SizedBox(width: AppSpace.x3),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(delivery.item, style: AppText.body.copyWith(fontSize: 14)),
                Text(dateStr, style: AppText.caption),
              ],
            ),
          ),
          if (!delivery.received)
            IconButton(
              icon: const Icon(Icons.check, size: 18),
              color: AppColors.success,
              onPressed: onMarkReceived,
              tooltip: 'تم الاستلام',
              visualDensity: VisualDensity.compact,
            ),
          IconButton(
            icon: const Icon(Icons.delete_outline, size: 18),
            color: AppColors.danger,
            onPressed: () async {
              final confirm = await showDialog<bool>(
                context: context,
                builder: (_) => AlertDialog(
                  title: const Text('حذف التوريد؟'),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context, false),
                      child: const Text('إلغاء'),
                    ),
                    TextButton(
                      onPressed: () => Navigator.pop(context, true),
                      child: const Text('حذف', style: TextStyle(color: AppColors.danger)),
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

/// Payment row
class _PaymentRow extends StatelessWidget {
  final SupplierPayment payment;
  final VoidCallback onDelete;
  final bool isLast;

  const _PaymentRow({
    required this.payment,
    required this.onDelete,
    required this.isLast,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpace.x4, vertical: AppSpace.x3,
      ),
      decoration: BoxDecoration(
        border: isLast
            ? null
            : const Border(bottom: BorderSide(color: AppColors.border, width: 0.5)),
      ),
      child: Row(
        children: [
          const Icon(Icons.payments_outlined,
              size: AppIconSize.md, color: AppColors.success),
          const SizedBox(width: AppSpace.x3),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${payment.amount.toStringAsFixed(0)} ج',
                  style: AppText.body.copyWith(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: AppColors.success,
                  ),
                ),
                Text(payment.date.toString().substring(0, 10), style: AppText.caption),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline, size: 18),
            color: AppColors.danger,
            onPressed: () async {
              final confirm = await showDialog<bool>(
                context: context,
                builder: (_) => AlertDialog(
                  title: const Text('حذف الدفعة؟'),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context, false),
                      child: const Text('إلغاء'),
                    ),
                    TextButton(
                      onPressed: () => Navigator.pop(context, true),
                      child: const Text('حذف', style: TextStyle(color: AppColors.danger)),
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
