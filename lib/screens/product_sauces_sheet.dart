import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../data/app_store.dart';
import '../theme/tokens.dart';
import '../widgets/basics.dart';
import '../widgets/chips.dart';
import '../widgets/glass_sheet.dart';
import '../widgets/inputs.dart';
import '../widgets/toast.dart';

Future<void> showSauceCatalog(BuildContext context) =>
    showGlassSheet<void>(context, builder: (_) => const _Sauces());

Future<List<Map<String, dynamic>>?> showProductSauces(
  BuildContext context,
  List<Map<String, dynamic>> options,
) => showGlassSheet<List<Map<String, dynamic>>>(
  context,
  builder: (_) => _Sauces(options: options),
);

class _Sauces extends StatefulWidget {
  const _Sauces({this.options});
  final List<Map<String, dynamic>>? options;
  @override
  State<_Sauces> createState() => _SaucesState();
}

class _SaucesState extends State<_Sauces> {
  final _search = TextEditingController();
  final _selected = <int>{};
  List<Map<String, dynamic>> _catalog = [];
  bool _loading = true, _saving = false;
  String? _error;
  bool get _assigning => widget.options != null;

  String get _name => _search.text
      .trim()
      .replaceFirst(RegExp(r'^salsa\s+', caseSensitive: false), '')
      .trim();
  bool get _canAdd =>
      _name.isNotEmpty &&
      _name.toLowerCase() != 'salsa' &&
      !_catalog.any(
        (s) => (s['nombre'] as String).toLowerCase() == _name.toLowerCase(),
      );

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final catalog = await store.getSauces();
      if (!mounted) return;
      setState(() {
        _catalog = catalog;
        for (final s in catalog) {
          if (widget.options?.any(
                (o) =>
                    o['salsaId'] == s['salsaId'] ||
                    (o['nombre'] as String).toLowerCase() ==
                        'salsa ${s['nombre']}'.toLowerCase(),
              ) ??
              false) {
            _selected.add(s['salsaId'] as int);
          }
        }
      });
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _create() async {
    if (!_canAdd || _saving) return;
    final name = _name;
    setState(() => _saving = true);
    try {
      final sauce = await store.createSauce(name);
      if (!mounted) return;
      setState(() {
        _catalog.removeWhere((s) => s['salsaId'] == sauce['salsaId']);
        _catalog.add(sauce);
        _catalog.sort(
          (a, b) => (a['nombre'] as String).compareTo(b['nombre'] as String),
        );
        if (_assigning) _selected.add(sauce['salsaId'] as int);
        _search.clear();
      });
      showToast(context, 'Salsa creada');
    } catch (e) {
      if (mounted) showErrorToast(context, e.toString());
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final query = _name.toLowerCase();
    return SheetBody(
      title: _assigning ? 'Salsas del producto' : 'Salsas',
      subtitle: _assigning
          ? 'Elige las disponibles. La selección se guarda con el producto.'
          : 'Crea una vez y reutiliza en cualquier producto.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (_loading)
            const Padding(
              padding: EdgeInsets.all(KSpace.m),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (_error != null) ...[
            Text(_error!, style: KText.caption),
            SoftButton(label: 'Reintentar', onTap: _load),
          ] else ...[
            KTextField(
              controller: _search,
              hint: 'Buscar o escribir una salsa nueva',
              inputFormatters: [LengthLimitingTextInputFormatter(54)],
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: KSpace.m),
            for (final sauce in _catalog.where(
              (s) => (s['nombre'] as String).toLowerCase().contains(query),
            ))
              Padding(
                padding: const EdgeInsets.only(bottom: KSpace.s),
                child: _assigning
                    ? ChoiceTile(
                        label: sauce['nombre'] as String,
                        selected: _selected.contains(sauce['salsaId']),
                        onTap: () => setState(() {
                          final id = sauce['salsaId'] as int;
                          if (!_selected.add(id)) _selected.remove(id);
                        }),
                      )
                    : Text(sauce['nombre'] as String, style: KText.body),
              ),
            if (_catalog.isEmpty)
              Text('Todavía no hay salsas.', style: KText.caption),
            if (_canAdd)
              SoftButton(
                label: _saving ? 'Guardando salsa...' : 'Agregar salsa',
                onTap: _saving ? null : _create,
              ),
          ],
          const SizedBox(height: KSpace.m),
          PrimaryButton(
            label: 'Listo',
            onTap: _loading || _saving || _error != null
                ? null
                : () {
                    if (!_assigning) {
                      Navigator.of(context).pop();
                      return;
                    }
                    Navigator.of(context).pop([
                      for (final s in _catalog.where(
                        (s) => _selected.contains(s['salsaId']),
                      ))
                        {
                          ...?widget.options
                              ?.where(
                                (o) =>
                                    o['salsaId'] == s['salsaId'] ||
                                    (o['nombre'] as String).toLowerCase() ==
                                        'salsa ${s['nombre']}'.toLowerCase(),
                              )
                              .firstOrNull,
                          'tipo': 'EXTRA',
                          'nombre': 'Salsa ${s['nombre']}',
                          'precioAdicional': 0,
                          'salsaId': s['salsaId'],
                        },
                    ]);
                  },
          ),
        ],
      ),
    );
  }
}
