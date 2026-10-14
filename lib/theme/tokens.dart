import 'dart:ui';

import 'package:flutter/cupertino.dart' show CupertinoPageTransitionsBuilder;
import 'package:flutter/material.dart';

const kFont = 'PlusJakartaSans';

/// Paleta costera: base blanca pura, agua/cyan como color principal,
/// coral como acento. Tinta oscura azul-pizarra, nunca negro puro.
abstract final class KColors {
  // Base (60%)
  static const white = Color(0xFFFFFFFF);

  /// Relleno neutro frío para pistas, chips y campos (nada de beige).
  static const mist = Color(0xFFF2F5F8);
  static const surface = Color(0xFFFFFFFF);

  // Tinta (30%)
  static const ink = Color(0xFF1E3442);
  static const inkSoft = Color(0xFF4F6573);

  /// Texto terciario: lo más claro que sigue siendo legible (≥4.5:1 en blanco).
  static const inkMuted = Color(0xFF657683);
  static const line = Color(0xFFE6EBEF);

  // Marca (10%)
  static const sea = Color(0xFF1B9DD9);

  /// Relleno de acciones con texto blanco y texto de marca (≥4.5:1).
  static const seaDeep = Color(0xFF0E78AD);
  static const lagoon = Color(0xFF33C2B4);

  /// Laguna para texto; [lagoon] solo alcanza para iconos y gráficas.
  static const lagoonDeep = Color(0xFF1A8277);
  static const sky = Color(0xFF9ED9F2);
  static const coral = Color(0xFFFF8A5C);
  static const coralDeep = Color(0xFFEC6A3C);
  static const sun = Color(0xFFF5B94A);

  // Estados
  static const success = Color(0xFF2BB57A);
  static const danger = Color(0xFFE5574B);

  /// Oscurece [c] hacia la tinta lo justo para leerse como texto sobre
  /// blanco o sobre su propio tinte al 10–13%.
  static Color readable(Color c) {
    for (var t = 0.0; t < 1; t += 0.05) {
      final v = Color.lerp(c, ink, t)!;
      if (1.05 / (v.computeLuminance() + 0.05) >= 5) return v;
    }
    return ink;
  }
}

/// Grid de 4/8 pt.
abstract final class KSpace {
  static const xs = 4.0;
  static const s = 8.0;
  static const m = 12.0;
  static const l = 16.0;
  static const xl = 24.0;
  static const xxl = 32.0;
  static const xxxl = 48.0;

  /// Espacio inferior que deja libre la barra flotante.
  static const navClearance = 128.0;
}

abstract final class KRadius {
  static const chip = 999.0;
  static const button = 18.0;
  static const tile = 16.0;
  static const card = 24.0;
  static const sheet = 32.0;
}

/// Una sola familia (Plus Jakarta Sans), 2 pesos y una escala cerrada:
/// display 32 · displaySmall 28 · title 22 · headline 17 · body 15 ·
/// bodySmall/label 14 · caption 12.5 · micro 11.5. Nada de fontSize sueltos.
abstract final class KText {
  static const _tab = [FontFeature.tabularFigures()];

  static TextStyle get _base =>
      const TextStyle(fontFamily: kFont, color: KColors.ink);

  /// Cifras protagonistas (totales, centro del donut).
  static TextStyle get display => _base.copyWith(
    fontSize: 32,
    fontWeight: FontWeight.w700,
    letterSpacing: -0.8,
    height: 1.1,
    fontFeatures: _tab,
  );

  /// Cifras grandes secundarias (total del carrito, métricas del cierre).
  static TextStyle get displaySmall => display.copyWith(fontSize: 28);

  static TextStyle get title => _base.copyWith(
    fontSize: 22,
    fontWeight: FontWeight.w700,
    letterSpacing: -0.4,
    height: 1.2,
  );

  static TextStyle get body =>
      _base.copyWith(fontSize: 15, fontWeight: FontWeight.w500, height: 1.35);

  static TextStyle get bodyStrong => body.copyWith(fontWeight: FontWeight.w700);

  /// Títulos de sección y nombres destacados en cards.
  static TextStyle get headline => bodyStrong.copyWith(fontSize: 17);

  /// Texto corrido compacto (líneas de pedido, avisos).
  static TextStyle get bodySmall => body.copyWith(fontSize: 14);

  /// Botones secundarios, chips, etiquetas de campo.
  static TextStyle get label => bodySmall.copyWith(fontWeight: FontWeight.w700);

  static TextStyle get caption => _base.copyWith(
    fontSize: 12.5,
    fontWeight: FontWeight.w500,
    color: KColors.inkSoft,
    height: 1.3,
  );

  /// Notas mínimas: "Opcional", unidades bajo un precio, etiquetas de la barra.
  static TextStyle get micro => caption.copyWith(fontSize: 11.5);

  static TextStyle get number => bodyStrong.copyWith(fontFeatures: _tab);
}

abstract final class KMotion {
  static const fast = Duration(milliseconds: 180);
  static const base = Duration(milliseconds: 280);
  static const slow = Duration(milliseconds: 520);
  static const ease = Curves.easeOutCubic;
  static const spring = Curves.easeOutBack;
}

ThemeData buildKosteoTheme() {
  return ThemeData(
    useMaterial3: true,
    fontFamily: kFont,
    colorScheme: ColorScheme.fromSeed(
      seedColor: KColors.sea,
      primary: KColors.sea,
      secondary: KColors.coral,
      surface: KColors.white,
    ),
    scaffoldBackgroundColor: KColors.white,
    splashFactory: NoSplash.splashFactory,
    highlightColor: Colors.transparent,
    hoverColor: KColors.sea.withValues(alpha: 0.04),
    textSelectionTheme: TextSelectionThemeData(
      cursorColor: KColors.sea,
      selectionColor: KColors.sky.withValues(alpha: 0.5),
      selectionHandleColor: KColors.sea,
    ),
    pageTransitionsTheme: PageTransitionsTheme(
      builders: {
        for (final p in TargetPlatform.values)
          p: const CupertinoPageTransitionsBuilder(),
      },
    ),
  );
}

/// Desplazamiento con rebote y arrastre con mouse/trackpad (Windows como tablet).
class KosteoScrollBehavior extends MaterialScrollBehavior {
  const KosteoScrollBehavior();

  @override
  Set<PointerDeviceKind> get dragDevices => PointerDeviceKind.values.toSet();

  @override
  ScrollPhysics getScrollPhysics(BuildContext context) =>
      const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics());

  @override
  Widget buildOverscrollIndicator(
    BuildContext context,
    Widget child,
    ScrollableDetails details,
  ) => child;
}

extension KResponsive on BuildContext {
  double get screenWidth => MediaQuery.sizeOf(this).width;
  bool get isTablet => screenWidth >= 720;
  bool get isWide => screenWidth >= 1100;
  double get gutter => isTablet ? 32 : 20;
  bool get reduceMotion => MediaQuery.of(this).disableAnimations;
}
