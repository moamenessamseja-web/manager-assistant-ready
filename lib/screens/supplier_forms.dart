import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../models/supplier.dart';
import '../services/storage_service.dart';
import '../design/tokens.dart';
import '../design/app_theme.dart';
import '../design/widgets.dart';
import '../design/format.dart';

/// نماذج إدخال المورد — مساران منفصلان بوضوح:
///  • تسجيل توريد بقيمة (بضاعة مستلمة) → يزوّد "إجمالي البضاعة".
///  • تسجيل دفعة (نقد مدفوع) → يزوّد "إجمالي المدفوع".
/// الفصل ده هو جوهر إصلاح خلط قيمة البضاعة بالمدفوعات.

Future<Supplier?> showAddSupplierSheet(BuildContext context) async {
  final name = TextEditingController();
  final item = TextEditingController();
  final phone = TextEditingController();

  return showAppBottomSheet<Supplier>(
    context: context,
    title: 'إضافة مورد',
    body: Padding(
      padding: const EdgeInsets.all(AppSpace.x4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: name,
            textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(
              labelText: 'اسم المورد',
              hintText: 'مثال: محمود للبن',
            ),
          ),
          const SizedBox(height: AppSpace.x3),
          TextField(
            controller: item,
            decoration: const InputDecoration(
              labelText: 'الصنف (اختياري)',
              hintText: 'بن، لبن، حديد…',
            ),
          ),
          const SizedBox(height: AppSpace.x3),
          TextField(
            controller: phone,
            keyboardType: TextInputType.phone,
            decoration: const InputDecoration(
              labelText: 'التليفون (اختياري)',
              hintText: '01012345678',
            ),
          ),
          const SizedBox(height: AppSpace.x6),
          FilledButton(
            onPressed: () async {
              final n = name.text.trim();
              if (n.isEmpty) {
                showAppSnack(context, 'من فضلك أدخل اسم المورد');
                return;
              }
              final s = Supplier(
                id: const Uuid().v4(),
                name: n,
                itemType: item.text.trim(),
                phone: phone.text.trim(),
              );
              await StorageService.saveSupplier(s);
              if (context.mounted) Navigator.pop(context, s);
            },
            child: const Text('إضافة المورد'),
          ),
        ],
      ),
    ),
  );
}

Future<Supplier?> showEditSupplierSheet(BuildContext context, Supplier s) async {
  final name = TextEditingController(text: s.name);
  final item = TextEditingController(text: s.itemType);
  final phone = TextEditingController(text: s.phone);
  final note = TextEditingController(text: s.note);

  return showAppBottomSheet<Supplier>(
    context: context,
    title: 'تعديل ${s.name}',
    body: SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpace.x4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(controller: name, decoration: const InputDecoration(labelText: 'اسم المورد')),
          const SizedBox(height: AppSpace.x3),
          TextField(controller: item, decoration: const InputDecoration(labelText: 'الصنف')),
          const SizedBox(height: AppSpace.x3),
          TextField(
            controller: phone,
            keyboardType: TextInputType.phone,
            decoration: const InputDecoration(labelText: 'التليفون'),
          ),
          const SizedBox(height: AppSpace.x3),
          TextField(
            controller: note,
            maxLines: 3,
            decoration: const InputDecoration(labelText: 'ملاحظات'),
          ),
          const SizedBox(height: AppSpace.x6),
          FilledButton(
            onPressed: () async {
              if (name.text.trim().isEmpty) {
                showAppSnack(context, 'اسم المورد مطلوب');
                return;
              }
              s.name = name.text.trim();
              s.itemType = item.text.trim();
              s.phone = phone.text.trim();
              s.note = note.text.trim();
              await StorageService.saveSupplier(s);
              if (context.mounted) Navigator.pop(context, s);
            },
            child: const Text('حفظ التعديلات'),
          ),
        ],
      ),
    ),
  );
}

