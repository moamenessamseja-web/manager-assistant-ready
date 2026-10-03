import 'package:flutter/material.dart';
import '../models/supplier.dart';
import '../services/storage_service.dart';
import 'supplier_details_screen.dart';

class SuppliersScreen extends StatefulWidget {
  const SuppliersScreen({super.key});
  @override
  State<SuppliersScreen> createState() => _S();
}

class _S extends State<SuppliersScreen> {
  String _filter = 'active'; // active | archived | all

  @override
  Widget build(BuildContext context) {
    final all = StorageService.suppliers();
    final shown = switch (_filter) {
      'archived' => all.where((s) => s.archived).toList(),
      'all' => all,
      _ => all.where((s) => !s.archived).toList(),
    };

    return Scaffold(
      appBar: AppBar(title: const Text('الموردين')),
      body: Column(children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(children: [
            ChoiceChip(label: const Text('نشط'), selected: _filter == 'active', onSelected: (_) => setState(() => _filter = 'active')),
            const SizedBox(width: 8),
            ChoiceChip(label: const Text('مؤرشف'), selected: _filter == 'archived', onSelected: (_) => setState(() => _filter = 'archived')),
            const SizedBox(width: 8),
            ChoiceChip(label: const Text('الكل'), selected: _filter == 'all', onSelected: (_) => setState(() => _filter = 'all')),
          ]),
        ),
        Expanded(
          child: shown.isEmpty
              ? const Center(
                  child: Padding(
                    padding: EdgeInsets.all(24),
                    child: Text(
                      'لا يوجد موردين هنا.\nمثال: "اعمل مورد بن اسمه محمود"\nأو من الشات: "محمود هيجيب 20 كيلو بن السبت"',
                      textAlign: TextAlign.center,
                    ),
                  ),
                )
              : ListView(
                  children: shown.map((s) {
                    final pending = s.pendingDeliveries;
                    return Card(
                      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      child: ListTile(
                        leading: CircleAvatar(child: Text(s.name.isNotEmpty ? s.name[0] : '؟')),
                        title: Text('${s.name}${s.itemType.isEmpty ? '' : ' — ${s.itemType}'}'),
                        subtitle: Text(
                          'المستحق عليك: ${s.balanceDue.toStringAsFixed(0)} ج'
                          '${pending.isEmpty ? '' : '\nتوريد متوقع: ${pending.first.expectedDate.toString().substring(0, 10)}'}'
                          '${s.archived ? '\nمؤرشف' : ''}',
                        ),
                        isThreeLine: pending.isNotEmpty || s.archived,
                        trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                          if (!s.archived)
                            Icon(s.balanceDue > 0 ? Icons.warning_amber_rounded : Icons.check_circle,
                                color: s.balanceDue > 0 ? Colors.orange : Colors.green),
                          PopupMenuButton<String>(
                            onSelected: (v) async {
                              if (v == 'edit') {
                                _editDialog(s);
                              } else if (v == 'archive') {
                                s.archived = !s.archived;
                                await StorageService.saveSupplier(s);
                                setState(() {});
                              }
                            },
                            itemBuilder: (_) => [
                              const PopupMenuItem(value: 'edit', child: Text('تعديل')),
                              PopupMenuItem(value: 'archive', child: Text(s.archived ? 'إلغاء الأرشفة' : 'أرشفة')),
                            ],
                          ),
                        ]),
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => SupplierDetailsScreen(supplier: s)),
                        ).then((_) => setState(() {})),
                      ),
                    );
                  }).toList(),
                ),
        ),
      ]),
      floatingActionButton: FloatingActionButton(onPressed: _add, child: const Icon(Icons.local_shipping)),
    );
  }

  void _add() {
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

  void _editDialog(Supplier s) {
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
}
