import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/tokens.dart';
import 'motion.dart';

/// Abre un bottom sheet tipo iOS: el fondo se desenfoca progresivamente,
/// la hoja sube con curva suave y se puede cerrar arrastrando hacia abajo.
Future<T?> showGlassSheet<T>(
  BuildContext context, {
  required WidgetBuilder builder,
  double maxWidth = 560,
}) {
  HapticFeedback.lightImpact();
  return showGeneralDialog<T>(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'Cerrar',
    barrierColor: Colors.transparent,
    transitionDuration: const Duration(milliseconds: 420),
    pageBuilder: (context, _, _) =>
        _GlassSheetFrame(maxWidth: maxWidth, builder: builder),
    transitionBuilder: (context, anim, _, child) {
      final curved = CurvedAnimation(
        parent: anim,
        curve: const Cubic(0.2, 0.9, 0.25, 1), // ease-out tipo spring de iOS
        reverseCurve: Curves.easeInCubic,
      );
      return Stack(
        children: [
          // Fondo desenfocado y oscurecido apenas; tocarlo cierra.
          Positioned.fill(
            child: GestureDetector(
              onTap: () => Navigator.of(context).maybePop(),
              child: AnimatedBuilder(
                animation: anim,
                builder: (_, _) => BackdropFilter(
                  filter: ImageFilter.blur(
                    sigmaX: 14 * anim.value,
                    sigmaY: 14 * anim.value,
                  ),
                  child: ColoredBox(
                    color: KColors.ink.withValues(alpha: 0.18 * anim.value),
                  ),
                ),
              ),
            ),
          ),
          SlideTransition(
            position: Tween(
              begin: const Offset(0, 1),
              end: Offset.zero,
            ).animate(curved),
            child: child,
          ),
        ],
      );
    },
  );
}

class _GlassSheetFrame extends StatefulWidget {
  const _GlassSheetFrame({required this.builder, required this.maxWidth});
  final WidgetBuilder builder;
  final double maxWidth;

  @override
  State<_GlassSheetFrame> createState() => _GlassSheetFrameState();
}

class _GlassSheetFrameState extends State<_GlassSheetFrame> {
  double _drag = 0;

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
    final safeBottom = MediaQuery.paddingOf(context).bottom;
    return Align(
      alignment: Alignment.bottomCenter,
      child: AnimatedPadding(
        duration: KMotion.fast,
        padding: EdgeInsets.only(bottom: bottomInset),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: widget.maxWidth,
            maxHeight: MediaQuery.sizeOf(context).height * 0.9,
          ),
          child: GestureDetector(
            onVerticalDragUpdate: (d) =>
                setState(() => _drag = (_drag + d.delta.dy).clamp(0, 600)),
            onVerticalDragEnd: (d) {
              if (_drag > 110 || d.primaryVelocity! > 700) {
                Navigator.of(context).maybePop();
              } else {
                setState(() => _drag = 0);
              }
            },
            child: TweenAnimationBuilder<double>(
              tween: Tween(end: _drag),
              duration: _drag == 0 ? KMotion.base : Duration.zero,
              curve: KMotion.ease,
              builder: (context, dy, child) =>
                  Transform.translate(offset: Offset(0, dy), child: child),
              child: Material(
                type: MaterialType.transparency,
                child: _SheetSurface(
                  safeBottom: bottomInset > 0 ? 0 : safeBottom,
                  child: widget.builder(context),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SheetSurface extends StatelessWidget {
  const _SheetSurface({required this.child, required this.safeBottom});
  final Widget child;
  final double safeBottom;

  @override
  Widget build(BuildContext context) {
    const radius = BorderRadius.vertical(top: Radius.circular(KRadius.sheet));
    return ClipRRect(
      borderRadius: radius,
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 30, sigmaY: 30),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: radius,
            color: KColors.white.withValues(alpha: 0.9),
            border: Border(
              top: BorderSide(color: Colors.white.withValues(alpha: 0.9)),
            ),
          ),
          padding: EdgeInsets.only(bottom: safeBottom + KSpace.l),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: KSpace.m),
              Container(
                width: 40,
                height: 5,
                decoration: BoxDecoration(
                  color: KColors.inkMuted.withValues(alpha: 0.35),
                  borderRadius: BorderRadius.circular(KRadius.chip),
                ),
              ),
              Flexible(child: child),
            ],
          ),
        ),
      ),
    );
  }
}

/// Contenido estándar de un sheet: título centrado + cuerpo con padding.
class SheetBody extends StatelessWidget {
  const SheetBody({
    super.key,
    required this.title,
    this.subtitle,
    required this.child,
  });
  final String title;
  final String? subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(KSpace.xl, KSpace.l, KSpace.xl, 0),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            title,
            style: KText.title.copyWith(fontSize: 19),
            textAlign: TextAlign.center,
          ),
          if (subtitle != null) ...[
            const SizedBox(height: KSpace.xs),
            Text(subtitle!, style: KText.caption, textAlign: TextAlign.center),
          ],
          const SizedBox(height: KSpace.xl),
          FadeSlideIn(child: child),
        ],
      ),
    );
  }
}
