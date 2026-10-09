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

/// Alta de insumo: configuración de una sola vez. Solo nombre, categoría,
/// cómo se compra, cómo se usa y si tiene merma. Costos van en Compras.
class NewIngredientScreen extends StatefulWidget {
  const NewIngredientScreen({super.key, this.initialCategory});
  final IngredientCategory? initialCategory;

  @override
  State<NewIngredientScreen> createState() => _NewIngredientScreenState();
}

class _NewIngredientScreenState extends State<NewIngredientScreen> {
  final _name = TextEditingController();
  late IngredientCategory _category =
      widget.initialCategory ?? IngredientCategory.seafood;
  String _buy = 'kg';
  String _use = 'g';
  bool _useTouched = false;
  bool _hasYield = false;

  @override
  void initState() {
    super.initState();
    _name.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _save() => runAction(context, () async {
    final i = Ingredient(
      _name.text.trim(),
      _category,
      _category.icon,
      _buy,
      _use,
      hasYield: _hasYield,
    );
    await store.addIngredient(i);
    if (!mounted) return;
    showToast(context, '${i.name} agregado a ${_category.label}');
    Navigator.of(context).pop(i);
  });

  @override
  Widget build(BuildContext context) {
    final name = _name.text.trim();
    return KScaffold(
      body: ContentWidth(
        maxWidth: 680,
        child: Column(
          children: [
            const PageHeader(
              title: 'Nuevo insumo',
              subtitle: 'Se configura una sola vez',
              back: true,
            ),
            Expanded(
              child: ListView(
                padding: EdgeInsets.fromLTRB(
                  context.gutter,
                  0,
                  context.gutter,
                  140,
                ),
                children: [
                  FadeSlideIn(
                    child: _Preview(
                      name: name,
                      category: _category,
                      buy: _buy,
                      use: _use,
                      hasYield: _hasYield,
                    ),
                  ),
                  const SizedBox(height: KSpace.xl),
                  FadeSlideIn(
                    index: 1,
                    child: _Block(
                      label: 'Nombre',
                      child: KTextField(
                        controller: _name,
                        hint: 'Ej. Camarón',
                        autofocus: true,
                      ),
                    ),
                  ),
                  FadeSlideIn(
                    index: 2,
                    child: _Block(
                      label: 'Categoría',
                      child: Wrap(
                        spacing: KSpace.s,
                        runSpacing: KSpace.s,
                        children: [
                          for (final c in IngredientCategory.values)
                            ChoiceTile(
                              label: c.label,
                              icon: c.icon,
                              selected: _category == c,
                              onTap: () => setState(() => _category = c),
                            ),
                        ],
                      ),
                    ),
                  ),
                  FadeSlideIn(
                    index: 3,
                    child: _Block(
                      label: '¿Cómo lo compras?',
                      child: _UnitWrap(
                        units: buyUnits,
                        selected: _buy,
                        onTap: (u) => setState(() {
                          _buy = u;
                          // Sugerimos la unidad de uso hasta que el usuario la elija.
                          if (!_useTouched) _use = suggestedUseUnit(u);
                        }),
                      ),
                    ),
                  ),
                  FadeSlideIn(
                    index: 4,
                    child: _Block(
                      label: '¿En qué unidad lo usas?',
                      child: _UnitWrap(
                        units: useUnits,
                        selected: _use,
                        onTap: (u) => setState(() {
                          _use = u;
                          _useTouched = true;
                        }),
                      ),
                    ),
                  ),
                  FadeSlideIn(
                    index: 5,
                    child: _Block(
                      label: '¿Tiene rendimiento o merma?',
                      optional: true,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Align(
                            alignment: Alignment.centerLeft,
                            child: SizedBox(
                              width: 220,
                              child: SegmentedPill<bool>(
                                values: const [false, true],
                                selected: _hasYield,
                                labelOf: (v) => v ? 'Sí' : 'No',
                                onChanged: (v) => setState(() => _hasYield = v),
                              ),
                            ),
                          ),
                          const SizedBox(height: KSpace.s),
                          Padding(
                            padding: const EdgeInsets.only(left: 4),
                            child: Text(
                              'Ej. el camarón se limpia o el limón se exprime. Lo capturas al comprar.',
                              style: KText.caption,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      bottom: BottomActionBar(
        child: PrimaryButton(
          label: 'Guardar insumo',
          icon: KIcons.checkStrong,
          onTap: name.isEmpty ? null : _save,
        ),
      ),
    );
  }
}

class _Block extends StatelessWidget {
  const _Block({
    required this.label,
    required this.child,
    this.optional = false,
  });
  final String label;
  final Widget child;
  final bool optional;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: KSpace.xl),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        FieldLabel(label, optional: optional),
        child,
      ],
    ),
  );
}

class _UnitWrap extends StatelessWidget {
  const _UnitWrap({
    required this.units,
    required this.selected,
    required this.onTap,
  });
  final List<String> units;
  final String selected;
  final ValueChanged<String> onTap;

  @override
  Widget build(BuildContext context) => Wrap(
    spacing: KSpace.s,
    runSpacing: KSpace.s,
    children: [
      for (final u in units)
        ChoiceTile(
          label: u,
          selected: u == selected,
          minWidth: 64,
          onTap: () => onTap(u),
        ),
    ],
  );
}

/// Vista previa viva de cómo se verá el insumo en el catálogo.
class _Preview extends StatelessWidget {
  const _Preview({
    required this.name,
    required this.category,
    required this.buy,
    required this.use,
    required this.hasYield,
  });

  final String name;
  final IngredientCategory category;
  final String buy;
  final String use;
  final bool hasYield;

  @override
  Widget build(BuildContext context) {
    return KosteoCard(
      padding: const EdgeInsets.all(KSpace.l),
      child: Row(
        children: [
          PopSwitcher(
            child: IconTile(
              category.icon,
              key: ValueKey(category),
              tint: category.tint,
              size: 56,
            ),
          ),
          const SizedBox(width: KSpace.l),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name.isEmpty ? 'Nombre del insumo' : name,
                  style: KText.bodyStrong.copyWith(
                    fontSize: 17,
                    color: name.isEmpty ? KColors.inkMuted : KColors.ink,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${category.label} · compras en $buy · usas en $use${hasYield ? ' · con merma' : ''}',
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
