import 'package:flutter/material.dart';
import '../services/storage_service.dart';

class BriefScreen extends StatelessWidget {
  const BriefScreen({super.key});
  @override
  Widget build(BuildContext c) {
    final cs = StorageService.commitments();
    final es = StorageService.employees();
    final ss = StorageService.suppliers();
    final overdue = cs
        .where((x) => x.status == 'pending' && x.dueDate.isBefore(DateTime.now()))
        .fold(0.0, (s, x) => s + (x.amount ?? 0));
    final adv = es.fold(0.0, (s, e) => s + e.totalAdvances);
    final suppliersDue = ss.fold(0.0, (s, e) => s + e.balanceDue);
    final pendingDeliveries = ss.fold<int>(0, (s, e) => s + e.pendingDeliveries.length);

    return Scaffold(
      appBar: AppBar(title: const Text('بريف الأسبوع')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              'الالتزامات: ${cs.length}\n'
              'العاملون: ${es.length}\n'
              'الموردون: ${ss.length}\n\n'
              'المتأخرات المالية عند العملاء: ${overdue.toStringAsFixed(0)} جنيه\n'
              'إجمالي السلف للعاملين: ${adv.toStringAsFixed(0)} جنيه\n'
              'إجمالي المستحق للموردين: ${suppliersDue.toStringAsFixed(0)} جنيه\n'
              'توريدات لسه متوقعة: $pendingDeliveries\n\n'
              'هذا ملخص حسابي للبيانات المحلية.',
            ),
          ),
        ),
      ),
    );
  }
}
