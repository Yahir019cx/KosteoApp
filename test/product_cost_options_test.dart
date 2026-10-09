import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:kosteo/data/api_client.dart';
import 'package:kosteo/data/app_store.dart';
import 'package:kosteo/screens/product_cost_sheet.dart';
import 'package:kosteo/widgets/chips.dart';

class _Store extends KosteoStore {
  _Store(ApiClient api) : super(client: api);
  @override
  Future<void> menu() async {}
  @override
  Future<void> refresh() async {}
}

void main() {
  setUpAll(() async {
    final font = FontLoader('PlusJakartaSans');
    for (final w in ['500', '700']) {
      font.addFont(
        File('assets/fonts/PlusJakartaSans-$w.ttf')
            .readAsBytes()
            .then((b) => ByteData.view(b.buffer)),
      );
    }
    await font.load();
  });
  for (final width in [390.0, 1194.0]) {
    for (final scenario in [
      'normal',
      'preview-error',
      'refresh-error',
      'duplicate',
    ]) {
      testWidgets('Costeo y borradores ($width, $scenario)', (tester) async {
        tester.view.physicalSize = Size(width, 1100);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        final previous = store;
        addTearDown(() => store = previous);
        final saved = <Map<String, dynamic>>[];
        final data = <String, dynamic>{
          'presentaciones': [
            {
              'presentacionId': 1,
              'nombre': 'Individual',
              'activa': true,
              'costoFijoCondimentos': 1.50,
              'configuracionCosteoConfirmada': false,
            },
            {
              'presentacionId': 2,
              'nombre': 'Pa Compartir',
              'activa': true,
              'costoFijoCondimentos': 1.50,
              'configuracionCosteoConfirmada': false,
            },
          ],
          'componentes': <dynamic>[
            if (scenario == 'duplicate')
              {
                'presentacionId': 1,
                'insumoId': 1,
                'opcionId': null,
                'cantidadUso': 2,
              },
          ],
        };
        final api = ApiClient(
          client: MockClient((r) async {
            if (r.method == 'PUT') {
              final body = Map<String, dynamic>.from(jsonDecode(r.body));
              saved.add(body);
              final components = data['componentes'] as List;
              components.removeWhere(
                (c) => c['presentacionId'] == body['presentacionId'],
              );
              components.addAll(
                (body['componentes'] as List).map(
                  (c) => {
                    ...c,
                    'presentacionId': body['presentacionId'],
                    'cantidadUso': c['cantidad'],
                  },
                ),
              );
              return http.Response('{}', 200);
            }
            if (saved.isNotEmpty &&
                ((scenario == 'preview-error' &&
                        r.url.path.endsWith('/costo')) ||
                    (scenario == 'refresh-error' &&
                        r.url.path.endsWith('/componentes')))) {
              return http.Response(
                '{"message":"Fallo de actualización de prueba"}',
                503,
              );
            }
            return http.Response(
              jsonEncode(
                r.url.path.endsWith('/costo')
                    ? {'costoTotal': null, 'subtotalCostoConocido': null}
                    : data,
              ),
              200,
            );
          }),
        );
        final fake = _Store(api);
        store = fake;
        fake.units = [
          {
            'unidadId': 1,
            'codigo': 'pza',
            'dimension': 'CONTEO',
            'factorBase': 1,
          },
          {'unidadId': 2, 'codigo': 'g', 'dimension': 'MASA', 'factorBase': 1},
        ];
        final names = ['Tostadas', 'Tostitos', 'Piña', 'Mango', 'Camarón'];
        for (var i = 0; i < names.length; i++) {
          final unit = i < 2 ? 'pza' : 'g';
          fake.ingredients.add(
            Ingredient(
              names[i],
              IngredientCategory.extras,
              Icons.restaurant,
              unit,
              unit,
            )..id = i + 1,
          );
        }
        final product =
            Product(
                'Aguachile',
                120,
                'Aguachiles',
                Icons.restaurant,
                Colors.green,
              )
              ..id = 1
              ..options = [
                for (var i = 0; i < 4; i++)
                  {
                    'opcionId': i + 1,
                    'nombre': names[i],
                    'tipo': i < 2 ? 'COMPLEMENTO' : 'EXTRA',
                    'precioAdicional': 0,
                  },
              ];
        await tester.pumpWidget(
          MaterialApp(
            home: Builder(
              builder: (context) => Scaffold(
                body: TextButton(
                  onPressed: () => showProductCost(context, product),
                  child: const Text('Abrir'),
                ),
              ),
            ),
          ),
        );
        await tester.tap(find.text('Abrir'));
        await tester.pumpAndSettle();
        expect(find.text('Siempre lleva'), findsOneWidget);
        for (final name in names.take(4)) {
          await tester.ensureVisible(find.widgetWithText(ChoiceTile, name));
          await tester.tap(find.widgetWithText(ChoiceTile, name));
          await tester.pumpAndSettle();
          expect(find.text('Agregar insumo'), findsNothing);
          await tester.ensureVisible(find.text('Configurar $name'));
          await tester.tap(find.text('Configurar $name'));
          await tester.pumpAndSettle();
          expect(find.text('Elegir insumos'), findsNothing);
          expect(find.text('Camarón'), findsNothing);
          expect(find.text('Configurar $name'), findsNothing);
        }
        await tester.ensureVisible(find.widgetWithText(ChoiceTile, 'Tostadas'));
        await tester.tap(find.widgetWithText(ChoiceTile, 'Tostadas'));
        await tester.pumpAndSettle();
        await tester.enterText(
          find.descendant(
            of: find.byKey(const ValueKey('1-1-1')),
            matching: find.byType(TextField),
          ),
          '5',
        );
        // Cambiar de presentación sin guardar conserva el borrador completo.
        await tester.ensureVisible(
          find.widgetWithText(ChoiceTile, 'Pa Compartir'),
        );
        await tester.tap(find.widgetWithText(ChoiceTile, 'Pa Compartir'));
        await tester.pumpAndSettle();
        await tester.ensureVisible(
          find.widgetWithText(ChoiceTile, 'Individual'),
        );
        await tester.tap(find.widgetWithText(ChoiceTile, 'Individual'));
        await tester.pumpAndSettle();
        expect(
          tester
              .widget<TextField>(
                find.descendant(
                  of: find.byKey(const ValueKey('1-1-1')),
                  matching: find.byType(TextField),
                ),
              )
              .controller!
              .text,
          '5',
        );
        expect(saved, isEmpty);
        await tester.ensureVisible(find.text('Guardar costeo'));
        await tester.tap(find.text('Guardar costeo'));
        await tester.pumpAndSettle();
        if (scenario == 'duplicate') {
          expect(saved, isEmpty);
          expect(find.text('Revisa las cantidades'), findsOneWidget);
          await tester.tap(find.text('Revisar'));
          await tester.pumpAndSettle();
          expect(saved, isEmpty);
          await tester.tap(find.text('Guardar costeo'));
          await tester.pumpAndSettle();
          await tester.tap(find.text('Guardar así'));
          await tester.pumpAndSettle();
        }
        if (scenario.endsWith('error')) {
          expect(
            find.textContaining('Cantidades guardadas. No se pudo'),
            findsOneWidget,
          );
        }
        await tester.pump(const Duration(seconds: 6));
        await tester.pumpAndSettle();
        expect(saved.last['presentacionId'], 1);
        expect(
          (saved.last['componentes'] as List).firstWhere(
            (c) => c['opcionId'] == 1,
          )['cantidad'],
          5,
        );
        await tester.ensureVisible(
          find.widgetWithText(ChoiceTile, 'Pa Compartir'),
        );
        await tester.tap(find.widgetWithText(ChoiceTile, 'Pa Compartir'));
        await tester.pumpAndSettle();
        await tester.ensureVisible(find.text('Configurar Tostadas'));
        await tester.tap(find.text('Configurar Tostadas'));
        await tester.pumpAndSettle();
        await tester.enterText(
          find.descendant(
            of: find.byKey(const ValueKey('2-1-1')),
            matching: find.byType(TextField),
          ),
          '10',
        );
        await tester.ensureVisible(find.text('Guardar costeo'));
        await tester.tap(find.text('Guardar costeo'));
        await tester.pumpAndSettle();
        expect(saved.last['presentacionId'], 2);
        expect((saved.last['componentes'] as List).single['cantidad'], 10);
        expect(
          (data['componentes'] as List).firstWhere(
            (c) => c['presentacionId'] == 1 && c['opcionId'] == 1,
          )['cantidadUso'],
          5,
        );
        await tester.pump(const Duration(seconds: 6));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      });
    }
  }
}
