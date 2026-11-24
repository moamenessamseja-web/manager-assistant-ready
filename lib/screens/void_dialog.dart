import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../design/tokens.dart';
import '../models/audit_entry.dart';
import '../services/app_error_service.dart';
import '../services/storage_service.dart';

/// بيسأل عن سبب إلغاء حركة مالية (إجباري). الحركة مش بتتمسح من التاريخ:
/// بتتحفظ كاملة في «سجل التصحيحات» مع السبب والوقت.
Future<String?> askCorrectionReason(BuildContext context,
    {required String title, required String summary}) async {
  final ctrl = TextEditingController();
  final r = await showDialog<String>(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setS) => AlertDialog(
        title: Text(title),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(summary),
              const SizedBox(height: 8),
              const Text(
                'الحركة مش هتتمسح من التاريخ: هتتحفظ في «سجل التصحيحات» مع السبب '
                'والوقت، والأرصدة هتتحسب من غيرها.',
                style: TextStyle(fontSize: 12),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: ctrl,
                autofocus: true,
                onChanged: (_) => setS(() {}),
                decoration: const InputDecoration(labelText: 'سبب الإلغاء (مطلوب)'),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('تراجع')),
          TextButton(
            onPressed: ctrl.text.trim().length >= 2 ? () => Navigator.pop(ctx, ctrl.text.trim()) : null,
            child: const Text('إلغاء الحركة', style: TextStyle(color: AppColors.danger)),
          ),
        ],
      ),
    ),
  );
  ctrl.dispose();
  return r;
}

/// ينفّذ إلغاء حركة بتتبّع كامل: (١) يسأل عن السبب (٢) يسجّل التصحيح الأول
/// (٣) ينفّذ الإلغاء الفعلي. لو التنفيذ فشل بنشيل التصحيح (مفيش أثر وهمي) وبنعرض
/// رسالة صريحة. بترجّع true لو اتنفّذ فعلًا.
Future<bool> voidWithAudit(
  BuildContext context, {
  required String title,
  required String summary,
  required AuditEntry Function(String id, String reason, DateTime at) entry,
  required Future<void> Function() apply,
}) async {
  final reason = await askCorrectionReason(context, title: title, summary: summary);
  if (reason == null) return false;
  final e = entry(const Uuid().v4(), reason, DateTime.now());
  await StorageService.addAudit(e);
  try {
    await apply();
    return true;
  } catch (err, st) {
    AppErrorService.log('audit.apply', err, st);
    await StorageService.removeAudit(e.id);
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تعذّر إلغاء الحركة. مفيش حاجة اتغيّرت.')),
      );
    }
    return false;
  }
}
