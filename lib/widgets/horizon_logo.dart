// Developed by Rajesh Biswas (rajeshbiswas.dev)
import 'package:flutter/material.dart';

/// Stylized BU Horizon emblem: loads the official logo asset.
class HorizonLogo extends StatelessWidget {
  final double size;
  const HorizonLogo({super.key, this.size = 48});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.white,
      ),
      clipBehavior: Clip.antiAlias,
      padding: EdgeInsets.all(size * 0.001),
      child: Image.asset(
        'assets/images/logo.png',
        fit: BoxFit.contain,
        semanticLabel: 'BU Horizon logo',
      ),
    );
  }
}
