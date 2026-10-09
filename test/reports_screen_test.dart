import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:kosteo/data/api_client.dart';
import 'package:kosteo/data/app_store.dart';
import 'package:kosteo/screens/reports_screen.dart';
import 'package:kosteo/theme/tokens.dart';

const jornadas = [
  {
    'jornadaId': 1,
    'fechaInicio': '2026-10-03',
    'fechaFin': '2026-10-04',
    'estado': 'CERRADA',
  },
  {
    'jornadaId': 2,
    'fechaInicio': '2026-10-10',
    'fechaFin': '2026-10-11',
    'estado': 'ABIERTA',
  },
];

Map<String, dynamic> resumen({bool pending = false}) => {
  'fechaInicio': '2026-10-05',
  'fechaFin': '2026-10-11',
  'ventas': 6340.50,
  'gananciaEstimada': pending ? null : 3690.50,
  'inversion': 3100.25,
  'costoConsumido': pending ? null : 2420,
  'subtotalCostoConocido': 1500.25,
  'gasolina': 230,
  'inventarioSobrante': pending ? null : 680.25,
  'estadoGanancia': pending ? 'PROVISIONAL' : 'COMPLETO',
  'variacionVentas': 12.5,
  'estados': [
    {'estado': 'ENTREGADO', 'cantidad': 12},
    {'estado': 'CANCELADO', 'cantidad': 2},
  ],
  'topSellers': [
    {'platilloId': 1, 'nombrePlatillo': 'Aguachile Verde', 'cantidad': 14},
  ],
};

void main() {
  setUpAll(() async {
    final font = FontLoader(kFont);
    for (final weight in ['500', '700']) {
      font.addFont(
        File('assets/fonts/PlusJakartaSans-$weight.ttf')
            .readAsBytes()
            .then((b) => ByteData.view(b.buffer)),
      );
    }
    await font.load();
    final configFile = File('.dart_tool/package_config.json').absolute;
    final config = jsonDecode(await configFile.readAsString()) as Map;
    final lucide = (config['packages'] as List).firstWhere(
      (p) => p['name'] == 'lucide_icons_flutter',
    );
    final root = configFile.uri.resolve('${lucide['rootUri']}/');
    for (final weight in ['300', '600']) {
      final loader = FontLoader('packages/lucide_icons_flutter/Lucide$weight');
      loader.addFont(
        File.fromUri(
          root.resolve('assets/build_font/LucideVariable-w$weight.ttf'),
        ).readAsBytes().then((b) => ByteData.view(b.buffer)),
      );
      await loader.load();
    }
  });

  Future<void> mount(
    WidgetTester tester,
    Size size,
    Future<http.Response> Function(http.Request) handler,
  ) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final api = ApiClient(client: MockClient(handler));
    store = KosteoStore(client: api);
    addTearDown(api.dispose);
    await tester.pumpWidget(
      MaterialApp(theme: buildKosteoTheme(), home: const ReportsScreen()),
    );
    await tester.pumpAndSettle();
  }

  http.Response json(dynamic value, [int status = 200]) => http.Response(
    jsonEncode(value),
    status,
    headers: {'content-type': 'application/json; charset=utf-8'},
  );

  for (final size in {
    'phone': const Size(390, 844),
    'tablet': const Size(1194, 900),
  }.entries) {
    testWidgets(
      'Reporte real, selector histórico sin cambiar jornada operativa · ${size.key}',
      (tester) async {
        final requested = <String>[];
        await mount(tester, size.value, (request) async {
          requested.add(request.url.toString());
          if (request.url.path == '/jornadas') return json(jornadas);
          return json({
            ...resumen(),
            if (request.url.path.contains('/1/')) 'ventas': 123.45,
          });
        });
        expect(find.text(money(6340.50)), findsOneWidget);
        expect(find.textContaining('+12.5%'), findsOneWidget);
        expect(tester.takeException(), isNull);
        await expectLater(
          find.byType(ReportsScreen),
          matchesGoldenFile('goldens/reports_${size.key}.png'),
        );
        await tester.tap(find.text('Jornadas'));
        await tester.pumpAndSettle();
        expect(requested.any((p) => p.endsWith('/jornadas/2/resumen')), isTrue);
        await tester.tap(find.text('05/10/2026 · 11/10/2026'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('03/10/2026 · 04/10/2026'));
        await tester.pumpAndSettle();
        expect(requested.any((p) => p.endsWith('/jornadas/1/resumen')), isTrue);
        expect(find.text(money(123.45)), findsOneWidget);
        expect(store.selectedJornadaId, isNull);
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets('Costos pendientes no se convierten en cero', (tester) async {
    await mount(
      tester,
      const Size(360, 640),
      (r) async =>
          json(r.url.path == '/jornadas' ? jornadas : resumen(pending: true)),
    );
    expect(find.textContaining('Provisional'), findsOneWidget);
    expect(find.text('Pendiente'), findsWidgets);
    expect(find.text(money(0)), findsNothing);
    await tester.scrollUntilVisible(find.text('Inventario sobrante'), 180);
    expect(find.text('Subtotal conocido'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Error permite reintentar y jornada vacía no inventa datos', (
    tester,
  ) async {
    bool failed = true;
    await mount(tester, const Size(390, 844), (r) async {
      if (failed) return json({'message': 'No se pudo conectar'}, 503);
      return json(
        r.url.path == '/jornadas' ? [] : {...resumen(), 'topSellers': []},
      );
    });
    expect(find.text('No pudimos cargar el reporte'), findsOneWidget);
    failed = false;
    await tester.tap(find.text('Reintentar'));
    await tester.pumpAndSettle();
    expect(find.text(money(6340.50)), findsOneWidget);
    await tester.tap(find.text('Jornadas'));
    await tester.pumpAndSettle();
    expect(find.text('Aún no hay jornadas'), findsOneWidget);
  });
}
