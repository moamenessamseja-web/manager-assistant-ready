import 'package:flutter/material.dart';
import '../models/supplier.dart';
import '../services/storage_service.dart';
import '../design/tokens.dart';
import '../design/widgets.dart';

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

  bool get _hasHistory => s.deliveries.isNotEmpty || s.payments.isNotEmpty;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(s.name), actions: [
        PopupMenuButton<String>(
          onSelected: (v) async {
            if (v == 'edit') {
              _editDialog();
            } else if (v == 'archive') {
              s.archived = !s.archived;
              await StorageService.saveSupplier(s);
              setState(() {});
            } else if (v == 'delete') {
              _confirmDelete();
            }
          },
          itemBuilder: (_) => [
            const PopupMenuItem(value: 'edit', child: Text('تعديل')),
            PopupMenuItem(value: 'archive', child: Text(s.archived ? 'إلغاء الأرشفة' : 'أرشفة')),
            if (!_hasHistory) const PopupMenuItem(value: 'delete', child: Text('حذف نهائي')),
          ],
        ),
      ]),
      body: ListView(
        padding: const EdgeInsets.all(AppSpace.x4),
        children: [
          if (s.archived)
            const Padding(
              padding: EdgeInsets.only(bottom: AppSpace.x3),
              child: AppStatusBanner(message: 'هذا المورد مؤرشف', kind: AppStatusKind.warning),
            ),
          Card(
            color: AppColors.primaryLight,
            child: Padding(
              padding: const EdgeInsets.all(AppSpace.x3),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                if (s.itemType.isNotEmpty) Text('الصنف: ${s.itemType}'),
                if (s.phone.isNotEmpty) Text('تليفون: ${s.phone}'),
                Text('إجمالي قيمة البضاعة: ${s.totalOwed.toStringAsFixed(0)} ج'),
                Text('إجمالي المدفوع: ${s.totalPaid.toStringAsFixed(0)} ج'),
                const SizedBox(height: AppSpace.x1),
                Text(
                  'المستحق عليك الآن: ${s.balanceDue.toStringAsFixed(0)} ج',
                  style: AppText.titleMedium.copyWith(
                      color: s.balanceDue > 0 ? AppColors.danger : AppColors.success),
                ),
              ]),
            ),
          ),
          const SizedBox(height: AppSpace.x3),
          Row(children: [
            Expanded(
              child: ElevatedButton.icon(
                  onPressed: _addDelivery, icon: const Icon(Icons.local_shipping), label: const Text('توريد متوقع')),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: ElevatedButton.icon(
                  onPressed: _addPayment, icon: const Icon(Icons.payments), label: const Text('تسجيل دفعة')),
            ),
          ]),
          const Divider(height: AppSpace.x8),
          const AppSectionHeader('التوريدات'),
          ...s.deliveries.map((d) => ListTile(
                leading: Icon(d.received ? Icons.check_circle : Icons.schedule,
                    color: d.received ? AppColors.success : AppColors.warning),
                title: Text('${d.item}${d.quantity == null ? '' : ' - ${d.quantity} ${d.unit}'}'),
                subtitle: Text(d.received
                    ? 'استُلم: ${d.receivedDate?.toString().substring(0, 10) ?? ''}'
                    : 'متوقع: ${d.expectedDate.toString().substring(0, 10)}'),
                trailing: d.received
                    ? null
                    : IconButton(
                        icon: const Icon(Icons.check),
                        onPressed: () async {
                          d.received = true;
                          d.receivedDate = DateTime.now();
                          await StorageService.saveSupplier(s);
                          setState(() {});
                        },
                      ),
              )),
          const Divider(height: AppSpace.x8),
          const AppSectionHeader('سجل الدفعات'),
          ...s.payments.map((p) => ListTile(
                leading: const Icon(Icons.attach_money, color: AppColors.success),
                title: Text('${p.amount.toStringAsFixed(0)} ج'),
                subtitle: Text(p.date.toString().substring(0, 10)),
              )),
        ],
      ),
    );
  }

  void _addDelivery() {
    final item = TextEditingController(text: s.itemType);
    final qty = TextEditingController();
    final unit = TextEditingController();
    DateTime expected = DateTime.now().add(const Duration(days: 1));
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setD) => AlertDialog(
          title: const Text('توريد متوقع جديد'),
          content: Column(mainAxisSize: MainAxisSize.min, children: [
            TextField(controller: item, decoration: const InputDecoration(labelText: 'الصنف')),
            TextField(controller: qty, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'الكمية')),
            TextField(controller: unit, decoration: const InputDecoration(labelText: 'الوحدة (كيلو/كرتونة)')),
            const SizedBox(height: 8),
            Row(children: [
              Text('التاريخ المتوقع: ${expected.toString().substring(0, 10)}'),
              const Spacer(),
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
          ]),
          actions: [
            TextButton(
              onPressed: () async {
                s.deliveries.add(Delivery(
                  id: DateTime.now().millisecondsSinceEpoch.toString(),
                  item: item.text.trim(),
                  quantity: double.tryParse(qty.text),
                  unit: unit.text.trim(),
                  expectedDate: expected,
                ));
                await StorageService.saveSupplier(s);
                if (mounted) {
                  Navigator.pop(ctx);
                  setState(() {});
                }
              },
              child: const Text('حفظ'),
            ),
          ],
        ),
      ),
    );
  }

  void _addPayment() {
    final amount = TextEditingController();
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('تسجيل دفعة'),
        content: TextField(controller: amount, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'المبلغ')),
        actions: [
          TextButton(
            onPressed: () async {
              s.payments.add(SupplierPayment(
                id: DateTime.now().millisecondsSinceEpoch.toString(),
                amount: double.tryParse(amount.text) ?? 0,
                date: DateTime.now(),
              ));
              await StorageService.saveSupplier(s);
              if (mounted) {
                Navigator.pop(context);
                setState(() {});
              }
            },
            child: const Text('حفظ'),
          ),
        ],
      ),
    );
  }

  void _editDialog() {
    final name = TextEditingController(text: s.name);
    final item = TextEditingController(text: s.itemType);
    final phone = TextEditingController(text: s.phone);
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('تعديل بيانات المورد'),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(controller: name, decoration: const InputDecoration(labelText: 'اسم المورد')),
          TextField(controller: item, decoration: const InputDecoration(labelText: 'الصنف')),
          TextField(controller: phone, decoration: const InputDecoration(labelText: 'تليفون')),
        ]),
        actions: [
          TextButton(
            onPressed: () async {
              if (name.text.trim().isEmpty) return;
              s.name = name.text.trim();
              s.itemType = item.text.trim();
              s.phone = phone.text.trim();
              await StorageService.saveSupplier(s);
              if (mounted) {
                Navigator.pop(context);
                setState(() {});
              }
            },
            child: const Text('حفظ'),
          ),
        ],
      ),
    );
  }

  void _confirmDelete() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('حذف نهائي'),
        content: Text('هتحذف ${s.name} نهائيًا. متأكد؟'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إلغاء')),
          TextButton(
            onPressed: () async {
              await StorageService.deleteSupplier(s.id);
              if (mounted) {
                Navigator.pop(ctx);
                Navigator.pop(context);
              }
            },
            child: const Text('حذف', style: TextStyle(color: AppColors.danger)),
          ),
        ],
      ),
    );
  }
}
