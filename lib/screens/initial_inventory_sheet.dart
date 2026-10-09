import 'package:flutter/material.dart';

import '../data/app_store.dart';
import '../theme/icons.dart';
import '../theme/tokens.dart';
import '../widgets/basics.dart';
import '../widgets/chips.dart';
import '../widgets/glass_sheet.dart';
import '../widgets/inputs.dart';
import '../widgets/toast.dart';
import 'common.dart';

Future<Ingredient?> showInitialInventory(BuildContext context) =>
    showGlassSheet<Ingredient>(
      context,
      builder: (_) => const _InitialInventory(),
    );

class _InitialInventory extends StatefulWidget {
  const _InitialInventory();
  @override
  State<_InitialInventory> createState() => _InitialInventoryState();
}

class _InitialInventoryState extends State<_InitialInventory> {
  Ingredient? _ingredient;
  String? _unit;
  final _qty = TextEditingController();
  final _cost = TextEditingController();
  num? value(TextEditingController c) =>
      num.tryParse(c.text.replaceAll(',', '.'));
  @override
  void dispose() {
    _qty.dispose();
    _cost.dispose();
    super.dispose();
  }

  List<String> get _units {
    final i = _ingredient;
    if (i == null) return [];
    final dimension = store.units.firstWhere(
      (u) => u['codigo'] == i.useUnit,
    )['dimension'];
    return store.units
        .where((u) => u['dimension'] == dimension && u['factorBase'] != null)
        .map((u) => u['codigo'] as String)
        .toList();
  }

  Future<void> _pick() async {
    final i = await showGlassSheet<Ingredient>(
      context,
      builder: (_) => const _InitialIngredientPicker(),
    );
    if (i == null || !mounted) return;
    setState(() {
      _ingredient = i;
      _unit = i.useUnit == 'g' ? 'kg' : i.useUnit;
      if (!_units.contains(_unit)) _unit = _units.first;
      _qty.clear();
      _cost.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    final qty = value(_qty), cost = value(_cost);
    final valid =
        _ingredient != null &&
        qty != null &&
        qty > 0 &&
        cost != null &&
        cost > 0;
    return SheetBody(
      title: 'Inventario inicial',
      subtitle: 'Lo que ya tenías. No cuenta como compra de la jornada.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SoftButton(
            label: _ingredient?.name ?? 'Elegir insumo',
            icon: KIcons.plus,
            onTap: _pick,
          ),
          if (_ingredient != null) ...[
            const SizedBox(height: KSpace.m),
            const FieldLabel('Cantidad útil'),
            KTextField(
              controller: _qty,
              hint: 'Cantidad',
              suffix: _unit,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: KSpace.s),
            Wrap(
              spacing: KSpace.s,
              runSpacing: KSpace.s,
              children: [
                for (final u in _units)
                  CategoryChip(
                    label: u,
                    selected: _unit == u,
                    onTap: () => setState(() {
                      _unit = u;
                      _qty.clear();
                      _cost.clear();
                    }),
                  ),
              ],
            ),
            const SizedBox(height: KSpace.m),
            FieldLabel('Costo por $_unit'),
            KTextField(
              controller: _cost,
              hint: 'Costo por unidad',
              prefix: '\$',
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: KSpace.m),
            if (valid)
              Text(
                'Valor inicial: ${money(qty * cost)}',
                style: KText.bodyStrong,
              ),
          ],
          const SizedBox(height: KSpace.l),
          PrimaryButton(
            label: 'Guardar saldo inicial',
            icon: KIcons.checkStrong,
            onTap: !valid
                ? null
                : () => runAction(context, () async {
                    await store.saveInitialInventory(
                      _ingredient!,
                      qty,
                      _unit!,
                      cost,
                    );
                    if (!context.mounted) return;
                    showToast(context, 'Inventario inicial guardado');
                    Navigator.of(context).pop(_ingredient);
                  }),
          ),
        ],
      ),
    );
  }
}

class _InitialIngredientPicker extends StatefulWidget {
  const _InitialIngredientPicker();
  @override
  State<_InitialIngredientPicker> createState() =>
      _InitialIngredientPickerState();
}

class _InitialIngredientPickerState extends State<_InitialIngredientPicker> {
  final _search = TextEditingController();
  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => SheetBody(
    title: 'Elegir insumo',
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        KTextField(
          controller: _search,
          hint: 'Buscar insumo',
          icon: KIcons.magnifyingGlass,
          onChanged: (_) => setState(() {}),
        ),
        const SizedBox(height: KSpace.m),
        for (final i in store.ingredients.where(
          (i) =>
              i.measurable &&
              i.name.toLowerCase().contains(_search.text.trim().toLowerCase()),
        ))
          Padding(
            padding: const EdgeInsets.only(bottom: KSpace.s),
            child: SoftButton(
              label: i.name,
              icon: i.icon,
              onTap: () => Navigator.of(context).pop(i),
            ),
          ),
      ],
    ),
  );
}
