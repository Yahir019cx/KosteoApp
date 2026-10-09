import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/icons.dart';

import '../data/app_store.dart';
import '../theme/tokens.dart';
import '../widgets/basics.dart';
import '../widgets/chips.dart';
import '../widgets/inputs.dart';
import '../widgets/motion.dart';
import '../widgets/toast.dart';
import 'common.dart';
import 'new_ingredient_screen.dart';

/// Compra en 3 pasos: categoría → insumo → cantidad y precio.
class NewPurchaseScreen extends StatefulWidget {
  const NewPurchaseScreen({super.key});

  @override
  State<NewPurchaseScreen> createState() => _NewPurchaseScreenState();
}

class _NewPurchaseScreenState extends State<NewPurchaseScreen> {
  int _step = 0;
  bool _forward = true;
  IngredientCategory? _category;
  Ingredient? _ingredient;
  String? _yieldUnit;
  final _qty = TextEditingController();
  final _price = TextEditingController();
  final _yield = TextEditingController();

  @override
  void initState() {
    super.initState();
    for (final c in [_qty, _price, _yield]) {
      c.addListener(() => setState(() {}));
    }
  }

  @override
  void dispose() {
    _qty.dispose();
    _price.dispose();
    _yield.dispose();
    super.dispose();
  }

  void _go(int step) => setState(() {
    _forward = step > _step;
    _step = step;
  });

  void _back() => _step == 0 ? Navigator.of(context).pop() : _go(_step - 1);

  num? get _qtyValue => num.tryParse(_qty.text.replaceAll(',', '.'));
  num? get _priceValue => num.tryParse(_price.text.replaceAll(',', '.'));
  bool get _canSave => (_qtyValue ?? 0) > 0 && (_priceValue ?? 0) > 0;

  Future<void> _save() => runAction(context, () async {
    final i = _ingredient!;
    await store.addPurchase(
      i,
      _qtyValue!,
      _priceValue!,
      yieldUnit: _yieldUnit,
      yieldValue: num.tryParse(_yield.text.replaceAll(',', '.')),
    );
    if (!mounted) return;
    showToast(context, '${i.name} · ${money(_priceValue!)} registrado');
    Navigator.of(context).pop();
  });

