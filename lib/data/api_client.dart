import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:http/http.dart' as http;

class ApiException implements Exception {
  ApiException(this.message, [this.status]);
  final String message;
  final int? status;
  @override
  String toString() => message;
}

String operationKey() {
  final r = Random.secure();
  final b = List.generate(16, (_) => r.nextInt(256));
  b[6] = (b[6] & 15) | 64;
  b[8] = (b[8] & 63) | 128;
  final h = b.map((n) => n.toRadixString(16).padLeft(2, '0')).join();
  return '${h.substring(0, 8)}-${h.substring(8, 12)}-${h.substring(12, 16)}-${h.substring(16, 20)}-${h.substring(20)}';
}

class ApiClient {
  ApiClient({http.Client? client, String? baseUrl})
    : client = client ?? http.Client(),
      baseUrl =
          baseUrl ??
          const String.fromEnvironment(
            'API_BASE_URL',
            defaultValue: 'http://127.0.0.1:3000',
          );
  final http.Client client;
  final String baseUrl;
  final Map<String, String> _pendingKeys = {};
  Future<dynamic> request(
    String method,
    String path, {
    Map<String, dynamic>? body,
    Map<String, dynamic>? query,
  }) async {
    String? fingerprint;
    if (body?.containsKey('claveOperacion') == true) {
      final stable = {...body!}..remove('claveOperacion');
      fingerprint = '$method $path ${jsonEncode(stable)}';
      body = {
        ...body,
        'claveOperacion': _pendingKeys.putIfAbsent(
          fingerprint,
          () => body!['claveOperacion'] as String,
        ),
      };
    }
    final uri = Uri.parse('$baseUrl$path').replace(
      queryParameters: query == null
          ? null
          : {
              for (final e in query.entries)
                if (e.value != null) e.key: '${e.value}',
            },
    );
    final req = http.Request(method, uri)
      ..headers['Content-Type'] = 'application/json';
    if (body != null) req.body = jsonEncode(body);
    try {
      final response = await (() async => http.Response.fromStream(
        await client.send(req),
      ))().timeout(const Duration(seconds: 30));
      final data = response.body.isEmpty ? null : jsonDecode(response.body);
      if (response.statusCode >= 400) {
        if (fingerprint != null && response.statusCode < 500) {
          _pendingKeys.remove(fingerprint);
        }
        final message = data is Map ? data['message'] : null;
        throw ApiException(
          message is List
              ? message.join('. ')
              : (message?.toString() ?? 'No se pudo guardar.'),
          response.statusCode,
        );
      }
      if (fingerprint != null) _pendingKeys.remove(fingerprint);
      return data;
    } on ApiException {
      rethrow;
    } catch (_) {
      throw ApiException('No se pudo conectar. Reintenta la operación.');
    }
  }

  Future<dynamic> get(String path, [Map<String, dynamic>? query]) =>
      request('GET', path, query: query);
  void dispose() => client.close();
}
