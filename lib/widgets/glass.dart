import 'dart:ui';

import 'package:flutter/material.dart';

import '../theme/tokens.dart';

/// Liquid glass limpio: blur real + tinte blanco + borde fino. Sin sombras.
/// Solo para capas flotantes puntuales (barra de navegación, sheets, avisos).
class Glass extends StatelessWidget {
  const Glass({
    super.key,
    required this.child,
    this.radius = KRadius.card,
    this.blur = 24,
    this.opacity = 0.7,
    this.padding,
  });

  final Widget child;
  final double radius;
  final double blur;
  final double opacity;
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    final br = BorderRadius.circular(radius);
    return ClipRRect(
      borderRadius: br,
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
        child: DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: br,
            color: Colors.white.withValues(alpha: opacity),
            border: Border.all(color: KColors.ink.withValues(alpha: 0.07)),
          ),
          child: Padding(padding: padding ?? EdgeInsets.zero, child: child),
        ),
      ),
    );
  }
}
