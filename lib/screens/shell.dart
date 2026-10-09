import 'package:flutter/material.dart';

import '../theme/icons.dart';

import '../data/app_store.dart';
import '../theme/tokens.dart';
import '../widgets/glass_bottom_bar.dart';
import '../widgets/glass_sheet.dart';
import '../widgets/rows.dart';
import 'common.dart';
import 'dashboard_screen.dart';
import 'day_close_screen.dart';
import 'gas_sheet.dart';
import 'ingredients_screen.dart';
import 'leftovers_screen.dart';
import 'new_order_screen.dart';
import 'new_purchase_screen.dart';
import 'orders_screen.dart';
import 'placeholder_screen.dart';
import 'products_screen.dart';
import 'purchases_screen.dart';
import 'reports_screen.dart';

/// Contenedor principal: cuatro secciones + botón + central en la barra flotante.
/// Las secciones se mantienen vivas (conservan scroll) y cambian con fundido.
class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  @override
  void initState() {
    super.initState();
    if (!store.loaded) Future.microtask(store.load);
  }

  int _tab = 0;
  bool _plusOpen = false;

  static const _tabs = [
    NavItem('Inicio', KIcons.house),
    NavItem('Pedidos', KIcons.receipt),
    NavItem('Compras', KIcons.shoppingBag),
    NavItem('Productos', KIcons.menu),
  ];

  void _goTo(int tab) => setState(() => _tab = tab);

  void _openOrders(OrderStatus filter) {
    store.ordersFilter.value = filter;
    _goTo(1);
  }

  Future<void> _openQuickActions() async {
    setState(() => _plusOpen = true);
    final action = await showGlassSheet<_Quick>(
      context,
      builder: (_) => const _QuickActionsSheet(),
    );
    if (!mounted) return;
    setState(() => _plusOpen = false);
    switch (action) {
      case _Quick.order:
        push(context, const NewOrderScreen());
      case _Quick.purchase:
        push(context, const NewPurchaseScreen());
      case _Quick.gas:
        showGasSheet(context);
      case _Quick.leftovers:
        push(context, const LeftoversScreen());
      case _Quick.close:
        push(context, const DayCloseScreen());
      case null:
        break;
    }
  }

  /// Opciones secundarias (desde el avatar de Inicio).
  Future<void> _openMore() async {
    final screen = await showGlassSheet<Widget>(
      context,
      builder: (_) => const _MoreSheet(),
    );
    if (screen != null && mounted) push(context, screen);
  }

  @override
  Widget build(BuildContext context) {
    final pages = [
      DashboardScreen(
        onOpenOrders: _openOrders,
        onOpenShift: () => push(context, const DayCloseScreen()),
        onOpenMore: _openMore,
      ),
      const OrdersScreen(),
      const PurchasesScreen(),
      const ProductsScreen(),
    ];
    return Scaffold(
      backgroundColor: KColors.white,
      resizeToAvoidBottomInset: false,
      body: ColoredBox(
        color: KColors.white,
        child: ListenableBuilder(
          listenable: store,
          builder: (context, _) => Stack(
            children: [
              for (var i = 0; i < pages.length; i++)
                Positioned.fill(
                  child: IgnorePointer(
                    ignoring: i != _tab,
                    // El TickerMode va dentro del fundido: así la pestaña que sale
                    // termina su animación y solo se pausan las animaciones internas.
                    child: AnimatedOpacity(
                      opacity: i == _tab ? 1 : 0,
                      duration: KMotion.base,
                      curve: KMotion.ease,
                      child: AnimatedSlide(
                        offset: i == _tab
                            ? Offset.zero
                            : const Offset(0, 0.015),
                        duration: KMotion.base,
                        curve: KMotion.ease,
                        child: TickerMode(
                          enabled: i == _tab,
                          child: SafeArea(bottom: false, child: pages[i]),
                        ),
                      ),
                    ),
                  ),
                ),
              if (store.loading || store.error != null)
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  child: SafeArea(
                    child: Material(
                      color: KColors.white,
                      child: ListTile(
                        title: Text(store.loading ? 'Cargando…' : store.error!),
                        trailing: store.loading
                            ? const SizedBox.square(
                                dimension: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : IconButton(
                                icon: const Icon(KIcons.caretRight),
                                onPressed: store.load,
                              ),
                      ),
                    ),
                  ),
                ),
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: GlassBottomBar(
                  tabs: _tabs,
                  index: _tab,
                  onTab: _goTo,
                  onPlus: _openQuickActions,
                  plusOpen: _plusOpen,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────── Acciones rápidas (+) ───────────────────────────

enum _Quick { order, purchase, gas, leftovers, close }

class _QuickActionsSheet extends StatelessWidget {
  const _QuickActionsSheet();

  @override
  Widget build(BuildContext context) {
    void pick(_Quick q) => Navigator.of(context).pop(q);
    return SheetBody(
      title: '¿Qué quieres hacer?',
      child: Column(
        children: [
          _Grid(
            children: [
              QuickAction(
                label: 'Nuevo pedido',
                caption: 'Cobrar y enviar a cocina',
                icon: KIcons.receipt,
                color: KColors.sea,
                onTap: () => pick(_Quick.order),
              ),
              QuickAction(
                label: 'Nueva compra',
                caption: 'Insumos del día',
                icon: KIcons.shoppingBag,
                color: KColors.coral,
                onTap: () => pick(_Quick.purchase),
              ),
              QuickAction(
                label: 'Gasolina',
                caption: 'Gasto de reparto',
                icon: KIcons.gasPump,
                color: KColors.sun,
                onTap: () => pick(_Quick.gas),
              ),
              QuickAction(
                label: 'Sobrantes',
                caption: 'Conteo al cierre',
                icon: KIcons.package,
                color: KColors.lagoon,
                onTap: () => pick(_Quick.leftovers),
              ),
            ],
          ),
          const SizedBox(height: KSpace.m),
          QuickAction(
            label: 'Cerrar jornada',
            caption: 'Ver resumen y cerrar el día',
            icon: KIcons.checkCircle,
            color: KColors.success,
            horizontal: true,
            onTap: () => pick(_Quick.close),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────── Más ───────────────────────────

class _MoreSheet extends StatelessWidget {
  const _MoreSheet();

  @override
  Widget build(BuildContext context) {
    void open(Widget s) => Navigator.of(context).pop(s);
    return SheetBody(
      title: 'Más opciones',
      child: Column(
        children: [
          _Grid(
            children: [
              QuickAction(
                label: 'Insumos',
                caption: '${store.ingredients.length} en catálogo',
                icon: KIcons.basket,
                color: KColors.lagoon,
                onTap: () => open(const IngredientsScreen()),
              ),
              QuickAction(
                label: 'Inventario',
                caption: 'Existencias',
                icon: KIcons.archive,
                color: KColors.sea,
                onTap: () => open(const PlaceholderScreen.inventory()),
              ),
              QuickAction(
                label: 'Jornada',
                caption: 'Resumen y cierre',
                icon: KIcons.jornada,
                color: KColors.coral,
                onTap: () => open(const DayCloseScreen()),
              ),
              QuickAction(
                label: 'Reportes',
                caption: 'Tendencias',
                icon: KIcons.chartBar,
                color: KColors.sun,
                onTap: () => open(const ReportsScreen()),
              ),
            ],
          ),
          const SizedBox(height: KSpace.m),
          QuickAction(
            label: 'Configuración',
            caption: 'Negocio',
            icon: KIcons.gear,
            color: KColors.inkSoft,
            horizontal: true,
            onTap: () => open(const PlaceholderScreen.settings()),
          ),
        ],
      ),
    );
  }
}

class _Grid extends StatelessWidget {
  const _Grid({required this.children});
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (var i = 0; i < children.length; i += 2) ...[
          if (i > 0) const SizedBox(height: KSpace.m),
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(child: children[i]),
                const SizedBox(width: KSpace.m),
                Expanded(
                  child: i + 1 < children.length
                      ? children[i + 1]
                      : const SizedBox(),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}
