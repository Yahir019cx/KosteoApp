import 'package:flutter/material.dart';

import '../theme/tokens.dart';
import 'api_activity.dart';
import 'basics.dart';

/// Pantalla de arranque: solo el logo mientras se hace la primera carga.
/// Si la carga falla, muestra el error y un botón para reintentar.
class Splash extends StatelessWidget {
  const Splash({super.key, this.error, required this.onRetry});
  final String? error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => ColoredBox(
    color: KColors.white,
    child: SafeArea(
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TweenAnimationBuilder<double>(
              tween: Tween(begin: 0.85, end: 1),
              duration: const Duration(milliseconds: 700),
              curve: Curves.easeOutBack,
              builder: (context, s, child) => Transform.scale(
                scale: s,
                child: Opacity(
                  opacity: ((s - 0.85) / 0.15).clamp(0, 1),
                  child: child,
                ),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(32),
                child: Image.asset(
                  'assets/fonts/logo/iconoKosteo.png',
                  width: 132,
                  height: 132,
                  // El PNG es grande; decodificarlo al tamaño en pantalla.
                  cacheWidth: 400,
                  filterQuality: FilterQuality.medium,
                ),
              ),
            ),
            if (error == null) ...[
              const SizedBox(height: KSpace.xxl),
              const BouncingDots(),
              const SizedBox(height: KSpace.l),
              Text('Estamos cargando tu app…', style: KText.caption),
            ] else ...[
              const SizedBox(height: KSpace.xl),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: KSpace.xxl),
                child: Text(
                  error!,
                  style: KText.caption,
                  textAlign: TextAlign.center,
                ),
              ),
              const SizedBox(height: KSpace.l),
              PrimaryButton(label: 'Reintentar', expand: false, onTap: onRetry),
            ],
          ],
        ),
      ),
    ),
  );
}