/// تسجيل توريد بقيمة (بضاعة مستلمة). يرجع true لو اتسجل فعلاً.
Future<bool> showAddPurchaseSheet(BuildContext context, Supplier s) async {
  final item = TextEditingController(text: s.itemType);
  final qty = TextEditingController();
  final unit = TextEditingController();
  final unitPrice = TextEditingController();
  final total = TextEditingController();
  final note = TextEditingController();

  final res = await showAppBottomSheet<bool>(
    context: context,
    title: 'تسجيل توريد بقيمة',
    body: StatefulBuilder(
      builder: (ctx, setSheet) => SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpace.x4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              padding: const EdgeInsets.all(AppSpace.x3),
              decoration: BoxDecoration(
                color: AppColors.infoTint,
                borderRadius: BorderRadius.circular(AppRadius.md),
              ),
              child: Row(children: [
                const Icon(Icons.inventory_2_outlined, size: 18, color: AppColors.info),
                const SizedBox(width: AppSpace.x2),
                Expanded(
                  child: Text(
                    'قيمة البضاعة تُسجَّل كدين على المحل — مش دفعة نقدية.',
                    style: AppText.caption.copyWith(color: AppColors.info),
                  ),
                ),
              ]),
            ),
            const SizedBox(height: AppSpace.x4),
            TextField(
              controller: item,
              decoration: const InputDecoration(labelText: 'الصنف', hintText: 'بن، لبن، حديد…'),
            ),
            const SizedBox(height: AppSpace.x3),
            Row(children: [
              Expanded(
                child: TextField(
                  controller: qty,
                  keyboardType: TextInputType.number,
                  onChanged: (_) => setSheet(() {}),
                  decoration: const InputDecoration(labelText: 'الكمية'),
                ),
              ),
              const SizedBox(width: AppSpace.x3),
              Expanded(
                child: TextField(
                  controller: unit,
                  decoration: const InputDecoration(labelText: 'الوحدة', hintText: 'كيلو، كرتونة'),
                ),
              ),
            ]),
            const SizedBox(height: AppSpace.x3),
            TextField(
              controller: unitPrice,
              keyboardType: TextInputType.number,
              onChanged: (_) => setSheet(() {}),
              decoration: const InputDecoration(labelText: 'سعر الوحدة (ج)', hintText: 'اختياري'),
            ),
            const SizedBox(height: AppSpace.x3),
            TextField(
              controller: total,
              keyboardType: TextInputType.number,
              onChanged: (_) => setSheet(() {}),
              decoration: const InputDecoration(
                labelText: 'الإجمالي (ج)',
                hintText: 'اتركه فاضي لو محسوب من الكمية × السعر',
              ),
            ),
            const SizedBox(height: AppSpace.x2),
            Text(
              _previewTotal(qty.text, unitPrice.text, total.text),
              style: AppText.caption.copyWith(color: AppColors.textPrimary, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: AppSpace.x3),
            TextField(
              controller: note,
              maxLines: 2,
              decoration: const InputDecoration(labelText: 'ملاحظات (اختياري)'),
            ),
            const SizedBox(height: AppSpace.x6),
            FilledButton(
              onPressed: () async {
                final t = _resolveTotal(qty.text, unitPrice.text, total.text);
                if (t <= 0) {
                  showAppSnack(context, 'محتاج قيمة التوريد أو الكمية وسعر الوحدة');
                  return;
                }
                final q = double.tryParse(qty.text.trim());
                final up = double.tryParse(unitPrice.text.trim()) ?? 0;
                s.purchases.add(SupplierPurchase(
                  id: const Uuid().v4(),
                  item: item.text.trim().isEmpty ? s.itemType : item.text.trim(),
                  quantity: q,
                  unit: unit.text.trim(),
                  unitPrice: up > 0 ? up : (q != null && q > 0 ? t / q : 0),
                  total: t,
                  date: DateTime.now(),
                  note: note.text.trim(),
                ));
                await StorageService.saveSupplier(s);
                if (context.mounted) Navigator.pop(context, true);
              },
              child: const Text('تسجيل التوريد'),
            ),
          ],
        ),
      ),
    ),
  );
  return res ?? false;
}

double _resolveTotal(String qty, String unitPrice, String total) {
  final t = double.tryParse(total.trim()) ?? 0;
  if (t > 0) return t;
  final q = double.tryParse(qty.trim());
  final up = double.tryParse(unitPrice.trim()) ?? 0;
  if (q != null && q > 0 && up > 0) return q * up;
  return 0;
}

String _previewTotal(String qty, String unitPrice, String total) {
  final t = _resolveTotal(qty, unitPrice, total);
  if (t <= 0) return 'الإجمالي هيظهر هنا';
  return 'الإجمالي: ${money(t)}';
}

