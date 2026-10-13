import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../data/app_store.dart';
import '../theme/tokens.dart';
import 'glass_sheet.dart';
import 'toast.dart';

final apiNavigatorKey = GlobalKey<NavigatorState>();

/// Indicador discreto de actualización y envíos; no bloquea la captura.
class ApiActivity extends StatefulWidget {
  const ApiActivity({super.key, required this.child});
  final Widget child;

  @override
  State<ApiActivity> createState() => _ApiActivityState();
}

class _ApiActivityState extends State<ApiActivity> {
  late final _outbox = store.outbox;
  int _completed = 0;

  @override
  void initState() {
    super.initState();
    _completed = _outbox.completed;
    _outbox.addListener(_onChange);
  }

  void _onChange() {
    if (_completed != _outbox.completed) {
      _completed = _outbox.completed;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final overlay = apiNavigatorKey.currentState?.overlay;
        if (mounted && overlay != null) {
          showToast(
            overlay.context,
            'Guardado: ${_outbox.lastSaved}',
            targetOverlay: overlay,
          );
        }
      });
    }
  }

  @override
  void dispose() {
    _outbox.removeListener(_onChange);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Stack(
    children: [
      widget.child,
      Positioned(
        top: MediaQuery.paddingOf(context).top + 4,
        right: 12,
        child: ListenableBuilder(
          listenable: store.outbox,
          builder: (context, _) {
            final items = store.outbox.items;
            if (!store.loaded || items.isEmpty) {
              return const SizedBox.shrink();
            }
            return Material(
              color: KColors.white,
              elevation: 2,
              borderRadius: BorderRadius.circular(20),
              child: InkWell(
                onTap: () => _pending(context),
                borderRadius: BorderRadius.circular(20),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  child: Text(
                    items.any((i) => i.error != null)
                        ? 'Envíos por revisar'
                        : items.isNotEmpty
                        ? 'Enviando ${items.length}'
                        : 'Guardado',
                    style: KText.caption,
                  ),
                ),
              ),
            );
          },
        ),
      ),
    ],
  );
  Future<void> _pending(BuildContext context) => showGlassSheet<void>(
    apiNavigatorKey.currentState?.overlay?.context ?? context,
    builder: (_) => ListenableBuilder(
      listenable: store.outbox,
      builder: (context, _) => SheetBody(
        title: 'Envíos',
        subtitle: 'Puedes seguir capturando mientras se envían.',
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (store.outbox.items.isEmpty)
              Text(
                store.outbox.lastSaved == null
                    ? 'Actualizando datos del servidor.'
                    : 'Guardado: ${store.outbox.lastSaved}',
                style: KText.body,
              ),
            for (final item in store.outbox.items)
              Padding(
                padding: const EdgeInsets.only(bottom: KSpace.m),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(item.label, style: KText.bodyStrong),
                    Text(
                      item.error ??
                          (item.sending ? 'Enviando…' : 'Pendiente de envío'),
                      style: KText.caption,
                    ),
                    if (item.error != null)
                      TextButton(
                        onPressed: () => store.outbox.retry(item),
                        child: const Text('Reintentar'),
                      ),
                  ],
                ),
              ),
          ],
        ),
      ),
    ),
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
