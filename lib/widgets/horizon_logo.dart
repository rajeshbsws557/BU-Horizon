// Developed by Rajesh Biswas (rajeshbiswas.dev)
import 'package:flutter/material.dart';

/// Stylized BU Horizon emblem: loads the official logo asset.
class HorizonLogo extends StatelessWidget {
  final double size;
  const HorizonLogo({super.key, this.size = 48});

  @override
  Widget build(BuildContext context) {
    return ClipOval(
      child: Image.asset(
        'assets/images/logo.png',
        width: size,
        height: size,
        fit: BoxFit.cover,
        semanticLabel: 'BU Horizon logo',
      ),
    );
  }
}
