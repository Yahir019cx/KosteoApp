import 'package:flutter/material.dart';

import '../theme/icons.dart';

import '../data/app_store.dart';
import '../theme/tokens.dart';
import '../widgets/basics.dart';
import '../widgets/chips.dart';
import '../widgets/metric_donut.dart';
import '../widgets/motion.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({
    super.key,
    required this.onOpenOrders,
    required this.onOpenShift,
    required this.onOpenMore,
  });
  final ValueChanged<OrderStatus> onOpenOrders;
  final VoidCallback onOpenShift;

  /// Opciones secundarias (insumos, menú, inventario...) desde el avatar.
  final VoidCallback onOpenMore;

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  Period _period = Period.today;
  int? _selected;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: store,
      builder: (context, _) {
        final g = context.gutter;
        final donut = _DonutCard(
          metrics: store.metrics[_period]!,
          period: _period,
          selected: _selected,
          onSelect: (i) =>
              setState(() => _selected = _selected == i ? null : i),
        );
        final orders = _OrdersSummary(onOpen: widget.onOpenOrders);
        const sellers = _TopSellers();

        return ListView(
          padding: EdgeInsets.fromLTRB(g, KSpace.l, g, KSpace.navClearance),
          children: [
            ContentWidth(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  FadeSlideIn(child: _Greeting(onSettings: widget.onOpenMore)),
                  const SizedBox(height: KSpace.l),
                  FadeSlideIn(
                    index: 1,
                    child: Row(
                      children: [
                        _ShiftBadge(onTap: widget.onOpenShift),
                        const Spacer(),
                        if (context.isTablet)
                          SizedBox(width: 320, child: _periodSelector()),
                      ],
                    ),
                  ),
                  if (!context.isTablet) ...[
                    const SizedBox(height: KSpace.l),
                    FadeSlideIn(index: 1, child: _periodSelector()),
                  ],
                  const SizedBox(height: KSpace.xl),
                  if (context.isTablet)
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          flex: 6,
                          child: FadeSlideIn(index: 2, child: donut),
                        ),
                        const SizedBox(width: KSpace.xl),
                        Expanded(
                          flex: 4,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              FadeSlideIn(index: 3, child: orders),
                              const SizedBox(height: KSpace.xl),
                              const FadeSlideIn(index: 4, child: sellers),
                            ],
                          ),
                        ),
                      ],
                    )
                  else ...[
                    FadeSlideIn(index: 2, child: donut),
                    const SizedBox(height: KSpace.xl),
                    FadeSlideIn(index: 3, child: orders),
                    const SizedBox(height: KSpace.xxl),
                    const FadeSlideIn(index: 4, child: sellers),
                  ],
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _periodSelector() => SegmentedPill<Period>(
    values: Period.values,
    selected: _period,
    labelOf: (p) => p.label,
    onChanged: (p) => setState(() {
      _period = p;
      store.dashboardPeriod = p;
      _selected = null;
    }),
  );
}

class _Greeting extends StatelessWidget {
  const _Greeting({required this.onSettings});
  final VoidCallback onSettings;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(greeting(), style: KText.title.copyWith(fontSize: 26)),
              const SizedBox(height: 2),
              Text(todayLabel(), style: KText.caption.copyWith(fontSize: 14)),
            ],
          ),
        ),
        // Engrane: abre las opciones secundarias (insumos, inventario, jornada...).
        CircleIconButton(
          icon: KIcons.gear,
          size: 48,
          semanticLabel: 'Más opciones',
          onTap: onSettings,
        ),
      ],
    );
  }
}

/// Indicador de jornada activa con punto "respirando". Toca para ver el cierre.
class _ShiftBadge extends StatefulWidget {
  const _ShiftBadge({required this.onTap});
  final VoidCallback onTap;

  @override
  State<_ShiftBadge> createState() => _ShiftBadgeState();
}

