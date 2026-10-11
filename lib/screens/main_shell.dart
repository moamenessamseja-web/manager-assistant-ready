import 'package:flutter/material.dart';
import 'chat_screen.dart';
import 'today_screen.dart';
import 'memory_screen.dart';
import 'staff_screen.dart';
import 'suppliers_screen.dart';
import 'rules_screen.dart';
import 'brief_screen.dart';
import 'settings_screen.dart';
import 'notification_debug_screen.dart';
import '../design/tokens.dart';
import '../design/widgets.dart';
import '../services/app_state.dart';
import '../services/storage_service.dart';

/// Premium Main Shell — 6-tab bottom navigation
/// يستمع لـ AppState عشان يبني كل الشاشات من جديد بأحدث بيانات
/// عند أي تعديل — بدون ما المستخدم يقفل التطبيق.
class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _index = 0;

  @override
  void initState() {
    super.initState();
    AppState.instance.addListener(_onAppStateChanged);
  }

  @override
  void dispose() {
    AppState.instance.removeListener(_onAppStateChanged);
    super.dispose();
  }

  void _onAppStateChanged() {
    if (mounted) setState(() {});
  }

  // Tab destinations — 6 screens
  static const _destinations = [
    ('القائمة', Icons.today_outlined, Icons.today, Icons.today),
    ('المحادثة', Icons.chat_bubble_outline, Icons.chat_bubble, Icons.chat_bubble),
    ('الذاكرة', Icons.psychology_outlined, Icons.psychology, Icons.psychology),
    ('بريف', Icons.summarize_outlined, Icons.summarize, Icons.summarize),
    ('الموظفين', Icons.people_outline, Icons.people, Icons.people),
    ('الموردين', Icons.local_shipping_outlined, Icons.local_shipping, Icons.local_shipping),
  ];

  // Secondary screens (from drawer)
  static const _secondaryTitles = ['القواعد والتنبيهات', 'بريف الأسبوع', 'الإعدادات'];
  static const _secondaryIcons = [Icons.rule, Icons.insights, Icons.settings];

  @override
  Widget build(BuildContext context) {
    final screens = [
      TodayScreen(key: const ValueKey('tab-today')),
      ChatScreen(key: const ValueKey('tab-chat')),
      MemoryScreen(key: const ValueKey('tab-memory')),
      BriefScreen(key: const ValueKey('tab-brief')),
      StaffScreen(key: const ValueKey('tab-staff')),
      SuppliersScreen(key: const ValueKey('tab-suppliers')),
    ];

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: _buildAppBar(),
      drawer: _buildDrawer(),
      body: IndexedStack(
        index: _index,
        children: screens,
      ),
      bottomNavigationBar: _buildBottomNav(),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    String title;
    switch (_index) {
      case 0:
        title = 'القائمة';
        break;
      case 1:
        title = 'المحادثة';
        break;
      case 2:
        title = 'الذاكرة';
        break;
      case 3:
        title = 'بريف الأسبوع';
        break;
      case 4:
        title = 'الموظفين';
        break;
      case 5:
        title = 'الموردين';
        break;
      default:
        title = 'مساعد الإدارة';
    }

    return AppBar(
      title: Text(title),
      leading: Builder(
        builder: (context) => IconButton(
          icon: const Icon(Icons.menu, size: AppIconSize.lg),
          onPressed: () => Scaffold.of(context).openDrawer(),
          tooltip: 'القائمة',
        ),
      ),
      actions: [
        // Notification bell
        _HeaderNotificationBell(),
        const SizedBox(width: AppSpace.x1),
      ],
    );
  }

  Widget _buildDrawer() {
    final secondary = [
      RulesScreen(key: const ValueKey('sec-rules')),
      BriefScreen(key: const ValueKey('sec-brief')),
      SettingsScreen(key: const ValueKey('sec-settings')),
    ];

    return Drawer(
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.horizontal(right: Radius.circular(AppRadius.xl)),
      ),
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Container(
              padding: const EdgeInsets.fromLTRB(
                AppSpace.x6, AppSpace.x6, AppSpace.x6, AppSpace.x4,
              ),
              decoration: const BoxDecoration(
                gradient: AppColors.primaryGradient,
                borderRadius: BorderRadius.horizontal(
                  right: Radius.circular(AppRadius.xl),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(AppRadius.md),
                    ),
                    child: const Icon(
                      Icons.business_center,
                      color: Colors.white,
                      size: AppIconSize.lg,
                    ),
                  ),
                  const SizedBox(height: AppSpace.x3),
                  Text(
                    'مساعد الإدارة',
                    style: AppText.h1.copyWith(color: Colors.white, fontSize: 20),
                  ),
                  const SizedBox(height: AppSpace.x1),
                  Text(
                    'لوحة تحكم الأعمال',
                    style: AppText.body.copyWith(
                      color: Colors.white.withValues(alpha: 0.8),
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: AppSpace.x2),
            // Primary nav is shown in bottom bar — drawer is for secondary
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpace.x4, AppSpace.x3, AppSpace.x4, AppSpace.x2,
              ),
              child: Text(
                'أدوات',
                style: AppText.caption.copyWith(
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.5,
                ),
              ),
            ),

            Expanded(
              child: ListView(
                padding: EdgeInsets.zero,
                children: [
                  for (var i = 0; i < secondary.length; i++)
                    _DrawerItem(
                      icon: _secondaryIcons[i],
                      label: _secondaryTitles[i],
                      onTap: () {
                        Navigator.pop(context);
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => secondary[i]),
                        );
                      },
                    ),
                ],
              ),
            ),

            // Footer
            Container(
              padding: const EdgeInsets.all(AppSpace.x4),
              decoration: const BoxDecoration(
                border: Border(
                  top: BorderSide(color: AppColors.border, width: 0.5),
                ),
              ),
              child: Text(
                'مساعد الإدارة v1.0',
                style: AppText.caption,
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomNav() {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(
          top: BorderSide(color: AppColors.border, width: 0.5),
        ),
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 64,
          child: Row(
            children: [
              for (var i = 0; i < 6; i++)
                Expanded(
                  child: _NavItem(
                    label: _destinations[i].$1,
                    icon: _destinations[i].$2,
                    selectedIcon: _destinations[i].$3,
                    isSelected: _index == i,
                    onTap: () => setState(() => _index = i),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Premium navigation item
class _NavItem extends StatelessWidget {
  final String label;
  final IconData icon;
  final IconData selectedIcon;
  final bool isSelected;
  final VoidCallback onTap;

  const _NavItem({
    required this.label,
    required this.icon,
    required this.selectedIcon,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: SizedBox(
          height: 64,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: EdgeInsets.symmetric(
                  horizontal: isSelected ? AppSpace.x3 : 0,
                  vertical: AppSpace.x1,
                ),
                decoration: BoxDecoration(
                  color: isSelected
                      ? AppColors.primaryTint
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(AppRadius.full),
                ),
                child: Icon(
                  isSelected ? selectedIcon : icon,
                  size: AppIconSize.lg,
                  color: isSelected
                      ? AppColors.primary
                      : AppColors.textDisabled,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                label,
                style: TextStyle(
                  fontFamily: 'Tajawal',
                  fontSize: 10,
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w400,
                  color: isSelected
                      ? AppColors.primary
                      : AppColors.textDisabled,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Notification bell in app bar header
class _HeaderNotificationBell extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: AppState.instance,
      builder: (context, _) {
        final broken = StorageService.reminders()
            .where((r) => r.status != 'scheduled' && r.status != 'cancelled')
            .length;

        return Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => const NotificationDebugScreen(),
              ),
            ),
            borderRadius: BorderRadius.circular(AppRadius.full),
            child: Padding(
              padding: const EdgeInsets.all(AppSpace.x2),
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  const Icon(
                    Icons.notifications_outlined,
                    size: AppIconSize.lg,
                  ),
                  if (broken > 0)
                    Positioned(
                      top: -2,
                      end: -2,
                      child: Container(
                        width: 16,
                        height: 16,
                        decoration: BoxDecoration(
                          color: AppColors.danger,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: AppColors.surface,
                            width: 1.5,
                          ),
                        ),
                        child: Center(
                          child: Text(
                            '$broken',
                            style: const TextStyle(
                              fontFamily: 'Tajawal',
                              fontSize: 9,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

