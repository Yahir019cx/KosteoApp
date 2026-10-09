import 'package:flutter/material.dart';

import '../theme/icons.dart';

import '../data/app_store.dart';
import '../theme/tokens.dart';
import '../widgets/basics.dart';
import '../widgets/chips.dart';
import '../widgets/inputs.dart';
import '../widgets/motion.dart';
import '../widgets/order_card.dart';
import '../widgets/toast.dart';
import '../widgets/glass_sheet.dart';
import 'common.dart';
import 'new_order_screen.dart';

class OrdersScreen extends StatefulWidget {
  const OrdersScreen({super.key});

  @override
  State<OrdersScreen> createState() => _OrdersScreenState();
}

class _OrdersScreenState extends State<OrdersScreen> {
  bool _searching = false;
  bool _selecting = false;
  final Set<int> _selected = {};
  final _query = TextEditingController();

  @override
  void dispose() {
    _query.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([store, store.ordersFilter, _query]),
      builder: (context, _) {
        final filter = store.ordersFilter.value;
        final q = _query.text.trim().toLowerCase();
        final list = store.ordersBy(filter).where((o) {
          if (_selecting &&
              (o.jornadaId != null || o.status != OrderStatus.pending)) {
            return false;
          }
          if (q.isEmpty) return true;
          return o.number == int.tryParse(q.replaceAll('#', '')) ||
              o.folio.contains(q) ||
              (o.customer ?? 'sin nombre').toLowerCase().contains(q) ||
              o.lines.any((l) => l.name.toLowerCase().contains(q));
        }).toList();

        return Column(
          children: [
            ContentWidth(
              child: PageHeader(
                title: 'Pedidos',
                subtitle:
                    '${store.orders.length} pedidos · ${store.countBy(OrderStatus.pending)} por atender',
                actions: [
                  if (_selecting ||
                      store.orders.any(
                        (o) =>
                            o.jornadaId == null &&
                            o.status == OrderStatus.pending,
                      ))
                    CircleIconButton(
                      icon: _selecting ? KIcons.x : KIcons.checks,
                      semanticLabel: _selecting
                          ? 'Terminar selección'
                          : 'Seleccionar sin jornada',
                      onTap: () => setState(() {
                        _selecting = !_selecting;
                        _selected.clear();
                        store.ordersFilter.value = OrderStatus.pending;
                      }),
                    ),
                  CircleIconButton(
                    icon: _searching ? KIcons.x : KIcons.magnifyingGlass,
                    semanticLabel: 'Buscar',
                    onTap: () => setState(() {
                      _searching = !_searching;
                      if (!_searching) _query.clear();
                    }),
                  ),
                  CircleIconButton(
                    icon: KIcons.plus,
                    semanticLabel: 'Nuevo pedido',
                    color: Colors.white,
                    background: KColors.sea,
                    onTap: () => push(context, const NewOrderScreen()),
                  ),
                ],
              ),
            ),
            AnimatedSize(
              duration: KMotion.base,
              curve: KMotion.ease,
              child: _searching
                  ? ContentWidth(
                      child: Padding(
                        padding: EdgeInsets.fromLTRB(
                          context.gutter,
                          0,
                          context.gutter,
                          KSpace.s,
                        ),
                        child: KTextField(
                          controller: _query,
                          autofocus: true,
                          hint: 'Folio, cliente o platillo',
                          icon: KIcons.magnifyingGlass,
                        ),
                      ),
                    )
                  : const SizedBox(width: double.infinity),
            ),
            ContentWidth(
              child: ChipBar(
                children: [
                  for (final s in OrderStatus.values)
                    CategoryChip(
                      label: s.filterLabel,
                      count: store.countBy(s),
                      selected: s == filter,
                      color: KColors.sea,
                      onTap: () => setState(() {
                        store.ordersFilter.value = s;
                        if (s != OrderStatus.pending) {
                          _selecting = false;
                          _selected.clear();
                        }
                      }),
                    ),
                ],
              ),
            ),
            if (_selecting)
              ContentWidth(
                child: Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: context.gutter,
                    vertical: KSpace.s,
                  ),
                  child: SoftButton(
                    label: 'Asignar ${_selected.length} a jornada',
                    icon: KIcons.checks,
                    onTap: _selected.isEmpty ? null : _assign,
                  ),
                ),
              ),
            Expanded(
              child: AnimatedSwitcher(
                duration: KMotion.base,
                switchInCurve: KMotion.ease,
                transitionBuilder: (child, a) => FadeTransition(
                  opacity: a,
                  child: SlideTransition(
                    position: Tween(
                      begin: const Offset(0, 0.02),
                      end: Offset.zero,
                    ).animate(a),
                    child: child,
                  ),
                ),
                child: KeyedSubtree(
                  key: ValueKey(
                    '$filter-${list.map((o) => o.number).join(',')}',
                  ),
                  child: list.isEmpty
                      ? ListView(children: [_empty(filter)])
                      : _OrdersGrid(
                          orders: list,
                          onAdvance: _advance,
                          selecting: _selecting,
                          selected: _selected,
                        ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Future<void> _advance(Order o) async {
    if (o.jornadaId == null && o.status == OrderStatus.pending) {
      if (!_selected.contains(o.number) && _selected.length >= 100) {
        showErrorToast(context, 'Selecciona hasta 100 pedidos por asignación.');
        return;
      }
      setState(() {
        _selecting = true;
        if (!_selected.add(o.number)) _selected.remove(o.number);
      });
      return;
    }
    await runAction(context, () async {
      final next = o.nextStep?.$1;
      await store.advance(o);
      if (!mounted) return;
      showToast(
        context,
        '${o.folio} · ${next?.label ?? o.status.label}',
        icon: KIcons.checkCircleStrong,
        color: o.status.color,
      );
    });
  }

  Future<void> _assign() async {
    final abiertas = store.jornadas
        .where((j) => j['estado'] == 'ABIERTA')
        .toList();
    await showGlassSheet<void>(
      context,
      builder: (ctx) => SheetBody(
        title: 'Asignar a jornada',
        subtitle: '${_selected.length} pedidos seleccionados',
        child: abiertas.isEmpty
            ? Text(
                'Todavía no hay jornada abierta. Puedes conservar tus pedidos y asignarlos cuando abras una.',
                style: KText.body,
              )
            : Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (final j in abiertas)
                    SoftButton(
                      label:
                          '${j['fechaInicio'].toString().split('T').first} · ${j['fechaFin'].toString().split('T').first}',
                      icon: KIcons.checks,
                      onTap: () => runAction(ctx, () async {
                        await store.asignarPedidos(
                          _selected.toList(),
                          j['jornadaId'] as int,
                        );
                        if (!mounted || !ctx.mounted) return;
                        setState(() {
                          _selected.clear();
                          _selecting = false;
                        });
                        showToast(ctx, 'Pedidos asignados a la jornada');
                        Navigator.of(ctx).pop();
                      }),
                    ),
                ],
              ),
      ),
    );
  }

  Widget _empty(OrderStatus s) => EmptyState(
    icon: s == OrderStatus.delivered ? KIcons.flag : KIcons.waves,
    title: 'Nada ${s == OrderStatus.pending ? 'pendiente' : 'aquí'} por ahora',
    message: s == OrderStatus.pending
        ? 'Cuando llegue un pedido aparecerá en esta lista.'
        : 'Los pedidos aparecerán aquí al cambiar de estado.',
    action: s == OrderStatus.pending
        ? PrimaryButton(
            label: 'Nuevo pedido',
            icon: KIcons.plusStrong,
            expand: false,
            onTap: () => push(context, const NewOrderScreen()),
          )
        : null,
  );
}

/// Lista en teléfono; columnas tipo mosaico en tablet.
class _OrdersGrid extends StatelessWidget {
  const _OrdersGrid({
    required this.orders,
    required this.onAdvance,
    this.selecting = false,
    this.selected = const {},
  });
  final List<Order> orders;
  final ValueChanged<Order> onAdvance;
  final bool selecting;
  final Set<int> selected;

  @override
  Widget build(BuildContext context) {
    final cols = context.isWide ? 3 : (context.isTablet ? 2 : 1);
    Widget card(int i) => Padding(
      padding: const EdgeInsets.only(bottom: KSpace.l),
      child: FadeSlideIn(
        index: i,
        child: GestureDetector(
          onLongPress: orders[i].nextStep == null
              ? null
              : () => showGlassSheet<void>(
                  context,
                  builder: (ctx) => SheetBody(
                    title: orders[i].folio,
                    subtitle: [
                      orders[i].tipoEntrega == 'ENTREGA'
                          ? 'Entrega'
                          : 'Recoger',
                      if ((orders[i].phone ?? '').isNotEmpty) orders[i].phone!,
                      if ((orders[i].reference ?? '').isNotEmpty)
                        orders[i].reference!,
                    ].join(' · '),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        SoftButton(
                          label: 'Editar pedido',
                          icon: KIcons.pencilSimple,
                          onTap: () {
                            final order = orders[i];
                            if (order.revision == null) {
                              showErrorToast(
                                ctx,
                                'Actualiza el backend y recarga los pedidos para editar.',
                              );
                              return;
                            }
                            Navigator.of(ctx).pop();
                            push(context, NewOrderScreen(order: order));
                          },
                        ),
                        const SizedBox(height: KSpace.m),
                        SoftButton(
                          label: 'Cancelar pedido',
                          icon: KIcons.trash,
                          color: KColors.danger,
                          onTap: () => runAction(ctx, () async {
                            await store.changeStatus(
                              orders[i],
                              OrderStatus.cancelled,
                            );
                            if (ctx.mounted) showToast(ctx, 'Pedido cancelado');
                            if (ctx.mounted) Navigator.of(ctx).pop();
                          }),
                        ),
                      ],
                    ),
                  ),
                ),
          child: OrderCard(
            key: ValueKey(orders[i].number),
            order: orders[i],
            onAdvance: () => onAdvance(orders[i]),
            selecting: selecting,
            selected: selected.contains(orders[i].number),
          ),
        ),
      ),
    );

    return ListView(
      padding: EdgeInsets.fromLTRB(
        context.gutter,
        KSpace.s,
        context.gutter,
        KSpace.navClearance,
      ),
      children: [
        ContentWidth(
          child: cols == 1
              ? Column(
                  children: [for (var i = 0; i < orders.length; i++) card(i)],
                )
              : Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (var c = 0; c < cols; c++) ...[
                      if (c > 0) const SizedBox(width: KSpace.l),
                      Expanded(
                        child: Column(
                          children: [
                            for (var i = c; i < orders.length; i += cols)
                              card(i),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
        ),
      ],
    );
  }
}
