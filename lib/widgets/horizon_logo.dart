// Developed by Rajesh Biswas (rajeshbiswas.dev)
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// Stylized BU Horizon emblem: loads the official logo asset.
class HorizonLogo extends StatelessWidget {
  final double size;
  final Color color;
  const HorizonLogo({super.key, this.size = 48, this.color = AppColors.primary});

  @override
  Widget build(BuildContext context) {
    return ClipOval(
      child: Image.asset(
        'assets/images/logo.png',
        width: size,
        height: size,
        fit: BoxFit.cover,
      ),
    );
  }
}
