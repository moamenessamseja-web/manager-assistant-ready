import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';
import '../models/employee.dart';
import '../services/storage_service.dart';
import '../design/tokens.dart';
import '../design/app_theme.dart';
import '../design/widgets.dart';

/// نماذج ملف العامل — كل نموذج يكتب بيانات حقيقية في قاعدة البيانات.
/// الملاحظات لا تُطبَّق ماليًا تلقائيًا؛ الخصم إجراء مالي مستقل بقيمة وسبب.

/// يختار صورة للعامل ويحفظها داخل مجلد التطبيق (تخزين آمن داخل sandbox)،
/// ثم يخزّن المسار النسبي في `photoPath`.
Future<bool> pickEmployeePhoto(Employee e) async {
  final picked = await ImagePicker().pickImage(
    source: ImageSource.gallery,
    maxWidth: 800,
    maxHeight: 800,
    imageQuality: 80,
  );
  if (picked == null) return false;
  final dir = await getApplicationDocumentsDirectory();
  final photos = Directory('${dir.path}/employee_photos');
  if (!photos.existsSync()) photos.createSync(recursive: true);
  final dest = '${photos.path}/${e.id}.jpg';
  await File(picked.path).copy(dest);
  e.photoPath = dest;
  await StorageService.saveEmployee(e);
  return true;
}

Future<void> showEditEmployeeSheet(BuildContext context, Employee e) async {
  final name = TextEditingController(text: e.name);
  final role = TextEditingController(text: e.role);
  final salary = TextEditingController(text: e.salaryMonthly.toStringAsFixed(0));
  final phone = TextEditingController(text: e.phone);
  final address = TextEditingController(text: e.address);
  final idNo = TextEditingController(text: e.idNumber);
  DateTime start = e.startDate;

  await showAppBottomSheet<void>(
    context: context,
    title: 'تعديل ${e.name}',
    body: StatefulBuilder(
      builder: (ctx, setSheet) => SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpace.x4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(children: [
              _PhotoSlot(employee: e, onChanged: () => setSheet(() {})),
              const SizedBox(width: AppSpace.x3),
              Expanded(
                child: Text(
                  e.photoPath.isEmpty ? 'لا توجد صورة — اضغط لإضافة صورة' : 'صورة العامل محفوظة',
                  style: AppText.caption,
                ),
              ),
            ]),
            const SizedBox(height: AppSpace.x4),
            TextField(controller: name, decoration: const InputDecoration(labelText: 'الاسم')),
            const SizedBox(height: AppSpace.x3),
            TextField(controller: role, decoration: const InputDecoration(labelText: 'الوظيفة')),
            const SizedBox(height: AppSpace.x3),
            TextField(
              controller: salary,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'الراتب الشهري (ج)'),
            ),
            const SizedBox(height: AppSpace.x3),
            TextField(
              controller: phone,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(labelText: 'الهاتف'),
            ),
            const SizedBox(height: AppSpace.x3),
            TextField(
              controller: idNo,
              decoration: const InputDecoration(labelText: 'رقم البطاقة / الهوية'),
            ),
            const SizedBox(height: AppSpace.x3),
            TextField(controller: address, decoration: const InputDecoration(labelText: 'العنوان')),
            const SizedBox(height: AppSpace.x3),
            Container(
              padding: const EdgeInsets.all(AppSpace.x3),
              decoration: BoxDecoration(
                color: AppColors.surfaceMuted,
                borderRadius: BorderRadius.circular(AppRadius.md),
              ),
              child: Row(children: [
                const Icon(Icons.calendar_today_outlined, size: 16),
                const SizedBox(width: AppSpace.x2),
                Expanded(child: Text('بداية العمل: ${start.toIso8601String().substring(0, 10)}', style: AppText.body)),
                TextButton(
                  onPressed: () async {
                    final p = await showDatePicker(
                      context: ctx,
                      initialDate: start,
                      firstDate: DateTime(2000),
                      lastDate: DateTime.now(),
                    );
                    if (p != null) setSheet(() => start = p);
                  },
                  child: const Text('تغيير'),
                ),
              ]),
            ),
            const SizedBox(height: AppSpace.x6),
            FilledButton(
              onPressed: () async {
                if (name.text.trim().isEmpty) {
                  showAppSnack(context, 'الاسم مطلوب');
                  return;
                }
                e.name = name.text.trim();
                e.role = role.text.trim();
                e.salaryMonthly = double.tryParse(salary.text.trim()) ?? e.salaryMonthly;
                e.phone = phone.text.trim();
                e.address = address.text.trim();
                e.idNumber = idNo.text.trim();
                e.startDate = start;
                await StorageService.saveEmployee(e);
                if (context.mounted) Navigator.pop(context);
              },
              child: const Text('حفظ'),
            ),
          ],
        ),
      ),
    ),
  );
}

