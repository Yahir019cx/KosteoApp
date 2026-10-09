import 'common.dart';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/icons.dart';

import '../data/app_store.dart';
import '../theme/tokens.dart';
import '../widgets/basics.dart';
import '../widgets/chips.dart';
import '../widgets/glass_sheet.dart';
import '../widgets/inputs.dart';
import '../widgets/toast.dart';

/// Gasto de gasolina de reparto: monto (con atajos) y vehículo. Nada más.
Future<void> showGasSheet(BuildContext context) =>
    showGlassSheet<void>(context, builder: (_) => const _GasSheet());

class _GasSheet extends StatefulWidget {
  const _GasSheet();

  @override
  State<_GasSheet> createState() => _GasSheetState();
}

class _GasSheetState extends State<_GasSheet> {
  final _amount = TextEditingController();
  final _comment = TextEditingController();

  @override
  void initState() {
    super.initState();
    _amount.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _amount.dispose();
    _comment.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final value = num.tryParse(_amount.text.replaceAll(',', '.')) ?? 0;
    return SheetBody(
      title: 'Gasolina de reparto',
      subtitle: 'Hoy llevas ${money(store.gasTotal)}',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          KTextField(
            controller: _amount,
            big: true,
            hint: '0',
            prefix: '\$',
            textAlign: TextAlign.start,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
            ],
          ),
          const SizedBox(height: KSpace.m),
          Wrap(
            spacing: KSpace.s,
            children: [
              for (final q in [50, 100, 150, 200])
                CategoryChip(
                  label: money(q),
                  selected: value == q,
                  color: KColors.sun,
                  onTap: () => _amount.text = '$q',
                ),
            ],
          ),
          const SizedBox(height: KSpace.xl),
          KTextField(controller: _comment, hint: 'Comentario (opcional)'),
          const SizedBox(height: KSpace.xl),
          PrimaryButton(
            label: value > 0 ? 'Guardar ${money(value)}' : 'Guardar',
            icon: KIcons.checkStrong,
            onTap: value > 0
                ? () => runAction(context, () async {
                    await store.addGas(value, comment: _comment.text.trim());
                    if (!context.mounted) return;
                    showToast(context, 'Gasolina ${money(value)} registrada');
                    Navigator.of(context).pop();
                  })
                : null,
          ),
        ],
      ),
    );
  }
}
