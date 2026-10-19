import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../design/app_theme.dart';
import '../design/format.dart';
import '../design/tokens.dart';
import '../design/widgets.dart';
import '../models/customer.dart';
import '../services/app_state.dart';
import '../services/storage_service.dart';
import 'receivables_screen.dart' show parseMoney;

/// حساب العميل: الرصيد + بيع آجل + دفعة + السجل. (عكس شاشة تفاصيل الموظف:
/// مفيش حضور ولا سلف.)
class CustomerDetailsScreen extends StatelessWidget {
  final String customerId;
  const CustomerDetailsScreen({super.key, required this.customerId});

  Customer? _find() {
    for (final c in StorageService.customers()) {
      if (c.id == customerId) return c;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: AppState.instance,
      builder: (context, _) {
        final c = _find();
        if (c == null) {
          return Scaffold(
            appBar: AppBar(title: const Text('العميل')),
            body: const AppEmptyState(
                icon: Icons.person_off_outlined,
                title: 'العميل ده مش موجود',
                subtitle: ''),
          );
        }
        final b = c.balanceDue;
        final color = c.owes
            ? AppColors.danger
            : (b < -0.005 ? AppColors.primary : AppColors.success);
        final rows = <_Row>[
          for (final s in c.sales) _Row(s.date, true, s.total, _saleText(s)),
          for (final p in c.payments)
            _Row(p.date, false, p.amount, p.note.isEmpty ? 'دفعة' : p.note),
        ]..sort((a, b) => b.date.compareTo(a.date));

        return Scaffold(
          appBar: AppBar(
            title: Text(c.name),
            actions: [
              IconButton(
                tooltip: c.archived ? 'إلغاء الأرشفة' : 'أرشفة',
                icon: Icon(c.archived ? Icons.unarchive_outlined : Icons.archive_outlined),
                onPressed: () => _toggleArchive(context, c),
              ),
            ],
          ),
          body: ListView(
            padding: const EdgeInsets.all(AppSpace.x4),
            children: [
              AppCard(
                elevated: true,
                padding: const EdgeInsets.all(AppSpace.x4),
                child: Column(
                  children: [
                    Text(
                      c.owes ? 'عليه' : (b < -0.005 ? 'رصيد لصالحه' : 'مسدّد'),
                      style: AppText.caption,
                    ),
                    Text(money(b.abs()),
                        style: AppText.titleMedium.copyWith(
                            color: color, fontSize: 28, fontWeight: FontWeight.w800)),
                    const SizedBox(height: 4),
                    Text(
                        'إجمالي المبيعات ${money(c.totalSales)} • المدفوع ${money(c.totalPaid)}',
                        style: AppText.caption),
                    if (c.phone.isNotEmpty) Text(c.phone, style: AppText.caption),
                  ],
                ),
              ),
              const SizedBox(height: AppSpace.x3),
              if (c.archived)
                const Padding(
                  padding: EdgeInsets.only(bottom: AppSpace.x2),
                  child: Text('العميل مؤرشف — فك الأرشفة لتسجيل عمليات جديدة.'),
                ),
              Row(
                children: [
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: c.archived ? null : () => _sale(context, c),
                      icon: const Icon(Icons.shopping_bag_outlined),
                      label: const Text('بيع آجل'),
                    ),
                  ),
                  const SizedBox(width: AppSpace.x3),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: c.archived ? null : () => _payment(context, c),
                      icon: const Icon(Icons.payments_outlined),
                      label: const Text('تسجيل دفعة'),
                    ),
                  ),
                ],
              ),
              const AppSectionHeader(title: 'السجل'),
              if (rows.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(AppSpace.x4),
                  child: Text('مفيش حركات لسه.'),
                ),
              for (final r in rows)
                Card(
                  child: ListTile(
                    leading: Icon(
                      r.isSale ? Icons.add_shopping_cart : Icons.south_west,
                      color: r.isSale ? AppColors.danger : AppColors.success,
                    ),
                    title: Text(r.text),
                    subtitle: Text(arabicDate(r.date)),
                    trailing: Text(
                      '${r.isSale ? '+' : '−'} ${money(r.amount)}',
                      style: TextStyle(
                          color: r.isSale ? AppColors.danger : AppColors.success,
                          fontWeight: FontWeight.w700),
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  static String _saleText(CreditSale s) {
    final q = s.quantity == null
        ? ''
        : ' ${s.quantity!.toStringAsFixed(s.quantity! % 1 == 0 ? 0 : 1)} ${s.unit}'.trimRight();
    return '${s.item}$q';
  }

  Future<void> _toggleArchive(BuildContext context, Customer c) async {
    // فلوسنا ما بتختفيش بالأرشفة: ممنوع نأرشف عميل لسه عليه رصيد.
    if (!c.archived && c.owes) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('لسه عليه فلوس — سدّد الحساب الأول قبل الأرشفة.'),
      ));
      return;
    }
    c.archived = !c.archived;
    await StorageService.saveCustomer(c);
  }

  Future<void> _sale(BuildContext context, Customer c) => showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        useSafeArea: true,
        builder: (_) => _SaleForm(customerId: c.id),
      );

  Future<void> _payment(BuildContext context, Customer c) =>
      showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        useSafeArea: true,
        builder: (_) => _PaymentForm(customerId: c.id),
      );
}

