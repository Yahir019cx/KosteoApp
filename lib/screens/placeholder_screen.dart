import 'package:flutter/material.dart';

import '../theme/icons.dart';
import '../widgets/basics.dart';
import 'common.dart';
import 'leftovers_screen.dart';

/// Secciones secundarias que aún no forman parte de este prototipo.
class PlaceholderScreen extends StatelessWidget {
  const PlaceholderScreen.inventory({super.key})
    : title = 'Inventario',
      icon = KIcons.box,
      message = 'Aquí verás tus existencias en tiempo real, calculadas con compras, ventas y sobrantes.',
      _leftoversCta = true;

  const PlaceholderScreen.reports({super.key})
    : title = 'Reportes',
      icon = KIcons.chartBar,
      message = 'Tendencias de ventas, costos y platillos más rentables por semana y mes.',
      _leftoversCta = false;

  const PlaceholderScreen.settings({super.key})
    : title = 'Configuración',
      icon = KIcons.gear,
      message = 'Datos del negocio, menú y precios.',
      _leftoversCta = false;

  final String title;
  final IconData icon;
  final String message;
  final bool _leftoversCta;

  @override
  Widget build(BuildContext context) {
    if (_leftoversCta) return const LeftoversScreen(counting: false);
    return KScaffold(
      body: ContentWidth(
        maxWidth: 640,
        child: Column(
          children: [
            PageHeader(title: title, subtitle: 'Próximamente', back: true),
            Expanded(
              child: Center(
                child: EmptyState(
                  icon: icon,
                  title: 'Estamos preparando esta sección',
                  message: message,
                  action: _leftoversCta
                      ? PrimaryButton(
                          label: 'Hacer conteo de sobrantes',
                          expand: false,
                          onTap: () => push(context, const LeftoversScreen()),
                        )
                      : null,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
