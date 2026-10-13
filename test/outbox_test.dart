import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:kosteo/data/api_client.dart';
import 'package:kosteo/data/outbox.dart';
import 'package:kosteo/data/app_store.dart';
import 'package:kosteo/widgets/api_activity.dart';
import 'package:kosteo/data/outbox_file.dart';

void main() {
  test(
    'Archivo real conserva envíos entre aperturas y reemplaza el diario',
    () async {
      final dir = await Directory.systemTemp.createTemp('kosteo-outbox-test-');
      addTearDown(() async {
        expect(
          dir.absolute.path.startsWith(
            '${Directory.systemTemp.absolute.path}${Platform.pathSeparator}',
          ),
          isTrue,
        );
        await dir.delete(recursive: true);
      });
      final response = Completer<http.Response>();
      final api = ApiClient(
        baseUrl: 'https://example.test',
        client: MockClient((_) => response.future),
      );
      final first = await openOutbox(api, (_) {}, directory: dir);
      final key = operationKey();
      await first.enqueue('Compra', 'POST', '/compras', {
        'claveOperacion': key,
      });
      final second = await openOutbox(
        ApiClient(
          baseUrl: api.baseUrl,
          client: MockClient((r) async {
            expect(jsonDecode(r.body)['claveOperacion'], key);
            return http.Response('{}', 200);
          }),
        ),
        (_) {},
        directory: dir,
      );
      await second.drain();
      response.complete(http.Response('{}', 200));
      await first.drain();
      final files = await dir
          .list()
          .where((f) => f.path.endsWith('.json'))
          .toList();
      expect(jsonDecode(await File(files.single.path).readAsString()), isEmpty);
    },
  );
  test(
    'Captura persistida no espera al servidor y recupera la misma clave',
    () async {
      final response = Completer<http.Response>();
      String? stored;
      final key = operationKey();
      final api = ApiClient(client: MockClient((r) => response.future));
      final box = Outbox(api, persist: (s) async => stored = s);
      final body = {'claveOperacion': key, 'cantidadCompra': 1.5};
      await box.enqueue('Compra', 'POST', '/compras', body);
      body['cantidadCompra'] = 99;
      expect(box.items.single.body['cantidadCompra'], 1.5);
      expect(jsonDecode(stored!)[0]['body']['claveOperacion'], key);
      expect(box.items.single.sending, isTrue);
      response.complete(http.Response('{}', 200));
      await Future<void>.delayed(Duration.zero);
      expect(box.items, isEmpty);
      expect(jsonDecode(stored!), isEmpty);
      final sent = <String>[];
      final restored = Outbox(
        ApiClient(
          client: MockClient((r) async {
            sent.add(jsonDecode(r.body)['claveOperacion']);
            return http.Response('{}', 200);
          }),
        ),
      );
      restored.restore(
        jsonEncode([
          {
            'id': 'restored',
            'label': 'Compra',
            'method': 'POST',
            'path': '/compras',
            'body': {'claveOperacion': key},
          },
        ]),
      );
      await Future<void>.delayed(Duration.zero);
      expect(sent, [key]);
      expect(restored.items, isEmpty);
    },
  );
  test(
    'Error conserva captura, otras capturas siguen y reintento no cambia clave',
    () async {
      final attempts = <String>[];
      bool fail = true;
      final box = Outbox(
        ApiClient(
          client: MockClient((r) async {
            final key = jsonDecode(r.body)['claveOperacion'] as String;
            attempts.add(key);
            return http.Response(
              fail ? '{"message":"Sin conexión"}' : '{}',
              fail ? 503 : 200,
            );
          }),
        ),
      );
      final key = operationKey();
      await box.enqueue('Pedido', 'POST', '/pedidos', {'claveOperacion': key});
      await Future<void>.delayed(Duration.zero);
      expect(box.items.single.error, contains('Sin conexión'));
      fail = false;
      await box.enqueue('Otra compra', 'POST', '/compras', {
        'claveOperacion': operationKey(),
      });
      await Future<void>.delayed(Duration.zero);
      expect(box.items.length, 1);
      await box.retry(box.items.single);
      await Future<void>.delayed(Duration.zero);
      expect(attempts.first, key);
      expect(attempts.last, key);
      expect(box.items, isEmpty);
    },
  );
  test(
    'Si falla conservar localmente no se envía ni se libera la captura',
    () async {
      var requests = 0;
      final box = Outbox(
        ApiClient(
          client: MockClient((_) async {
            requests++;
            return http.Response('{}', 200);
          }),
        ),
        persist: (_) async => throw Exception('Disco'),
      );
      await expectLater(
        box.enqueue('Pedido', 'POST', '/pedidos', {}),
        throwsA(isA<ApiException>()),
      );
      expect(requests, 0);
      expect(box.items, isEmpty);
    },
  );
  testWidgets('Petición pendiente permite seguir interactuando', (
    tester,
  ) async {
    final previous = store;
    store = KosteoStore()..loaded = true;
    addTearDown(() => store = previous);
    var taps = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: ApiActivity(
          child: Scaffold(
            body: TextButton(
              onPressed: () => taps++,
              child: const Text('Capturar otra'),
            ),
          ),
        ),
      ),
    );
    ApiClient.pending.value++;
    await tester.pump(const Duration(seconds: 1));
    await tester.tap(find.text('Capturar otra'));
    expect(taps, 1);
    ApiClient.pending.value--;
    await tester.pump();
  });
}
