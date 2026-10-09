import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../data/api_client.dart';
import '../data/app_store.dart';
import '../theme/tokens.dart';

/// Overlay de pantalla completa mientras haya peticiones a la API en curso:
/// bloquea los toques al instante y, si tarda, oscurece el fondo y muestra un
/// spinner al centro (el retraso evita parpadeos en respuestas rápidas).
class ApiActivity extends StatefulWidget {
  const ApiActivity({super.key, required this.child});
  final Widget child;

  @override
  State<ApiActivity> createState() => _ApiActivityState();
}

class _ApiActivityState extends State<ApiActivity> {
  bool _blocking = false;
  bool _visible = false;
  Timer? _delay;

  @override
  void initState() {
    super.initState();
    ApiClient.pending.addListener(_onChange);
  }

  void _onChange() {
    // Durante la primera carga ya se ve el splash con el logo.
    if (ApiClient.pending.value > 0 && store.loaded) {
      if (!_blocking) {
        // Las peticiones pueden empezar durante un build.
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted && ApiClient.pending.value > 0) {
            setState(() => _blocking = true);
          }
        });
      }
      _delay ??= Timer(const Duration(milliseconds: 150), () {
        if (mounted) setState(() => _visible = true);
      });
    } else {
      _delay?.cancel();
      _delay = null;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && ApiClient.pending.value == 0) {
          setState(() => _blocking = _visible = false);
        }
      });
    }
  }

  @override
  void dispose() {
    ApiClient.pending.removeListener(_onChange);
    _delay?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Stack(
    children: [
      widget.child,
      if (_blocking)
        Positioned.fill(
          child: AbsorbPointer(
            child: AnimatedOpacity(
              opacity: _visible ? 1 : 0,
              duration: KMotion.fast,
              child: ColoredBox(
                color: KColors.ink.withValues(alpha: 0.35),
                child: const Center(child: BouncingDots()),
              ),
            ),
          ),
        ),
    ],
  );
}

/// Cinco bolitas que suben y bajan una tras otra, como ola.
class BouncingDots extends StatefulWidget {
  const BouncingDots({super.key});

  @override
  State<BouncingDots> createState() => _BouncingDotsState();
}

class _BouncingDotsState extends State<BouncingDots>
    with SingleTickerProviderStateMixin {
  static const _count = 5;
  static const _size = 12.0;
  static const _jump = 14.0;

  /// Del cian al azul profundo, como el logo.
  static const _colors = [
    Color(0xFF3FE6F2),
    Color(0xFF22C3EC),
    KColors.sea,
    KColors.seaDeep,
    Color(0xFF1858C8),
  ];

  late final _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1100),
  )..repeat();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => SizedBox(
    height: _size + _jump,
    child: AnimatedBuilder(
      animation: _controller,
      builder: (context, _) => Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          for (var i = 0; i < _count; i++) ...[
            if (i > 0) const SizedBox(width: 8),
            Transform.translate(
              offset: Offset(0, -_jump * _lift(i)),
              child: Container(
                width: _size,
                height: _size,
                decoration: BoxDecoration(
                  color: _colors[i],
                  shape: BoxShape.circle,
                ),
              ),
            ),
          ],
        ],
      ),
    ),
  );

  /// 0..1: cada bolita salta en su turno y descansa el resto del ciclo.
  double _lift(int i) {
    final t = (_controller.value - i * 0.12) % 1;
    const span = 0.4;
    return t < span ? math.sin(t / span * math.pi) : 0;
  }
}
