import 'package:flutter/material.dart';
import '../models/employee.dart';
import '../services/storage_service.dart';
import '../design/widgets.dart';
import 'employee_details_screen.dart';

class StaffScreen extends StatefulWidget {
  const StaffScreen({super.key});
  @override
  State<StaffScreen> createState() => _S();
}

class _S extends State<StaffScreen> {
  String _filter = 'active'; // active | archived | all

  @override
  Widget build(BuildContext c) {
    final all = StorageService.employees();
    final shown = switch (_filter) {
      'archived' => all.where((e) => e.archived).toList(),
      'all' => all,
      _ => all.where((e) => !e.archived).toList(),
    };

    return Scaffold(
      appBar: AppBar(title: const Text('العاملين')),
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
              ? const AppEmptyState(
                  icon: Icons.people_outline,
                  title: 'لا يوجد موظفون هنا',
                  subtitle: 'مثال: محمد بدأ شغل يوم 4 ومرتبه 4000',
                )
              : ListView(
                  children: shown.map((e) => Card(
                        child: ListTile(
                          title: Text('${e.name} — ${e.role}'),
                          subtitle: Text('حضور ${e.attendance.length} | سلف ${e.totalAdvances.toStringAsFixed(0)} ج | المتبقي ${e.remainingSalary.toStringAsFixed(0)} ج'),
                          trailing: PopupMenuButton<String>(
                            onSelected: (v) async {
                              if (v == 'edit') {
                                _editDialog(e);
                              } else if (v == 'archive') {
                                e.archived = !e.archived;
                                await StorageService.saveEmployee(e);
                                setState(() {});
                              }
                            },
                            itemBuilder: (_) => [
                              const PopupMenuItem(value: 'edit', child: Text('تعديل')),
                              PopupMenuItem(value: 'archive', child: Text(e.archived ? 'إلغاء الأرشفة' : 'أرشفة')),
                            ],
                          ),
                          onTap: () => Navigator.push(c, MaterialPageRoute(builder: (_) => EmployeeDetailsScreen(employee: e)))
                              .then((_) => setState(() {})),
                        ),
                      )).toList(),
                ),
        ),
      ]),
      floatingActionButton: FloatingActionButton(onPressed: _add, child: const Icon(Icons.person_add)),
    );
  }

  void _add() {
    final n = TextEditingController(), r = TextEditingController(text: 'عامل'), s = TextEditingController();
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('إضافة موظف'),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(controller: n, decoration: const InputDecoration(labelText: 'الاسم')),
          TextField(controller: r, decoration: const InputDecoration(labelText: 'الوظيفة')),
          TextField(controller: s, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'المرتب الشهري')),
        ]),
        actions: [
          TextButton(
            onPressed: () async {
              if (n.text.trim().isEmpty) return;
              await StorageService.saveEmployee(Employee(
                id: DateTime.now().millisecondsSinceEpoch.toString(),
                name: n.text.trim(),
                role: r.text.trim(),
                startDate: DateTime.now(),
                salaryMonthly: double.tryParse(s.text) ?? 0,
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

  void _editDialog(Employee e) {
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
              if (n.text.trim().isEmpty) return;
              e.name = n.text.trim();
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
}
