import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../data/app_store.dart';
import '../theme/tokens.dart';

/// Envuelve cualquier cosa tocable: se hunde un poco al presionar y rebota
/// al soltar, con un clic háptico ligero. Reemplaza al ripple de Material.
class Pressable extends StatefulWidget {
  const Pressable({
    super.key,
    required this.child,
    this.onTap,
    this.scale = 0.96,
    this.haptic = true,
    this.semanticLabel,
  });

  final Widget child;
  final VoidCallback? onTap;
  final double scale;
  final bool haptic;
  final String? semanticLabel;

  @override
  State<Pressable> createState() => _PressableState();
}

class _PressableState extends State<Pressable> {
  bool _down = false;

  void _set(bool v) {
    if (widget.onTap == null || _down == v) return;
    setState(() => _down = v);
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: widget.onTap != null,
      label: widget.semanticLabel,
      child: MouseRegion(
        cursor: widget.onTap != null
            ? SystemMouseCursors.click
            : MouseCursor.defer,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapDown: (_) => _set(true),
          onTapUp: (_) => _set(false),
          onTapCancel: () => _set(false),
          onTap: widget.onTap == null
              ? null
              : () {
                  if (widget.haptic) HapticFeedback.selectionClick();
                  widget.onTap!();
                },
          child: AnimatedScale(
            scale: _down ? widget.scale : 1,
            duration: _down
                ? const Duration(milliseconds: 90)
                : const Duration(milliseconds: 320),
            curve: _down ? Curves.easeOut : Curves.easeOutBack,
            child: widget.child,
          ),
        ),
      ),
    );
  }
}

/// Entrada escalonada: aparece con fade + leve desplazamiento hacia arriba.
/// [index] retrasa la entrada para crear cascada en listas.
class FadeSlideIn extends StatelessWidget {
  const FadeSlideIn({
    super.key,
    required this.child,
    this.index = 0,
    this.offset = 16,
  });

  final Widget child;
  final int index;
  final double offset;

  @override
  Widget build(BuildContext context) {
    if (context.reduceMotion) return child;
    final delay = (index.clamp(0, 10)) * 45;
    final total = 380 + delay;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: Duration(milliseconds: total),
      curve: Interval(delay / total, 1, curve: KMotion.ease),
      builder: (context, t, child) => Opacity(
        opacity: t,
        child: Transform.translate(
          offset: Offset(0, (1 - t) * offset),
          child: child,
        ),
      ),
      child: child,
    );
  }
}

/// Cifra de dinero que "cuenta" hasta su nuevo valor.
class AnimatedMoney extends StatelessWidget {
  const AnimatedMoney(this.value, {super.key, required this.style});
  final num? value;
  final TextStyle style;

  @override
  Widget build(BuildContext context) {
    if (value == null) return Text('Pendiente', style: style);
    return TweenAnimationBuilder<double>(
      tween: Tween(end: value!.toDouble()),
      duration: context.reduceMotion ? Duration.zero : KMotion.slow,
      curve: KMotion.ease,
      builder: (context, v, _) => Text(money(v), style: style),
    );
  }
}

/// Cambia de valor con un pequeño "pop" (contadores, badges).
class PopSwitcher extends StatelessWidget {
  const PopSwitcher({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: KMotion.base,
      switchInCurve: KMotion.spring,
      switchOutCurve: Curves.easeIn,
      transitionBuilder: (child, a) => ScaleTransition(
        scale: Tween(begin: 0.6, end: 1.0).animate(a),
        child: FadeTransition(opacity: a, child: child),
      ),
      child: child,
    );
  }
}