/// تسجيل دفعة نقدية فعلية للمورد.
Future<bool> showAddPaymentSheet(BuildContext context, Supplier s) async {
  final amount = TextEditingController();
  final note = TextEditingController();
  String method = 'كاش';

  final res = await showAppBottomSheet<bool>(
    context: context,
    title: 'تسجيل دفعة',
    body: StatefulBuilder(
      builder: (ctx, setSheet) => SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpace.x4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              padding: const EdgeInsets.all(AppSpace.x3),
              decoration: BoxDecoration(
                color: AppColors.accentTint,
                borderRadius: BorderRadius.circular(AppRadius.md),
              ),
              child: Row(children: [
                const Icon(Icons.info_outline, size: 18, color: AppColors.accentStrong),
                const SizedBox(width: AppSpace.x2),
                Expanded(
                  child: Text(
                    'المتبقي الحالي للمورد: ${money(s.balanceDue)}',
                    style: AppText.caption.copyWith(color: AppColors.accentStrong),
                  ),
                ),
              ]),
            ),
            const SizedBox(height: AppSpace.x4),
            TextField(
              controller: amount,
              autofocus: true,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'المبلغ المدفوع (ج)', hintText: '500'),
            ),
            const SizedBox(height: AppSpace.x3),
            Wrap(
              spacing: AppSpace.x2,
              children: [
                for (final m in ['كاش', 'تحويل', 'شيك'])
                  ChoiceChip(
                    label: Text(m),
                    selected: method == m,
                    onSelected: (_) => setSheet(() => method = m),
                  ),
              ],
            ),
            const SizedBox(height: AppSpace.x3),
            TextField(
              controller: note,
              maxLines: 2,
              decoration: const InputDecoration(labelText: 'ملاحظات (اختياري)'),
            ),
            const SizedBox(height: AppSpace.x6),
            FilledButton(
              onPressed: () async {
                final amt = double.tryParse(amount.text.trim()) ?? 0;
                if (amt <= 0) {
                  showAppSnack(context, 'أدخل مبلغًا صحيحًا');
                  return;
                }
                s.payments.add(SupplierPayment(
                  id: const Uuid().v4(),
                  amount: amt,
                  date: DateTime.now(),
                  note: note.text.trim(),
                  method: method,
                ));
                await StorageService.saveSupplier(s);
                if (context.mounted) Navigator.pop(context, true);
              },
              child: const Text('تسجيل الدفعة'),
            ),
          ],
        ),
      ),
    ),
  );
  return res ?? false;
}

/// أرشفة / إلغاء أرشفة — العملية الافتراضية للمورد اللي عنده تاريخ.
Future<void> archiveSupplier(BuildContext context, Supplier s) async {
  final next = !s.archived;
  if (next) {
    final ok = await _confirm(
      context,
      title: 'أرشفة المورد؟',
      message: 'هيتخفى من القوائم النشطة، وكل السجلات المالية تفضل محفوظة.',
      confirmLabel: 'أرشفة',
    );
    if (ok != true) return;
  }
  s.archived = next;
  await StorageService.saveSupplier(s);
  if (context.mounted) {
    showAppSnack(
      context,
      next ? 'تم أرشفة ${s.name} — يمكنك التراجع من الفلتر' : 'تم إلغاء أرشفة ${s.name}',
    );
  }
}

/// حذف نهائي — مسموح فقط لمورد بلا أي سجل تاريخي.
Future<bool> deleteSupplierSafely(BuildContext context, Supplier s) async {
  if (s.hasHistory) {
    await _info(
      context,
      title: 'لا يمكن الحذف النهائي',
      message: 'المورد ${s.name} عنده سجلات مالية/تاريخية. استخدم الأرشفة للحفاظ على التاريخ.',
    );
    return false;
  }
  final ok = await _confirm(
    context,
    title: 'حذف المورد نهائيًا؟',
    message: 'لا يوجد سجلات مرتبطة، فالحذف آمن — لكن لا يمكن التراجع.',
    confirmLabel: 'حذف',
    destructive: true,
  );
  if (ok != true) return false;
  await StorageService.deleteSupplier(s.id);
  if (context.mounted) showAppSnack(context, 'تم حذف ${s.name}');
  return true;
}

Future<bool?> _confirm(
  BuildContext context, {
  required String title,
  required String message,
  required String confirmLabel,
  bool destructive = false,
}) {
  return showDialog<bool>(
    context: context,
    builder: (_) => AlertDialog(
      title: Text(title),
      content: Text(message),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('إلغاء')),
        TextButton(
          onPressed: () => Navigator.pop(context, true),
          child: Text(
            confirmLabel,
            style: TextStyle(color: destructive ? AppColors.danger : AppColors.primary),
          ),
        ),
      ],
    ),
  );
}

Future<void> _info(BuildContext context, {required String title, required String message}) async {
  await showDialog<void>(
    context: context,
    builder: (_) => AlertDialog(
      title: Text(title),
      content: Text(message),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('تمام')),
      ],
    ),
  );
}
