import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../models/employee.dart';
import '../services/storage_service.dart';
import '../design/tokens.dart';
import '../design/widgets.dart';

class EmployeeDetailsScreen extends StatefulWidget {
  final Employee employee;
  const EmployeeDetailsScreen({super.key, required this.employee});
  @override
  State<EmployeeDetailsScreen> createState() => _S();
}

class _S extends State<EmployeeDetailsScreen> {
  late Employee e;
  @override
  void initState() {
    super.initState();
    e = widget.employee;
  }

  bool get _hasHistory => e.advances.isNotEmpty || e.attendance.isNotEmpty;

  // Activity timeline موحدة: سلف + حضور، مرتبة من الأحدث للأقدم
  List<MapEntry<DateTime, String>> get _timeline {
    final items = <MapEntry<DateTime, String>>[];
    for (final a in e.advances) {
      items.add(MapEntry(a.date, 'سلفة ${a.amount.toStringAsFixed(0)} ج'));
    }
    for (final d in e.attendance) {
      final parsed = DateTime.tryParse(d);
      if (parsed != null) items.add(MapEntry(parsed, 'تسجيل حضور'));
    }
    items.sort((a, b) => b.key.compareTo(a.key));
    return items;
  }

  @override
  Widget build(BuildContext c) => Scaffold(
        appBar: AppBar(
          title: Text(e.name),
          actions: [
            PopupMenuButton<String>(
              onSelected: (v) async {
                if (v == 'edit') {
                  _editDialog();
                } else if (v == 'archive') {
                  e.archived = !e.archived;
                  await StorageService.saveEmployee(e);
                  setState(() {});
                } else if (v == 'delete') {
                  _confirmDelete();
                }
              },
              itemBuilder: (_) => [
                const PopupMenuItem(value: 'edit', child: Text('تعديل')),
                PopupMenuItem(value: 'archive', child: Text(e.archived ? 'إلغاء الأرشفة' : 'أرشفة')),
                if (!_hasHistory) const PopupMenuItem(value: 'delete', child: Text('حذف نهائي')),
              ],
            ),
          ],
        ),
        body: ListView(padding: const EdgeInsets.all(AppSpace.x4), children: [
          if (e.archived)
            const Padding(
              padding: EdgeInsets.only(bottom: AppSpace.x3),
              child: AppStatusBanner(message: 'هذا الموظف مؤرشف', kind: AppStatusKind.warning),
            ),
          Text('الوظيفة: ${e.role}'),
          Text('المرتب: ${e.salaryMonthly.toStringAsFixed(0)} ج'),
          Text('الحضور: ${e.attendance.length} | الغياب التقريبي: ${e.absenceDays}'),
          Text('السلف: ${e.totalAdvances.toStringAsFixed(0)} ج'),
          Text('المتبقي: ${e.remainingSalary.toStringAsFixed(0)} ج'),
          const SizedBox(height: AppSpace.x4),
          Row(children: [
            Expanded(child: ElevatedButton.icon(onPressed: _advance, icon: const Icon(Icons.money_off), label: const Text('سلفة'))),
            const SizedBox(width: AppSpace.x2),
            Expanded(child: ElevatedButton.icon(onPressed: _attendance, icon: const Icon(Icons.check), label: const Text('حضور اليوم'))),
          ]),
          const Divider(height: AppSpace.x8),
          const AppSectionHeader('آخر الحركات'),
          if (_timeline.isEmpty) const Padding(padding: EdgeInsets.all(AppSpace.x3), child: Text('أول حركة ستظهر هنا.', style: AppText.bodyMuted)),
          ..._timeline.map((t) => ListTile(dense: true, title: Text(t.value), subtitle: Text(t.key.toString().substring(0, 10)))),
        ]),
      );

  Future<void> _advance() async {
    final x = TextEditingController();
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('سلفة'),
        content: TextField(controller: x, keyboardType: TextInputType.number),
        actions: [
          TextButton(
            onPressed: () async {
              e.advances.add(Advance(id: const Uuid().v4(), amount: double.tryParse(x.text) ?? 0, date: DateTime.now()));
              await StorageService.saveEmployee(e);
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

  Future<void> _attendance() async {
    final d = DateTime.now().toIso8601String().substring(0, 10);
    if (!e.attendance.contains(d)) e.attendance.add(d);
    await StorageService.saveEmployee(e);
    setState(() {});
  }

  void _editDialog() {
    final n = TextEditingController(text: e.name), r = TextEditingController(text: e.role), s = TextEditingController(text: e.salaryMonthly.toStringAsFixed(0));
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('تعديل بيانات الموظف'),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(controller: n, decoration: const InputDecoration(labelText: 'الاسم')),
          TextField(controller: r, decoration: const InputDecoration(labelText: 'الوظيفة')),
          TextField(controller: s, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'المرتب الشهري')),
        ]),
        actions: [
          TextButton(
            onPressed: () async {
              e.name = n.text.trim().isEmpty ? e.name : n.text.trim();
              e.role = r.text.trim();
              e.salaryMonthly = double.tryParse(s.text) ?? e.salaryMonthly;
              await StorageService.saveEmployee(e);
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
        content: Text('هتحذف ${e.name} نهائيًا. متأكد؟'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إلغاء')),
          TextButton(
            onPressed: () async {
              await StorageService.deleteEmployee(e.id);
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
