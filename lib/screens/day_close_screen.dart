import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/icons.dart';

import '../data/app_store.dart';
import '../theme/tokens.dart';
import '../widgets/basics.dart';
import '../widgets/glass_sheet.dart';
import '../widgets/metric_donut.dart';
import '../widgets/motion.dart';
import 'common.dart';
import 'leftovers_screen.dart';

/// Resumen visual de la jornada y cierre.
class DayCloseScreen extends StatefulWidget {
  const DayCloseScreen({super.key});

  @override
  State<DayCloseScreen> createState() => _DayCloseScreenState();
}

class _DayCloseScreenState extends State<DayCloseScreen> {
  int? _selected;
  Future<void> _openShift() async {
    final now = DateTime.now();
    final dates = await showDateRangePicker(
      context: context,
      firstDate: DateTime(now.year - 1),
      lastDate: DateTime(now.year + 1),
      initialDateRange: DateTimeRange(
        start: DateTime(now.year, now.month, now.day),
        end: DateTime(now.year, now.month, now.day + 1),
      ),
      helpText: 'Fechas de la jornada',
    );
    if (dates != null && mounted) {
      await runAction(
        context,
        () => store.openShift(dates.start, dates.end),
        successMessage: 'Jornada abierta',
      );
    }
  }

  Future<void> _history() async {
    await showGlassSheet<void>(
      context,
      builder: (context) => SheetBody(
        title: 'Jornadas',
        child: Column(
          children: [
            for (final j in store.jornadas)
              KosteoCard(
                onTap: () => runAction(context, () async {
                  await store.selectShift(j['jornadaId']);
                  if (context.mounted) Navigator.of(context).pop();
                }),
                child: Text(
                  '${j['fechaInicio']} · ${j['fechaFin']} · ${j['estado']}',
                  style: KText.body,
                ),
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmClose() async {
    final ok = await showGlassSheet<bool>(
      context,
      builder: (_) => const _ConfirmSheet(),
    );
    if (ok != true || !mounted) return;
    HapticFeedback.heavyImpact();
    await runAction(
      context,
      store.closeShift,
      successMessage: 'Jornada cerrada',
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: store,
      builder: (context, _) {
        final m = store.metrics[Period.shift]!;
        final gas = store.gasTotal;
        final segments = [
          DonutSegment('Ganancia neta', m.profit, KColors.sea),
          DonutSegment('Costo de insumos', m.cost, KColors.coral),
          DonutSegment('Gasolina reparto', gas, KColors.sun),
        ];
        final inventory = DonutSegment(
          'Inventario sobrante',
          m.inventory,
          KColors.lagoon,
        );
        final sel = _selected == null ? null : segments[_selected!];
        final closed = store.shiftClosed;

        final donutCard = KosteoCard(
          child: LayoutBuilder(
            builder: (context, c) {
              final side = c.maxWidth >= 560;
              final donut = MetricDonut(
                segments: segments,
                selected: _selected,
                ring: inventory,
                ringOf: m.sales,
                size: side ? 260 : (c.maxWidth * 0.82).clamp(220, 280),
                center: DonutCenter(
                  value: sel == null ? m.sales : sel.value,
                  label: sel?.label ?? 'Ventas',
                ),
              );
              final legend = Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (var i = 0; i < segments.length; i++)
                    DonutLegendRow(
                      segment: segments[i],
                      total: m.sales,
                      selected: _selected == i,
                      dimmed: _selected != null && _selected != i,
                      onTap: () =>
                          setState(() => _selected = _selected == i ? null : i),
                    ),
                  DonutLegendRow(
                    segment: inventory,
                    total: 0,
                    hint: 'Inversión ${money(m.investment)} · anillo exterior',
                  ),
                ],
              );
              return side
                  ? Row(
                      children: [
                        donut,
                        const SizedBox(width: KSpace.xl),
                        Expanded(child: legend),
                      ],
                    )
                  : Column(
                      children: [
                        donut,
                        const SizedBox(height: KSpace.xl),
                        legend,
                      ],
                    );
            },
          ),
        );

        final delivered = store.countByJornada(OrderStatus.delivered);
        final open =
            store.ordersDeJornada.length -
            delivered -
            store.countByJornada(OrderStatus.cancelled);
        final stats = KosteoCard(
          padding: const EdgeInsets.symmetric(
            vertical: KSpace.l,
            horizontal: KSpace.s,
          ),
          child: IntrinsicHeight(
            child: Row(
              children: [
                _Stat(
                  '${store.ordersDeJornada.length}',
                  'Pedidos',
                  KColors.ink,
                ),
                Container(width: 1, color: KColors.line),
                _Stat('$delivered', 'Entregados', KColors.success),
                Container(width: 1, color: KColors.line),
                _Stat('$open', 'Pendientes', KColors.coral),
              ],
            ),
          ),
        );

        final counted = store.leftovers.where((l) => l.touched).length;
        final checklist = KosteoCard(
          padding: const EdgeInsets.symmetric(
            horizontal: KSpace.l,
            vertical: KSpace.s,
          ),
          child: Column(
            children: [
              _Check(
                done: counted == store.leftovers.length,
                title: 'Conteo de sobrantes',
                caption: '$counted de ${store.leftovers.length} contados',
                onTap: () => push(context, const LeftoversScreen()),
              ),
              _Check(
                done:
                    gas > 0 ||
                    store.jornada?['sinGastoRepartoConfirmado'] == true,
                title: 'Gasolina registrada',
                caption: gas > 0
                    ? money(gas)
                    : 'Sin reparto: toca para confirmar',
                onTap: gas == 0 && !closed
                    ? () => runAction(
                        context,
                        store.noGas,
                        successMessage:
                            'Jornada confirmada sin gasto de gasolina',
                      )
                    : null,
              ),
              _Check(
                done: open == 0,
                title: 'Pedidos cerrados',
                caption: open == 0 ? 'Todo entregado' : '$open sin entregar',
              ),
            ],
          ),
        );

        final active = store.jornadas
            .where((j) => j['estado'] == 'ABIERTA')
            .firstOrNull;
        final Widget action = store.jornada == null || closed
            ? PrimaryButton(
                label: active == null ? 'Abrir jornada' : 'Usar jornada activa',
                icon: KIcons.plusStrong,
                onTap: active == null
                    ? _openShift
                    : () => runAction(
                        context,
                        () => store.selectShift(active['jornadaId']),
                      ),
              )
            : PrimaryButton(
                label: 'Cerrar jornada',
                icon: KIcons.moonStarsStrong,
                onTap: _confirmClose,
              );

        final content = ContentWidth(
          child: ListView(
            padding: EdgeInsets.only(bottom: KSpace.xxxl),
            children: [
              PageHeader(
                title: 'Jornada',
                subtitle: store.jornada == null
                    ? 'Sin jornada'
                    : '${store.jornada!["fechaInicio"]} · ${store.jornada!["fechaFin"]}',
                back: true,
                actions: [
                  CircleIconButton(
                    icon: KIcons.jornada,
                    semanticLabel: 'Jornadas anteriores',
                    onTap: _history,
                  ),
                ],
              ),
              Padding(
                padding: EdgeInsets.symmetric(horizontal: context.gutter),
                child: AnimatedSwitcher(
                  duration: KMotion.slow,
                  child: closed
                      ? const _ClosedBanner()
                      : context.isTablet
                      ? Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              flex: 6,
                              child: FadeSlideIn(child: donutCard),
                            ),
                            const SizedBox(width: KSpace.xl),
                            Expanded(
                              flex: 4,
                              child: Column(
                                children: [
                                  FadeSlideIn(index: 1, child: stats),
                                  const SizedBox(height: KSpace.l),
                                  FadeSlideIn(index: 2, child: checklist),
                                ],
                              ),
                            ),
                          ],
                        )
                      : Column(
                          children: [
                            FadeSlideIn(child: donutCard),
                            const SizedBox(height: KSpace.l),
                            FadeSlideIn(index: 1, child: stats),
                            const SizedBox(height: KSpace.l),
                            FadeSlideIn(index: 2, child: checklist),
                          ],
                        ),
                ),
              ),
              Padding(
                padding: EdgeInsets.fromLTRB(
                  context.gutter,
                  KSpace.xl,
                  context.gutter,
                  0,
                ),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 520),
                    child: action,
                  ),
                ),
              ),
            ],
          ),
        );
        return KScaffold(body: content);
      },
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat(this.value, this.label, this.color);
  final String value;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) => Expanded(
    child: Column(
      children: [
        Text(value, style: KText.display.copyWith(fontSize: 26, color: color)),
        Text(label, style: KText.caption),
      ],
    ),
  );
}

