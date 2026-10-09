import 'dart:async';

import 'package:flutter/material.dart';

import '../data/api_client.dart';
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
    if (ApiClient.pending.value > 0) {
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
                child: Center(
                  child: Container(
                    width: 72,
                    height: 72,
                    padding: const EdgeInsets.all(KSpace.l),
                    decoration: BoxDecoration(
                      color: KColors.white,
                      borderRadius: BorderRadius.circular(KRadius.card),
                    ),
                    child: const CircularProgressIndicator(
                      strokeWidth: 3,
                      color: KColors.sea,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
    ],
  );
}
