import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../data/app_store.dart';
import '../theme/icons.dart';
import '../theme/tokens.dart';
import '../widgets/basics.dart';
import '../widgets/chips.dart';
import '../widgets/glass_sheet.dart';
import '../widgets/inputs.dart';
import '../widgets/motion.dart';
import '../widgets/rows.dart';
import '../widgets/toast.dart';
import 'common.dart';

Future<void> showProductCost(BuildContext context, Product product) async {
  try {
    final data = await store.api.get('/platillos/${product.id}/componentes');
    if (context.mounted) {
      await showGlassSheet<void>(
        context,
        builder: (_) =>
            _CostSheet(product: product, data: Map<String, dynamic>.from(data)),
      );
    }
  } catch (e) {
    if (context.mounted) showErrorToast(context, e.toString());
  }
}

class _CostSheet extends StatefulWidget {
  const _CostSheet({required this.product, required this.data});
  final Product product;
  final Map<String, dynamic> data;
  @override
  State<_CostSheet> createState() => _CostSheetState();
}

class _CostSheetState extends State<_CostSheet> {
  late final List<dynamic> _presentations =
      (widget.data['presentaciones'] as List)
          .where((p) => p['activa'] == true)
          .toList();
  late int _id = _presentations.first['presentacionId'];
  late List<Map<String, dynamic>> _components;
  final _quantities = <String, TextEditingController>{};
  TextEditingController _quantity(Map<String, dynamic> c) =>
      _quantities.putIfAbsent(
        '${c['insumoId']}/${c['opcionId']}',
        () => TextEditingController(text: c['cantidad']?.toString() ?? ''),
      );
  final _fixed = TextEditingController();
  bool _confirmed = false;
  int? _option;
  Map<String, dynamic>? _preview;
  final _additional = TextEditingController();
  final _drafts = <int, Map<String, dynamic>>{};
  final _extraPrices = <int, String>{};
  bool _selectedOnce = false;
  @override
  void initState() {
    super.initState();
    _select(_id);
  }

  void _select(int id) {
    if (_selectedOnce && store.saving) return;
    if (_selectedOnce) {
      _drafts[_id] = {
        'componentes': _components,
        'fijo': _fixed.text,
        'confirmada': _confirmed,
      };
    }
    _selectedOnce = true;
    for (final c in _quantities.values) {
      c.dispose();
    }
    _quantities.clear();
    _id = id;
    final p = _presentations.firstWhere((p) => p['presentacionId'] == id);
    final draft = _drafts[id];
    _fixed.text = draft?['fijo'] ?? p['costoFijoCondimentos']?.toString() ?? '';
    _confirmed =
        draft?['confirmada'] ?? p['configuracionCosteoConfirmada'] == true;
    _preview = null;
    _components = draft != null
        ? List<Map<String, dynamic>>.from(draft['componentes'])
        : (widget.data['componentes'] as List)
              .where((c) => c['presentacionId'] == id)
              .map(
                (c) => <String, dynamic>{
                  'insumoId': c['insumoId'],
                  'opcionId': c['opcionId'],
                  'cantidad': c['cantidadUso'],
                  'unidadId': store.unitId(
                    store.ingredient(c['insumoId']).useUnit,
                  ),
                },
              )
              .toList();
  }

  @override
  void dispose() {
    for (final c in _quantities.values) {
      c.dispose();
    }
    _fixed.dispose();
    _additional.dispose();
    super.dispose();
  }

  List<dynamic> _units(Ingredient i) {
    final base = store.units.firstWhere((u) => u['codigo'] == i.useUnit);
    return store.units
        .where(
          (u) => u['dimension'] == base['dimension'] && u['factorBase'] != null,
        )
        .toList();
  }

