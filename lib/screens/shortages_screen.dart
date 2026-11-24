import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../design/app_theme.dart';
import '../design/format.dart';
import '../design/tokens.dart';
import '../design/widgets.dart';
import '../models/shortage.dart';
import '../services/app_state.dart';
import '../services/storage_service.dart';
import 'form_sheet.dart';
import 'receivables_screen.dart' show parseMoney;

/// النواقص — قائمة «لازم أشتري». مش مخزون: مفيش رصيد ولا خصم تلقائي ولا
/// أي أثر على حسابات الموردين أو الفلوس.
class ShortagesScreen extends StatefulWidget {
  const ShortagesScreen({super.key});
  @override
  State<ShortagesScreen> createState() => _ShortagesScreenState();
}

const _statusLabel = {
  ShortageItem.pending: 'مطلوب',
  ShortageItem.ordered: 'تم الطلب',
  ShortageItem.purchased: 'تم الشراء',
  ShortageItem.cancelled: 'ملغي',
};

class _ShortagesScreenState extends State<ShortagesScreen> {
  bool _showHistory = false;

  Future<void> _setStatus(ShortageItem x, String status) async {
    x.setStatus(status, DateTime.now());
    await StorageService.saveShortage(x);
  }

  Future<void> _edit(ShortageItem? existing) =>
      showFormSheet<void>(context, _ShortageForm(existing: existing));

