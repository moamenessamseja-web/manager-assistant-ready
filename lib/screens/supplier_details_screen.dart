import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:uuid/uuid.dart';
import '../models/supplier.dart';
import '../services/storage_service.dart';
import '../services/app_state.dart';
import '../design/tokens.dart';
import '../design/app_theme.dart';
import '../design/widgets.dart';
import '../design/format.dart';
import 'supplier_forms.dart';
import 'supplier_report_screen.dart';

/// حساب المورد — مركز حقيقي: موقف مالي قابل للفتح، إجراءات، توريدات، وسجل نشاط.
class SupplierDetailsScreen extends StatefulWidget {
  final Supplier supplier;
  const SupplierDetailsScreen({super.key, required this.supplier});

  @override
  State<SupplierDetailsScreen> createState() => _SupplierDetailsScreenState();
}

class _SupplierDetailsScreenState extends State<SupplierDetailsScreen> {
  late Supplier s;
  int _tab = 0;

  @override
  void initState() {
    super.initState();
    s = widget.supplier;
  }

  void _openReport(SupplierReportKind kind) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => SupplierReportScreen(supplier: s, kind: kind)),
    );
  }

  Future<void> _addPurchase() async {
    if (await showAddPurchaseSheet(context, s)) {
      if (mounted) setState(() {});
    }
  }

  Future<void> _addPayment() async {
    if (await showAddPaymentSheet(context, s)) {
      if (mounted) setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(s.name),
        actions: [
          PopupMenuButton<String>(
            onSelected: (v) async {
              switch (v) {
                case 'edit':
                  if (await showEditSupplierSheet(context, s) != null && mounted) setState(() {});
                  break;
                case 'archive':
                  await archiveSupplier(context, s);
                  if (mounted) setState(() {});
                  break;
                case 'delete':
                  if (await deleteSupplierSafely(context, s) && mounted) {
                    if (context.mounted) Navigator.pop(context);
                  }
                  break;
              }
            },
            itemBuilder: (_) => [
              const PopupMenuItem(value: 'edit', child: Text('تعديل البيانات')),
              PopupMenuItem(value: 'archive', child: Text(s.archived ? 'إلغاء الأرشفة' : 'أرشفة')),
              if (!s.hasHistory) const PopupMenuItem(value: 'delete', child: Text('حذف نهائي')),
            ],
          ),
        ],
      ),
      body: ListenableBuilder(
        listenable: AppState.instance,
        builder: (context, _) {
          final fresh = StorageService.suppliers().where((x) => x.id == s.id).toList();
          if (fresh.isNotEmpty) s = fresh.first;
          return ListView(
            padding: const EdgeInsets.all(AppSpace.x4),
            children: [
              _header(),
              const SizedBox(height: AppSpace.x3),
              _finance(),
              const SizedBox(height: AppSpace.x3),
              _quickActions(),
              const SizedBox(height: AppSpace.x4),
              AppSegmented(
                labels: const ['المعاملات', 'التوريدات', 'البيانات'],
                selectedIndex: _tab,
                onSelected: (i) => setState(() => _tab = i),
              ),
              const SizedBox(height: AppSpace.x3),
              if (_tab == 0) ..._timelineTab(),
              if (_tab == 1) ..._deliveriesTab(),
              if (_tab == 2) ..._dataTab(),
              const SizedBox(height: AppSpace.x16),
            ],
          );
        },
      ),
    );
  }

  // ── رأس الصفحة ──────────────────────────────────────────────
  Widget _header() {
    return AppCard(
      padding: const EdgeInsets.all(AppSpace.x4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            AppAvatar(name: s.name, size: 56, icon: Icons.local_shipping_outlined),
            const SizedBox(width: AppSpace.x3),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(s.name, style: AppText.h2.copyWith(fontSize: 20)),
                if (s.itemType.isNotEmpty) Text(s.itemType, style: AppText.bodyMuted),
                if (s.phone.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Row(children: [
                      const Icon(Icons.phone_outlined, size: 12, color: AppColors.textSecondary),
                      const SizedBox(width: 4),
                      Text(s.phone, style: AppText.caption),
                    ]),
                  ),
              ]),
            ),
          ]),
          if (s.archived) ...[
            const SizedBox(height: AppSpace.x3),
            const AppBadge(kind: BadgeKind.neutral, label: 'مؤرشف'),
          ],
        ],
      ),
    );
  }

  // ── الموقف المالي (كل رقم قابل للفتح) ───────────────────────
  Widget _finance() {
    return Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Expanded(
        child: AppStatTile(
          label: 'إجمالي البضاعة',
          value: money(s.goodsTotal),
          icon: Icons.inventory_2_outlined,
          color: AppColors.info,
          onTap: () => _openReport(SupplierReportKind.purchases),
        ),
      ),
      const SizedBox(width: AppSpace.x3),
      Expanded(
        child: AppStatTile(
          label: 'إجمالي المدفوع',
          value: money(s.totalPaid),
          icon: Icons.payments_outlined,
          color: AppColors.success,
          onTap: () => _openReport(SupplierReportKind.payments),
        ),
      ),
      const SizedBox(width: AppSpace.x3),
      Expanded(
        child: AppStatTile(
          label: 'المستحق',
          value: money(s.balanceDue),
          icon: Icons.account_balance_wallet_outlined,
          color: s.balanceDue > 0 ? AppColors.accent : AppColors.success,
          onTap: () => _openReport(SupplierReportKind.balance),
        ),
      ),
    ]);
  }

  // ── إجراءات سريعة ───────────────────────────────────────────
  Widget _quickActions() {
    return Row(children: [
      Expanded(
        child: _Action(
          icon: Icons.inventory_2_outlined,
          label: 'تسجيل توريد',
          color: AppColors.info,
          onTap: _addPurchase,
        ),
      ),
      const SizedBox(width: AppSpace.x3),
      Expanded(
        child: _Action(
          icon: Icons.payments_outlined,
          label: 'تسجيل دفعة',
          color: AppColors.success,
          onTap: _addPayment,
        ),
      ),
      const SizedBox(width: AppSpace.x3),
      Expanded(
        child: _Action(
          icon: s.phone.isEmpty ? Icons.notes_outlined : Icons.copy_all_outlined,
          label: s.phone.isEmpty ? 'ملاحظة' : 'نسخ الرقم',
          color: AppColors.primary,
          onTap: () async {
            if (s.phone.isEmpty) {
              await showEditSupplierSheet(context, s);
              if (mounted) setState(() {});
              return;
            }
            await Clipboard.setData(ClipboardData(text: s.phone));
            if (context.mounted) showAppSnack(context, 'تم نسخ رقم ${s.name}');
          },
        ),
      ),
    ]);
  }

  // ── تبويب المعاملات (Timeline موحّد) ────────────────────────
  List<Widget> _timelineTab() {
    final events = s.timeline;
    if (events.isEmpty) {
      return [
        const AppEmptyState(
          icon: Icons.history,
          title: 'لا يوجد نشاط بعد',
          subtitle: 'أول توريد أو دفعة ستظهر هنا.',
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

  Widget _eventRow(SupplierEvent e, bool isLast) {
    switch (e.kind) {
      case 'purchase':
        final p = e.payload as SupplierPurchase;
        return AppTimelineItem(
          title: 'توريد ${p.item.isEmpty ? '' : p.item}'.trim(),
          subtitle: [
            if (p.quantityLabel.isNotEmpty) p.quantityLabel,
            if (p.unitPriceLabel.isNotEmpty) p.unitPriceLabel,
          ].join(' · '),
          trailing: money(p.total),
          dateText: arabicDateTime(p.date),
          icon: Icons.inventory_2_outlined,
          color: AppColors.info,
          isLast: isLast,
        );
      case 'payment':
        final p = e.payload as SupplierPayment;
        return AppTimelineItem(
          title: 'دفعة',
          subtitle: p.note.isEmpty ? (p.method.isEmpty ? '' : p.method) : p.note,
          trailing: money(p.amount),
          dateText: arabicDateTime(p.date),
          icon: Icons.payments_outlined,
          color: AppColors.success,
          isLast: isLast,
        );
      default:
        final d = e.payload as Delivery;
        return AppTimelineItem(
          title: 'توريد متوقع ${d.item.isEmpty ? '' : d.item}'.trim(),
          subtitle: d.received ? 'تم الاستلام' : 'لم يُستلم بعد',
          dateText: arabicDateTime(e.date),
          icon: d.received ? Icons.check_circle_outline : Icons.schedule,
          color: d.received ? AppColors.success : AppColors.warning,
          isLast: isLast,
        );
    }
  }

  // ── تبويب التوريدات المتوقعة ────────────────────────────────
  List<Widget> _deliveriesTab() {
    return [
      AppSectionHeader(
        title: 'التوريدات المتوقعة',
        trailing: Text('${s.deliveries.length}', style: AppText.caption),
      ),
      if (s.deliveries.isEmpty)
        AppCard(
          padding: const EdgeInsets.all(AppSpace.x6),
          child: Column(children: [
            const Icon(Icons.local_shipping_outlined, size: 32, color: AppColors.textDisabled),
            const SizedBox(height: AppSpace.x2),
            Text('لا توجد توريدات متوقعة', style: AppText.bodyMuted),
            const SizedBox(height: AppSpace.x3),
            FilledButton(onPressed: _addDelivery, child: const Text('إضافة توريد متوقع')),
          ]),
        )
      else ...[
        AppCard(
          padding: const EdgeInsets.symmetric(vertical: AppSpace.x2),
          child: Column(
            children: [
              for (var i = 0; i < s.deliveries.length; i++)
                _deliveryRow(i, i == s.deliveries.length - 1),
            ],
          ),
        ),
        const SizedBox(height: AppSpace.x3),
        OutlinedButton(onPressed: _addDelivery, child: const Text('إضافة توريد متوقع')),
      ],
    ];
  }

  Widget _deliveryRow(int i, bool isLast) {
    final d = s.deliveries[i];
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppSpace.x4, vertical: AppSpace.x3),
      decoration: BoxDecoration(
        border: isLast ? null : const Border(bottom: BorderSide(color: AppColors.border, width: 0.5)),
      ),
      child: Row(children: [
        Icon(d.received ? Icons.check_circle : Icons.schedule,
            size: AppIconSize.md, color: d.received ? AppColors.success : AppColors.warning),
        const SizedBox(width: AppSpace.x3),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(d.item.isEmpty ? 'توريد' : d.item, style: AppText.label.copyWith(fontWeight: FontWeight.w600)),
            Text(
              d.received
                  ? 'استُلم: ${arabicDate(d.receivedDate ?? d.expectedDate)}'
                  : 'متوقع: ${arabicDate(d.expectedDate)}',
              style: AppText.caption,
            ),
          ]),
        ),
        if (!d.received)
          IconButton(
            tooltip: 'تم الاستلام',
            icon: const Icon(Icons.check, size: 18),
            color: AppColors.success,
            visualDensity: VisualDensity.compact,
            onPressed: () async {
              final ok = await showDialog<bool>(
                context: context,
                builder: (_) => AlertDialog(
                  title: const Text('تم استلام التوريد؟'),
                  content: const Text('لو عندك قيمة التوريد، سجّلها من "تسجيل توريد" لتُحسب على الحساب.'),
                  actions: [
                    TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('إلغاء')),
                    TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('تأكيد')),
                  ],
                ),
              );
              if (ok == true) {
                d.received = true;
                d.receivedDate = DateTime.now();
                await StorageService.saveSupplier(s);
                if (mounted) setState(() {});
              }
            },
          ),
        IconButton(
          tooltip: 'حذف',
          icon: const Icon(Icons.delete_outline, size: 18),
          color: AppColors.danger,
          visualDensity: VisualDensity.compact,
          onPressed: () async {
            s.deliveries.removeAt(i);
            await StorageService.saveSupplier(s);
            if (mounted) setState(() {});
          },
        ),
      ]),
    );
  }

  void _addDelivery() {
    final item = TextEditingController(text: s.itemType);
    final qty = TextEditingController();
    final unit = TextEditingController();
    DateTime expected = DateTime.now().add(const Duration(days: 1));

    showAppBottomSheet<void>(
      context: context,
      title: 'توريد متوقع جديد',
      body: StatefulBuilder(
        builder: (ctx, setD) => SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpace.x4),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            TextField(controller: item, decoration: const InputDecoration(labelText: 'الصنف')),
            const SizedBox(height: AppSpace.x3),
            Row(children: [
              Expanded(
                child: TextField(
                  controller: qty,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'الكمية'),
                ),
              ),
              const SizedBox(width: AppSpace.x3),
              Expanded(
                child: TextField(controller: unit, decoration: const InputDecoration(labelText: 'الوحدة')),
              ),
            ]),
            const SizedBox(height: AppSpace.x3),
            Container(
              padding: const EdgeInsets.all(AppSpace.x3),
              decoration: BoxDecoration(
                color: AppColors.surfaceMuted,
                borderRadius: BorderRadius.circular(AppRadius.md),
              ),
              child: Row(children: [
                const Icon(Icons.calendar_today_outlined, size: 16),
                const SizedBox(width: AppSpace.x2),
                Expanded(child: Text('متوقع: ${arabicDate(expected)}', style: AppText.body)),
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
              ]),
            ),
            const SizedBox(height: AppSpace.x6),
            FilledButton(
              onPressed: () async {
                s.deliveries.add(Delivery(
                  id: const Uuid().v4(),
                  item: item.text.trim(),
                  quantity: double.tryParse(qty.text.trim()),
                  unit: unit.text.trim(),
                  expectedDate: expected,
                ));
                await StorageService.saveSupplier(s);
                if (context.mounted) Navigator.pop(context);
                if (mounted) setState(() {});
              },
              child: const Text('إضافة التوريد'),
            ),
          ]),
        ),
      ),
    );
  }

  // ── تبويب البيانات ──────────────────────────────────────────
  List<Widget> _dataTab() {
    return [
      AppSectionHeader(title: 'البيانات', trailing: TextButton(
        onPressed: () async {
          if (await showEditSupplierSheet(context, s) != null && mounted) setState(() {});
        },
        child: const Text('تعديل'),
      )),
      AppCard(
        padding: const EdgeInsets.symmetric(horizontal: AppSpace.x4, vertical: AppSpace.x2),
        child: Column(children: [
          AppInfoRow(label: 'الاسم', value: s.name),
          AppInfoRow(label: 'الصنف', value: s.itemType.isEmpty ? '—' : s.itemType),
          AppInfoRow(label: 'التليفون', value: s.phone.isEmpty ? '—' : s.phone),
          AppInfoRow(label: 'أُضيف في', value: arabicDate(s.createdAt)),
          AppInfoRow(label: 'ملاحظات', value: s.note.isEmpty ? '—' : s.note),
          AppInfoRow(label: 'الحالة', value: s.archived ? 'مؤرشف' : 'نشط'),
        ]),
      ),
      const SizedBox(height: AppSpace.x3),
      if (!s.hasHistory)
        OutlinedButton.icon(
          onPressed: () async {
            if (await deleteSupplierSafely(context, s) && context.mounted) Navigator.pop(context);
          },
          icon: const Icon(Icons.delete_outline, color: AppColors.danger),
          label: const Text('حذف نهائي', style: TextStyle(color: AppColors.danger)),
          style: OutlinedButton.styleFrom(minimumSize: const Size(0, AppTouch.min)),
        )
      else
        AppStatusBanner(
          kind: BannerKind.info,
          icon: Icons.lock_outline,
          message: 'المورد عنده سجلات، فالحذف النهائي متوقف — استخدم الأرشفة للحفاظ على التاريخ.',
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
    final enabled = onTap != null;
    final c = enabled ? color : AppColors.textDisabled;
    return Material(
      color: enabled ? c.withValues(alpha: 0.08) : AppColors.surfaceMuted,
      borderRadius: BorderRadius.circular(AppRadius.md),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.md),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: AppSpace.x3, horizontal: AppSpace.x2),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadius.md),
            border: Border.all(color: enabled ? c.withValues(alpha: 0.25) : AppColors.border),
          ),
          child: Column(children: [
            Icon(icon, size: AppIconSize.lg, color: c),
            const SizedBox(height: 4),
            Text(label,
                style: TextStyle(
                    fontFamily: 'Tajawal', fontSize: 11, fontWeight: FontWeight.w600, color: c),
                textAlign: TextAlign.center,
                maxLines: 2),
          ]),
        ),
      ),
    );
  }
}
