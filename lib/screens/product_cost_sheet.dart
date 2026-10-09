import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../data/app_store.dart';
import '../theme/icons.dart';
import '../theme/tokens.dart';
import '../widgets/basics.dart';
import '../widgets/chips.dart';
import '../widgets/glass_sheet.dart';
import '../widgets/inputs.dart';
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
  @override
  void initState() {
    super.initState();
    _select(_id);
  }

  void _select(int id) {
    for (final c in _quantities.values) {
      c.dispose();
    }
    _quantities.clear();
    _id = id;
    final p = _presentations.firstWhere((p) => p['presentacionId'] == id);
    _fixed.text = p['costoFijoCondimentos']?.toString() ?? '';
    _confirmed = p['configuracionCosteoConfirmada'] == true;
    _preview = null;
    _components = (widget.data['componentes'] as List)
        .where((c) => c['presentacionId'] == id)
        .map(
          (c) => <String, dynamic>{
            'insumoId': c['insumoId'],
            'opcionId': c['opcionId'],
            'cantidad': c['cantidadUso'],
            'unidadId': store.unitId(store.ingredient(c['insumoId']).useUnit),
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

  Future<void> _add() async {
    final chosen = await showGlassSheet<Ingredient>(
      context,
      builder: (context) => SheetBody(
        title: 'Elegir insumo',
        child: Column(
          children: [
            for (final i in store.ingredients.where(
              (i) =>
                  i.measurable &&
                  !_components.any(
                    (c) => c['insumoId'] == i.id && c['opcionId'] == _option,
                  ),
            ))
              ListTile(
                title: Text(i.name),
                onTap: () => Navigator.of(context).pop(i),
              ),
          ],
        ),
      ),
    );
    if (chosen != null && mounted) {
      setState(
        () => _components.add({
          'insumoId': chosen.id,
          'opcionId': _option,
          'cantidad': null,
          'unidadId': store.unitId(chosen.useUnit),
        }),
      );
    }
  }

  Future<void> _save() => runAction(context, () async {
    await store.api.request(
      'PUT',
      '/platillos/${widget.product.id}/componentes',
      body: {
        'presentacionId': _id,
        'componentes': _components,
        'costoFijoCondimentos': num.tryParse(_fixed.text.replaceAll(',', '.')),
        'confirmada': _confirmed,
      },
    );
    if (_option != null &&
        widget.product.options.any(
          (o) => o['opcionId'] == _option && o['tipo'] == 'EXTRA',
        )) {
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
  });
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
              label: 'Base',
              selected: _option == null,
              onTap: () => setState(() => _option = null),
            ),
            for (final o in widget.product.options)
              ChoiceTile(
                label: o['nombre'],
                selected: _option == o['opcionId'],
                onTap: () => setState(() {
                  _option = o['opcionId'];
                  _additional.text = o['precioAdicional']?.toString() ?? '';
                }),
              ),
          ],
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
        SoftButton(label: 'Agregar insumo', icon: KIcons.plus, onTap: _add),
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
        PrimaryButton(
          label: 'Guardar costeo',
          icon: KIcons.checkStrong,
          onTap: _save,
        ),
      ],
    ),
  );
}
