import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../design/app_theme.dart';
import '../design/format.dart';
import '../design/tokens.dart';
import '../design/widgets.dart';
import '../models/customer.dart';
import '../services/app_state.dart';
import '../services/local_command_parser.dart';
import '../services/storage_service.dart';
import 'customer_details_screen.dart';

/// قراءة رقم من حقل نصي (أرقام عربية/إنجليزية). null لو فاضي/غلط.
double? parseMoney(String raw) =>
    double.tryParse(LocalCommandParser.normalize(raw.trim()));

/// المستحقات — الفلوس اللي لنا برّه (عملاء بيشتروا بالآجل). تبويب رئيسي بدل
/// «بريف» (البريف لسه موجود في القائمة الجانبية).
class ReceivablesScreen extends StatefulWidget {
  const ReceivablesScreen({super.key});

  @override
  State<ReceivablesScreen> createState() => _ReceivablesScreenState();
}

class _ReceivablesScreenState extends State<ReceivablesScreen> {
  String _filter = 'active';
  final _search = TextEditingController();

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: ListenableBuilder(
        listenable: AppState.instance,
        builder: (context, _) => _body(context),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _addCustomer,
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        tooltip: 'إضافة عميل',
        child: const Icon(Icons.person_add),
      ),
    );
  }

  Widget _body(BuildContext context) {
    final all = StorageService.customers();
    final filtered = filterCustomers(all, _filter);
    final q = _search.text.trim().toLowerCase();
    final list = (q.isEmpty
            ? filtered
            : filtered.where((c) => c.name.toLowerCase().contains(q)).toList())
      ..sort((a, b) => b.balanceDue.compareTo(a.balanceDue));
    final debtors = all.where((c) => c.owes).length;

    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.all(AppSpace.x4),
            child: Row(
              children: [
                Expanded(
                  child: _Tile(
                    label: 'إجمالي المستحقات',
                    value: money(totalReceivables(all)),
                    icon: Icons.account_balance_wallet_outlined,
                    color: debtors > 0 ? AppColors.accent : AppColors.success,
                  ),
                ),
                const SizedBox(width: AppSpace.x3),
                Expanded(
                  child: _Tile(
                    label: 'عملاء عليهم فلوس',
                    value: '$debtors',
                    icon: Icons.groups_outlined,
                    color: debtors > 0 ? AppColors.warning : AppColors.success,
                  ),
                ),
              ],
            ),
          ),
        ),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
                AppSpace.x4, 0, AppSpace.x4, AppSpace.x2),
            child: TextField(
              controller: _search,
              onChanged: (_) => setState(() {}),
              decoration: const InputDecoration(
                hintText: 'ابحث باسم العميل...',
                prefixIcon: Icon(Icons.search),
              ),
            ),
          ),
        ),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpace.x4),
            child: Wrap(
              spacing: AppSpace.x2,
              children: [
                for (final f in const [
                  ['active', 'النشطون'],
                  ['archived', 'المؤرشفون'],
                  ['all', 'الكل'],
                ])
                  ChoiceChip(
                    label: Text(f[1]),
                    selected: _filter == f[0],
                    onSelected: (_) => setState(() => _filter = f[0]),
                  ),
              ],
            ),
          ),
        ),
        if (list.isEmpty)
          const SliverFillRemaining(
            hasScrollBody: false,
            child: AppEmptyState(
              icon: Icons.request_quote_outlined,
              title: 'لا يوجد عملاء بعد',
              subtitle: 'اضغط + لإضافة عميل بيشتري بالآجل وتتبّع اللي عليه',
            ),
          )
        else
          SliverPadding(
            padding: const EdgeInsets.all(AppSpace.x4),
            sliver: SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, i) => _CustomerTile(customer: list[i]),
                childCount: list.length,
              ),
            ),
          ),
      ],
    );
  }

  Future<void> _addCustomer() async {
    await showDialog<void>(
      context: context,
      builder: (_) => const _AddCustomerDialog(),
    );
  }
}