/// تسجيل حضور/انصراف حقيقي بوقت.
Future<void> showAttendanceSheet(BuildContext context, Employee e) async {
  final now = DateTime.now();
  await showAppBottomSheet<bool>(
    context: context,
    title: 'حضور ${e.name}',
    body: Padding(
      padding: const EdgeInsets.all(AppSpace.x4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          AppInfoRow(label: 'حاضر اليوم', value: e.isPresentToday ? 'نعم' : 'لا'),
          AppInfoRow(label: 'سجّل انصراف اليوم', value: e.checkedOutToday ? 'نعم' : 'لا'),
          const SizedBox(height: AppSpace.x4),
          FilledButton.icon(
            onPressed: () async {
              e.markAttendance(now);
              await StorageService.saveEmployee(e);
              if (context.mounted) Navigator.pop(context, true);
            },
            icon: const Icon(Icons.login),
            label: const Text('تسجيل حضور الآن'),
          ),
          const SizedBox(height: AppSpace.x3),
          OutlinedButton.icon(
            onPressed: () async {
              e.markCheckout(now);
              await StorageService.saveEmployee(e);
              if (context.mounted) Navigator.pop(context, true);
            },
            icon: const Icon(Icons.logout),
            label: const Text('تسجيل انصراف الآن'),
          ),
        ],
      ),
    ),
  );
}

Future<void> showAdvanceSheet(BuildContext context, Employee e) => _moneySheet(
      context,
      e,
      title: 'سلفة لـ ${e.name}',
      label: 'المبلغ (ج)',
      hint: '500',
      onSave: (amount, note) {
        e.advances.add(Advance(id: const Uuid().v4(), amount: amount, date: DateTime.now(), note: note));
      },
    );

Future<void> showPaymentSheet(BuildContext context, Employee e) => _moneySheet(
      context,
      e,
      title: 'دفعة راتب لـ ${e.name}',
      label: 'المبلغ المدفوع (ج)',
      hint: '3000',
      onSave: (amount, note) {
        e.payments.add(EmployeePayment(id: const Uuid().v4(), amount: amount, date: DateTime.now(), note: note));
      },
    );

Future<void> showDeductionSheet(BuildContext context, Employee e) => _moneySheet(
      context,
      e,
      title: 'خصم على ${e.name}',
      label: 'قيمة الخصم (ج)',
      hint: '200',
      reasonLabel: 'سبب الخصم',
      reasonHint: 'مثال: غياب 3 أيام',
      onSave: (amount, reason) {
        e.deductions.add(EmployeeDeduction(
            id: const Uuid().v4(), amount: amount, reason: reason, date: DateTime.now()));
      },
    );

Future<void> showBonusSheet(BuildContext context, Employee e) => _moneySheet(
      context,
      e,
      title: 'مكافأة لـ ${e.name}',
      label: 'قيمة المكافأة (ج)',
      hint: '300',
      reasonLabel: 'سبب المكافأة',
      reasonHint: 'مثال: أداء ممتاز',
      onSave: (amount, reason) {
        e.bonuses.add(EmployeeBonus(
            id: const Uuid().v4(), amount: amount, reason: reason, date: DateTime.now()));
      },
    );

Future<void> showNoteSheet(BuildContext context, Employee e) async {
  final text = TextEditingController();
  await showAppBottomSheet<void>(
    context: context,
    title: 'ملاحظة على ${e.name}',
    body: Padding(
      padding: const EdgeInsets.all(AppSpace.x4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(AppSpace.x3),
            decoration: BoxDecoration(
              color: AppColors.surfaceMuted,
              borderRadius: BorderRadius.circular(AppRadius.md),
            ),
            child: Text(
              'الملاحظة ده مش بتتطبّق ماليًا. لو عايز خصم فعلي، سجّله من "خصم" بقيمة وسبب.',
              style: AppText.caption,
            ),
          ),
          const SizedBox(height: AppSpace.x4),
          TextField(
            controller: text,
            maxLines: 3,
            autofocus: true,
            decoration: const InputDecoration(labelText: 'الملاحظة', hintText: 'مثال: غاب 3 أيام — بموافقة'),
          ),
          const SizedBox(height: AppSpace.x6),
          FilledButton(
            onPressed: () async {
              if (text.text.trim().isEmpty) return;
              e.notes.add(EmployeeNote(id: const Uuid().v4(), text: text.text.trim(), date: DateTime.now()));
              await StorageService.saveEmployee(e);
              if (context.mounted) Navigator.pop(context);
            },
            child: const Text('حفظ الملاحظة'),
          ),
        ],
      ),
    ),
  );
}

