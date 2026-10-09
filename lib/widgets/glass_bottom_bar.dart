import 'package:flutter/material.dart';

import '../theme/icons.dart';
import '../theme/tokens.dart';
import 'glass.dart';
import 'motion.dart';

class NavItem {
  const NavItem(this.label, this.icon);
  final String label;
  final IconData icon;
}

/// Barra flotante en liquid glass: rectángulo con esquinas redondeadas (no pill).
/// Slots: [tab0, tab1, acciones, tab2, tab3].
/// La sección activa solo cambia de color: sin fondos, sin sombras.
class GlassBottomBar extends StatelessWidget {
  const GlassBottomBar({
    super.key,
    required this.tabs,
    required this.index,
    required this.onTab,
    required this.onPlus,
    this.plusOpen = false,
  });

  final List<NavItem> tabs; // exactamente 4
  final int index;
  final ValueChanged<int> onTab;
  final VoidCallback onPlus;
  final bool plusOpen;

  static const height = 68.0;
  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.paddingOf(context).bottom;
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 0, 20, (bottom > 0 ? bottom : 0) + 16),
      child: Center(
        heightFactor: 1,
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: context.isTablet ? 460 : 420),
          child: SizedBox(
            height: height,
            child: Glass(
              radius: KRadius.card, // rectángulo redondeado, no pill
              opacity: 0.72,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6),
                child: Row(
                  children: [
                    _tab(0),
                    _tab(1),
                    Expanded(
                      child: Center(
                        child: _PlusButton(onTap: onPlus, open: plusOpen),
                      ),
                    ),
                    _tab(2),
                    _tab(3),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _tab(int i) => Expanded(
    child: _NavButton(item: tabs[i], active: i == index, onTap: () => onTab(i)),
  );
}

class _NavButton extends StatelessWidget {
  const _NavButton({
    required this.item,
    required this.active,
    required this.onTap,
  });
  final NavItem item;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = active ? KColors.seaDeep : KColors.inkMuted;
    return Pressable(
      onTap: onTap,
      scale: 0.88,
      semanticLabel: item.label,
      child: SizedBox(
        height: double.infinity,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            TweenAnimationBuilder<Color?>(
              tween: ColorTween(end: color),
              duration: KMotion.base,
              builder: (_, c, _) => Icon(item.icon, color: c, size: 24),
            ),
            const SizedBox(height: 3),
            AnimatedDefaultTextStyle(
              duration: KMotion.base,
              style: KText.caption.copyWith(fontSize: 11, color: color),
              child: Text(item.label),
            ),
          ],
        ),
      ),
    );
  }
}

/// Botón central de acciones: cuadrado redondeado dentro de la barra.
/// Con el menú abierto el icono de cuadritos cambia a ×.
class _PlusButton extends StatelessWidget {
  const _PlusButton({required this.onTap, required this.open});
  final VoidCallback onTap;
  final bool open;

  @override
  Widget build(BuildContext context) {
    return Pressable(
      onTap: onTap,
      scale: 0.88,
      semanticLabel: 'Acciones rápidas',
      child: Container(
        width: 52,
        height: 52,
        decoration: BoxDecoration(
          color: KColors.sea,
          borderRadius: BorderRadius.circular(16),
        ),
        child: AnimatedSwitcher(
          duration: KMotion.base,
          transitionBuilder: (c, a) => RotationTransition(
            turns: Tween(begin: 0.75, end: 1.0).animate(a),
            child: ScaleTransition(scale: a, child: c),
          ),
          child: Icon(
            open ? KIcons.x : KIcons.grid,
            key: ValueKey(open),
            color: Colors.white,
            size: 24,
          ),
        ),
      ),
    );
  }
}