class _ShiftBadgeState extends State<_ShiftBadge>
    with SingleTickerProviderStateMixin {
  late final _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1600),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final closed = store.shiftClosed;
    final color = closed ? KColors.inkMuted : KColors.success;
    return Pressable(
      onTap: widget.onTap,
      child: Container(
        height: 36,
        padding: const EdgeInsets.symmetric(horizontal: KSpace.m),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(KRadius.chip),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox.square(
              dimension: 14,
              child: AnimatedBuilder(
                animation: _pulse,
                builder: (_, _) => Stack(
                  alignment: Alignment.center,
                  children: [
                    if (!closed)
                      Container(
                        width: 8 + 6 * _pulse.value,
                        height: 8 + 6 * _pulse.value,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: color.withValues(
                            alpha: 0.3 * (1 - _pulse.value),
                          ),
                        ),
                      ),
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: color,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: KSpace.s),
            Text(
              store.jornada == null
                  ? 'Abrir jornada'
                  : (closed ? 'Jornada cerrada' : 'Jornada activa'),
              style: KText.caption.copyWith(
                color: Color.lerp(color, KColors.ink, 0.3),
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DonutCard extends StatelessWidget {
  const _DonutCard({
    required this.metrics,
    required this.period,
    required this.selected,
    required this.onSelect,
  });

  final Metrics metrics;
  final Period period;
  final int? selected;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) {
    final m = metrics;
    final segments = [
      DonutSegment('Ganancia estimada', m.profit, KColors.sea),
      DonutSegment('Costo de insumos', m.cost, KColors.coral),
      DonutSegment('Gasolina reparto', m.gas, KColors.sun),
    ];
    final sel = selected == null ? null : segments[selected!];

    final center = DonutCenter(
      value: sel == null ? m.sales : sel.value,
      label: sel?.label ?? 'Ventas',
      footer: AnimatedSwitcher(
        duration: KMotion.fast,
        child: sel == null
            ? _Delta(key: ValueKey(period), pct: m.salesDelta, period: period)
            : Text(
                sel.value == null
                    ? 'Provisional'
                    : m.sales == 0
                    ? 'Sin ventas'
                    : '${(sel.value! / m.sales * 100).round()}% de ventas',
                key: ValueKey(sel.label),
                style: KText.caption.copyWith(
                  color: sel.color,
                  fontWeight: FontWeight.w700,
                ),
              ),
      ),
    );

    final legend = Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < segments.length; i++)
          DonutLegendRow(
            segment: segments[i],
            total: m.sales,
            selected: selected == i,
            dimmed: selected != null && selected != i,
            onTap: () => onSelect(i),
          ),
      ],
    );

    return KosteoCard(
      padding: const EdgeInsets.all(KSpace.xl),
      child: LayoutBuilder(
        builder: (context, c) {
          final side = c.maxWidth >= 560;
          final donut = MetricDonut(
            segments: segments,
            selected: selected,
            size: side ? 240 : (c.maxWidth * 0.78).clamp(200, 260),
            center: center,
          );
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Estado del negocio',
                      style: KText.bodyStrong.copyWith(fontSize: 17),
                    ),
                  ),
                  const SizedBox(width: KSpace.s),
                  Text('${m.orderCount} pedidos', style: KText.caption),
                ],
              ),
              const SizedBox(height: KSpace.xl),
              if (side)
                Row(
                  children: [
                    donut,
                    const SizedBox(width: KSpace.xl),
                    Expanded(child: legend),
                  ],
                )
              else ...[
                Center(child: donut),
                const SizedBox(height: KSpace.xl),
                legend,
              ],
            ],
          );
        },
      ),
    );
  }
}

class _Delta extends StatelessWidget {
  const _Delta({super.key, required this.pct, required this.period});
  final num? pct;
  final Period period;

  @override
  Widget build(BuildContext context) {
    final vs = switch (period) {
      Period.today => 'vs ayer',
      Period.week => 'vs semana pasada',
      Period.shift => 'vs jornada anterior',
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: KColors.success.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(KRadius.chip),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(KIcons.trendUpStrong, size: 13, color: KColors.success),
          const SizedBox(width: 4),
          Text(
            pct == null ? 'Sin comparativo' : '$pct% $vs',
            style: KText.caption.copyWith(
              fontSize: 11.5,
              color: KColors.success,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

/// Resumen compacto: una sola card con tres cifras tocables.
class _OrdersSummary extends StatelessWidget {
  const _OrdersSummary({required this.onOpen});
  final ValueChanged<OrderStatus> onOpen;

  @override
  Widget build(BuildContext context) {
    final items = [
      (OrderStatus.pending, 'Pendientes'),
      (OrderStatus.preparing, 'Preparando'),
      (OrderStatus.delivered, 'Entregados'),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SectionTitle(
          'Pedidos de jornada',
          trailing: Text(
            '${store.ordersDeJornada.length} en total',
            style: KText.caption,
          ),
        ),
        KosteoCard(
          padding: const EdgeInsets.symmetric(
            vertical: KSpace.l,
            horizontal: KSpace.s,
          ),
          child: IntrinsicHeight(
            child: Row(
              children: [
                for (var i = 0; i < items.length; i++) ...[
                  if (i > 0) Container(width: 1, color: KColors.line),
                  Expanded(
                    child: Pressable(
                      onTap: () => onOpen(items[i].$1),
                      child: Column(
                        children: [
                          PopSwitcher(
                            child: Text(
                              '${store.countByJornada(items[i].$1)}',
                              key: ValueKey(store.countByJornada(items[i].$1)),
                              style: KText.display.copyWith(
                                fontSize: 28,
                                color: items[i].$1.color,
                              ),
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(items[i].$2, style: KText.caption),
                        ],
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _TopSellers extends StatelessWidget {
  const _TopSellers();

  @override
  Widget build(BuildContext context) {
    final top = store.topSellers;
    final max = top.isEmpty ? 1 : top.first.$2;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SectionTitle('Más vendidos'),
        KosteoCard(
          padding: const EdgeInsets.symmetric(
            horizontal: KSpace.l + 4,
            vertical: KSpace.m,
          ),
          child: Column(
            children: [
              for (var i = 0; i < top.length; i++)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: KSpace.s),
                  child: Row(
                    children: [
                      IconTile(top[i].$1.icon, tint: KColors.sea, size: 44),
                      const SizedBox(width: KSpace.m),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    top[i].$1.name,
                                    style: KText.bodyStrong.copyWith(
                                      fontSize: 14,
                                    ),
                                  ),
                                ),
                                Text(
                                  '${top[i].$2} vendidos',
                                  style: KText.caption,
                                ),
                              ],
                            ),
                            const SizedBox(height: KSpace.s),
                            _Bar(
                              fraction: top[i].$2 / max,
                              color: i == 0 ? KColors.sea : KColors.sky,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _Bar extends StatelessWidget {
  const _Bar({required this.fraction, required this.color});
  final double fraction;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 6,
      decoration: BoxDecoration(
        color: KColors.mist,
        borderRadius: BorderRadius.circular(3),
      ),
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: fraction),
        duration: const Duration(milliseconds: 900),
        curve: KMotion.ease,
        builder: (_, f, _) => FractionallySizedBox(
          alignment: Alignment.centerLeft,
          widthFactor: f.clamp(0, 1),
          child: Container(
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(3),
            ),
          ),
        ),
      ),
    );
  }
}
