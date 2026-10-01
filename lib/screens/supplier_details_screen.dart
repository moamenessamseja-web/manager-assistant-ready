import 'package:flutter/material.dart';
import '../models/supplier.dart';
import '../services/storage_service.dart';

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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(s.name)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            color: Colors.teal.withOpacity(0.06),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                if (s.itemType.isNotEmpty) Text('الصنف: ${s.itemType}'),
                if (s.phone.isNotEmpty) Text('تليفون: ${s.phone}'),
                Text('إجمالي قيمة البضاعة: ${s.totalOwed.toStringAsFixed(0)} ج'),
                Text('إجمالي المدفوع: ${s.totalPaid.toStringAsFixed(0)} ج'),
                Text(
                  'المستحق عليك الآن: ${s.balanceDue.toStringAsFixed(0)} ج',
                  style: TextStyle(
                      fontWeight: FontWeight.bold, color: s.balanceDue > 0 ? Colors.red : Colors.green),
                ),
              ]),
            ),
          ),
          const SizedBox(height: 12),
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
          const Divider(height: 32),
          const Text('التوريدات:', style: TextStyle(fontWeight: FontWeight.bold)),
          ...s.deliveries.map((d) => ListTile(
                leading: Icon(d.received ? Icons.check_circle : Icons.schedule,
                    color: d.received ? Colors.green : Colors.orange),
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
          const Divider(height: 32),
          const Text('سجل الدفعات:', style: TextStyle(fontWeight: FontWeight.bold)),
          ...s.payments.map((p) => ListTile(
                leading: const Icon(Icons.attach_money, color: Colors.green),
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
}
