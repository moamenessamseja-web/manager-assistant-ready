import 'package:flutter/material.dart';
import '../models/supplier.dart';
import '../services/storage_service.dart';
import '../services/app_state.dart';
import '../design/tokens.dart';
import '../design/app_theme.dart';
import '../design/widgets.dart';
import '../design/format.dart';
import 'supplier_details_screen.dart';
import 'supplier_forms.dart';

/// الموردون — قائمة كيانات تفاعلية (صروف مدمجة، مش كروت ضخمة).
class SuppliersScreen extends StatefulWidget {
  const SuppliersScreen({super.key});

  @override
  State<SuppliersScreen> createState() => _SuppliersScreenState();
}

class _SuppliersScreenState extends State<SuppliersScreen> {
  final _search = TextEditingController();
  int _filter = 0; // 0 نشط 1 عليه مستحقات 2 توريدات قادمة 3 مؤرشف 4 الكل

  static const _filters = ['نشط', 'عليه مستحقات', 'توريدات قادمة', 'مؤرشف', 'الكل'];

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  List<Supplier> _apply(List<Supplier> all) {
    final q = _search.text.trim().toLowerCase();
    var list = switch (_filter) {
      0 => all.where((s) => !s.archived).toList(),
      1 => all.where((s) => !s.archived && s.balanceDue > 0).toList(),
      2 => all.where((s) => !s.archived && s.pendingDeliveries.isNotEmpty).toList(),
      3 => all.where((s) => s.archived).toList(),
      _ => all,
    };
    if (q.isNotEmpty) {
      list = list.where((s) =>
          s.name.toLowerCase().contains(q) ||
          s.itemType.toLowerCase().contains(q)).toList();
    }
    return list;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('الموردون'),
        actions: [
          IconButton(
            tooltip: 'المدفوعات',
            icon: const Icon(Icons.receipt_long_outlined),
            onPressed: () => _showSuppliersBreakdown(context),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          final s = await showAddSupplierSheet(context);
          if (s != null) {
            if (!context.mounted) return;
            await Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => SupplierDetailsScreen(supplier: s)),
            );
          }
        },
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add_business),
        label: const Text('إضافة مورد'),
      ),
      body: ListenableBuilder(
        listenable: AppState.instance,
        builder: (context, _) => _body(context),
      ),
    );
  }

  Widget _body(BuildContext context) {
    final all = StorageService.suppliers();
    final active = all.where((s) => !s.archived).toList();
    final goods = active.fold<double>(0, (t, s) => t + s.goodsTotal);
    final paid = active.fold<double>(0, (t, s) => t + s.totalPaid);
    final due = active.fold<double>(0, (t, s) => t + s.balanceDue);
    final list = _apply(all);

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(AppSpace.x4, AppSpace.x3, AppSpace.x4, AppSpace.x2),
          child: AppCard(
            onTap: () => _showSuppliersBreakdown(context),
            padding: const EdgeInsets.all(AppSpace.x4),
            child: Row(children: [
              _triple('إجمالي البضاعة', goods, AppColors.info),
              _divider(),
              _triple('المدفوع', paid, AppColors.success),
              _divider(),
              _triple('المستحق', due, due > 0 ? AppColors.accent : AppColors.success),
            ]),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpace.x4),
          child: AppSearchBar(
            controller: _search,
            hint: 'ابحث باسم المورد أو الصنف…',
            onChanged: (_) => setState(() {}),
          ),
        ),
        AppFilterChips(
          labels: _filters,
          selectedIndex: _filter,
          onSelected: (i) => setState(() => _filter = i),
        ),
        Expanded(
          child: list.isEmpty
              ? AppEmptyState(
                  icon: Icons.local_shipping_outlined,
                  title: _search.text.isNotEmpty ? 'لا توجد نتائج' : 'لا يوجد موردون',
                  subtitle: _search.text.isNotEmpty
                      ? 'جرّب اسمًا أو فلترًا آخر'
                      : 'أضف أول مورد من الزر بالأسفل.',
                  action: _search.text.isNotEmpty
                      ? null
                      : FilledButton(
                          onPressed: () async => showAddSupplierSheet(context),
                          child: const Text('+ إضافة مورد'),
                        ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.only(bottom: AppSpace.x16),
                  itemCount: list.length,
                  itemBuilder: (context, i) => _row(context, list[i]),
                ),
        ),
      ],
    );
  }

  Widget _row(BuildContext context, Supplier s) {
    final last = s.timeline.isEmpty ? '' : ' · آخر حركة ${relativeDay(s.timeline.first.date)}';
    final dueColor = s.balanceDue > 0 ? AppColors.accent : AppColors.success;
    return AppEntityRow(
      title: s.name + (s.archived ? ' (مؤرشف)' : ''),
      subtitle: '${s.itemType.isEmpty ? 'مورد' : s.itemType}$last',
      leading: AppAvatar(name: s.name, icon: Icons.local_shipping_outlined),
      trailing: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            money(s.balanceDue),
            style: AppText.label.copyWith(fontWeight: FontWeight.w700, color: dueColor),
          ),
          if (s.pendingDeliveries.isNotEmpty)
            Text('${s.pendingDeliveries.length} توريد قادم', style: AppText.caption),
        ],
      ),
      menuItems: [
        const PopupMenuItem(value: 'open', child: Text('فتح الحساب')),
        const PopupMenuItem(value: 'purchase', child: Text('تسجيل توريد')),
        const PopupMenuItem(value: 'payment', child: Text('تسجيل دفعة')),
        const PopupMenuItem(value: 'edit', child: Text('تعديل')),
        PopupMenuItem(value: 'archive', child: Text(s.archived ? 'إلغاء الأرشفة' : 'أرشفة')),
        if (!s.hasHistory)
          const PopupMenuItem(value: 'delete', child: Text('حذف نهائي')),
      ],
      onMenuSelected: (v) => _menu(context, s, v),
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => SupplierDetailsScreen(supplier: s)),
      ),
    );
  }

  Future<void> _menu(BuildContext context, Supplier s, String v) async {
    switch (v) {
      case 'open':
        await Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => SupplierDetailsScreen(supplier: s)),
        );
        break;
      case 'purchase':
        if (await showAddPurchaseSheet(context, s)) {
          if (context.mounted) showAppSnack(context, 'تم تسجيل التوريد بقيمة ${money(s.goodsTotal)}');
        }
        break;
      case 'payment':
        if (await showAddPaymentSheet(context, s)) {
          if (context.mounted) showAppSnack(context, 'تم تسجيل الدفعة — المتبقي ${money(s.balanceDue)}');
        }
        break;
      case 'edit':
        await showEditSupplierSheet(context, s);
        break;
      case 'archive':
        await archiveSupplier(context, s);
        break;
      case 'delete':
        await deleteSupplierSafely(context, s);
        break;
    }
  }

  Future<void> _showSuppliersBreakdown(BuildContext context) async {
    final active = StorageService.suppliers().where((s) => !s.archived).toList()
      ..sort((a, b) => b.balanceDue.compareTo(a.balanceDue));
    if (!context.mounted) return;
    await showAppBottomSheet<void>(
      context: context,
      title: 'تفصيل الموردين',
      body: ListView(
        shrinkWrap: true,
        padding: const EdgeInsets.all(AppSpace.x4),
        children: [
          if (active.isEmpty)
            const Padding(
              padding: EdgeInsets.all(AppSpace.x4),
              child: Text('لا يوجد موردون نشطون.'),
            )
          else
            for (final s in active)
              AppInfoRow(
                label: s.name,
                value: 'بضاعة ${money(s.goodsTotal)} · مدفوع ${money(s.totalPaid)} · متبقي ${money(s.balanceDue)}',
              ),
        ],
      ),
    );
  }

  Widget _triple(String label, double value, Color color) => Expanded(
        child: Column(
          children: [
            Text(money(value),
                style: AppText.label.copyWith(fontWeight: FontWeight.w700, color: color)),
            Text(label, style: AppText.caption, textAlign: TextAlign.center),
          ],
        ),
      );

  Widget _divider() => Container(width: 1, height: 32, color: AppColors.border);
}
