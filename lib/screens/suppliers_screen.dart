import 'package:flutter/material.dart';
import '../models/supplier.dart';
import '../services/storage_service.dart';
import '../services/app_state.dart';
import '../design/tokens.dart';
import '../design/widgets.dart';
import 'supplier_details_screen.dart';

/// الموردون — Premium Supplier Management Screen
class SuppliersScreen extends StatefulWidget {
  const SuppliersScreen({super.key});

  @override
  State<SuppliersScreen> createState() => _S();
}

class _S extends State<_S> {
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
      backgroundColor: AppColors.background,
      body: ListenableBuilder(
        listenable: AppState.instance,
        builder: (context, _) => _buildBody(context),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _add,
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        child: const Icon(Icons.add_business),
      ),
    );
  }

  Widget _buildBody(BuildContext context) {
    final all = StorageService.suppliers();
    final active = all.where((s) => !s.archived).toList();
    final totalDue = active.fold<double>(0, (s, x) => s + x.balanceDue);
    final totalOwed = active.fold<double>(0, (s, x) => s + x.totalOwed);
    final totalPaid = active.fold<double>(0, (s, x) => s + x.totalPaid);

    final filtered = switch (_filter) {
      'archived' => all.where((s) => s.archived).toList(),
      'all' => all,
      _ => all,
    };

    final query = _search.text.trim().toLowerCase();
    final suppliers = query.isEmpty
        ? filtered
        : filtered.where((s) => s.name.toLowerCase().contains(query)).toList();

    return CustomScrollView(
      slivers: [
        // Summary header
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.all(AppSpace.x4),
            child: Row(
              children: [
                Expanded(
                  child: _SummaryTile(
                    label: 'مستحق للموردين',
                    value: '${totalDue.toStringAsFixed(0)} ج',
                    icon: Icons.local_shipping_outlined,
                    color: totalDue > 0 ? AppColors.accent : AppColors.success,
                  ),
                ),
                const SizedBox(width: AppSpace.x3),
                Expanded(
                  child: _SummaryTile(
                    label: 'عدد الموردين',
                    value: '${active.length}',
                    icon: Icons.business_outlined,
                    color: AppColors.primary,
                  ),
                ),
              ],
            ),
          ),
        ),

        // Financial summary
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpace.x4, 0, AppSpace.x4, AppSpace.x3,
            ),
            child: AppCard(
              elevated: true,
              padding: const EdgeInsets.all(AppSpace.x4),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('إجمالي قيمة البضاعة', style: AppText.caption),
                        Text(
                          '${totalOwed.toStringAsFixed(0)} ج',
                          style: AppText.titleMedium.copyWith(
                            fontSize: 18,
                            color: AppColors.info,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(width: 1, height: 40, color: AppColors.border),
                  const SizedBox(width: AppSpace.x4),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('إجمالي المدفوع', style: AppText.caption),
                        Text(
                          '${totalPaid.toStringAsFixed(0)} ج',
                          style: AppText.titleMedium.copyWith(
                            fontSize: 18,
                            color: AppColors.success,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(width: 1, height: 40, color: AppColors.border),
                  const SizedBox(width: AppSpace.x4),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('المستحق الآن', style: AppText.caption),
                        Text(
                          '${totalDue.toStringAsFixed(0)} ج',
                          style: AppText.titleMedium.copyWith(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            color: totalDue > 0 ? AppColors.accent : AppColors.success,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),

        // Search
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpace.x4, 0, AppSpace.x4, AppSpace.x3,
            ),
            child: TextField(
              controller: _search,
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                hintText: 'ابحث باسم المورد...',
                prefixIcon: const Icon(Icons.search, size: AppIconSize.md),
                suffixIcon: _search.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, size: AppIconSize.md),
                        onPressed: () {
                          _search.clear();
                          setState(() {});
                        },
                      )
                    : null,
              ),
            ),
          ),
        ),

        // Filter chips
        SliverToBoxAdapter(
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.fromLTRB(
              AppSpace.x4, 0, AppSpace.x4, AppSpace.x3,
            ),
            child: Row(
              children: [
                _FilterChip(
                  label: 'نشط',
                  count: all.where((s) => !s.archived).length,
                  isSelected: _filter == 'active',
                  onTap: () => setState(() => _filter = 'active'),
                ),
                const SizedBox(width: AppSpace.x2),
                _FilterChip(
                  label: 'مؤرشف',
                  count: all.where((s) => s.archived).length,
                  isSelected: _filter == 'archived',
                  onTap: () => setState(() => _filter = 'archived'),
                ),
                const SizedBox(width: AppSpace.x2),
                _FilterChip(
                  label: 'الكل',
                  count: all.length,
                  isSelected: _filter == 'all',
                  onTap: () => setState(() => _filter = 'all'),
                ),
              ],
            ),
          ),
        ),

        // Supplier list
        if (suppliers.isEmpty)
          SliverFillRemaining(
            hasScrollBody: false,
            child: AppEmptyState(
              icon: Icons.local_shipping_outlined,
              title: _search.text.isNotEmpty ? 'لا يوجد نتائج' : 'لا يوجد موردون',
              subtitle: _search.text.isNotEmpty
                  ? 'ابحث باسم مختلف'
                  : 'مثال: "مورد جديد:حديد -0101234567"',
            ),
          )
        else
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(
              AppSpace.x4, 0, AppSpace.x4, AppSpace.x16,
            ),
            sliver: SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, i) => _SupplierCard(
                  supplier: suppliers[i],
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => SupplierDetailsScreen(supplier: suppliers[i]),
                    ),
                  ).then((_) => setState(() {})),
                  onArchive: () async {
                    suppliers[i].archived = !suppliers[i].archived;
                    await StorageService.saveSupplier(suppliers[i]);
                    setState(() {});
                  },
                ),
                childCount: suppliers.length,
              ),
            ),
          ),
      ],
    );
  }

  void _add() {
    final n = TextEditingController();
    final t = TextEditingController();
    final p = TextEditingController();

    showAppBottomSheet(
      context: context,
      title: 'إضافة مورد',
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpace.x4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: n,
              decoration: const InputDecoration(
                labelText: 'اسم المورد',
                hintText: 'مثال: أحمد للحديد',
              ),
              textCapitalization: TextCapitalization.words,
            ),
            const SizedBox(height: AppSpace.x3),
            TextField(
              controller: t,
              decoration: const InputDecoration(
                labelText: 'الصنف (اختياري)',
                hintText: 'مثال: حديد، خشب، كهرباء',
              ),
            ),
            const SizedBox(height: AppSpace.x3),
            TextField(
              controller: p,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(
                labelText: 'التليفون (اختياري)',
                hintText: 'مثال: 01012345678',
              ),
            ),
            const SizedBox(height: AppSpace.x6),
            FilledButton(
              onPressed: () async {
                if (n.text.trim().isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('من فضلك أدخل اسم المورد')),
                  );
                  return;
                }
                await StorageService.saveSupplier(Supplier(
                  id: DateTime.now().millisecondsSinceEpoch.toString(),
                  name: n.text.trim(),
                  itemType: t.text.trim(),
                  phone: p.text.trim(),
                  deliveries: [],
                  payments: [],
                  archived: false,
                ));
                if (mounted) Navigator.pop(context);
              },
              child: const Text('إضافة'),
            ),
          ],
        ),
      ),
    );
  }
}

