import 'common.dart';

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

/// Editar una compra ya registrada. Caso típico: en la mañana se anota
/// cantidad y precio; en la tarde, tras pelar o exprimir, el rendimiento.
Future<void> showEditPurchaseSheet(BuildContext context, Purchase purchase) =>
    showGlassSheet<void>(
      context,
      builder: (_) => _EditPurchaseSheet(purchase: purchase),
    );

class _EditPurchaseSheet extends StatefulWidget {
  const _EditPurchaseSheet({required this.purchase});
  final Purchase purchase;

  @override
  State<_EditPurchaseSheet> createState() => _EditPurchaseSheetState();
}

class _EditPurchaseSheetState extends State<_EditPurchaseSheet> {
  late final Purchase p = widget.purchase;
  late String _yieldUnit = p.ingredient.useUnit;
  late final _qty = TextEditingController(text: _fmt(p.qty));
  late final _price = TextEditingController(text: '${p.total}');
  late final _yield = TextEditingController(
    text: p.yieldValue?.toString() ?? '',
  );

  static String _fmt(num q) => q == q.roundToDouble() ? '${q.toInt()}' : '$q';

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

  num? get _qtyValue => num.tryParse(_qty.text.replaceAll(',', '.'));
  num? get _priceValue => num.tryParse(_price.text.replaceAll(',', '.'));
  bool get _valid => (_qtyValue ?? 0) > 0 && (_priceValue ?? 0) > 0;

  Future<void> _save() => runAction(context, () async {
    final y = num.tryParse(_yield.text.replaceAll(',', '.'));
    final completedYield = p.needsYield && y != null;
    await store.updatePurchase(
      p,
      qty: _qtyValue!,
      total: _priceValue!,
      yieldUnit: _yieldUnit,
      yieldValue: y,
    );
    if (!mounted) return;
    showToast(
      context,
      completedYield
          ? 'Rendimiento de ${p.ingredient.name} guardado'
          : 'Compra actualizada',
    );
    Navigator.of(context).pop();
  });

  Future<void> _delete() => runAction(context, () async {
    await store.removePurchase(p);
    if (!mounted) return;
    if (!mounted) return;
    showToast(context, 'Compra eliminada', color: KColors.danger);
    Navigator.of(context).pop();
  });

  @override
  Widget build(BuildContext context) {
    final i = p.ingredient;
    final entered = num.tryParse(_yield.text.replaceAll(',', '.'));
    final y = entered == null ? null : entered * store.yieldFactor(_yieldUnit);
    final qty = _qtyValue ?? 0;

    // Muestra cuánto se aprovechó, comparando con lo comprado.
    String? yieldHint;
    if (y != null && y > 0 && qty > 0) {
      final factor = switch (i.buyUnit) {
        'kg' || 'L' => 1000,
        _ => 1,
      };
      final sameFamily =
          (i.buyUnit == 'kg' && i.useUnit == 'g') ||
          (i.buyUnit == 'L' && i.useUnit == 'ml');
      if (sameFamily) {
        final pct = (y / (qty * factor) * 100).round();
        yieldHint = 'Aprovechaste el $pct% · merma ${100 - pct}%';
      }
      final price = _priceValue ?? 0;
      if (price > 0) {
        final per = i.useUnit == 'pza' ? price / y : price / y * 100;
        yieldHint = [
          ?yieldHint,
          'Costo real ${money(per)} por ${i.useUnit == 'pza' ? 'pieza' : '100 ${i.useUnit}'}',
        ].join('\n');
      }
    }

    return SheetBody(
      title: i.name,
      subtitle: 'Compra de las ${p.time}',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const FieldLabel('Cantidad'),
                    KTextField(
                      controller: _qty,
                      suffix: i.buyUnit,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: KSpace.m),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const FieldLabel('Precio total'),
                    KTextField(
                      controller: _price,
                      prefix: '\$',
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (i.measurable && i.requiresUseful) ...[
            const SizedBox(height: KSpace.xl),
            const FieldLabel('Rendimiento final'),
            KTextField(
              controller: _yield,
              big: true,
              hint: '0',
              suffix: _yieldUnit,
              autofocus: p.needsYield, // si viene a completarlo, el teclado ya está listo
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
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
                yieldHint ??
                    (i.useUnit == 'ml'
                        ? 'Lo que obtuviste al exprimir.'
                        : 'Lo que quedó útil después de limpiar.'),
                style: KText.caption.copyWith(
                  color: yieldHint == null ? KColors.inkSoft : KColors.lagoon,
                ),
              ),
            ),
          ],
          const SizedBox(height: KSpace.xl),
          PrimaryButton(
            label: 'Guardar',
            icon: KIcons.checkStrong,
            onTap: _valid ? _save : null,
          ),
          const SizedBox(height: KSpace.s),
          SoftButton(
            label: 'Eliminar compra',
            icon: KIcons.trash,
            color: KColors.danger,
            onTap: _delete,
          ),
        ],
      ),
    );
  }
}
