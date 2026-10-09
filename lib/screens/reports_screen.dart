import 'package:flutter/material.dart';

import '../data/app_store.dart';
import '../theme/icons.dart';
import '../theme/tokens.dart';
import '../widgets/basics.dart';
import '../widgets/chips.dart';
import '../widgets/glass_sheet.dart';
import 'common.dart';

class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key});

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
  String _period = 'SEMANA';
  int? _jornadaId;
  List<dynamic> _jornadas = [];
  Map<String, dynamic>? _summary;
  String? _error;
  bool _loading = true;
  int _request = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final request = ++_request;
    final period = _period;
    final selected = _jornadaId;
    setState(() {
      _loading = true;
      _error = null;
      _summary = null;
    });
    try {
      final jornadas = await store.api.get('/jornadas') as List;
      jornadas.sort(
        (a, b) =>
            (b['fechaInicio'] as String).compareTo(a['fechaInicio'] as String),
      );
      final id =
          selected != null && jornadas.any((j) => j['jornadaId'] == selected)
          ? selected
          : jornadas
                        .where((j) => j['estado'] == 'ABIERTA')
                        .firstOrNull?['jornadaId']
                    as int? ??
                jornadas.firstOrNull?['jornadaId'] as int?;
      final result = period == 'JORNADA' && id != null
          ? await store.api.get('/jornadas/$id/resumen')
          : period == 'JORNADA'
          ? null
          : await store.api.get('/dashboard', {'periodo': period});
      if (!mounted || request != _request) return;
      setState(() {
        _jornadas = jornadas;
        _jornadaId = id;
        _summary = result == null ? null : Map<String, dynamic>.from(result);
        _loading = false;
      });
    } catch (e) {
      if (!mounted || request != _request) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  Future<void> _pickJornada() async {
    final selected = await showGlassSheet<int>(
      context,
      builder: (context) => SheetBody(
        title: 'Elegir jornada',
        child: Column(
          children: [
            for (final j in _jornadas)
              Padding(
                padding: const EdgeInsets.only(bottom: KSpace.s),
                child: KosteoCard(
                  padding: const EdgeInsets.all(KSpace.l),
                  onTap: () => Navigator.of(context).pop(j['jornadaId'] as int),
                  child: Row(
                    children: [
                      Icon(
                        KIcons.jornada,
                        color: j['jornadaId'] == _jornadaId
                            ? KColors.sea
                            : KColors.inkSoft,
                      ),
                      const SizedBox(width: KSpace.m),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(_range(j), style: KText.bodyStrong),
                            Text(
                              j['estado'] == 'ABIERTA' ? 'Abierta' : 'Cerrada',
                              style: KText.caption,
                            ),
                          ],
                        ),
                      ),
                      if (j['jornadaId'] == _jornadaId)
                        const Icon(KIcons.checkStrong, color: KColors.sea),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
    if (selected == null || !mounted) return;
    setState(() => _jornadaId = selected);
    await _load();
  }

  String _date(dynamic value) {
    if (value == null) return '';
    final d = DateTime.parse(value as String);
    return '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
  }

  String _range(Map<dynamic, dynamic> data) {
    final start = _date(data['fechaInicio']);
    final end = _date(data['fechaFin']);
    return start == end ? start : '$start · $end';
  }

  @override
  Widget build(BuildContext context) => KScaffold(
    body: Column(
      children: [
        const PageHeader(
          title: 'Reportes',
          subtitle: 'Cómo va tu negocio',
          back: true,
        ),
        Expanded(
          child: RefreshIndicator(
            color: KColors.sea,
            onRefresh: _load,
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: EdgeInsets.fromLTRB(
                context.gutter,
                0,
                context.gutter,
                KSpace.xxl + MediaQuery.paddingOf(context).bottom,
              ),
              children: [
                ContentWidth(
                maxWidth: 760,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      SegmentedPill<String>(
                        values: const ['HOY', 'SEMANA', 'JORNADA'],
                        selected: _period,
                        labelOf: (p) => const {
                          'HOY': 'Hoy',
                          'SEMANA': 'Semana',
                          'JORNADA': 'Jornadas',
                        }[p]!,
                        onChanged: (p) {
                          setState(() => _period = p);
                          _load();
                        },
                      ),
                      const SizedBox(height: KSpace.l),
                      if (_loading)
                        const Padding(
                          padding: EdgeInsets.all(KSpace.xxl),
                          child: Center(
                            child: CircularProgressIndicator(
                              color: KColors.sea,
                            ),
                          ),
                        )
                      else if (_error != null)
                        EmptyState(
                          icon: KIcons.alert,
                          title: 'No pudimos cargar el reporte',
                          message: _error!,
                          action: SoftButton(
                            label: 'Reintentar',
                            expand: false,
                            onTap: _load,
                          ),
                        )
                      else if (_summary == null)
                        const EmptyState(
                          icon: KIcons.jornada,
                          title: 'Aún no hay jornadas',
                          message: 'Abre tu primera jornada desde el inicio. Aquí podrás consultar sus resultados.',
                        )
                      else ...[
                        if (_period == 'JORNADA') ...[
                          SoftButton(
                            label: _range(_summary!),
                            icon: KIcons.calendarBlank,
                            onTap: _pickJornada,
                          ),
                          const SizedBox(height: KSpace.l),
                        ] else ...[
                          Text(
                            _range(_summary!),
                            style: KText.caption,
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: KSpace.l),
                        ],
                        _totals(),
                        const SizedBox(height: KSpace.l),
                        _financials(),
                        const SizedBox(height: KSpace.l),
                        _sellers(),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    ),
  );

  Widget _totals() {
    final s = _summary!;
    final provisional = s['estadoGanancia'] == 'PROVISIONAL';
    final states = (s['estados'] as List? ?? []).cast<Map>();
    int count(String state) => states
        .where((s) => s['estado'] == state)
        .fold(0, (v, s) => v + (s['cantidad'] as num).toInt());
    final variation = s['variacionVentas'] as num?;
    return KosteoCard(
      color: KColors.sea.withValues(alpha: 0.06),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Ventas', style: KText.bodyStrong),
          const SizedBox(height: KSpace.s),
          Text(
            money(s['ventas'] as num?),
            style: KText.display.copyWith(color: KColors.sea),
          ),
          const SizedBox(height: KSpace.s),
          Text(
            '${count('ENTREGADO')} pedidos entregados · ${count('CANCELADO')} cancelados',
            style: KText.caption,
          ),
          if (variation != null) ...[
            const SizedBox(height: KSpace.m),
            Text(
              '${variation >= 0 ? '+' : ''}${variation.toStringAsFixed(1)}% vs. ${_period == 'HOY'
                  ? 'ayer'
                  : _period == 'SEMANA'
                  ? 'semana anterior'
                  : 'jornada anterior'}',
              style: KText.caption,
            ),
          ],
          const Padding(
            padding: EdgeInsets.symmetric(vertical: KSpace.l),
            child: Divider(height: 1, color: KColors.line),
          ),
          _amount(
            'Ganancia estimada',
            s['gananciaEstimada'] as num?,
            color: KColors.success,
          ),
          if (provisional) ...[
            const SizedBox(height: KSpace.s),
            Text(
              'Provisional · faltan datos para completar el costo.',
              style: KText.caption.copyWith(color: KColors.coral),
            ),
          ],
        ],
      ),
    );
  }

  Widget _amount(String label, num? value, {Color color = KColors.ink}) =>
      Padding(
        padding: const EdgeInsets.symmetric(vertical: KSpace.s),
        child: Row(
          children: [
            Expanded(child: Text(label, style: KText.body)),
            const SizedBox(width: KSpace.m),
            Flexible(
              fit: FlexFit.tight,
              child: Text(
                money(value),
                style: KText.number.copyWith(color: color),
                textAlign: TextAlign.right,
              ),
            ),
          ],
        ),
      );

  Widget _financials() {
    final s = _summary!;
    return KosteoCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Inversión y consumo', style: KText.title),
          const SizedBox(height: KSpace.m),
          _amount('Compras', s['inversion'] as num?),
          _amount('Costo consumido', s['costoConsumido'] as num?),
          if (s['costoConsumido'] == null && s['subtotalCostoConocido'] != null)
            _amount(
              'Subtotal conocido',
              s['subtotalCostoConocido'] as num?,
              color: KColors.inkSoft,
            ),
          _amount('Gasolina de reparto', s['gasolina'] as num?),
          _amount('Inventario sobrante', s['inventarioSobrante'] as num?),
          const SizedBox(height: KSpace.m),
          Text(
            'Las compras son inversión. El sobrante no se cuenta como pérdida.',
            style: KText.caption,
          ),
        ],
      ),
    );
  }

  Widget _sellers() {
    final sellers = _summary!['topSellers'] as List? ?? [];
    final max = sellers.isEmpty
        ? 1
        : (sellers.first['cantidad'] as num).clamp(1, double.infinity);
    return KosteoCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Más vendidos', style: KText.title),
          const SizedBox(height: KSpace.s),
          Text('Productos de pedidos entregados', style: KText.caption),
          if (sellers.isEmpty)
            Padding(
              padding: const EdgeInsets.only(top: KSpace.l),
              child: Text(
                'Todavía no hay ventas en este periodo.',
                style: KText.body,
              ),
            )
          else
            for (final s in sellers)
              Padding(
                padding: const EdgeInsets.only(top: KSpace.l),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            s['nombrePlatillo'] as String,
                            style: KText.bodyStrong,
                          ),
                        ),
                        const SizedBox(width: KSpace.m),
                        Text('${s['cantidad']} vendidos', style: KText.caption),
                      ],
                    ),
                    const SizedBox(height: KSpace.s),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(KRadius.chip),
                      child: LinearProgressIndicator(
                        value: ((s['cantidad'] as num) / max)
                            .clamp(0, 1)
                            .toDouble(),
                        minHeight: 6,
                        color: KColors.sea,
                        backgroundColor: KColors.mist,
                      ),
                    ),
                  ],
                ),
              ),
        ],
      ),
    );
  }
}
