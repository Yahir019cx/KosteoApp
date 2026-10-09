import 'package:flutter/material.dart';

import '../data/app_store.dart';
import '../theme/icons.dart';
import '../theme/tokens.dart';
import 'motion.dart';

/// Foto del platillo; si no tiene, muestra su icono sobre el tinte.
class DishImage extends StatelessWidget {
  const DishImage({
    super.key,
    required this.product,
    this.radius = KRadius.card - 6,
  });
  final Product product;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final img = product.image;
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: AnimatedSwitcher(
        duration: KMotion.base,
        child: img != null
            ? Image.memory(
                img,
                key: ValueKey(img.hashCode),
                errorBuilder: (_, error, stack) => ColoredBox(
                  color: product.tint,
                  child: Center(
                    child: Icon(product.icon, color: KColors.inkSoft),
                  ),
                ),
                fit: BoxFit.cover,
                width: double.infinity,
                height: double.infinity,
              )
            : Container(
                key: const ValueKey('icon'),
                color: product.tint,
                alignment: Alignment.center,
                child: LayoutBuilder(
                  builder: (_, c) => Icon(
                    product.icon,
                    size: (c.maxHeight * 0.36).clamp(20, 56),
                    color: Color.lerp(product.tint, KColors.ink, 0.45),
                  ),
                ),
              ),
      ),
    );
  }
}

/// Producto del menú: foto, nombre, precio y +. Si tiene presentaciones
/// (Individual/Doble) se eligen en la misma card y el precio cambia al instante.
/// Mantener presionado permite cambiar la foto.
class ProductCard extends StatelessWidget {
  const ProductCard({
    super.key,
    required this.product,
    required this.inCart,
    required this.size,
    required this.onSize,
    required this.onAdd,
    this.onLongPress,
  });

  final Product product;
  final int inCart;
  final String? size;
  final ValueChanged<String> onSize;
  final VoidCallback onAdd;
  final VoidCallback? onLongPress;

  @override
  Widget build(BuildContext context) {
    final sizes = product.sizes;
    return GestureDetector(
      onLongPress: onLongPress,
      child: Pressable(
        onTap: onAdd,
        scale: 0.97,
        semanticLabel: 'Agregar ${product.name}',
        child: AnimatedContainer(
          duration: KMotion.base,
          decoration: BoxDecoration(
            color: KColors.white,
            borderRadius: BorderRadius.circular(KRadius.card),
            border: Border.all(
              color: inCart > 0 ? KColors.sea : KColors.line,
              width: inCart > 0 ? 1.5 : 1,
            ),
          ),
          padding: const EdgeInsets.all(KSpace.s),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    DishImage(product: product),
                    Positioned(
                      top: 8,
                      right: 8,
                      child: PopSwitcher(
                        child: inCart == 0
                            ? const SizedBox.shrink(key: ValueKey(0))
                            : Container(
                                key: ValueKey(inCart),
                                constraints: const BoxConstraints(minWidth: 26),
                                height: 26,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                ),
                                alignment: Alignment.center,
                                decoration: BoxDecoration(
                                  color: KColors.sea,
                                  borderRadius: BorderRadius.circular(
                                    KRadius.chip,
                                  ),
                                  border: Border.all(
                                    color: Colors.white,
                                    width: 2,
                                  ),
                                ),
                                child: Text(
                                  '$inCart',
                                  style: KText.caption.copyWith(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(6, KSpace.m, 4, 4),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      product.name,
                      style: KText.bodyStrong.copyWith(fontSize: 14),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (sizes != null) ...[
                      const SizedBox(height: KSpace.s),
                      _SizeToggle(
                        sizes: sizes.keys.toList(),
                        selected: size,
                        onChanged: onSize,
                      ),
                    ],
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Expanded(
                          child: AnimatedMoney(
                            product.priceFor(size),
                            style: KText.number.copyWith(
                              color: KColors.inkSoft,
                            ),
                          ),
                        ),
                        Container(
                          width: 32,
                          height: 32,
                          decoration: const BoxDecoration(
                            color: KColors.sea,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            KIcons.plusStrong,
                            color: Colors.white,
                            size: 16,
                          ),
                        ),
                      ],
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
}

/// Mini selector Individual / Doble dentro de la card.
class _SizeToggle extends StatelessWidget {
  const _SizeToggle({
    required this.sizes,
    required this.selected,
    required this.onChanged,
  });
  final List<String> sizes;
  final String? selected;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final current = selected ?? sizes.first;
    final i = sizes.indexOf(current);
    return Container(
      height: 30,
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: KColors.mist,
        borderRadius: BorderRadius.circular(KRadius.chip),
      ),
      child: Stack(
        children: [
          AnimatedAlign(
            duration: KMotion.base,
            curve: KMotion.ease,
            alignment: Alignment(-1 + 2 * i / (sizes.length - 1), 0),
            child: FractionallySizedBox(
              widthFactor: 1 / sizes.length,
              heightFactor: 1,
              child: DecoratedBox(
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
              for (final s in sizes)
                Expanded(
                  // Toque propio: elegir tamaño no agrega al pedido.
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () => onChanged(s),
                    child: Center(
                      child: AnimatedDefaultTextStyle(
                        duration: KMotion.base,
                        style: KText.caption.copyWith(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w700,
                          color: s == current
                              ? KColors.seaDeep
                              : KColors.inkMuted,
                        ),
                        child: Text(s),
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
