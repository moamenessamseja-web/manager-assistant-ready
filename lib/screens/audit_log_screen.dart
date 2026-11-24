import 'package:flutter/material.dart';
import '../design/format.dart';
import '../design/tokens.dart';
import '../design/widgets.dart';
import '../services/app_state.dart';
import '../services/storage_service.dart';

/// سجل التصحيحات: كل حركة اتلغت (مع سببها ووقتها). الحركة الأصلية محفوظة
/// كاملة هنا — الرصيد بيتحسب من الحركات الفعالة بس.
class AuditLogScreen extends StatelessWidget {
  const AuditLogScreen({super.key});

  static const _owner = {'employee': 'موظف', 'supplier': 'مورد', 'customer': 'عميل'};

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: AppState.instance,
      builder: (context, _) {
        final list = StorageService.auditLog()..sort((a, b) => b.at.compareTo(a.at));
        return Scaffold(
          appBar: AppBar(title: const Text('سجل التصحيحات')),
          body: list.isEmpty
              ? const AppEmptyState(
                  icon: Icons.history,
                  title: 'مفيش تصحيحات',
                  subtitle: 'أي حركة تتلغي هتظهر هنا مع السبب.',
                )
              : ListView(
                  padding: const EdgeInsets.all(AppSpace.x4),
                  children: [
                    for (final a in list)
                      Card(
                        child: ListTile(
                          leading: const Icon(Icons.undo, color: AppColors.warning),
                          title: Text('${_owner[a.ownerType] ?? ''} ${a.ownerName}: ${a.summary}'),
                          subtitle: Text('السبب: ${a.reason}\n${arabicDateTime(a.at)}'),
                          isThreeLine: true,
                        ),
                      ),
                  ],
                ),
        );
      },
    );
  }
}
