import 'package:flutter/material.dart';

import '../theme/icons.dart';

import '../data/app_store.dart';
import '../theme/tokens.dart';
import 'basics.dart';
import 'motion.dart';

/// Acción rápida grande para el grid del botón +.
class QuickAction extends StatelessWidget {
  const QuickAction({
    super.key,
    required this.label,
    required this.icon,
    required this.color,
    required this.onTap,
    this.caption,
    this.horizontal = false,
  });

  final String label;
  final String? caption;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  final bool horizontal;

  @override
  Widget build(BuildContext context) {
    final iconBox = Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.13),
        borderRadius: BorderRadius.circular(KRadius.tile),
      ),
      child: Icon(icon, color: color, size: 24),
    );
    final texts = Column(
      crossAxisAlignment: horizontal
          ? CrossAxisAlignment.start
          : CrossAxisAlignment.center,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          style: KText.bodyStrong.copyWith(fontSize: 14),
          textAlign: TextAlign.center,
        ),
        if (caption != null)
          Text(
            caption!,
            style: KText.caption.copyWith(fontSize: 11.5),
            textAlign: TextAlign.center,
          ),
      ],
    );
    return Pressable(
      onTap: onTap,
      scale: 0.95,
      semanticLabel: label,
      child: Container(
        padding: const EdgeInsets.all(KSpace.l),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(KRadius.card - 4),
          border: Border.all(color: KColors.line),
        ),
        child: horizontal
            ? Row(
                children: [
                  iconBox,
                  const SizedBox(width: KSpace.l),
                  Expanded(child: texts),
                  const Icon(
                    KIcons.caretRight,
                    color: KColors.inkMuted,
                    size: 18,
                  ),
                ],
              )
            : Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  iconBox,
                  const SizedBox(height: KSpace.m),
                  texts,
                ],
              ),
      ),
    );
  }
}

/// Fila de compra: insumo, cantidad comprada y hora; total a la derecha.
/// Tocarla permite editarla (p. ej. capturar el rendimiento más tarde).
class PurchaseRow extends StatelessWidget {
  const PurchaseRow({super.key, required this.purchase, this.onTap});
  final Purchase purchase;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final i = purchase.ingredient;
    final p = purchase;
    return Pressable(
      onTap: onTap,
      scale: 0.98,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: KSpace.m - 2),
        child: Row(
          children: [
            IconTile(i.icon, tint: i.category.tint),
            const SizedBox(width: KSpace.m),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(i.name, style: KText.bodyStrong.copyWith(fontSize: 15)),
                  Text('${p.qtyLabel} · ${p.time}', style: KText.caption),
                  if (p.needsYield)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: StatusPill(
                        label: 'Falta rendimiento',
                        color: KColors.coral,
                      ),
                    )
                  else if (p.yieldValue != null)
                    Text(
                      'Rinde ${p.yieldValue} ${i.useUnit}',
                      style: KText.caption.copyWith(color: KColors.lagoon),
                    ),
                ],
              ),
            ),
            Text(money(p.total), style: KText.number),
            if (onTap != null) ...[
              const SizedBox(width: KSpace.s),
              const Icon(KIcons.caretRight, size: 16, color: KColors.inkMuted),
            ],
          ],
        ),
      ),
    );
  }
}

/// Fila de catálogo de insumos: nombre, unidad de uso y último costo.
class IngredientRow extends StatelessWidget {
  const IngredientRow({
    super.key,
    required this.ingredient,
    this.onTap,
    this.showCost = true,
  });
  final Ingredient ingredient;

  /// Último costo a la derecha; se oculta donde solo importa elegir.
  final bool showCost;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final i = ingredient;
    return Pressable(
      onTap: onTap,
      scale: 0.98,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: KSpace.s + 2),
        child: Row(
          children: [
            IconTile(i.icon, tint: i.category.tint, size: 40),
            const SizedBox(width: KSpace.m),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(i.name, style: KText.bodyStrong.copyWith(fontSize: 15)),
                  Text(
                    'Compra ${i.buyUnit} · usa ${i.useUnit}${i.hasYield ? ' · merma' : ''}',
                    style: KText.caption,
                  ),
                ],
              ),
            ),
            if (showCost && i.lastCost != null)
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    money(i.lastCost!),
                    style: KText.number.copyWith(fontSize: 14),
                  ),
                  Text(
                    '/${i.buyUnit}',
                    style: KText.caption.copyWith(fontSize: 11),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}

/// Divisor fino con sangría (para listas dentro de una card).
class InsetDivider extends StatelessWidget {
  const InsetDivider({super.key, this.indent = 56});
  final double indent;

  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.only(left: indent),
    child: Container(height: 1, color: KColors.line.withValues(alpha: 0.7)),
  );
}
