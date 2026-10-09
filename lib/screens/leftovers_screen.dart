import 'package:flutter/material.dart';

import '../theme/icons.dart';

import '../data/app_store.dart';
import '../theme/tokens.dart';
import '../widgets/basics.dart';
import '../widgets/chips.dart';
import '../widgets/inputs.dart';
import '../widgets/motion.dart';
import '../widgets/toast.dart';
import 'common.dart';
import 'initial_inventory_sheet.dart';

/// Conteo de sobrantes al cierre, por categoría y en pantalla completa.
class LeftoversScreen extends StatefulWidget {
  const LeftoversScreen({super.key, this.counting = true});
  final bool counting;

  @override
  State<LeftoversScreen> createState() => _LeftoversScreenState();
}

class _LeftoversScreenState extends State<LeftoversScreen> {
  IngredientCategory _cat = IngredientCategory.seafood;

  @override
  Widget build(BuildContext context) {
    return KScaffold(
      body: ListenableBuilder(
        listenable: store,
        builder: (context, _) {
          final items = store.leftoversIn(_cat);
          final all = store.leftovers;
          final done = all.where((l) => l.touched).length;
          final cols = context.isWide ? 3 : (context.isTablet ? 2 : 1);

          return ContentWidth(
            child: Column(
              children: [
                PageHeader(
                  title: widget.counting ? 'Conteo de sobrantes' : 'Inventario',
                  subtitle: todayLabel(),
                  back: true,
                ),
                Padding(
                  padding: EdgeInsets.fromLTRB(
                    context.gutter,
                    0,
                    context.gutter,
                    2,
                  ),
                  child: Align(
                    alignment: Alignment.centerRight,
                    child: SoftButton(
                      label: 'Cargar inventario inicial',
                      icon: KIcons.plus,
                      expand: false,
                      height: 40,
                      onTap: () async {
                        final i = await showInitialInventory(context);
                        if (i != null && mounted) {
                          setState(() => _cat = i.category);
                        }
                      },
                    ),
                  ),
                ),
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: context.gutter),
                  child: _ProgressCard(done: done, total: all.length),
                ),
                const SizedBox(height: KSpace.s),
                ChipBar(
                  children: [
                    for (final c in IngredientCategory.values)
                      if (store.leftoversIn(c).isNotEmpty)
                        CategoryChip(
                          label: c.label,
                          icon: c.icon,
                          selected: c == _cat,
                          count: store
                              .leftoversIn(c)
                              .where((l) => !l.touched)
                              .length,
                          onTap: () => setState(() => _cat = c),
                        ),
                  ],
                ),
                Expanded(
                  child: AnimatedSwitcher(
                    duration: KMotion.base,
                    child: GridView.builder(
                      key: ValueKey(_cat),
                      padding: EdgeInsets.fromLTRB(
                        context.gutter,
                        KSpace.s,
                        context.gutter,
                        140,
                      ),
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: cols,
                        mainAxisSpacing: KSpace.m,
                        crossAxisSpacing: KSpace.m,
                        mainAxisExtent: 156,
                      ),
                      itemCount: items.length,
                      itemBuilder: (_, i) => FadeSlideIn(
                        index: i,
                        child: _LeftoverCard(
                          item: items[i],
                          counting: widget.counting,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
      bottom: widget.counting
          ? BottomActionBar(
              child: PrimaryButton(
                label: 'Guardar conteo',
                icon: KIcons.checkStrong,
                onTap: store.shiftClosed
                    ? null
                    : () => runAction(context, () async {
                        await store.saveCounts();
                        if (!context.mounted) return;
                        showToast(context, 'Conteo guardado');
                        Navigator.of(context).pop();
                      }),
              ),
            )
          : null,
    );
  }
}

class _ProgressCard extends StatelessWidget {
  const _ProgressCard({required this.done, required this.total});
  final int done;
  final int total;

  @override
  Widget build(BuildContext context) {
    return KosteoCard(
      padding: const EdgeInsets.all(KSpace.l),
      child: Row(
        children: [
          SizedBox.square(
            dimension: 44,
            child: TweenAnimationBuilder<double>(
              tween: Tween(end: total == 0 ? 0 : done / total),
              duration: KMotion.slow,
              curve: KMotion.ease,
              builder: (_, v, _) => CircularProgressIndicator(
                value: v,
                strokeWidth: 5,
                strokeCap: StrokeCap.round,
                backgroundColor: KColors.mist,
                color: KColors.lagoon,
              ),
            ),
          ),
          const SizedBox(width: KSpace.l),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('$done de $total contados', style: KText.bodyStrong),
                Text(
                  'Ajusta solo lo que no coincide con lo teórico.',
                  style: KText.caption,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _LeftoverCard extends StatelessWidget {
  const _LeftoverCard({required this.item, required this.counting});
  final bool counting;
  final LeftoverItem item;

  @override
  Widget build(BuildContext context) {
    final i = item.ingredient;
    final unit = i.useUnit;
    final diff = item.diff;
    final color = diff == null
        ? KColors.inkMuted
        : diff == 0
        ? KColors.success
        : (diff < 0 ? KColors.coralDeep : KColors.sea);
    final diffText = !item.touched
        ? 'Por contar'
        : (diff == null
              ? 'Teórico pendiente'
              : diff == 0
              ? 'Exacto'
              : '${diff > 0 ? '+' : ''}$diff $unit');

    return KosteoCard(
      padding: const EdgeInsets.all(KSpace.l),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Stack(
                clipBehavior: Clip.none,
                children: [
                  IconTile(i.icon, tint: i.category.tint, size: 44),
                  Positioned(
                    right: -4,
                    bottom: -4,
                    child: AnimatedScale(
                      scale: item.touched ? 1 : 0,
                      duration: KMotion.base,
                      curve: KMotion.spring,
                      child: Container(
                        decoration: const BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          KIcons.checkCircleStrong,
                          color: KColors.lagoon,
                          size: 18,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(width: KSpace.m),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      i.name,
                      style: KText.bodyStrong.copyWith(fontSize: 15),
                    ),
                    Text(
                      'Teórico: ${item.theoretical ?? 'Pendiente'} $unit',
                      style: KText.caption,
                    ),
                  ],
                ),
              ),
              StatusPill(
                label: diffText,
                color: item.touched ? color : KColors.inkMuted,
              ),
            ],
          ),
          const Spacer(),
          Row(
            children: [
              if (!counting)
                Text(
                  item.touched
                      ? 'Físico: ${item.counted} $unit'
                      : 'Sin conteo físico',
                  style: KText.body,
                )
              else
                QtyStepper(
                  value: item.counted,
                  decimal: true,
                  step: item.step,
                  unit: unit,
                  onChanged: (v) => store.setCount(item, v),
                ),
              const Spacer(),
              // Un toque: "coincide con lo teórico".
              if (counting)
                Pressable(
                  onTap: item.theoretical == null
                      ? null
                      : () => store.setCount(item, item.theoretical!),
                  child: Container(
                    height: 40,
                    padding: const EdgeInsets.symmetric(horizontal: KSpace.m),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: KColors.success.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(KRadius.chip),
                    ),
                    child: Text(
                      'Coincide',
                      style: KText.caption.copyWith(
                        color: KColors.success,
                        fontWeight: FontWeight.w700,
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