  String? get _optionIngredientName {
    final name = widget.product.options
        .where((o) => o['opcionId'] == _option)
        .map((o) => o['nombre'] as String)
        .firstOrNull;
    return name != null &&
            const {
              'tostadas',
              'tostitos',
              'piña',
              'mango',
            }.contains(name.trim().toLowerCase())
        ? name
        : null;
  }

  void _chooseOption(int? id) {
    if (store.saving) return;
    setState(() {
      if (_option != null) {
        _extraPrices[_option!] = _additional.text;
      }
      _option = id;
      final option = widget.product.options
          .where((o) => o['opcionId'] == id)
          .firstOrNull;
      _additional.text =
          _extraPrices[id] ?? option?['precioAdicional']?.toString() ?? '';
    });
  }

  void _appendIngredients(List<Ingredient> chosen) {
    setState(
      () => _components.addAll([
        for (final i in chosen)
          {
            'insumoId': i.id,
            'opcionId': _option,
            'cantidad': null,
            'unidadId': store.unitId(i.useUnit),
          },
      ]),
    );
  }

  Future<void> _add() async {
    final name = _optionIngredientName;
    if (name != null) {
      final ingredient = store.ingredients
          .where(
            (i) =>
                i.measurable &&
                i.name.trim().toLowerCase() == name.trim().toLowerCase(),
          )
          .firstOrNull;
      if (ingredient == null) {
        showErrorToast(
          context,
          'Da de alta el insumo $name para configurar su cantidad.',
        );
        return;
      }
      if (!_components.any(
        (c) => c['insumoId'] == ingredient.id && c['opcionId'] == _option,
      )) {
        _appendIngredients([ingredient]);
      }
      return;
    }
    final chosen = await showGlassSheet<List<Ingredient>>(
      context,
      builder: (context) => _IngredientPicker(
        ingredients: store.ingredients
            .where(
              (i) =>
                  i.measurable &&
                  !_components.any(
                    (c) => c['insumoId'] == i.id && c['opcionId'] == _option,
                  ),
            )
            .toList(),
      ),
    );
    if (chosen != null && mounted) {
      _appendIngredients(chosen);
    }
  }

  List<String> get _duplicateIngredients {
    final base = _components
        .where((c) => c['opcionId'] == null)
        .map((c) => c['insumoId'])
        .toSet();
    final active = widget.product.options.map((o) => o['opcionId']).toSet();
    return _components
        .where(
          (c) =>
              c['opcionId'] != null &&
              active.contains(c['opcionId']) &&
              base.contains(c['insumoId']),
        )
        .map((c) => store.ingredient(c['insumoId']).name)
        .toSet()
        .toList();
  }