class _Row {
  final DateTime date;
  final bool isSale;
  final double amount;
  final String text;
  _Row(this.date, this.isSale, this.amount, this.text);
}

Customer? _customer(String id) {
  for (final c in StorageService.customers()) {
    if (c.id == id) return c;
  }
  return null;
}

class _SaleForm extends StatefulWidget {
  final String customerId;
  const _SaleForm({required this.customerId});
  @override
  State<_SaleForm> createState() => _SaleFormState();
}

class _SaleFormState extends State<_SaleForm> {
  final _item = TextEditingController();
  final _qty = TextEditingController();
  final _unit = TextEditingController();
  final _total = TextEditingController();
  final _note = TextEditingController();
  final String _id = const Uuid().v4(); // ثابت للنموذج: ضغطتين = بيع واحد
  String? _error;
  bool _saving = false;

  @override
  void dispose() {
    for (final c in [_item, _qty, _unit, _total, _note]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    if (_saving) return;
    final item = _item.text.trim();
    final total = parseMoney(_total.text);
    if (item.isEmpty) {
      setState(() => _error = 'اكتب اسم الصنف.');
      return;
    }
    if (total == null || total <= 0) {
      setState(() => _error = 'اكتب قيمة البيع أرقام فقط وأكبر من صفر.');
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
    final c = _customer(widget.customerId);
    if (c == null || c.archived) {
      setState(() => _error = 'العميل مش متاح للتسجيل.');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    c.addSale(CreditSale(
      id: _id,
      item: item,
      quantity: qty,
      unit: _unit.text.trim(),
      total: total,
      date: DateTime.now(),
      note: _note.text.trim(),
    ));
    await StorageService.saveCustomer(c);
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return _FormShell(
      title: 'بيع آجل',
      error: _error,
      saving: _saving,
      onSave: _save,
      children: [
        TextField(controller: _item, decoration: const InputDecoration(labelText: 'الصنف')),
        Row(children: [
          Expanded(
              child: TextField(
                  controller: _qty,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'الكمية (اختياري)'))),
          const SizedBox(width: 8),
          Expanded(
              child: TextField(
                  controller: _unit,
                  decoration: const InputDecoration(labelText: 'الوحدة'))),
        ]),
        TextField(
            controller: _total,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(labelText: 'إجمالي القيمة (جنيه)')),
        TextField(controller: _note, decoration: const InputDecoration(labelText: 'ملاحظة (اختياري)')),
      ],
    );
  }
}

class _PaymentForm extends StatefulWidget {
  final String customerId;
  const _PaymentForm({required this.customerId});
  @override
  State<_PaymentForm> createState() => _PaymentFormState();
}

class _PaymentFormState extends State<_PaymentForm> {
  final _amount = TextEditingController();
  final _note = TextEditingController();
  final String _id = const Uuid().v4();
  String? _error;
  bool _saving = false;

  @override
  void dispose() {
    _amount.dispose();
    _note.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_saving) return;
    final amount = parseMoney(_amount.text);
    if (amount == null || amount <= 0) {
      setState(() => _error = 'اكتب المبلغ أرقام فقط وأكبر من صفر.');
      return;
    }
    final c = _customer(widget.customerId);
    if (c == null || c.archived) {
      setState(() => _error = 'العميل مش متاح للتسجيل.');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    c.addPayment(CustomerPayment(
      id: _id,
      amount: amount,
      date: DateTime.now(),
      note: _note.text.trim(),
    ));
    await StorageService.saveCustomer(c);
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final c = _customer(widget.customerId);
    return _FormShell(
      title: 'تسجيل دفعة',
      error: _error,
      saving: _saving,
      onSave: _save,
      children: [
        if (c != null && c.owes)
          Text('المتبقي عليه ${money(c.balanceDue)}', style: AppText.caption),
        TextField(
            controller: _amount,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(labelText: 'المبلغ المدفوع (جنيه)')),
        TextField(controller: _note, decoration: const InputDecoration(labelText: 'ملاحظة (اختياري)')),
      ],
    );
  }
}

class _FormShell extends StatelessWidget {
  final String title;
  final String? error;
  final bool saving;
  final VoidCallback onSave;
  final List<Widget> children;
  const _FormShell({
    required this.title,
    required this.error,
    required this.saving,
    required this.onSave,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
          16, 8, 16, MediaQuery.of(context).viewInsets.bottom + 16),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title,
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
            const SizedBox(height: 8),
            ...children,
            if (error != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(error!, style: const TextStyle(color: AppColors.danger)),
              ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: saving ? null : onSave,
                child: Text(saving ? 'جاري الحفظ…' : 'حفظ'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
