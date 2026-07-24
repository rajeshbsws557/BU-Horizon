// Developed by Rajesh Biswas (rajeshbiswas.dev)
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../widgets/common.dart';
import '../widgets/horizon_logo.dart';

class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final links = <List<dynamic>>[
      [Icons.privacy_tip_outlined, 'Privacy Policy'],
      [Icons.description_outlined, 'Terms of Service'],
      [Icons.mail_outline_rounded, 'Contact Us'],
      [Icons.code_rounded, 'About Developer'],
    ];
    return Scaffold(
      appBar: AppBar(title: const Text('BU Horizon')),
      body: ResponsivePage(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            const SizedBox(height: 10),
            const Center(child: HorizonLogo(size: 96)),
            const SizedBox(height: 16),
            Center(
              child: Text(
                'BU Horizon',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.5,
                  color: context.colors.textPrimary,
                ),
              ),
            ),
            const SizedBox(height: 6),
            Center(
              child: Text(
                'Version 1.0.0',
                style: TextStyle(
                  color: context.colors.textSecondary,
                  fontSize: 13,
                ),
              ),
            ),
            const SizedBox(height: 16),
            Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Text(
                  'BU Horizon is your all-in-one campus companion.\nStay informed, connected and ahead.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: context.colors.textSecondary,
                    fontSize: 13,
                    height: 1.5,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 28),
            ...links.map(
              (l) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _LinkTile(
                  icon: l[0] as IconData,
                  label: l[1] as String,
                  onTap: () => showToast(context, '${l[1]} coming soon'),
                ),
              ),
            ),
            const SizedBox(height: 24),
            Center(
              child: Text(
                '© ${DateTime.now().year} BU Horizon. All rights reserved.',
                style: TextStyle(
                  color: context.colors.textMuted,
                  fontSize: 11.5,
                ),
              ),
            ),
            const SizedBox(height: 8),
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
        ),
      ),
    );
  }
}

class _LinkTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  const _LinkTile({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: label,
      child: Material(
        color: context.colors.surfaceAlt,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: context.colors.border),
            ),
            child: Row(
              children: [
                Icon(icon, color: context.colors.textSecondary, size: 20),
                const SizedBox(width: 14),
                Expanded(
                  child: Text(
                    label,
                    style: TextStyle(
                      fontSize: 14.5,
                      color: context.colors.textPrimary,
                    ),
                  ),
                ),
                Icon(
                  Icons.chevron_right_rounded,
                  color: context.colors.textMuted,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
