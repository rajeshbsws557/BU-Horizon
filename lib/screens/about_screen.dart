// Developed by Rajesh Biswas (rajeshbiswas.dev)
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../config/app_links.dart';
import '../theme/app_theme.dart';
import '../widgets/common.dart';
import '../widgets/horizon_logo.dart';

class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  /// Only links with a real destination are listed. A policy that has not been
  /// published yet simply has no row, instead of a tappable "coming soon" one.
  static List<_AboutLink> _linksFor() {
    const email = AppLinks.contactEmail;
    return <_AboutLink>[
      const _AboutLink(
        icon: Icons.privacy_tip_outlined,
        label: 'Privacy Policy',
        url: AppLinks.privacyPolicyUrl,
      ),
      const _AboutLink(
        icon: Icons.description_outlined,
        label: 'Terms of Service',
        url: AppLinks.termsOfServiceUrl,
      ),
      _AboutLink(
        icon: Icons.mail_outline_rounded,
        label: 'Contact Us',
        url: email == null ? null : 'mailto:$email',
      ),
      const _AboutLink(
        icon: Icons.code_rounded,
        label: 'About Developer',
        url: AppLinks.developerUrl,
      ),
    ].where((link) => link.url != null).toList();
  }

  Future<void> _open(BuildContext context, _AboutLink link) async {
    final uri = Uri.tryParse(link.url!);
    var opened = false;
    if (uri != null) {
      try {
        opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
      } catch (_) {
        opened = false;
      }
    }
    if (!opened && context.mounted) {
      showToast(context, 'Could not open ${link.label}');
    }
  }

  @override
  Widget build(BuildContext context) {
    final links = _linksFor();
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
              (link) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _LinkTile(
                  icon: link.icon,
                  label: link.label,
                  onTap: () => _open(context, link),
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

/// One About row. [url] is null while the destination is unpublished, which
/// keeps the row out of the list entirely.
class _AboutLink {
  final IconData icon;
  final String label;
  final String? url;

  const _AboutLink({required this.icon, required this.label, this.url});
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
      hint: 'Opens outside the app',
      excludeSemantics: true,
      child: Material(
        color: context.colors.surfaceAlt,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: onTap,
          child: Container(
            constraints: const BoxConstraints(minHeight: 52),
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
                  Icons.open_in_new_rounded,
                  size: 18,
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