class _Check extends StatelessWidget {
  const _Check({
    required this.done,
    required this.title,
    required this.caption,
    this.onTap,
  });
  final bool done;
  final String title;
  final String caption;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Pressable(
      onTap: onTap,
      scale: 0.98,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: KSpace.m),
        child: Row(
          children: [
            Icon(
              done ? KIcons.checkCircleStrong : KIcons.circleDashed,
              color: done ? KColors.success : KColors.inkMuted,
              size: 24,
            ),
            const SizedBox(width: KSpace.m),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: KText.bodyStrong.copyWith(fontSize: 14)),
                  Text(caption, style: KText.caption),
                ],
              ),
            ),
            if (onTap != null)
              const Icon(KIcons.caretRight, size: 18, color: KColors.inkMuted),
          ],
        ),
      ),
    );
  }
}

class _ConfirmSheet extends StatelessWidget {
  const _ConfirmSheet();

  @override
  Widget build(BuildContext context) {
    final pending =
        store.ordersDeJornada.length -
        store.countByJornada(OrderStatus.delivered) -
        store.countByJornada(OrderStatus.cancelled);
    return SheetBody(
      title: '¿Cerrar la jornada?',
      subtitle: pending > 0
          ? 'Resuelve $pending pedidos: entrega o cancela antes de cerrar.'
          : 'Se guardará el resumen del día.',
      child: Row(
        children: [
          Expanded(
            child: SoftButton(
              label: 'Todavía no',
              height: 56,
              onTap: () => Navigator.of(context).pop(false),
            ),
          ),
          const SizedBox(width: KSpace.m),
          Expanded(
            child: PrimaryButton(
              label: 'Sí, cerrar',
              onTap: pending > 0 ? null : () => Navigator.of(context).pop(true),
            ),
          ),
        ],
      ),
    );
  }
}

