import 'package:flutter/material.dart';
import '../services/storage_service.dart';
import '../design/tokens.dart';
import '../design/widgets.dart';

class MemoryScreen extends StatefulWidget {
  const MemoryScreen({super.key});
  @override
  State<MemoryScreen> createState() => _MemoryScreenState();
}

class _MemoryScreenState extends State<MemoryScreen> {
  final _q = TextEditingController();
  String query = '';

  @override
  Widget build(BuildContext context) {
    final commitments = StorageService.commitments().where((c) => c.person.contains(query)).toList()
      ..sort((a, b) => b.dueDate.compareTo(a.dueDate));
    final suppliers = StorageService.suppliers().where((s) => s.name.contains(query)).toList();
    final employees = StorageService.employees().where((e) => e.name.contains(query)).toList();

    final hasResults = query.isNotEmpty && (commitments.isNotEmpty || suppliers.isNotEmpty || employees.isNotEmpty);

    return Scaffold(
      appBar: AppBar(title: const Text('الذاكرة')),
      body: Column(children: [
        Padding(
          padding: const EdgeInsets.all(12),
          child: TextField(
            controller: _q,
            decoration: const InputDecoration(
              prefixIcon: Icon(Icons.search),
              hintText: 'ابحث باسم عميل / مورد / موظف...',
              border: OutlineInputBorder(),
            ),
            onChanged: (v) => setState(() => query = v.trim()),
          ),
        ),
        Expanded(
          child: query.isEmpty
              ? const AppEmptyState(icon: Icons.search, title: 'ابحث بأي اسم', subtitle: 'عميل / مورد / موظف — وهيجيبلك كل سجلاته السابقة')
              : !hasResults
                  ? const AppEmptyState(icon: Icons.search_off, title: 'مفيش نتائج بهذا الاسم')
                  : ListView(
                      children: [
                        if (employees.isNotEmpty) ...[
                          const AppSectionHeader('العاملين'),
                          ...employees.map((e) => ListTile(
                                leading: const Icon(Icons.person),
                                title: Text(e.name),
                                subtitle: Text('المتبقي له: ${e.remainingSalary.toStringAsFixed(0)} ج | سلف: ${e.totalAdvances.toStringAsFixed(0)} ج'),
                              )),
                        ],
                        if (suppliers.isNotEmpty) ...[
                          const AppSectionHeader('الموردين'),
                          ...suppliers.map((s) => ListTile(
                                leading: const Icon(Icons.local_shipping),
                                title: Text(s.name),
                                subtitle: Text('المستحق عليك: ${s.balanceDue.toStringAsFixed(0)} ج'),
                              )),
                        ],
                        if (commitments.isNotEmpty) ...[
                          const AppSectionHeader('الالتزامات والوعود السابقة'),
                          ...commitments.map((c) => ListTile(
                                leading: Icon(c.status == 'done' ? Icons.check_circle : Icons.schedule,
                                    color: c.status == 'done' ? AppColors.success : AppColors.warning),
                                title: Text('${c.person}${c.amount == null ? '' : ' - ${c.amount!.toStringAsFixed(0)} ج'}'),
                                subtitle: Text('${c.textOriginal}\n${c.dueDate.toString().substring(0, 10)} — ${c.status == 'done' ? 'تم' : 'لسه قائم'}'),
                                isThreeLine: true,
                              )),
                        ],
                      ],
                    ),
        ),
      ]),
    );
  }
}