  Future<void> _save() async {
    if (store.saving) return;
    final duplicates = _duplicateIngredients;
    if (duplicates.isNotEmpty) {
      final proceed = await showGlassSheet<bool>(
        context,
        builder: (context) => SheetBody(
          title: 'Revisa las cantidades',
          subtitle:
              '${duplicates.join(', ')} está en Siempre lleva y también en una opción. Al elegirla se sumarán ambas cantidades.',
          child: Column(
            children: [
              SoftButton(
                label: 'Revisar',
                onTap: () => Navigator.of(context).pop(false),
              ),
              const SizedBox(height: KSpace.s),
              PrimaryButton(
                label: 'Guardar así',
                onTap: () => Navigator.of(context).pop(true),
              ),
            ],
          ),
        ),
      );
      if (proceed != true || !mounted) return;
    }
    await runAction(context, () async {
      await store.api.request(
        'PUT',
        '/platillos/${widget.product.id}/componentes',
        body: {
          'presentacionId': _id,
          'componentes': _components,
          'costoFijoCondimentos': num.tryParse(
            _fixed.text.replaceAll(',', '.'),
          ),
          'confirmada': _confirmed,
        },
      );
      var stage = 'actualizar la vista';
      try {
        if (_option != null &&
            widget.product.options.any(
              (o) =>
                  o['opcionId'] == _option &&
                  o['tipo'] == 'EXTRA' &&
                  !isOptionalIngredient(o['nombre']),
            )) {
          stage = 'guardar el precio del extra';
          final options = widget.product.options
              .map(
                (o) => {
                  'tipo': o['tipo'],
                  'nombre': o['nombre'],
                  'precioAdicional': isOptionalIngredient(o['nombre'])
                      ? 0
                      : o['opcionId'] == _option
                      ? num.tryParse(_additional.text.replaceAll(',', '.'))
                      : o['precioAdicional'],
                },
              )
              .toList();
          await store.api.request(
            'PATCH',
            '/platillos/${widget.product.id}',
            body: {'opciones': options},
          );
        }
        stage = 'actualizar el costo y la vista';
        final options = _option == null
            ? widget.product.options
                  .where((o) => o['tipo'] == 'COMPLEMENTO')
                  .take(1)
                  .map((o) => o['opcionId'])
                  .toList()
            : [
                if (widget.product.options.any(
                  (o) => o['opcionId'] == _option && o['tipo'] == 'EXTRA',
                ))
                  ...widget.product.options
                      .where((o) => o['tipo'] == 'COMPLEMENTO')
                      .take(1)
                      .map((o) => o['opcionId']),
                _option,
              ];
        final preview = await store.api.get(
          '/platillos/${widget.product.id}/costo',
          {'presentacionId': _id, 'opciones': '[${options.join(',')}]'},
        );
        final fresh = await store.api.get(
          '/platillos/${widget.product.id}/componentes',
        );
        widget.data['componentes'] = fresh['componentes'];
        for (final p in _presentations) {
          p.addAll(
            (fresh['presentaciones'] as List).firstWhere(
              (v) => v['presentacionId'] == p['presentacionId'],
            ),
          );
        }
        await store.menu();
        await store.refresh();
        if (!mounted) return;
        setState(() => _preview = Map<String, dynamic>.from(preview));
        showToast(context, 'Cantidades guardadas');
      } catch (e) {
        store.error =
            'Cantidades guardadas. No se pudo $stage. ${e.toString()}';
      }
    });
  }

