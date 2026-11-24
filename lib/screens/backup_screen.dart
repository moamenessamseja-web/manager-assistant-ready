import 'dart:io';
import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import '../design/app_theme.dart';
import '../design/format.dart';
import '../design/tokens.dart';
import '../design/widgets.dart';
import '../services/app_error_service.dart';
import '../services/app_state.dart';
import '../services/backup_codec.dart';
import '../services/backup_service.dart';
import '../services/cafe_profile_service.dart';
import '../services/notification_prefs.dart';
import '../services/notification_service.dart';
import '../services/reminder_service.dart';
import '../services/settings_service.dart';
import '../services/storage_service.dart';

/// النسخ الاحتياطي والاسترجاع. البيانات على الجهاز بس — النسخة الاحتياطية هي
/// الحماية الوحيدة لو التليفون ضاع.
class BackupScreen extends StatefulWidget {
  const BackupScreen({super.key});
  @override
  State<BackupScreen> createState() => _BackupScreenState();
}

class _BackupScreenState extends State<BackupScreen> {
  bool _busy = false;
  List<File> _safety = [];

  PrefsStore get _store => SharedPrefsStore(StorageService.prefs);

  @override
  void initState() {
    super.initState();
    _loadSafety();
  }

  Future<void> _loadSafety() async {
    try {
      final s = await BackupService.safetyBackups();
      if (mounted) setState(() => _safety = s);
    } catch (_) {}
  }