  void _history(ShortageItem x) {
    showDialog<void>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(x.item),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (final e in x.history)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  child: Text('${_statusLabel[e.status] ?? e.status} — ${arabicDateTime(e.at)}'),
                ),
              if (x.note.isNotEmpty) ...[const SizedBox(height: 8), Text('ملاحظة: ${x.note}')],
            ],
          ),
        ),
        actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('تمام'))],
      ),
    );
  }

  Widget _tile(ShortageItem x) {
    final sub = <String>[
      _statusLabel[x.status] ?? x.status,
      if (x.supplierName.isNotEmpty) 'المورد: ${x.supplierName}',
      if (x.note.isNotEmpty) x.note,
    ].join(' · ');
    return Card(
      child: ListTile(
        onTap: () => _history(x),
        leading: Icon(
          x.isDone ? Icons.check_circle : (x.status == ShortageItem.ordered ? Icons.local_shipping_outlined : Icons.shopping_basket_outlined),
          color: x.isDone ? AppColors.success : AppColors.warning,
        ),
        title: Text(x.quantityLabel.isEmpty ? x.item : '${x.item} — ${x.quantityLabel}'),
        subtitle: Text(sub),
        trailing: PopupMenuButton<String>(
          onSelected: (v) {
            if (v == 'edit') {
              _edit(x);
            } else {
              _setStatus(x, v);
            }
          },
          itemBuilder: (_) => [
            if (x.status == ShortageItem.pending)
              const PopupMenuItem(value: ShortageItem.ordered, child: Text('تم الطلب')),
            if (x.isOutstanding)
              const PopupMenuItem(value: ShortageItem.purchased, child: Text('تم الشراء ✔')),
            if (!x.isOutstanding)
              const PopupMenuItem(value: ShortageItem.pending, child: Text('إعادة فتح (مطلوب)')),
            const PopupMenuItem(value: 'edit', child: Text('تعديل')),
            if (x.isOutstanding)
              const PopupMenuItem(value: ShortageItem.cancelled, child: Text('إلغاء الطلب')),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: AppState.instance,
      builder: (context, _) {
        final all = StorageService.shortages()..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
        final outstanding = all.where((x) => x.isOutstanding).toList();
        final history = all.where((x) => !x.isOutstanding).toList();
        final list = _showHistory ? history : outstanding;
        return Scaffold(
          appBar: AppBar(title: const Text('النواقص')),
          floatingActionButton: FloatingActionButton.extended(
            onPressed: () => _edit(null),
            icon: const Icon(Icons.add),
            label: const Text('إضافة نقص'),
          ),
          body: ListView(
            padding: const EdgeInsets.fromLTRB(AppSpace.x4, AppSpace.x3, AppSpace.x4, 96),
            children: [
              Text(
                'قائمة بالحاجات اللي محتاج تشتريها. مش مخزون ومبتلمسش حسابات الموردين أو الفلوس.',
                style: AppText.caption,
              ),
              const SizedBox(height: AppSpace.x3),
              Wrap(
                spacing: AppSpace.x2,
                children: [
                  ChoiceChip(
                    label: Text('مطلوب (${outstanding.length})'),
                    selected: !_showHistory,
                    onSelected: (_) => setState(() => _showHistory = false),
                  ),
                  ChoiceChip(
                    label: Text('تم / ملغي (${history.length})'),
                    selected: _showHistory,
                    onSelected: (_) => setState(() => _showHistory = true),
                  ),
                ],
              ),
              const SizedBox(height: AppSpace.x3),
              if (list.isEmpty)
                AppEmptyState(
                  icon: Icons.shopping_basket_outlined,
                  title: _showHistory ? 'مفيش سجل لسه' : 'مفيش نواقص دلوقتي',
                  subtitle: _showHistory ? '' : 'اضغط «إضافة نقص» وسجّل اللي محتاج تشتريه.',
                )
              else
                for (final x in list) _tile(x),
            ],
          ),
        );
      },
    );
  }
}

class _ShortageForm extends StatefulWidget {
  final ShortageItem? existing;
  const _ShortageForm({this.existing});
  @override
  State<_ShortageForm> createState() => _ShortageFormState();
}

class _ShortageFormState extends State<_ShortageForm> {
  late final TextEditingController _item;
  late final TextEditingController _qty;
  late final TextEditingController _unit;
  late final TextEditingController _note;
  late String _supplierId;
  final String _newId = const Uuid().v4(); // ثابت للنموذج: ضغطتين = طلب واحد
  String? _error;
  bool _saving = false;

  static const _units = ['كيلو', 'لتر', 'قطعة', 'علبة', 'كرتونة', 'كيس', 'زجاجة'];

  @override
  void initState() {
    super.initState();
    final x = widget.existing;
    _item = TextEditingController(text: x?.item ?? '');
    _qty = TextEditingController(
        text: x?.quantity == null ? '' : (x!.quantity! == x.quantity!.truncateToDouble() ? x.quantity!.toInt().toString() : x.quantity.toString()));
    _unit = TextEditingController(text: x?.unit ?? '');
    _note = TextEditingController(text: x?.note ?? '');
    _supplierId = x?.supplierId ?? '';
  }

  @override
  void dispose() {
    for (final c in [_item, _qty, _unit, _note]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    if (_saving) return;
    final item = _item.text.trim();
    if (item.isEmpty) {
      setState(() => _error = 'اكتب اسم الصنف.');
      return;
    }
    double? qty;
    if (_qty.text.trim().isNotEmpty) {
      qty = parseMoney(_qty.text);
      if (qty == null || qty <= 0) {
        setState(() => _error = 'الكمية لازم تكون رقم أكبر من صفر.');
        return;
      }
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    final suppliers = StorageService.suppliers();
    final sup = suppliers.where((s) => s.id == _supplierId).toList();
    final x = widget.existing ??
        ShortageItem(id: _newId, item: item, createdAt: DateTime.now());
    x
      ..item = item
      ..quantity = qty
      ..unit = _unit.text.trim()
      ..note = _note.text.trim()
      ..supplierId = sup.isEmpty ? '' : sup.first.id
      ..supplierName = sup.isEmpty ? '' : sup.first.name
      ..updatedAt = DateTime.now();
    await StorageService.saveShortage(x);
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final suppliers = StorageService.suppliers().where((s) => !s.archived).toList();
    return FormSheet(
      title: widget.existing == null ? 'إضافة نقص' : 'تعديل النقص',
      error: _error,
      saving: _saving,
      onSave: _save,
      children: [
        TextField(controller: _item, decoration: const InputDecoration(labelText: 'الصنف (مثلًا: بن)')),
        Row(children: [
          Expanded(
              child: TextField(
                  controller: _qty,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'الكمية'))),
          const SizedBox(width: AppSpace.x2),
          Expanded(child: TextField(controller: _unit, decoration: const InputDecoration(labelText: 'الوحدة'))),
        ]),
        Wrap(
          spacing: AppSpace.x2,
          children: [
            for (final u in _units) ActionChip(label: Text(u), onPressed: () => setState(() => _unit.text = u)),
          ],
        ),
        if (suppliers.isNotEmpty)
          DropdownButtonFormField<String>(
            initialValue: suppliers.any((s) => s.id == _supplierId) ? _supplierId : '',
            decoration: const InputDecoration(labelText: 'المورد (اختياري)'),
            items: [
              const DropdownMenuItem(value: '', child: Text('بدون مورد')),
              for (final s in suppliers) DropdownMenuItem(value: s.id, child: Text(s.name)),
            ],
            onChanged: (v) => setState(() => _supplierId = v ?? ''),
          ),
        TextField(controller: _note, decoration: const InputDecoration(labelText: 'ملاحظة (اختياري)')),
      ],
    );
  }
}