  @override
  Widget build(BuildContext context) => SheetBody(
    title: 'Costeo · ${widget.product.name}',
    subtitle: 'Configura una vez; se aplica al vender.',
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Wrap(
          spacing: KSpace.s,
          runSpacing: KSpace.s,
          children: [
            for (final p in _presentations)
              ChoiceTile(
                label: p['nombre'],
                selected: _id == p['presentacionId'],
                onTap: () => setState(() => _select(p['presentacionId'])),
              ),
          ],
        ),
        const SizedBox(height: KSpace.m),
        Wrap(
          spacing: KSpace.s,
          runSpacing: KSpace.s,
          children: [
            ChoiceTile(
              label: 'Siempre lleva',
              selected: _option == null,
              onTap: () => _chooseOption(null),
            ),
            for (final o in widget.product.options)
              ChoiceTile(
                label: o['nombre'],
                selected: _option == o['opcionId'],
                onTap: () => _chooseOption(o['opcionId']),
              ),
          ],
        ),
        const SizedBox(height: KSpace.m),
        if (_duplicateIngredients.isNotEmpty) ...[
          Text(
            'Revisa ${_duplicateIngredients.join(', ')}: se sumará Siempre lleva más la opción elegida.',
            style: KText.caption.copyWith(color: KColors.coral),
          ),
          const SizedBox(height: KSpace.s),
        ],
        Text(
          _option == null
              ? 'Insumos que siempre lleva esta presentación, sin importar el complemento.'
              : 'Cantidad por producto de esta presentación, solo cuando el pedido lleva ${widget.product.options.firstWhere((o) => o['opcionId'] == _option)['nombre']}.',
          style: KText.caption,
        ),
        const SizedBox(height: KSpace.m),
        for (final c in _components.where((c) => c['opcionId'] == _option))
          Padding(
            padding: const EdgeInsets.only(bottom: KSpace.m),
            child: Row(
              children: [
                Expanded(
                  flex: 3,
                  child: Text(
                    store.ingredient(c['insumoId']).name,
                    style: KText.body,
                  ),
                ),
                const SizedBox(width: KSpace.s),
                Expanded(
                  flex: 2,
                  child: KTextField(
                    controller: _quantity(c),
                    key: ValueKey('$_id-${c['insumoId']}-${c['opcionId']}'),
                    hint: c['cantidad']?.toString() ?? 'Pendiente',
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
                    ],
                    onChanged: (v) {
                      c['cantidad'] = num.tryParse(v.replaceAll(',', '.'));
                    },
                  ),
                ),
                const SizedBox(width: KSpace.s),
                DropdownButton<int>(
                  value: c['unidadId'],
                  items: [
                    for (final u in _units(store.ingredient(c['insumoId'])))
                      DropdownMenuItem(
                        value: u['unidadId'],
                        child: Text(
                          u['codigo'] == 'fl_oz_US' ? 'oz' : u['codigo'],
                        ),
                      ),
                  ],
                  onChanged: (v) => setState(() => c['unidadId'] = v),
                ),
                IconButton(
                  icon: const Icon(KIcons.x, size: 18),
                  onPressed: () => setState(() => _components.remove(c)),
                ),
              ],
            ),
          ),
        if (_optionIngredientName == null ||
            !_components.any(
              (c) =>
                  c['opcionId'] == _option &&
                  store.ingredient(c['insumoId']).name.trim().toLowerCase() ==
                      _optionIngredientName!.trim().toLowerCase(),
            ))
          SoftButton(
            label: _optionIngredientName == null
                ? 'Agregar insumo'
                : 'Configurar $_optionIngredientName',
            icon: KIcons.plus,
            onTap: _add,
          ),
        const SizedBox(height: KSpace.m),
        const FieldLabel('Salsas / condimentos por unidad'),
        KTextField(
          controller: _fixed,
          hint: 'Pendiente',
          prefix: '\$',
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          inputFormatters: [
            FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
          ],
        ),
        if (_option != null &&
            widget.product.options.any(
              (o) =>
                  o['opcionId'] == _option &&
                  o['tipo'] == 'EXTRA' &&
                  !isOptionalIngredient(o['nombre']),
            )) ...[
          const SizedBox(height: KSpace.m),
          const FieldLabel('Precio del extra'),
          KTextField(
            controller: _additional,
            hint: 'Pendiente',
            prefix: '\$',
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
            ],
          ),
        ],
        Material(
          type: MaterialType.transparency,
          child: CheckboxListTile(
            contentPadding: EdgeInsets.zero,
            title: Text('Confirmar cantidades', style: KText.body),
            value: _confirmed,
            onChanged: (v) => setState(() => _confirmed = v ?? false),
          ),
        ),
        if (_preview != null)
          Text(
            _preview!['costoTotal'] == null
                ? 'Costeo incompleto · conocido ${money(_preview!['subtotalCostoConocido'])}'
                : 'Costo estimado ${money(_preview!['costoTotal'])}',
            style: KText.caption,
          ),
        const SizedBox(height: KSpace.m),
        Text(
          'Guarda esta presentación. Puedes cambiar a otra sin perder el borrador.',
          style: KText.caption,
        ),
        const SizedBox(height: KSpace.s),
        PrimaryButton(
          label: 'Guardar costeo',
          icon: KIcons.checkStrong,
          onTap: _save,
        ),
      ],
    ),
  );
}

/// Selector de insumo: una categoría a la vez; al buscar, busca en todas.
class _IngredientPicker extends StatefulWidget {
  const _IngredientPicker({required this.ingredients});
  final List<Ingredient> ingredients;

  @override
  State<_IngredientPicker> createState() => _IngredientPickerState();
}