  void _snack(String m) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));

  Future<void> _export() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final f = await BackupService.exportToTempFile(_store);
      await SharePlus.instance.share(ShareParams(
        files: [XFile(f.path, mimeType: 'application/json')],
        subject: 'نسخة احتياطية — ${CafeProfileService.displayName}',
        text: 'نسخة احتياطية من بيانات ${CafeProfileService.displayName}. احتفظ بيها في مكان آمن.',
      ));
    } catch (e, st) {
      AppErrorService.log('backup.export', e, st);
      _snack('تعذّر إنشاء النسخة الاحتياطية.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _pickAndRestore() async {
    if (_busy) return;
    try {
      final XFile? f = await openFile();
      if (f == null) return;
      final text = await f.readAsString();
      await _confirmAndRestore(text);
    } on BackupException catch (e) {
      _snack(e.message);
    } catch (e, st) {
      AppErrorService.log('backup.pick', e, st);
      _snack('تعذّر قراءة الملف.');
    }
  }

  Future<void> _restoreSafety(File f) async {
    try {
      await _confirmAndRestore(await f.readAsString());
    } on BackupException catch (e) {
      _snack(e.message);
    }
  }

  String _summaryText(BackupDecoded d) {
    final c = d.summary.counts;
    return 'تاريخ النسخة: ${arabicDateTime(d.createdAt)}\n'
        'موظفين: ${c['employees']} · موردين: ${c['suppliers']} · عملاء: ${c['customers']}\n'
        'التزامات: ${c['commitments']} · تذكيرات: ${c['reminders']} · شيفتات: ${c['shifts']}\n'
        'إقفالات يومية: ${c['daily_closings']} · نواقص: ${c['shortages']} · تصحيحات: ${c['audit_log']}\n'
        'مستحقات العملاء: ${money(d.summary.receivables)} · المستحق للموردين: ${money(d.summary.suppliersDue)}';
  }

  Future<void> _confirmAndRestore(String text) async {
    final d = BackupCodec.decode(text); // بيرفض أي ملف فاسد قبل أي تغيير
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('استرجاع النسخة دي؟'),
        content: SingleChildScrollView(
          child: Text('${_summaryText(d)}\n\n'
              '⚠️ الاسترجاع بيستبدل كل بياناتك الحالية بمحتوى النسخة دي. '
              'هنعمل نسخة أمان تلقائية من بياناتك الحالية قبل الاستبدال، وتقدر ترجع لها من نفس الشاشة.'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('تراجع')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('استرجع')),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    setState(() => _busy = true);
    try {
      final oldReminders = StorageService.reminders().map((r) => r.id).toSet();
      final res = await BackupService.restore(_store, d);
      // إعادة تحميل الإعدادات وجدولة التذكيرات من البيانات المسترجعة
      await SettingsService.init();
      await NotificationPrefs.init();
      await CafeProfileService.init();
      try {
        final now = StorageService.reminders().map((r) => r.id).toSet();
        for (final id in oldReminders.difference(now)) {
          await NotificationService.cancel(id);
        }
        await ReminderService.rescheduleAllActive();
      } catch (e, st) {
        AppErrorService.log('backup.reschedule', e, st);
      }
      AppState.instance.notify();
      await _loadSafety();
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text('تم الاسترجاع ✅'),
          content: Text('${_summaryText(d)}\n\nنسخة الأمان: ${res.safetyBackupName ?? ''}'),
          actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('تمام'))],
        ),
      );
    } on BackupException catch (e) {
      _snack(e.message);
    } catch (e, st) {
      AppErrorService.log('backup.restore', e, st);
      _snack('حصلت مشكلة. بياناتك زي ما كانت.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final last = BackupService.lastBackupAt(_store);
    final stale = last == null || DateTime.now().difference(last).inDays >= 7;
    return Scaffold(
      appBar: AppBar(title: const Text('النسخ الاحتياطي')),
      body: ListView(
        padding: const EdgeInsets.all(AppSpace.x4),
        children: [
          AppCard(
            backgroundColor: stale ? AppColors.warning.withValues(alpha: 0.12) : null,
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('آخر نسخة احتياطية', style: AppText.titleMedium),
              const SizedBox(height: 4),
              Text(last == null
                  ? 'لسه ما عملتش نسخة. بياناتك على التليفون ده بس — لو ضاع هتضيع.'
                  : '${arabicDateTime(last)}${stale ? '  (من أكتر من أسبوع — يُفضّل تعمل نسخة جديدة)' : ''}'),
            ]),
          ),
          const SizedBox(height: AppSpace.x3),
          FilledButton.icon(
            onPressed: _busy ? null : _export,
            icon: const Icon(Icons.ios_share),
            label: const Text('تصدير نسخة احتياطية ومشاركتها'),
          ),
          const SizedBox(height: AppSpace.x2),
          OutlinedButton.icon(
            onPressed: _busy ? null : _pickAndRestore,
            icon: const Icon(Icons.restore),
            label: const Text('استرجاع من نسخة'),
          ),
          if (_busy) const Padding(padding: EdgeInsets.all(AppSpace.x3), child: LinearProgressIndicator()),
          const SizedBox(height: AppSpace.x4),
          Text(
            'بتتحفظ: الموظفين والحضور والسلف، الموردين، العملاء والمستحقات، الالتزامات والتذكيرات، الشيفتات '
            'والإقفالات، النواقص، سجل التصحيحات، اسم الكافيه وشعاره، وصور الموظفين، والإعدادات.\n'
            'مش بتتحفظ: سجل المحادثة.\n'
            'الاسترجاع بيستبدل كل البيانات الحالية (مش بيدمج). ابعت الملف لنفسك على واتساب أو إيميل أو خزّنه في مكان آمن.',
            style: AppText.caption,
          ),
          if (_safety.isNotEmpty) ...[
            const SizedBox(height: AppSpace.x4),
            AppSectionHeader(title: 'نسخ الأمان التلقائية (قبل كل استرجاع)'),
            for (final f in _safety)
              Card(
                child: ListTile(
                  leading: const Icon(Icons.history),
                  title: Text(f.uri.pathSegments.last, style: const TextStyle(fontSize: 12)),
                  trailing: TextButton(
                    onPressed: _busy ? null : () => _restoreSafety(f),
                    child: const Text('رجّع'),
                  ),
                ),
              ),
          ],
        ],
      ),
    );
  }
}
