import 'package:flutter/material.dart';

import '../theme/tokens.dart';
import 'motion.dart';

/// Chip de selección: relleno agua cuando está activo, contador opcional.
class CategoryChip extends StatelessWidget {
  const CategoryChip({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
    this.count,
    this.icon,
    this.color = KColors.sea,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final int? count;
  final IconData? icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Pressable(
      onTap: onTap,
      scale: 0.94,
      child: AnimatedContainer(
        duration: KMotion.base,
        curve: KMotion.ease,
        height: 40,
        padding: EdgeInsets.only(
          left: KSpace.l,
          right: count != null ? 6 : KSpace.l,
        ),
        decoration: BoxDecoration(
          color: selected ? color : KColors.mist,
          borderRadius: BorderRadius.circular(KRadius.chip),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(
                icon,
                size: 16,
                color: selected ? Colors.white : KColors.inkSoft,
              ),
              const SizedBox(width: 6),
            ],
            AnimatedDefaultTextStyle(
              duration: KMotion.base,
              style: KText.body.copyWith(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: selected ? Colors.white : KColors.inkSoft,
              ),
              child: Text(label),
            ),
            if (count != null) ...[
              const SizedBox(width: KSpace.s),
              AnimatedContainer(
                duration: KMotion.base,
                constraints: const BoxConstraints(minWidth: 28),
                height: 28,
                padding: const EdgeInsets.symmetric(horizontal: 8),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: selected
                      ? Colors.white.withValues(alpha: 0.25)
                      : color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(KRadius.chip),
                ),
                child: PopSwitcher(
                  child: Text(
                    '$count',
                    key: ValueKey(count),
                    style: KText.caption.copyWith(
                      fontWeight: FontWeight.w700,
                      color: selected ? Colors.white : color,
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Fila horizontal desplazable de chips, alineada al gutter de la pantalla.
class ChipBar extends StatelessWidget {
  const ChipBar({super.key, required this.children});
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 56,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: EdgeInsets.symmetric(horizontal: context.gutter, vertical: 8),
        clipBehavior: Clip.none,
        itemCount: children.length,
        separatorBuilder: (_, _) => const SizedBox(width: KSpace.s),
        itemBuilder: (_, i) => children[i],
      ),
    );
  }
}

/// Selector segmentado con "thumb" blanco que se desliza (estilo iOS).
class SegmentedPill<T> extends StatelessWidget {
  const SegmentedPill({
    super.key,
    required this.values,
    required this.selected,
    required this.labelOf,
    required this.onChanged,
    this.height = 44,
  });

  final List<T> values;
  final T selected;
  final String Function(T) labelOf;
  final ValueChanged<T> onChanged;
  final double height;

  @override
  Widget build(BuildContext context) {
    final index = values.indexOf(selected);
    final n = values.length;
    return Container(
      height: height,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: KColors.mist.withValues(alpha: 0.85),
        borderRadius: BorderRadius.circular(KRadius.chip),
      ),
      child: Stack(
        children: [
          AnimatedAlign(
            duration: KMotion.base,
            curve: KMotion.ease,
            alignment: Alignment(n == 1 ? 0 : -1 + 2 * index / (n - 1), 0),
            child: FractionallySizedBox(
              widthFactor: 1 / n,
              heightFactor: 1,
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(KRadius.chip),
                  border: Border.all(color: KColors.line),
                ),
              ),
            ),
          ),
          Row(
            children: [
              for (final v in values)
                Expanded(
                  child: Pressable(
                    onTap: () => onChanged(v),
                    scale: 0.95,
                    child: Center(
                      child: AnimatedDefaultTextStyle(
                        duration: KMotion.base,
                        style: KText.body.copyWith(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: v == selected
                              ? KColors.seaDeep
                              : KColors.inkMuted,
                        ),
                        child: Text(labelOf(v)),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Opción grande seleccionable (unidades, Sí/No, complementos).
class ChoiceTile extends StatelessWidget {
  const ChoiceTile({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
    this.caption,
    this.icon,
    this.minWidth = 64,
  });

  final String label;
  final String? caption;
  final IconData? icon;
  final bool selected;
  final VoidCallback onTap;
  final double minWidth;

  @override
  Widget build(BuildContext context) {
    return Pressable(
      onTap: onTap,
      scale: 0.95,
      child: AnimatedContainer(
        duration: KMotion.base,
        curve: KMotion.ease,
        constraints: BoxConstraints(minWidth: minWidth, minHeight: 48),
        padding: const EdgeInsets.symmetric(
          horizontal: KSpace.l,
          vertical: KSpace.m,
        ),
        decoration: BoxDecoration(
          color: selected ? KColors.sea.withValues(alpha: 0.1) : Colors.white,
          borderRadius: BorderRadius.circular(KRadius.tile),
          border: Border.all(
            color: selected ? KColors.sea : KColors.line,
            width: selected ? 1.6 : 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (icon != null) ...[
              Icon(
                icon,
                size: 18,
                color: selected ? KColors.seaDeep : KColors.inkSoft,
              ),
              const SizedBox(width: KSpace.s),
            ],
            Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: KText.bodyStrong.copyWith(
                    fontSize: 14,
                    color: selected ? KColors.seaDeep : KColors.ink,
                  ),
                ),
                if (caption != null)
                  Text(caption!, style: KText.caption.copyWith(fontSize: 11.5)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