class _IngredientPickerState extends State<_IngredientPicker> {
  final _query = TextEditingController();
  late final _categories = [
    for (final c in IngredientCategory.values)
      if (widget.ingredients.any((i) => i.category == c)) c,
  ];
  late IngredientCategory? _cat = _categories.firstOrNull;
  final _selected = <Ingredient>{};

  @override
  void initState() {
    super.initState();
    _query.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _query.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final q = _query.text.trim().toLowerCase();
    final searching = q.isNotEmpty;
    final items = widget.ingredients
        .where(
          (i) =>
              searching ? i.name.toLowerCase().contains(q) : i.category == _cat,
        )
        .toList();
    final body = SheetBody(
      title: 'Elegir insumos',
      subtitle: 'Toca los que quieras y agrégalos juntos.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          KTextField(
            controller: _query,
            hint: 'Buscar insumo',
            icon: KIcons.magnifyingGlass,
          ),
          const SizedBox(height: KSpace.m),
          AnimatedOpacity(
            duration: KMotion.base,
            opacity: searching ? 0.4 : 1,
            child: Wrap(
              spacing: KSpace.s,
              runSpacing: KSpace.s,
              children: [
                for (final c in _categories)
                  CategoryChip(
                    label: c.label,
                    icon: c.icon,
                    count: widget.ingredients
                        .where((i) => i.category == c)
                        .length,
                    selected: !searching && c == _cat,
                    onTap: () => setState(() {
                      _cat = c;
                      _query.clear();
                    }),
                  ),
              ],
            ),
          ),
          const SizedBox(height: KSpace.s),
          AnimatedSize(
            duration: KMotion.base,
            curve: KMotion.ease,
            alignment: Alignment.topCenter,
            child: items.isEmpty
                ? Padding(
                    padding: const EdgeInsets.symmetric(vertical: KSpace.xl),
                    child: Text(
                      searching
                          ? 'Sin resultados para "${_query.text.trim()}"'
                          : 'No hay insumos disponibles',
                      style: KText.caption,
                      textAlign: TextAlign.center,
                    ),
                  )
                : Column(
                    key: ValueKey(searching ? 'q:$q' : _cat),
                    children: [
                      for (var i = 0; i < items.length; i++) ...[
                        if (i > 0) const InsetDivider(indent: 52),
                        Pressable(
                          onTap: () => setState(
                            () =>
                                _selected.remove(items[i]) ||
                                _selected.add(items[i]),
                          ),
                          scale: 0.98,
                          child: Row(
                            children: [
                              Expanded(
                                child: IgnorePointer(
                                  child: IngredientRow(
                                    ingredient: items[i],
                                    showCost: false,
                                  ),
                                ),
                              ),
                              const SizedBox(width: KSpace.m),
                              AnimatedSwitcher(
                                duration: KMotion.fast,
                                child: Icon(
                                  _selected.contains(items[i])
                                      ? KIcons.checkCircleStrong
                                      : KIcons.checkCircle,
                                  key: ValueKey(_selected.contains(items[i])),
                                  size: 24,
                                  color: _selected.contains(items[i])
                                      ? KColors.sea
                                      : KColors.inkMuted.withValues(
                                          alpha: 0.35,
                                        ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
          ),
        ],
      ),
    );
    // Botón fijo abajo para no tener que bajar hasta el final de la lista.
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Flexible(child: body),
        Padding(
          padding: const EdgeInsets.fromLTRB(KSpace.xl, KSpace.m, KSpace.xl, 0),
          child: PrimaryButton(
            label: _selected.isEmpty
                ? 'Elige insumos'
                : _selected.length == 1
                ? 'Agregar 1 insumo'
                : 'Agregar ${_selected.length} insumos',
            icon: KIcons.plusStrong,
            onTap: _selected.isEmpty
                ? null
                : () => Navigator.of(context).pop(_selected.toList()),
          ),
        ),
      ],
    );
  }
}