/// نموذج مبلغ موحّد (سلفة/دفعة/خصم/مكافأة) — بيمنع النجاح الوهمي.
Future<void> _moneySheet(
  BuildContext context,
  Employee e, {
  required String title,
  required String label,
  String hint = '',
  String? reasonLabel,
  String? reasonHint,
  required void Function(double amount, String extra) onSave,
}) async {
  final amount = TextEditingController();
  final extra = TextEditingController();
  await showAppBottomSheet<void>(
    context: context,
    title: title,
    body: Padding(
      padding: const EdgeInsets.all(AppSpace.x4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: amount,
            autofocus: true,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(labelText: label, hintText: hint),
          ),
          const SizedBox(height: AppSpace.x3),
          TextField(
            controller: extra,
            maxLines: 2,
            decoration: InputDecoration(
              labelText: reasonLabel ?? 'ملاحظة (اختياري)',
              hintText: reasonHint ?? '',
            ),
          ),
          const SizedBox(height: AppSpace.x6),
          FilledButton(
            onPressed: () async {
              final a = double.tryParse(amount.text.trim()) ?? 0;
              if (a <= 0) {
                showAppSnack(context, 'أدخل مبلغًا صحيحًا');
                return;
              }
              onSave(a, extra.text.trim());
              await StorageService.saveEmployee(e);
              if (context.mounted) Navigator.pop(context);
            },
            child: const Text('حفظ'),
          ),
        ],
      ),
    ),
  );
}

/// أرشفة / إلغاء أرشفة العامل (لا يُحذف السجل التاريخي).
Future<void> archiveEmployee(BuildContext context, Employee e) async {
  final next = !e.archived;
  if (next) {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('أرشفة العامل؟'),
        content: const Text('هيتخفى من القوائم النشطة، وكل السجلات (حضور/سلف/رواتب) تفضل محفوظة.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('إلغاء')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('أرشفة')),
        ],
      ),
    );
    if (ok != true) return;
  }
  e.archived = next;
  await StorageService.saveEmployee(e);
  if (context.mounted) showAppSnack(context, next ? 'تم أرشفة ${e.name}' : 'تم إلغاء أرشفة ${e.name}');
}

/// حذف نهائي — مسموح فقط لعامل بلا أي سجل تاريخي.
Future<bool> deleteEmployeeSafely(BuildContext context, Employee e) async {
  if (e.hasHistory) {
    await showDialog<void>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('لا يمكن الحذف النهائي'),
        content: Text('${e.name} عنده سجلات (حضور/سلف/رواتب). استخدم الأرشفة للحفاظ على التاريخ.'),
        actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('تمام'))],
      ),
    );
    return false;
  }
  final ok = await showDialog<bool>(
    context: context,
    builder: (_) => AlertDialog(
      title: const Text('حذف العامل نهائيًا؟'),
      content: const Text('لا يوجد سجلات مرتبطة — الحذف آمن ولا يمكن التراجع.'),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('إلغاء')),
        TextButton(
          onPressed: () => Navigator.pop(context, true),
          child: const Text('حذف', style: TextStyle(color: AppColors.danger)),
        ),
      ],
    ),
  );
  if (ok != true) return false;
  await StorageService.deleteEmployee(e.id);
  if (context.mounted) showAppSnack(context, 'تم حذف ${e.name}');
  return true;
}

/// مربع الصورة (اختيار/استبدال/حالة فراغ واضحة).
class _PhotoSlot extends StatelessWidget {
  final Employee employee;
  final VoidCallback onChanged;
  const _PhotoSlot({required this.employee, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final has = employee.photoPath.isNotEmpty && File(employee.photoPath).existsSync();
    return GestureDetector(
      onTap: () async {
        final ok = await pickEmployeePhoto(employee);
        if (ok) onChanged();
      },
      child: Container(
        width: 72,
        height: 72,
        decoration: BoxDecoration(
          color: AppColors.surfaceMuted,
          borderRadius: BorderRadius.circular(AppRadius.md),
          border: Border.all(color: AppColors.border),
        ),
        clipBehavior: Clip.antiAlias,
        child: has
            ? Image.file(File(employee.photoPath), fit: BoxFit.cover)
            : Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.add_a_photo_outlined, size: AppIconSize.md, color: AppColors.textSecondary),
                  const SizedBox(height: 2),
                  Text('صورة', style: AppText.caption.copyWith(fontSize: 10)),
                ],
              ),
      ),
    );
  }
}

/// يُستخدم من شاشة التفاصيل لعرض الصورة (نفس منطق الحالة الفارغة).
class EmployeePhoto extends StatelessWidget {
  final Employee employee;
  final double size;
  const EmployeePhoto({super.key, required this.employee, this.size = 56});

  @override
  Widget build(BuildContext context) => _PhotoSlot(employee: employee, onChanged: () {});
}