  @override
  Widget build(BuildContext context) {
    final current = switch (_step) {
      0 => _categoryStep(),
      1 => _ingredientStep(),
      _ => _amountStep(),
    };
    return PopScope(
      canPop: _step == 0,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _back();
      },
      child: KScaffold(
        body: ContentWidth(
          maxWidth: 760,
          child: Column(
            children: [
              // "Atrás" usa maybePop → PopScope regresa un paso si no es el primero.
              PageHeader(
                title: 'Nueva compra',
                subtitle: 'Paso ${_step + 1} de 3',
                back: true,
              ),
              Padding(
                padding: EdgeInsets.symmetric(horizontal: context.gutter),
                child: _Progress(step: _step),
              ),
              const SizedBox(height: KSpace.l),
              Expanded(
                child: AnimatedSwitcher(
                  duration: KMotion.base,
                  switchInCurve: KMotion.ease,
                  switchOutCurve: Curves.easeIn,
                  transitionBuilder: (child, a) {
                    final incoming = child.key == ValueKey(_step);
                    final dx = (incoming == _forward) ? 0.08 : -0.08;
                    return FadeTransition(
                      opacity: a,
                      child: SlideTransition(
                        position: Tween(
                          begin: Offset(dx, 0),
                          end: Offset.zero,
                        ).animate(a),
                        child: child,
                      ),
                    );
                  },
                  child: KeyedSubtree(key: ValueKey(_step), child: current),
                ),
              ),
            ],
          ),
        ),
        bottom: _step == 2
            ? BottomActionBar(
                child: PrimaryButton(
                  label: 'Guardar compra',
                  icon: KIcons.checkStrong,
                  onTap: _canSave ? _save : null,
                ),
              )
            : null,
      ),
    );
  }

  // ── Paso 1
  Widget _categoryStep() {
    final cats = IngredientCategory.values;
    return ListView(
      padding: EdgeInsets.fromLTRB(
        context.gutter,
        0,
        context.gutter,
        KSpace.xxl,
      ),
      children: [
        Text('¿Qué compraste?', style: KText.title),
        const SizedBox(height: KSpace.l),
        GridView.count(
          crossAxisCount: context.isTablet ? 4 : 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: KSpace.m,
          crossAxisSpacing: KSpace.m,
          childAspectRatio: 1.05,
          children: [
            for (var i = 0; i < cats.length; i++)
              FadeSlideIn(
                index: i,
                child: _BigTile(
                  icon: cats[i].icon,
                  title: cats[i].label,
                  caption: '${store.ingredientsIn(cats[i]).length} insumos',
                  tint: cats[i].tint,
                  onTap: () {
                    _category = cats[i];
                    _go(1);
                  },
                ),
              ),
          ],
        ),
      ],
    );
  }

  // ── Paso 2
  Widget _ingredientStep() {
    final cat = _category!;
    final items = store.ingredientsIn(cat);
    return ListView(
      padding: EdgeInsets.fromLTRB(
        context.gutter,
        0,
        context.gutter,
        KSpace.xxl,
      ),
      children: [
        Row(
          children: [
            Icon(cat.icon, size: 24, color: cat.tint),
            const SizedBox(width: KSpace.s),
            Text(cat.label, style: KText.title),
          ],
        ),
        const SizedBox(height: KSpace.l),
        GridView.count(
          crossAxisCount: context.isTablet ? 4 : 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: KSpace.m,
          crossAxisSpacing: KSpace.m,
          childAspectRatio: 1.3,
          children: [
            for (var i = 0; i < items.length; i++)
              FadeSlideIn(
                index: i,
                child: _BigTile(
                  icon: items[i].icon,
                  title: items[i].name,
                  caption: items[i].lastCost == null
                      ? 'Por ${items[i].buyUnit}'
                      : 'Último ${money(items[i].lastCost!)}/${items[i].buyUnit}',
                  tint: cat.tint,
                  compact: true,
                  onTap: () => _pick(items[i]),
                ),
              ),
            FadeSlideIn(
              index: items.length,
              child: _AddTile(
                onTap: () async {
                  final created = await push<Ingredient>(
                    context,
                    NewIngredientScreen(initialCategory: cat),
                  );
                  if (created != null && created.category == cat) {
                    _pick(created);
                  }
                },
              ),
            ),
          ],
        ),
      ],
    );
  }

  void _pick(Ingredient i) {
    if (_ingredient != i) {
      _qty.clear();
      _price.clear();
      _yield.clear();
    }
    _ingredient = i;
    _yieldUnit = i.useUnit;
    _go(2);
  }

  // ── Paso 3
  Widget _amountStep() {
    final i = _ingredient!;
    final qty = _qtyValue ?? 0;
    final price = _priceValue ?? 0;
    final y =
        (num.tryParse(_yield.text.replaceAll(',', '.')) ?? 0) *
        store.yieldFactor(_yieldUnit);
    final quick = switch (i.buyUnit) {
      'kg' || 'L' => [0.5, 1, 2, 3, 5],
      'g' || 'ml' => [100, 250, 500, 1000],
      _ => [1, 5, 10, 25],
    };

    String? hint;
    if (qty > 0 && price > 0) {
      hint = i.requiresUseful && y > 0
          ? 'Te sale en ${money(price / y * (i.useUnit == 'pza' ? 1 : 100))} por ${i.useUnit == 'pza' ? 'pieza útil' : '100 ${i.useUnit} útiles'}'
          : 'Te sale en ${money(price / qty)} por ${unitLabel(i.buyUnit, 1)}';
    }

    return ListView(
      padding: EdgeInsets.fromLTRB(context.gutter, 0, context.gutter, 140),
      children: [
        // Insumo elegido (tocar para cambiar)
        KosteoCard(
          padding: const EdgeInsets.all(KSpace.l),
          onTap: () => _go(1),
          child: Row(
            children: [
              IconTile(i.icon, tint: i.category.tint, size: 52),
              const SizedBox(width: KSpace.m),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      i.name,
                      style: KText.bodyStrong.copyWith(fontSize: 17),
                    ),
                    Text(
                      '${i.category.label} · se compra por ${i.buyUnit}',
                      style: KText.caption,
                    ),
                  ],
                ),
              ),
              Text(
                'Cambiar',
                style: KText.caption.copyWith(
                  color: KColors.sea,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: KSpace.xl),
        const FieldLabel('¿Cuánto compraste?'),
        KTextField(
          controller: _qty,
          big: true,
          hint: '0',
          suffix: unitLabel(i.buyUnit, qty == 0 ? 2 : qty),
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          inputFormatters: [
            FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
          ],
        ),
        const SizedBox(height: KSpace.s),
        Wrap(
          spacing: KSpace.s,
          runSpacing: KSpace.s,
          children: [
            for (final q in quick)
              CategoryChip(
                label: '$q ${i.buyUnit}',
                selected: qty == q,
                onTap: () => _qty.text = '$q',
              ),
          ],
        ),
        const SizedBox(height: KSpace.xl),
        const FieldLabel('¿Cuánto pagaste en total?'),
        KTextField(
          controller: _price,
          big: true,
          hint: '0',
          prefix: '\$',
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          inputFormatters: [
            FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
          ],
        ),
        if (i.measurable && i.requiresUseful) ...[
          const SizedBox(height: KSpace.xl),
          const FieldLabel('Rendimiento final', optional: true),
          KTextField(
            controller: _yield,
            big: true,
            hint: '0',
            suffix: _yieldUnit ?? i.useUnit,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
            ],
          ),
          if (store.yieldUnits(i).length > 1)
            Wrap(
              spacing: KSpace.s,
              children: [
                for (final u in store.yieldUnits(i))
                  CategoryChip(
                    label: u['codigo'] == 'fl_oz_US' ? 'oz' : u['codigo'],
                    selected: _yieldUnit == u['codigo'],
                    onTap: () => setState(() => _yieldUnit = u['codigo']),
                  ),
              ],
            ),
          Padding(
            padding: const EdgeInsets.only(top: KSpace.s, left: 4),
            child: Text(
              i.useUnit == 'ml'
                  ? '¿Aún no exprimes? Déjalo vacío y complétalo después en Compras.'
                  : '¿Aún no lo limpias? Déjalo vacío y complétalo después en Compras.',
              style: KText.caption,
            ),
          ),
        ],
        const SizedBox(height: KSpace.xl),
        AnimatedSwitcher(
          duration: KMotion.base,
          child: hint == null
              ? const SizedBox.shrink()
              : Container(
                  key: ValueKey(hint),
                  padding: const EdgeInsets.all(KSpace.l),
                  decoration: BoxDecoration(
                    color: KColors.lagoon.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(KRadius.tile),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        KIcons.sparkleStrong,
                        color: KColors.lagoon,
                        size: 20,
                      ),
                      const SizedBox(width: KSpace.m),
                      Expanded(
                        child: Text(
                          hint,
                          style: KText.body.copyWith(fontSize: 14),
                        ),
                      ),
                    ],
                  ),
                ),
        ),
      ],
    );
  }
}

