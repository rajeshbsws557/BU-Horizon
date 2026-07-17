// Developed by Rajesh Biswas (rajeshbiswas.dev)
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../data/sample_data.dart';
import '../navigation/app_router.dart';
import '../theme/app_theme.dart';
import '../widgets/common.dart';
import '../widgets/horizon_logo.dart';
import '../widgets/theme_toggle.dart';

/// Rendered as the "Profile" tab.
class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: ValueListenableBuilder<bool>(
        valueListenable: SampleData.isLoggedIn,
        builder: (context, isLoggedIn, child) {
          if (!isLoggedIn) {
            return const _LoggedOutView();
          }
          return const _LoggedInView();
        },
      ),
    );
  }
}

class _LoggedInView extends StatelessWidget {
  const _LoggedInView();

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      children: [
        const TabHeader(
          title: 'Student Profile',
          subtitle: 'Manage your campus identity and account settings.',
        ),
        const SizedBox(height: 24),
        Center(
          child: Stack(
            children: [
              Container(
                width: 96,
                height: 96,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: AppColors.blueGradient,
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primary.withValues(alpha: 0.35),
                      blurRadius: 20,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Center(
                  child: Text(
                    SampleData.studentName
                        .trim()
                        .split(RegExp(r'\s+'))
                        .map((w) => w[0])
                        .take(2)
                        .join()
                        .toUpperCase(),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 32,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ),
              Positioned(
                bottom: 2,
                right: 2,
                child: Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    color: AppColors.success,
                    shape: BoxShape.circle,
                    border: Border.all(color: context.colors.background, width: 3),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        Center(
          child: Text(
            SampleData.studentName,
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w700,
              color: context.colors.textPrimary,
            ),
          ),
        ),
        const SizedBox(height: 4),
        Center(
          child: Text(
            '${SampleData.studentId}  ·  ${SampleData.studentEmail}',
            style: TextStyle(color: context.colors.textMuted, fontSize: 12),
          ),
        ),
        const SizedBox(height: 28),
        const ThemeToggleRow(),
        _Tile(
          icon: Icons.edit_outlined,
          label: 'Edit Profile',
          onTap: () => showToast(context, 'Edit profile'),
        ),
        _Tile(
          icon: Icons.directions_bus_outlined,
          label: 'My Routes',
          onTap: () => context.push(AppRoutes.bus),
        ),
        _Tile(
          icon: Icons.fact_check_outlined,
          label: 'Attendance History',
          onTap: () => context.push(AppRoutes.attendance),
        ),
        _Tile(
          icon: Icons.settings_outlined,
          label: 'Settings',
          onTap: () => showToast(context, 'Settings'),
        ),
        _Tile(
          icon: Icons.info_outline_rounded,
          label: 'About',
          onTap: () => context.push(AppRoutes.about),
        ),
        const SizedBox(height: 8),
        _Tile(
          icon: Icons.logout_rounded,
          label: 'Logout',
          danger: true,
          onTap: () {
            SampleData.isLoggedIn.value = false;
            showToast(context, 'Logged out');
          },
        ),
        const SizedBox(height: 20),
        Center(
          child: Text(
            'Developer: Rajesh Biswas (rajeshbiswas.dev)',
            style: TextStyle(
              color: context.colors.textMuted,
              fontSize: 11,
              fontStyle: FontStyle.italic,
            ),
          ),
        ),
      ],
    );
  }
}

class _LoggedOutView extends StatelessWidget {
  const _LoggedOutView();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const HorizonLogo(size: 96),
          const SizedBox(height: 24),
          Text(
            'BU Horizon',
            style: TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.w800,
              letterSpacing: 1,
              color: context.colors.textPrimary,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Your Campus Companion',
            style: TextStyle(fontSize: 14, color: context.colors.textSecondary),
          ),
          const SizedBox(height: 24),
          const ThemeToggleRow(),
          const SizedBox(height: 16),
          GlassCard(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
            child: Column(
              children: [
                Text(
                  'Join your campus network to sync your course schedules, track classes and bus notifications, check attendance history, and build your student profile.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 13.5,
                    color: context.colors.textSecondary,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 28),
                PrimaryButton(
                  label: 'Sign In',
                  onPressed: () => context.push(AppRoutes.login),
                ),
                const SizedBox(height: 14),
                TextButton(
                  onPressed: () => context.push(AppRoutes.register),
                  child: const Text(
                    'Create an Account',
                    style: TextStyle(
                      color: AppColors.primary,
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const Spacer(),
          Text(
            'Developer: Rajesh Biswas (rajeshbiswas.dev)',
            style: TextStyle(
              color: context.colors.textMuted,
              fontSize: 11,
              fontStyle: FontStyle.italic,
            ),
          ),
          const SizedBox(height: 10),
        ],
      ),
    );
  }
}

class _Tile extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool danger;
  const _Tile({
    required this.icon,
    required this.label,
    required this.onTap,
    this.danger = false,
  });

  @override
  Widget build(BuildContext context) {
    final color = danger ? AppColors.danger : context.colors.textPrimary;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: context.colors.surfaceAlt,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: context.colors.border),
            ),
            child: Row(
              children: [
                Icon(
                  icon,
                  color: danger ? AppColors.danger : context.colors.textSecondary,
                  size: 20,
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Text(
                    label,
                    style: TextStyle(fontSize: 14.5, color: color),
                  ),
                ),
                if (!danger)
                  Icon(Icons.chevron_right_rounded, color: context.colors.textMuted),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