class _SummaryTile extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  const _SummaryTile({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return AppCard(
      elevated: true,
      padding: const EdgeInsets.all(AppSpace.x3),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: AppIconSize.md, color: color),
          const SizedBox(height: AppSpace.x2),
          Text(
            value,
            style: AppText.titleMedium.copyWith(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
          Text(label, style: AppText.caption),
        ],
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final int count;
  final bool isSelected;
  final VoidCallback onTap;

  const _FilterChip({
    required this.label,
    required this.count,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: isSelected ? AppColors.primaryTint : AppColors.surface,
      borderRadius: BorderRadius.circular(AppRadius.full),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.full),
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpace.x3,
            vertical: AppSpace.x2,
          ),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadius.full),
            border: Border.all(
              color: isSelected ? AppColors.primary : AppColors.border,
              width: 1,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                style: AppText.label.copyWith(
                  fontSize: 13,
                  color: isSelected ? AppColors.primary : AppColors.textSecondary,
                ),
              ),
              const SizedBox(width: 4),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                decoration: BoxDecoration(
                  color: isSelected
                      ? AppColors.primary.withValues(alpha: 0.15)
                      : AppColors.surfaceMuted,
                  borderRadius: BorderRadius.circular(AppRadius.full),
                ),
                child: Text(
                  '$count',
                  style: TextStyle(
                    fontFamily: 'Tajawal',
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: isSelected ? AppColors.primary : AppColors.textSecondary,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SupplierCard extends StatelessWidget {
  final Supplier supplier;
  final VoidCallback onTap;
  final VoidCallback onArchive;

  const _SupplierCard({
    required this.supplier,
    required this.onTap,
    required this.onArchive,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpace.x3),
      child: AppCard(
        onTap: onTap,
        padding: const EdgeInsets.all(AppSpace.x4),
        child: Column(
          children: [
            Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: AppColors.primaryTint,
                    borderRadius: BorderRadius.circular(AppRadius.md),
                  ),
                  child: const Icon(
                    Icons.local_shipping,
                    color: AppColors.primary,
                    size: AppIconSize.lg,
                  ),
                ),
                const SizedBox(width: AppSpace.x3),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              supplier.name,
                              style: AppText.titleMedium.copyWith(fontSize: 16),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (supplier.archived)
                            AppBadge(
                              label: 'مؤرشف',
                              kind: BadgeKind.neutral,
                              compact: true,
                            ),
                        ],
                      ),
                      if (supplier.itemType.isNotEmpty)
                        Text(
                          supplier.itemType,
                          style: AppText.bodyMuted,
                        ),
                    ],
                  ),
                ),
                PopupMenuButton<String>(
                  icon: const Icon(Icons.more_vert, size: AppIconSize.md),
                  onSelected: (v) {
                    if (v == 'archive') onArchive();
                  },
                  itemBuilder: (_) => [
                    PopupMenuItem(
                      value: 'archive',
                      child: Text(
                        supplier.archived ? 'إلغاء الأرشفة' : 'أرشفة',
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: AppSpace.x3),
            Row(
              children: [
                Expanded(
                  child: _SupplierStat(
                    label: 'إجمالي البضاعة',
                    value: '${supplier.totalOwed.toStringAsFixed(0)} ج',
                    color: AppColors.info,
                  ),
                ),
                const SizedBox(width: AppSpace.x2),
                Expanded(
                  child: _SupplierStat(
                    label: 'المدفوع',
                    value: '${supplier.totalPaid.toStringAsFixed(0)} ج',
                    color: AppColors.success,
                  ),
                ),
                const SizedBox(width: AppSpace.x2),
                Expanded(
                  child: _SupplierStat(
                    label: 'المستحق',
                    value: '${supplier.balanceDue.toStringAsFixed(0)} ج',
                    color: supplier.balanceDue > 0
                        ? AppColors.accent
                        : AppColors.success,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _SupplierStat extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _SupplierStat({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpace.x2,
        vertical: AppSpace.x2,
      ),
      decoration: BoxDecoration(
        color: AppColors.surfaceMuted,
        borderRadius: BorderRadius.circular(AppRadius.sm),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            value,
            style: TextStyle(
              fontFamily: 'Tajawal',
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: color,
            ),
            overflow: TextOverflow.ellipsis,
          ),
          Text(
            label,
            style: const TextStyle(
              fontFamily: 'Tajawal',
              fontSize: 9,
              color: AppColors.textDisabled,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}
