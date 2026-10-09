import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kosteo/data/api_client.dart';
import 'package:kosteo/data/app_store.dart';
import 'package:kosteo/screens/orders_screen.dart';
import 'package:kosteo/theme/tokens.dart';
import 'package:kosteo/widgets/basics.dart';

class PlanningStore extends KosteoStore {
  List<int>? ids;
  String scenario = 'complete';
  @override
  Future<Map<String, dynamic>> orderIngredients(List<int> selected) async {
    ids = selected;
    if (scenario == 'error') {
      throw ApiException('Selecciona pedidos pendientes.');
    }
    return {
      'pedidos': 2,
      'productos': 3,
      'estadoCantidades': scenario == 'partial' ? 'INCOMPLETO' : 'COMPLETO',
      'insumos': [
        {
          'nombre': 'Camarón',
          'unidadUso': 'g',
          'cantidadRequerida': 1500,
          'cantidadConocida': 1500,
        },
        {
          'nombre': 'Pepino',
          'unidadUso': 'g',
          'cantidadRequerida': 375,
          'cantidadConocida': 375,
        },
        {
          'nombre': 'Cebolla',
          'unidadUso': 'g',
          'cantidadRequerida': scenario == 'partial' ? null : 75,
          'cantidadConocida': scenario == 'partial' ? 25 : 75,
        },
        {
          'nombre': 'Piña',
          'unidadUso': 'g',
          'cantidadRequerida': 80,
          'cantidadConocida': 80,
        },
        {
          'nombre': 'Tostitos',
          'unidadUso': 'pza',
          'cantidadRequerida': 3,
          'cantidadConocida': 3,
        },
        {
          'nombre': 'Tostadas',
          'unidadUso': 'pza',
          'cantidadRequerida': 4,
          'cantidadConocida': 4,
        },
      ],
      'pendientes': scenario == 'partial'
          ? [
              {'nombre': 'Producto individual'},
            ]
          : [],
    };
  }
}

void main() {
  for (final width in [390.0, 1194.0]) {
    for (final scenario in ['complete', 'partial', 'error']) {
      testWidgets('Seleccion y resumen $width $scenario', (tester) async {
        tester.view.physicalSize = Size(width, 844);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        final data = PlanningStore()..scenario = scenario;
        store = data;
        final p = Product(
          'Producto',
          120,
          'Especiales',
          Icons.restaurant,
          KColors.mist,
        );
        data.orders.addAll([
          Order(1, 'Ana', '12:00', [OrderLine(p, 2)], OrderStatus.pending),
          Order(2, 'Luis', '12:00', [OrderLine(p, 1)], OrderStatus.pending)
            ..jornadaId = 5,
        ]);
        await tester.pumpWidget(
          MaterialApp(
            theme: buildKosteoTheme(),
            home: Scaffold(body: const OrdersScreen()),
          ),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.bySemanticsLabel('Seleccionar pedidos'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Seleccionar').first);
        await tester.pumpAndSettle();
        await tester.tap(find.text('Seleccionar').first);
        await tester.pumpAndSettle();
        expect(find.text('2 pedidos seleccionados'), findsOneWidget);
        final assign = tester.widget<SoftButton>(
          find
              .byWidgetPredicate(
                (w) => w is SoftButton && w.label == 'Asignar jornada',
              )
              .first,
        );
        expect(
          assign.onTap,
          isNull,
        ); // mixed selection cannot silently reassign existing jornada
        await tester.tap(find.text('Ver insumos'));
        await tester.pumpAndSettle();
        expect(data.ids!.toSet(), {1, 2});
        expect(data.orders.every((o) => o.status == OrderStatus.pending), true);
        if (scenario == 'error') {
          expect(find.text('Selecciona pedidos pendientes.'), findsOneWidget);
        } else {
          expect(find.text('Insumos para estos pedidos'), findsOneWidget);
          expect(find.text('1.5 kg'), findsOneWidget);
          expect(find.text('375 g'), findsOneWidget);
          if (scenario == 'partial') {
            expect(find.text('Pendiente'), findsWidgets);
            expect(find.text('25 g conocidos'), findsOneWidget);
          } else {
            expect(find.text('75 g'), findsOneWidget);
          }
        }
        expect(tester.takeException(), isNull);
        await tester.pump(const Duration(seconds: 6));
        await tester.pumpAndSettle();
      });
    }
  }
}