/// Momento "peak-end": cierre celebrado con check animado y resumen corto.
class _ClosedBanner extends StatelessWidget {
  const _ClosedBanner();

  @override
  Widget build(BuildContext context) {
    final m = store.metrics[Period.shift]!;
    return KosteoCard(
      padding: const EdgeInsets.symmetric(
        horizontal: KSpace.xl,
        vertical: KSpace.xxxl,
      ),
      child: Column(
        children: [
          TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: 1),
            duration: const Duration(milliseconds: 700),
            curve: Curves.elasticOut,
            builder: (_, v, child) => Transform.scale(scale: v, child: child),
            child: Container(
              width: 96,
              height: 96,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: KColors.success.withValues(alpha: 0.12),
              ),
              child: const Icon(
                KIcons.checkCircleStrong,
                color: KColors.success,
                size: 64,
              ),
            ),
          ),
          const SizedBox(height: KSpace.xl),
          Text('¡Jornada cerrada!', style: KText.title),
          const SizedBox(height: KSpace.s),
          Text(
            m.profit == null
                ? 'Vendiste ${money(m.sales)} · Ganancia provisional.'
                : 'Vendiste ${money(m.sales)} y te quedan ${money(m.profit)} de ganancia.',
            style: KText.body.copyWith(color: KColors.inkSoft),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
