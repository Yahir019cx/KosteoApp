import 'package:flutter/material.dart';

import '../data/app_store.dart';
import '../theme/tokens.dart';
import '../widgets/basics.dart';
import '../widgets/glass_sheet.dart';

class OrderIngredientsSheet extends StatelessWidget {
  const OrderIngredientsSheet({
    super.key,
    required this.data,
    this.allPending = false,
  });
  final bool allPending;
  final Map<String, dynamic> data;

  String _quantity(num value, String unit) {
    if (unit == 'g' && value >= 1000) {
      value /= 1000;
      unit = 'kg';
    }
    final text = value.toStringAsFixed(3).replaceFirst(RegExp(r'\.?0+$'), '');
    return '$text ${unitLabel(unit, value)}';
  }

  @override
  Widget build(BuildContext context) {
    final items = data['insumos'] as List;
    final pending = data['pendientes'] as List;
    return SheetBody(
      title: allPending
          ? 'Insumos de todos los pendientes'
          : 'Insumos para estos pedidos',
      subtitle: '${data['pedidos']} pedidos · ${data['productos']} productos',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Cantidades útiles según tu configuración. Al comprar, considera la merma y lo que ya tienes.',
            style: KText.caption,
          ),
          const SizedBox(height: KSpace.l),
          if (data['estadoCantidades'] == 'INCOMPLETO') ...[
            Text(
              'Resumen parcial · faltan cantidades por configurar',
              style: KText.bodyStrong.copyWith(color: KColors.coral),
            ),
            const SizedBox(height: KSpace.m),
          ],
          if (items.isEmpty)
            Text(
              allPending && data['productos'] == 0
                  ? 'No hay pedidos pendientes por ahora.'
                  : 'Todavía no hay cantidades configuradas para estos productos.',
              style: KText.body,
            ),
          for (final item in items) ...[
            KosteoCard(
              padding: const EdgeInsets.all(KSpace.m),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      item['nombre'] as String,
                      style: KText.bodyStrong,
                    ),
                  ),
                  const SizedBox(width: KSpace.m),
                  Flexible(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          item['cantidadRequerida'] == null
                              ? 'Pendiente'
                              : _quantity(
                                  item['cantidadRequerida'] as num,
                                  item['unidadUso'] as String,
                                ),
                          style: KText.bodyStrong,
                          textAlign: TextAlign.right,
                        ),
                        if (item['cantidadRequerida'] == null &&
                            item['cantidadConocida'] != null)
                          Text(
                            '${_quantity(item['cantidadConocida'] as num, item['unidadUso'] as String)} conocidos',
                            style: KText.caption,
                            textAlign: TextAlign.right,
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: KSpace.s),
          ],
          if (pending.isNotEmpty) ...[
            const SizedBox(height: KSpace.m),
            Text('Por completar', style: KText.bodyStrong),
            const SizedBox(height: KSpace.s),
            for (final name
                in pending.map((p) => p['nombre'] as String).toSet())
              Padding(
                padding: const EdgeInsets.only(bottom: KSpace.s),
                child: Text(name, style: KText.caption),
              ),
          ],
        ],
      ),
    );
  }
}
