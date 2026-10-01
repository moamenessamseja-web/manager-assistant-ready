import 'package:flutter/material.dart';
import '../models/supplier.dart';
import '../services/storage_service.dart';
import 'supplier_details_screen.dart';

class SuppliersScreen extends StatefulWidget {
  const SuppliersScreen({super.key});
  @override
  State<SuppliersScreen> createState() => _SuppliersScreenState();
}

class _SuppliersScreenState extends State<SuppliersScreen> {
  @override
  Widget build(BuildContext context) {
    final suppliers = StorageService.suppliers();
    return Scaffold(
      appBar: AppBar(title: const Text('الموردين')),
      body: suppliers.isEmpty
          ? const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'لا يوجد موردين بعد.\nمثال: "اعمل مورد بن اسمه محمود"\nأو من الشات: "محمود هيجيب 20 كيلو بن السبت"',
                  textAlign: TextAlign.center,
                ),
              ),
            )
          : ListView(
              children: suppliers.map((s) {
                final pending = s.pendingDeliveries;
                return Card(
                  margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  child: ListTile(
                    leading: CircleAvatar(child: Text(s.name.isNotEmpty ? s.name[0] : '؟')),
                    title: Text('${s.name}${s.itemType.isEmpty ? '' : ' — ${s.itemType}'}'),
                    subtitle: Text(
                      'المستحق عليك: ${s.balanceDue.toStringAsFixed(0)} ج'
                      '${pending.isEmpty ? '' : '\nتوريد متوقع: ${pending.first.expectedDate.toString().substring(0, 10)}'}',
                    ),
                    isThreeLine: pending.isNotEmpty,
                    trailing: s.balanceDue > 0
                        ? const Icon(Icons.warning_amber_rounded, color: Colors.orange)
                        : const Icon(Icons.check_circle, color: Colors.green),
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => SupplierDetailsScreen(supplier: s)),
                    ).then((_) => setState(() {})),
                  ),
                );
              }).toList(),
            ),
      floatingActionButton: FloatingActionButton(onPressed: _addSupplier, child: const Icon(Icons.local_shipping)),
    );
  }

  void _addSupplier() {
    final name = TextEditingController();
    final item = TextEditingController();
    final phone = TextEditingController();
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('إضافة مورد'),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(controller: name, decoration: const InputDecoration(labelText: 'اسم المورد')),
          TextField(controller: item, decoration: const InputDecoration(labelText: 'الصنف (بن / لبن / مخبوزات...)')),
          TextField(controller: phone, decoration: const InputDecoration(labelText: 'تليفون (اختياري)')),
        ]),
        actions: [
          TextButton(
            onPressed: () async {
              if (name.text.trim().isEmpty) return;
              await StorageService.saveSupplier(Supplier(
                id: DateTime.now().millisecondsSinceEpoch.toString(),
                name: name.text.trim(),
                itemType: item.text.trim(),
                phone: phone.text.trim(),
              ));
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