class _Progress extends StatelessWidget {
  const _Progress({required this.step});
  final int step;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (var i = 0; i < 3; i++) ...[
          if (i > 0) const SizedBox(width: 6),
          Expanded(
            child: AnimatedContainer(
              duration: KMotion.slow,
              curve: KMotion.ease,
              height: 6,
              decoration: BoxDecoration(
                color: i <= step ? KColors.sea : KColors.mist,
                borderRadius: BorderRadius.circular(3),
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class _BigTile extends StatelessWidget {
  const _BigTile({
    required this.icon,
    required this.title,
    required this.caption,
    required this.tint,
    required this.onTap,
    this.compact = false,
  });

  final IconData icon;
  final String title;
  final String caption;
  final Color tint;
  final VoidCallback onTap;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return KosteoCard(
      onTap: onTap,
      padding: const EdgeInsets.all(KSpace.l),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          IconTile(icon, tint: tint, size: compact ? 40 : 56),
          const Spacer(),
          Text(
            title,
            style: KText.bodyStrong.copyWith(fontSize: compact ? 15 : 17),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          Text(
            caption,
            style: KText.caption,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

class _AddTile extends StatelessWidget {
  const _AddTile({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Pressable(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: KColors.sea.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(KRadius.card),
          border: Border.all(
            color: KColors.sea.withValues(alpha: 0.3),
            width: 1.5,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(KIcons.plusCircle, color: KColors.sea, size: 28),
            const SizedBox(height: KSpace.s),
            Text(
              'Nuevo insumo',
              style: KText.bodyStrong.copyWith(
                color: KColors.seaDeep,
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
