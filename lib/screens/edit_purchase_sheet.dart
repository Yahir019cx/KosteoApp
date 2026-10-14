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
Future<void> showEditPurchaseSheet(BuildContext context, Purchase purchase) {
  if ((purchase.remainingToProcess ?? 0) > 0) {
    return showGlassSheet<void>(
      context,
      builder: (_) => _PartialYieldSheet(purchase: purchase),
    );
  }
  if (purchase.manualProcessing) {
    return showGlassSheet<void>(
      context,
      builder: (_) => SheetBody(
        title: purchase.ingredient.name,
        subtitle: 'Compra procesada completamente',
        child: Text(
          '${purchase.qtyLabel} · ${money(purchase.total)}\nObtuviste ${purchase.yieldValue} ${purchase.ingredient.useUnit} útiles.',
          style: KText.body,
        ),
      ),
    );
  }
  return showGlassSheet<void>(
    context,
    builder: (_) => _EditPurchaseSheet(purchase: purchase),
  );
}

class _PartialYieldSheet extends StatefulWidget {
  const _PartialYieldSheet({required this.purchase});
  final Purchase purchase;
  @override
  State<_PartialYieldSheet> createState() => _PartialYieldSheetState();
}

class _PartialYieldSheetState extends State<_PartialYieldSheet> {
  late final _processed = TextEditingController(
    text: '${widget.purchase.remainingToProcess}',
  );
  final _useful = TextEditingController();
  late String _unit =
      store
          .yieldUnits(widget.purchase.ingredient)
          .any((u) => u['codigo'] == widget.purchase.processingUnit)
      ? widget.purchase.processingUnit
      : widget.purchase.ingredient.useUnit;
  bool _saving = false;
  num? _number(TextEditingController controller) =>
      num.tryParse(controller.text.replaceAll(',', '.'));
  String _display(num value) =>
      value.toStringAsFixed(8).replaceFirst(RegExp(r'\.?0+$'), '');
  @override
  void dispose() {
    _processed.dispose();
    _useful.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_saving) return;
    setState(() => _saving = true);
    try {
      await runAction(context, () async {
        await store.queuePurchaseYield(
          widget.purchase,
          _number(_processed)!,
          _number(_useful)!,
          _unit,
        );
        if (!mounted) return;
        showToast(context, 'Rendimiento en envío. Puedes continuar.');
        Navigator.of(context).pop();
      });
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.purchase;
    final amount = _number(_processed), useful = _number(_useful);
    final valid =
        amount != null &&
        amount > 0 &&
        amount <= p.remainingToProcess! &&
        useful != null &&
        useful > 0;
    return SheetBody(
      title: 'Procesar ${p.ingredient.name}',
      subtitle:
          '${p.remainingToProcess} ${p.processingUnit} por procesar de esta compra',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const FieldLabel('Cantidad procesada'),
          KTextField(
            controller: _processed,
            suffix: p.processingUnit,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: KSpace.l),
          const FieldLabel('Cantidad útil'),
          KTextField(
            controller: _useful,
            suffix: _unit,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            onChanged: (_) => setState(() {}),
          ),
          if (store.yieldUnits(p.ingredient).length > 1) ...[
            const SizedBox(height: KSpace.s),
            Wrap(
              spacing: KSpace.s,
              runSpacing: KSpace.s,
              children: [
                for (final unit in store.yieldUnits(p.ingredient))
                  CategoryChip(
                    label: unit['codigo'],
                    selected: _unit == unit['codigo'],
                    onTap: () => setState(() => _unit = unit['codigo']),
                  ),
              ],
            ),
          ],
          if (amount != null && amount > 0 && amount <= p.remainingToProcess!)
            Padding(
              padding: const EdgeInsets.only(top: KSpace.s, left: 4),
              child: Text(
                'Quedarán ${_display(p.remainingToProcess! - amount)} ${p.processingUnit} por procesar.',
                style: KText.caption,
              ),
            ),
          const SizedBox(height: KSpace.xl),
          PrimaryButton(
            label: _saving ? 'Guardando…' : 'Registrar rendimiento',
            onTap: valid && !_saving ? _save : null,
          ),
          if (!p.manualProcessing) ...[
            const SizedBox(height: KSpace.s),
            SoftButton(
              label: 'Editar datos de compra',
              onTap: () => showGlassSheet<void>(
                context,
                builder: (_) => _EditPurchaseSheet(purchase: p),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

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
    showToast(context, 'Compra eliminada');
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
            if (store.yieldUnits(i).length > 1) ...[
              const SizedBox(height: KSpace.s),
              Wrap(
                spacing: KSpace.s,
                runSpacing: KSpace.s,
                children: [
                  for (final u in store.yieldUnits(i))
                    CategoryChip(
                      label: u['codigo'] == 'fl_oz_US' ? 'oz' : u['codigo'],
                      selected: _yieldUnit == u['codigo'],
                      onTap: () => setState(() => _yieldUnit = u['codigo']),
                    ),
                ],
              ),
            ],
            Padding(
              padding: const EdgeInsets.only(top: KSpace.s, left: 4),
              child: Text(
                yieldHint ??
                    (i.useUnit == 'ml'
                        ? 'Lo que obtuviste al exprimir.'
                        : 'Lo que quedó útil después de limpiar.'),
                style: KText.caption.copyWith(
                  color: yieldHint == null
                      ? KColors.inkSoft
                      : KColors.lagoonDeep,
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
          const SizedBox(height: KSpace.l),
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
