import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:kosteo/data/api_client.dart';
import 'package:kosteo/data/app_store.dart';
import 'package:kosteo/screens/common.dart';
import 'package:kosteo/theme/icons.dart';
import 'package:kosteo/theme/tokens.dart';

void main() {
  Future<void> mount(
    WidgetTester tester,
    Future<void> Function() action,
  ) async {
    store = KosteoStore();
    addTearDown(store.api.dispose);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () => runAction(
                context,
                action,
                successMessage: 'Guardado correctamente',
              ),
              child: const Text('Guardar'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Guardar'));
    await tester.pump();
  }

  Future<void> finish(WidgetTester tester) async {
    await tester.pump(const Duration(seconds: 6));
    await tester.pumpAndSettle();
    expect(store.saving, isFalse);
  }

  testWidgets('Éxito solo después de confirmar la respuesta de la API', (
    tester,
  ) async {
    final completion = Completer<http.Response>();
    final api = ApiClient(client: MockClient((r) => completion.future));
    addTearDown(api.dispose);
    await mount(tester, () async {
      await api.request('POST', '/compras', body: {});
    });
    expect(find.text('Guardado correctamente'), findsNothing);
    completion.complete(http.Response('{"compraId":1}', 201));
    await tester.pumpAndSettle();
    expect(find.text('Guardado correctamente'), findsOneWidget);
    expect(find.byIcon(KIcons.checkCircleStrong), findsOneWidget);
    await finish(tester);
  });

  testWidgets('Mensaje de error SQL se muestra rojo y nunca como éxito', (
    tester,
  ) async {
    final api = ApiClient(
      client: MockClient(
        (r) async => http.Response(
          jsonEncode({
            'message': 'El inventario cambió. Actualiza antes de guardar.',
            'code': 51022,
          }),
          409,
        ),
      ),
    );
    addTearDown(api.dispose);
    await mount(tester, () async {
      await api.request('PUT', '/jornadas/1/conteo', body: {});
    });
    await tester.pumpAndSettle();
    expect(find.textContaining('El inventario cambió'), findsOneWidget);
    expect(find.text('Guardado correctamente'), findsNothing);
    expect(
      tester.widget<Icon>(find.byIcon(KIcons.alert)).color,
      KColors.danger,
    );
    await finish(tester);
  });

  testWidgets(
    'Guardado con actualización pendiente informa sin invitar a duplicar',
    (tester) async {
      await mount(tester, () async {
        store.error = 'Guardado. No se pudo actualizar la vista.';
      });
      await tester.pumpAndSettle();
      expect(
        find.text('Guardado. No se pudo actualizar la vista.'),
        findsOneWidget,
      );
      expect(find.text('Guardado correctamente'), findsNothing);
    expect(tester.widget<Icon>(find.byIcon(KIcons.alert)).color, KColors.coral);
      await finish(tester);
    },
  );

  testWidgets('Excepción inesperada no filtra detalles técnicos', (
    tester,
  ) async {
    await mount(tester, () async {
      throw StateError('detalle interno privado');
    });
    await tester.pumpAndSettle();
    expect(find.textContaining('No se pudo completar'), findsOneWidget);
    expect(find.textContaining('detalle interno privado'), findsNothing);
    await finish(tester);
  });

  test('Errores de validación mantienen mensaje y estado HTTP', () async {
    final api = ApiClient(
      client: MockClient(
        (r) async => http.Response(
          jsonEncode({
            'message': ['Revisa el precio.', 'Selecciona una presentación.'],
          }),
          400,
        ),
      ),
    );
    try {
      await expectLater(
        api.request('POST', '/platillos'),
        throwsA(
          isA<ApiException>()
              .having((e) => e.status, 'estado', 400)
              .having(
                (e) => e.message,
                'mensaje',
                'Revisa el precio.. Selecciona una presentación.',
              ),
        ),
      );
    } finally {
      api.dispose();
    }
  });

  test(
    'Error HTML de Render conserva HTTP y no expone HTML ni simula desconexión',
    () async {
      final api = ApiClient(
        client: MockClient(
          (r) async => http.Response('<html>Bad Gateway</html>', 502),
        ),
      );
      try {
        await expectLater(
          api.get('/dashboard'),
          throwsA(
            isA<ApiException>()
                .having((e) => e.status, 'estado', 502)
                .having(
                  (e) => e.message,
                  'mensaje',
                  contains('El servidor no pudo completar'),
                ),
          ),
        );
      } finally {
        api.dispose();
      }
    },
  );
}
