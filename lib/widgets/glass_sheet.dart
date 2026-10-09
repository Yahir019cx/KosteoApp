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
              onTap: () {
                FocusManager.instance.primaryFocus?.unfocus();
                Navigator.of(context).maybePop();
              },
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

  void _unfocus() => FocusManager.instance.primaryFocus?.unfocus();

  void _dragBy(double dy) => setState(() => _drag = (_drag + dy).clamp(0, 600));

  void _release(double velocity) {
    if (_drag > 110 || (_drag > 0 && velocity > 700)) {
      _unfocus();
      Navigator.of(context).maybePop();
    } else if (_drag != 0) {
      setState(() => _drag = 0);
    }
  }

  /// Si el contenido es scrolleable, arrastrar hacia abajo estando ya arriba
  /// mueve la hoja en lugar del scroll (como en iOS).
  bool _onScroll(ScrollNotification n) {
    if (n.depth != 0) return false;
    if (n is OverscrollNotification &&
        n.dragDetails != null &&
        n.overscroll < 0) {
      _dragBy(-n.overscroll);
    } else if (n is ScrollUpdateNotification &&
        n.dragDetails != null &&
        _drag > 0) {
      _dragBy(n.dragDetails!.delta.dy);
    } else if (n is ScrollEndNotification && _drag > 0) {
      _release(n.dragDetails?.primaryVelocity ?? 0);
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
    final safeBottom = MediaQuery.paddingOf(context).bottom;
    final safeTop = MediaQuery.paddingOf(context).top;
    final height = MediaQuery.sizeOf(context).height;
    // Con el teclado abierto la hoja no debe tapar toda la pantalla: siempre
    // queda una franja de fondo para tocar y cerrar.
    final maxHeight = (height - bottomInset - safeTop - 48).clamp(
      120.0,
      height * 0.9,
    );
    return Align(
      alignment: Alignment.bottomCenter,
      child: AnimatedPadding(
        duration: KMotion.fast,
        padding: EdgeInsets.only(bottom: bottomInset),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: widget.maxWidth,
            maxHeight: maxHeight,
          ),
          child: GestureDetector(
            // Tocar fuera de un campo cierra el teclado.
            onTap: _unfocus,
            onVerticalDragStart: (_) => _unfocus(),
            onVerticalDragUpdate: (d) => _dragBy(d.delta.dy),
            onVerticalDragEnd: (d) => _release(d.primaryVelocity ?? 0),
            child: NotificationListener<ScrollNotification>(
              onNotification: _onScroll,
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
      // Clamping para que el arrastre en el tope pase a la hoja; deslizar
      // también baja el teclado.
      physics: const ClampingScrollPhysics(),
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
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
