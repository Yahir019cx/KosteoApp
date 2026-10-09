import 'package:flutter/material.dart';

import '../data/app_store.dart';
import '../theme/icons.dart';
import '../theme/tokens.dart';
import '../widgets/basics.dart';
import '../widgets/chips.dart';
import '../widgets/motion.dart';
import '../widgets/product_card.dart';
import '../widgets/toast.dart';
import 'common.dart';
import 'product_edit_screen.dart';

/// Pestaña Productos: el menú que se vende. Foto real, precio y
/// disponibilidad (pausar/activar con un toque). Tocar abre el editor.
class ProductsScreen extends StatefulWidget {
  const ProductsScreen({super.key});

  @override
  State<ProductsScreen> createState() => _ProductsScreenState();
}

class _ProductsScreenState extends State<ProductsScreen> {
  String _category = productCategories.first;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: store,
      builder: (context, _) {
        final items = products
            .where((p) => _category == 'Todos' || p.category == _category)
            .toList();
        final paused = products.where((p) => p.paused).length;

        return Column(
          children: [
            ContentWidth(
              child: PageHeader(
                title: 'Productos',
                subtitle:
                    '${products.length} en el menú${paused > 0 ? ' · $paused pausado${paused == 1 ? '' : 's'}' : ''}',
                actions: [
                  CircleIconButton(
                    icon: KIcons.plus,
                    semanticLabel: 'Nuevo producto',
                    color: Colors.white,
                    background: KColors.sea,
                    onTap: () => push(context, const ProductEditScreen()),
                  ),
                ],
              ),
            ),
            ContentWidth(
              child: ChipBar(
                children: [
                  for (final c in productCategories)
                    CategoryChip(
                      label: c,
                      selected: c == _category,
                      onTap: () => setState(() => _category = c),
                    ),
                ],
              ),
            ),
            Expanded(
              child: ContentWidth(
                child: LayoutBuilder(
                  builder: (context, c) => AnimatedSwitcher(
                    duration: KMotion.base,
                    child: GridView.builder(
                      key: ValueKey(_category),
                      padding: EdgeInsets.fromLTRB(
                        context.gutter,
                        KSpace.s,
                        context.gutter,
                        KSpace.navClearance,
                      ),
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: (c.maxWidth / 200).floor().clamp(2, 5),
                        mainAxisSpacing: KSpace.m,
                        crossAxisSpacing: KSpace.m,
                        childAspectRatio: 0.72,
                      ),
                      itemCount: items.length,
                      itemBuilder: (_, i) => FadeSlideIn(
                        index: i,
                        child: _ProductTile(product: items[i]),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _ProductTile extends StatelessWidget {
  const _ProductTile({required this.product});
  final Product product;

  @override
  Widget build(BuildContext context) {
    final p = product;
    final price = p.sizes == null
        ? money(p.price)
        : p.sizes!.values.map(money).join(' / ');
    return KosteoCard(
      padding: const EdgeInsets.all(KSpace.s),
      onTap: () => push(context, ProductEditScreen(product: p)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            // Pausado: la foto se apaga para que se note de un vistazo.
            child: AnimatedOpacity(
              duration: KMotion.base,
              opacity: p.paused ? 0.35 : 1,
              child: DishImage(product: p),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(6, KSpace.m, 4, 2),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  p.name,
                  style: KText.bodyStrong.copyWith(
                    fontSize: 14,
                    color: p.paused ? KColors.inkMuted : KColors.ink,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  price,
                  style: KText.caption,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: KSpace.s),
                _AvailabilityToggle(product: p),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Un toque: Disponible ↔ Pausado.
class _AvailabilityToggle extends StatelessWidget {
  const _AvailabilityToggle({required this.product});
  final Product product;

  @override
  Widget build(BuildContext context) {
    final on = !product.paused;
    final color = on ? KColors.success : KColors.inkMuted;
    return Pressable(
      onTap: () => runAction(context, () async {
        await store.togglePaused(product);
        if (!context.mounted) return;
        showToast(
          context,
          '${product.name} ${!product.paused ? 'pausado' : 'disponible'}',
          color: product.paused ? KColors.inkMuted : KColors.success,
        );
      }),
      child: AnimatedContainer(
        duration: KMotion.base,
        height: 32,
        padding: const EdgeInsets.symmetric(horizontal: KSpace.m),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(KRadius.chip),
        ),
        child: Row(
          children: [
            AnimatedContainer(
              duration: KMotion.base,
              width: 8,
              height: 8,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            ),
            const SizedBox(width: KSpace.s),
            Expanded(
              child: Text(
                on ? 'Disponible' : 'Pausado',
                style: KText.caption.copyWith(
                  color: Color.lerp(color, KColors.ink, 0.3),
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
