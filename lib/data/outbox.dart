import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';

import 'api_client.dart';

class PendingSend {
  PendingSend(
    this.id,
    this.label,
    this.method,
    this.path,
    this.body, {
    this.error,
  });
  final String id, label, method, path;
  final Map<String, dynamic> body;
  String? error;
  bool sending = false;
  bool ready = false;
  Map<String, dynamic> toJson() => {
    'id': id,
    'label': label,
    'method': method,
    'path': path,
    'body': body,
    'error': error,
  };
  factory PendingSend.fromJson(Map<String, dynamic> j) => PendingSend(
    j['id'],
    j['label'],
    j['method'],
    j['path'],
    Map<String, dynamic>.from(j['body']),
    error: j['error'],
  );
}

/// Envíos persistidos antes de liberar el formulario. Un escritor por cola.
class Outbox extends ChangeNotifier {
  Outbox(this.api, {Future<void> Function(String)? persist, this.onSaved})
    : persist = persist ?? ((_) async {});
  final ApiClient api;
  final Future<void> Function(String) persist;
  final void Function(PendingSend)? onSaved;
  final List<PendingSend> items = [];
  Future<void>? _writes;
  Future<void>? _activeDrain;
  String? lastSaved;
  int completed = 0;
  void restore(String? data) {
    if (data != null && data.isNotEmpty) {
      items.addAll(
        (jsonDecode(data) as List).map(
          (j) =>
              PendingSend.fromJson(Map<String, dynamic>.from(j))..ready = true,
        ),
      );
    }
    notifyListeners();
    unawaited(drain());
  }

  Future<void> _save() {
    final snapshot = jsonEncode(items.map((i) => i.toJson()).toList());
    final previous = _writes;
    final next = previous == null
        ? persist(snapshot)
        : previous.then((_) => persist(snapshot));
    _writes = next.catchError((_) {});
    return next;
  }

  Future<void> enqueue(
    String label,
    String method,
    String path,
    Map<String, dynamic> body,
  ) async {
    final item = PendingSend(
      operationKey(),
      label,
      method,
      path,
      Map<String, dynamic>.from(jsonDecode(jsonEncode(body))),
    );
    items.add(item);
    try {
      await _save();
    } catch (_) {
      items.remove(item);
      throw ApiException(
        'No se pudo conservar la captura en el dispositivo. Intenta guardar otra vez.',
      );
    }
    item.ready = true;
    notifyListeners();
    unawaited(drain());
  }

  Future<void> retry(PendingSend item) async {
    if (item.sending) return;
    item.error = null;
    await _save();
    notifyListeners();
    unawaited(drain());
  }

  Future<void> drain() {
    if (_activeDrain != null) return _activeDrain!;
    final next = _runDrain();
    _activeDrain = next;
    unawaited(
      next.then(
        (_) {
          _activeDrain = null;
          if (items.any((i) => i.ready && i.error == null)) {
            unawaited(drain());
          }
        },
        onError: (Object _, StackTrace _) {
          _activeDrain = null;
        },
      ),
    );
    return next;
  }

  Future<void> _runDrain() async {
    try {
      while (true) {
        final pending = items
            .where((i) => i.ready && i.error == null)
            .firstOrNull;
        if (pending == null) break;
        pending.sending = true;
        notifyListeners();
        try {
          await api.request(pending.method, pending.path, body: pending.body);
          items.remove(pending);
          try {
            await _save();
          } catch (e) {
            items.add(pending);
            rethrow;
          }
          lastSaved = pending.label;
          completed++;
          onSaved?.call(pending);
        } catch (e) {
          pending.error = e.toString();
          try {
            await _save();
          } catch (_) {
            /* Conserva la copia anterior; reintento idempotente. */
          }
        } finally {
          pending.sending = false;
          notifyListeners();
        }
      }
    } finally {
      // Una segunda llamada a drain espera a este mismo trabajo.
    }
  }
}
