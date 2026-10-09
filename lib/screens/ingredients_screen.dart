import 'package:flutter/material.dart';

import '../data/app_store.dart';
import '../theme/icons.dart';
import '../theme/tokens.dart';
import '../widgets/basics.dart';
import '../widgets/chips.dart';
import '../widgets/inputs.dart';
import '../widgets/motion.dart';
import '../widgets/rows.dart';
import 'common.dart';
import 'new_ingredient_screen.dart';

/// Catálogo de insumos: una categoría a la vez (empieza en Mariscos).
/// Al buscar, se busca en todas las categorías.
class IngredientsScreen extends StatefulWidget {
  const IngredientsScreen({super.key});

  @override
  State<IngredientsScreen> createState() => _IngredientsScreenState();
}

class _IngredientsScreenState extends State<IngredientsScreen> {
  final _query = TextEditingController();
  IngredientCategory _cat = IngredientCategory.seafood;

  @override
  void dispose() {
    _query.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return KScaffold(
      body: ListenableBuilder(
        listenable: Listenable.merge([store, _query]),
        builder: (context, _) {
          final q = _query.text.trim().toLowerCase();
          final searching = q.isNotEmpty;
          final items = searching
              ? store.ingredients
                    .where((i) => i.name.toLowerCase().contains(q))
                    .toList()
              : store.ingredientsIn(_cat);

          return ContentWidth(
            maxWidth: 760,
            child: Column(
              children: [
                PageHeader(
                  title: 'Insumos',
                  subtitle: '${store.ingredients.length} en catálogo',
                  back: true,
                  actions: [
                    PrimaryButton(
                      label: 'Agregar',
                      icon: KIcons.plusStrong,
                      expand: false,
                      height: 44,
                      onTap: () => push(
                        context,
                        NewIngredientScreen(initialCategory: _cat),
                      ),
                    ),
                  ],
                ),
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: context.gutter),
                  child: KTextField(
                    controller: _query,
                    hint: 'Buscar insumo',
                    icon: KIcons.magnifyingGlass,
                  ),
                ),
                const SizedBox(height: KSpace.xs),
                AnimatedOpacity(
                  duration: KMotion.base,
                  opacity: searching ? 0.4 : 1,
                  child: ChipBar(
                    children: [
                      for (final c in IngredientCategory.values)
                        CategoryChip(
                          label: c.label,
                          icon: c.icon,
                          count: store.ingredientsIn(c).length,
                          selected: !searching && c == _cat,
                          onTap: () => setState(() {
                            _cat = c;
                            _query.clear();
                          }),
                        ),
                    ],
                  ),
                ),
                Expanded(
                  child: AnimatedSwitcher(
                    duration: KMotion.base,
                    child: ListView(
                      key: ValueKey(searching ? 'q:$q' : _cat),
                      padding: EdgeInsets.fromLTRB(
                        context.gutter,
                        KSpace.s,
                        context.gutter,
                        KSpace.xxxl,
                      ),
                      children: [
                        if (items.isEmpty)
                          EmptyState(
                            icon: KIcons.magnifyingGlass,
                            title: 'Sin resultados',
                            message:
                                '¿No existe todavía? Agrégalo en un momento.',
                            action: PrimaryButton(
                              label: 'Agregar insumo',
                              expand: false,
                              onTap: () => push(
                                context,
                                NewIngredientScreen(initialCategory: _cat),
                              ),
                            ),
                          )
                        else
                          FadeSlideIn(
                            child: KosteoCard(
                              padding: const EdgeInsets.symmetric(
                                horizontal: KSpace.l,
                                vertical: KSpace.xs,
                              ),
                              child: Column(
                                children: [
                                  for (var i = 0; i < items.length; i++) ...[
                                    if (i > 0) const InsetDivider(indent: 52),
                                    IngredientRow(ingredient: items[i]),
                                  ],
                                ],
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