class _Tile extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;
  const _Tile(
      {required this.label,
      required this.value,
      required this.icon,
      required this.color});

  @override
  Widget build(BuildContext context) {
    return AppCard(
      elevated: true,
      padding: const EdgeInsets.all(AppSpace.x3),
      child: Row(
        children: [
          Icon(icon, color: color),
          const SizedBox(width: AppSpace.x2),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(value,
                    style: AppText.titleMedium
                        .copyWith(color: color, fontWeight: FontWeight.w700),
                    overflow: TextOverflow.ellipsis),
                Text(label, style: AppText.caption, overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CustomerTile extends StatelessWidget {
  final Customer customer;
  const _CustomerTile({required this.customer});

  @override
  Widget build(BuildContext context) {
    final b = customer.balanceDue;
    final color = customer.owes
        ? AppColors.danger
        : (b < -0.005 ? AppColors.primary : AppColors.success);
    final last = customer.lastActivity;
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpace.x2),
      child: AppCard(
        padding: EdgeInsets.zero,
        child: Material(
          color: Colors.transparent,
          child: ListTile(
          leading: CircleAvatar(
            backgroundColor: color.withValues(alpha: 0.12),
            child: Icon(Icons.person_outline, color: color),
          ),
          title: Text(customer.name,
              style: const TextStyle(fontWeight: FontWeight.w600)),
          subtitle: Text(
            [
              if (customer.archived) 'مؤرشف',
              if (last != null) 'آخر حركة ${arabicDate(last)}',
            ].join(' • '),
            style: AppText.caption,
          ),
          trailing: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(money(b.abs()),
                  style: TextStyle(color: color, fontWeight: FontWeight.w700)),
              Text(
                customer.owes
                    ? 'عليه'
                    : (b < -0.005 ? 'رصيد له' : 'مسدّد'),
                style: AppText.caption,
              ),
            ],
          ),
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
                builder: (_) => CustomerDetailsScreen(customerId: customer.id)),
          ),
        ),
        ),
      ),
    );
  }
}

class _AddCustomerDialog extends StatefulWidget {
  const _AddCustomerDialog();

  @override
  State<_AddCustomerDialog> createState() => _AddCustomerDialogState();
}

class _AddCustomerDialogState extends State<_AddCustomerDialog> {
  final _name = TextEditingController();
  final _phone = TextEditingController();
  final _opening = TextEditingController();
  final String _id = const Uuid().v4(); // ثابت لهذا الحوار: ضغطتين = عميل واحد
  String? _error;
  bool _saving = false;

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    _opening.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_saving) return;
    final name = _name.text.trim();
    if (name.isEmpty) {
      setState(() => _error = 'اكتب اسم العميل.');
      return;
    }
    if (StorageService.customersMatching(name, includeArchived: true)
        .any((c) => c.name.trim() == name)) {
      setState(() => _error = 'فيه عميل بنفس الاسم بالفعل.');
      return;
    }
    double? opening;
    if (_opening.text.trim().isNotEmpty) {
      opening = parseMoney(_opening.text);
      if (opening == null || opening <= 0) {
        setState(() => _error = 'الرصيد السابق لازم يكون رقم أكبر من صفر.');
        return;
      }
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    final c = Customer(id: _id, name: name, phone: _phone.text.trim());
    if (opening != null) {
      c.addSale(CreditSale(
        id: '$_id-opening',
        item: 'رصيد سابق',
        total: opening,
        date: DateTime.now(),
        note: 'رصيد سابق عند إضافة العميل',
      ));
    }
    await StorageService.saveCustomer(c);
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('إضافة عميل'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
                controller: _name,
                decoration: const InputDecoration(labelText: 'اسم العميل')),
            TextField(
                controller: _phone,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(labelText: 'التليفون (اختياري)')),
            TextField(
                controller: _opening,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                    labelText: 'رصيد سابق عليه (اختياري)')),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(_error!,
                    style: const TextStyle(color: AppColors.danger)),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
            onPressed: _saving ? null : () => Navigator.pop(context),
            child: const Text('إلغاء')),
        FilledButton(
            onPressed: _saving ? null : _save, child: const Text('حفظ')),
      ],
    );
  }
}
