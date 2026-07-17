import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../navigation/app_router.dart';
import '../theme/app_theme.dart';
import '../widgets/app_bottom_nav.dart';
import '../widgets/horizon_logo.dart';
import '../widgets/theme_toggle.dart';
import 'about_screen.dart';
import 'alerts_screen.dart';
import 'home_screen.dart';
import 'people_search_screen.dart';
import 'profile_screen.dart';

/// App-wide navigation coordinator backed by [go_router].
///
/// The [navigationShell] is the single source of truth for the selected root
/// tab; the bottom nav simply tells the shell to change branches.
class MainScaffold extends StatelessWidget {
  final StatefulNavigationShell navigationShell;

  const MainScaffold({super.key, required this.navigationShell});

  static const List<Widget> _pages = [
    HomeScreen(),
    PeopleSearchScreen(),
    AlertsScreen(),
    AboutScreen(),
    ProfileScreen(),
  ];

  void _onNavTap(BuildContext context, int raw) {
    if (raw == 2) {
      _openHub(context);
      return;
    }
    // Raw bottom-nav slots: 0 Home, 1 Search, 2 Hub, 3 Alerts, 4 Profile.
    // Shell branches: 0 Home, 1 Search, 2 Alerts, 3 About, 4 Profile.
    final branch = raw == 0
        ? 0
        : raw == 1
            ? 1
            : raw == 3
                ? 2
                : 4;
    navigationShell.goBranch(branch);
  }

  void _openHub(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: context.colors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (ctx) => _HubSheet(
        onSelect: (dest) {
          Navigator.pop(ctx);
          switch (dest) {
            case 'bus':
              context.push(AppRoutes.bus);
              break;
            case 'notices':
              context.push(AppRoutes.notices);
              break;
            case 'blood':
              context.push(AppRoutes.blood);
              break;
            case 'lost':
              context.push(AppRoutes.lostFound);
              break;
            case 'attendance':
              context.push(AppRoutes.attendance);
              break;
            case 'about':
              context.push(AppRoutes.about);
              break;
          }
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isWide = MediaQuery.of(context).size.width > 768;

    return PopScope(
      canPop: navigationShell.currentIndex == 0,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop && navigationShell.currentIndex != 0) {
          navigationShell.goBranch(0);
        }
      },
      child: Scaffold(
        body: Column(
          children: [
            if (isWide) _buildWebTopNavBar(context),
            Expanded(
              child: Center(
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    maxWidth: isWide ? 1320 : double.infinity,
                  ),
                  child: IndexedStack(
                    index: navigationShell.currentIndex,
                    children: _pages,
                  ),
                ),
              ),
            ),
          ],
        ),
        bottomNavigationBar: isWide
            ? null
            : AppBottomNav(
                currentIndex: _rawIndex(navigationShell.currentIndex),
                onTap: (i) => _onNavTap(context, i),
              ),
      ),
    );
  }

  Widget _buildWebTopNavBar(BuildContext context) {
    return Container(
      height: 68,
      padding: const EdgeInsets.symmetric(horizontal: 28),
      decoration: BoxDecoration(
        color: context.colors.surface,
        border: Border(bottom: BorderSide(color: context.colors.border)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            const HorizonLogo(size: 34),
            const SizedBox(width: 12),
            Text(
              'BU Horizon',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.5,
                color: context.colors.textPrimary,
              ),
            ),
            const SizedBox(width: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Text(
                'University of Barishal Portal',
                style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w600,
                  color: AppColors.primary,
                ),
              ),
            ),
            const SizedBox(width: 24),
            _webNavButton(
              context: context,
              label: 'Home',
              icon: Icons.home_rounded,
              isSelected: navigationShell.currentIndex == 0,
              onTap: () => navigationShell.goBranch(0),
            ),
            _webNavButton(
              context: context,
              label: 'Bus Schedule',
              icon: Icons.directions_bus_rounded,
              isSelected: false,
              onTap: () => context.push(AppRoutes.bus),
            ),
            _webNavButton(
              context: context,
              label: 'People Search',
              icon: Icons.search_rounded,
              isSelected: navigationShell.currentIndex == 1,
              onTap: () => navigationShell.goBranch(1),
            ),
            _webNavButton(
              context: context,
              label: 'Alerts',
              icon: Icons.notifications_rounded,
              isSelected: navigationShell.currentIndex == 2,
              onTap: () => navigationShell.goBranch(2),
            ),
            _webNavButton(
              context: context,
              label: 'About',
              icon: Icons.info_outline_rounded,
              isSelected: navigationShell.currentIndex == 3,
              onTap: () => navigationShell.goBranch(3),
            ),
            _webNavButton(
              context: context,
              label: 'Profile',
              icon: Icons.person_rounded,
              isSelected: navigationShell.currentIndex == 4,
              onTap: () => navigationShell.goBranch(4),
            ),
            const SizedBox(width: 12),
            const ThemeToggleIcon(),
            const SizedBox(width: 12),
            ElevatedButton.icon(
              onPressed: () => _openHub(context),
              icon: const Icon(Icons.apps_rounded, size: 18),
              label: const Text('Quick Hub'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _webNavButton({
    required BuildContext context,
    required String label,
    required IconData icon,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: TextButton.icon(
        onPressed: onTap,
        icon: Icon(
          icon,
          size: 18,
          color: isSelected ? AppColors.primary : context.colors.textSecondary,
        ),
        label: Text(
          label,
          style: TextStyle(
            fontSize: 13.5,
            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
            color: isSelected ? AppColors.primary : context.colors.textPrimary,
          ),
        ),
        style: TextButton.styleFrom(
          backgroundColor: isSelected
              ? AppColors.primary.withValues(alpha: 0.12)
              : Colors.transparent,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      ),
    );
  }

  static int _rawIndex(int shellIndex) {
    switch (shellIndex) {
      case 0: // Home
        return 0;
      case 1: // Search
        return 1;
      case 2: // Alerts
        return 3;
      case 4: // Profile
        return 4;
      case 3: // About — not in the bottom bar, so highlight nothing
      default:
        return -1;
    }
  }
}

class _HubSheet extends StatelessWidget {
  final ValueChanged<String> onSelect;
  const _HubSheet({required this.onSelect});

  @override
  Widget build(BuildContext context) {
    final items = <List<dynamic>>[
      ['bus', Icons.directions_bus_rounded, 'Bus Schedule', AppColors.primary],
      ['notices', Icons.campaign_rounded, 'Class Notices', AppColors.accentCyan],
      ['blood', Icons.water_drop_rounded, 'Blood Help', AppColors.danger],
      ['lost', Icons.inventory_2_rounded, 'Lost & Found', AppColors.warning],
      ['attendance', Icons.check_circle_rounded, 'Attendance', AppColors.success],
      ['about', Icons.info_rounded, 'About', AppColors.purple],
    ];
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: context.colors.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 16),
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Quick Access',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: context.colors.textPrimary,
                ),
              ),
            ),
            const SizedBox(height: 12),
            const ThemeToggleRow(),
            const SizedBox(height: 16),
            GridView.count(
              crossAxisCount: 3,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 14,
              crossAxisSpacing: 14,
              childAspectRatio: 0.95,
              children: items.map((it) {
                return GestureDetector(
                  onTap: () => onSelect(it[0] as String),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        width: 54,
                        height: 54,
                        decoration: BoxDecoration(
                          color: (it[3] as Color).withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Icon(it[1] as IconData, color: it[3] as Color),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        it[2] as String,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 12,
                          color: context.colors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }
}
