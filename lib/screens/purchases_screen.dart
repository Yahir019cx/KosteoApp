import 'package:flutter/material.dart';

import '../theme/icons.dart';

import '../data/app_store.dart';
import '../theme/tokens.dart';
import '../widgets/basics.dart';
import '../widgets/chips.dart';
import '../widgets/motion.dart';
import '../widgets/rows.dart';
import 'common.dart';
import 'edit_purchase_sheet.dart';
import 'ingredients_screen.dart';
import 'new_purchase_screen.dart';

class PurchasesScreen extends StatefulWidget {
  const PurchasesScreen({super.key});

  @override
  State<PurchasesScreen> createState() => _PurchasesScreenState();
}

class _PurchasesScreenState extends State<PurchasesScreen> {
  Period _period = Period.today;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: store,
      builder: (context, _) {
        final filtered = store.purchasesFor(_period);
        final total = filtered.fold<num>(0, (v, p) => v + p.total);
        final count = filtered.length;

        final summary = _Summary(total: total, count: count, period: _period);
        final list = _PurchaseList(purchases: filtered);
        final g = context.gutter;

        return ListView(
          padding: EdgeInsets.only(bottom: KSpace.navClearance),
          children: [
            ContentWidth(
              child: PageHeader(
                title: 'Compras',
                subtitle: 'Insumos y gastos',
                actions: [
                  CircleIconButton(
                    icon: KIcons.basket,
                    semanticLabel: 'Insumos',
                    onTap: () => push(context, const IngredientsScreen()),
                  ),
                ],
              ),
            ),
            ContentWidth(
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: g),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    FadeSlideIn(
                      child: SegmentedPill<Period>(
                        values: Period.values,
                        selected: _period,
                        labelOf: (p) => p.label,
                        onChanged: (p) => setState(() => _period = p),
                      ),
                    ),
                    const SizedBox(height: KSpace.xl),
                    if (context.isTablet)
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            flex: 4,
                            child: FadeSlideIn(index: 1, child: summary),
                          ),
                          const SizedBox(width: KSpace.xl),
                          Expanded(
                            flex: 6,
                            child: FadeSlideIn(index: 2, child: list),
                          ),
                        ],
                      )
                    else ...[
                      FadeSlideIn(index: 1, child: summary),
                      const SizedBox(height: KSpace.xxl),
                      FadeSlideIn(index: 2, child: list),
                    ],
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _Summary extends StatelessWidget {
  const _Summary({
    required this.total,
    required this.count,
    required this.period,
  });
  final num total;
  final int count;
  final Period period;

  @override
  Widget build(BuildContext context) {
    final byCat = store.purchasesCategories(period);
    final catTotal = byCat.values.fold<num>(0, (a, b) => a + b);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        KosteoCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Total comprado · ${period.label.toLowerCase()}',
                style: KText.caption,
              ),
              const SizedBox(height: KSpace.xs),
              AnimatedMoney(total, style: KText.display),
              const SizedBox(height: KSpace.xs),
              Text('$count compras registradas', style: KText.caption),
              const SizedBox(height: KSpace.xl),
              // Barra segmentada por categoría: se entiende sin leer números.
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: SizedBox(
                  height: 10,
                  child: Row(
                    children: [
                      for (final c in IngredientCategory.values)
                        if ((byCat[c] ?? 0) > 0)
                          Expanded(
                            flex: (byCat[c]! * 100).round().clamp(
                              1,
                              1000000000,
                            ),
                            child: Container(
                              margin: const EdgeInsets.only(right: 2),
                              color: c.tint,
                            ),
                          ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: KSpace.m),
              Wrap(
                spacing: KSpace.l,
                runSpacing: KSpace.s,
                children: [
                  for (final c in IngredientCategory.values)
                    if ((byCat[c] ?? 0) > 0)
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(
                              color: c.tint,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            '${c.label} ${(byCat[c]! / catTotal * 100).round()}%',
                            style: KText.caption,
                          ),
                        ],
                      ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: KSpace.l),
        PrimaryButton(
          label: 'Nueva compra',
          icon: KIcons.plusStrong,
          onTap: () => push(context, const NewPurchaseScreen()),
        ),
      ],
    );
  }
}

class _PurchaseList extends StatelessWidget {
  const _PurchaseList({required this.purchases});
  final List<Purchase> purchases;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SectionTitle(
          'Registro',
          trailing: Text('${purchases.length}', style: KText.caption),
        ),
        if (store.purchasesMissingYield > 0) ...[
          _PendingYieldBanner(count: store.purchasesMissingYield),
          const SizedBox(height: KSpace.m),
        ],
        KosteoCard(
          padding: const EdgeInsets.symmetric(
            horizontal: KSpace.l + 4,
            vertical: KSpace.s,
          ),
          child: Column(
            children: [
              for (var i = 0; i < purchases.length; i++) ...[
                if (i > 0) const InsetDivider(),
                FadeSlideIn(
                  index: i,
                  child: PurchaseRow(
                    purchase: purchases[i],
                    onTap: () => showEditPurchaseSheet(context, purchases[i]),
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

/// Recordatorio: compras cuyo rendimiento se captura más tarde (p. ej. tras pelar).
class _PendingYieldBanner extends StatelessWidget {
  const _PendingYieldBanner({required this.count});
  final int count;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(KSpace.l),
      decoration: BoxDecoration(
        color: KColors.coral.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(KRadius.tile),
      ),
      child: Row(
        children: [
          const Icon(KIcons.alert, color: KColors.coralDeep, size: 22),
          const SizedBox(width: KSpace.m),
          Expanded(
            child: Text(
              count == 1
                  ? '1 compra espera su rendimiento. Tócala para completarlo.'
                  : '$count compras esperan su rendimiento. Tócalas para completarlo.',
              style: KText.body.copyWith(fontSize: 13.5),
            ),
          ),
        ],
      ),
    );
  }
}
