import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/icons.dart';

import '../data/app_store.dart';
import '../theme/tokens.dart';
import '../widgets/basics.dart';
import '../widgets/chips.dart';
import '../widgets/glass_sheet.dart';
import '../widgets/inputs.dart';
import '../widgets/motion.dart';
import '../widgets/product_card.dart';
import '../widgets/toast.dart';
import 'common.dart';
import 'dish_photo.dart';

class NewOrderScreen extends StatefulWidget {
  const NewOrderScreen({super.key, this.order});
  final Order? order;

  @override
  State<NewOrderScreen> createState() => _NewOrderScreenState();
}

class _NewOrderScreenState extends State<NewOrderScreen> {
  final List<OrderLine> _cart = [];
  final _query = TextEditingController();
  String _category = productCategories.first;
  String? _customer;
  String? _phone, _reference, _notes;
  String _type = 'RECOGER';
  bool _sinJornada = false;
  bool get _editing => widget.order != null;
  bool get _started => _editing && widget.order!.status != OrderStatus.pending;
  bool _locked(OrderLine l) => _started && l.detailId != null;
  void _clearCart() => setState(() => _cart.removeWhere((l) => !_locked(l)));

  @override
  void initState() {
    super.initState();
    final order = widget.order;
    if (order == null) return;
    _cart.addAll(order.lines.map((l) => l.copyForEditing()));
    _customer = order.customer;
    _phone = order.phone;
    _type = order.tipoEntrega;
    _reference = order.reference;
    _notes = order.notes;
    _sinJornada = order.jornadaId == null;
  }

  /// Presentación elegida en cada card (Individual/Doble).
  final Map<Product, String> _sizes = {};
  String? _sizeOf(Product p) =>
      p.sizes == null ? null : (_sizes[p] ?? p.sizes!.keys.first);

  num get _total => _cart.fold<num>(0, (s, l) => s + l.total);
  int get _items => _cart.fold(0, (s, l) => s + l.qty);
  int _inCart(Product p) =>
      _cart.where((l) => l.product == p).fold(0, (s, l) => s + l.qty);

  @override
  void dispose() {
    _query.dispose();
    super.dispose();
  }

  List<Product> get _visible {
    final q = _query.text.trim().toLowerCase();
    return products
        .where((p) => !p.paused) // los pausados no se venden
        .where((p) => _category == 'Todos' || p.category == _category)
        .where((p) => q.isEmpty || p.name.toLowerCase().contains(q))
        .toList();
  }

  Future<void> _add(Product p) async {
    if (p.priceFor(_sizeOf(p)) == null) {
      showErrorToast(context, 'Configura primero el precio de venta.');
      return;
    }
    OrderLine? line;
    if (p.hasOptions) {
      line = await showGlassSheet<OrderLine>(
        context,
        builder: (_) => _ProductOptionsSheet(product: p, size: _sizeOf(p)),
      );
    } else {
      HapticFeedback.lightImpact();
      line = OrderLine(p, 1, size: _sizeOf(p));
    }
    if (line == null) return;
    final l = line;
    setState(() {
      final same = _cart.where(
        (e) =>
            e.detailId == null &&
            e.product == l.product &&
            e.size == l.size &&
            e.sides.length == l.sides.length &&
            e.sides.toSet().containsAll(l.sides) &&
            e.extras.join() == l.extras.join(),
      );
      if (same.isNotEmpty) {
        same.first.qty += l.qty;
      } else {
        _cart.add(l);
      }
    });
  }

  void _changeQty(OrderLine l, int qty) => setState(() {
    if (_locked(l)) return;
    if (qty <= 0) {
      _cart.remove(l);
    } else {
      l.qty = qty;
    }
  });

  Future<void> _save() => runAction(context, () async {
    if (_cart.isEmpty) return;
    if (_editing) {
      await store.editOrder(
        widget.order!,
        List.of(_cart),
        customer: _customer,
        phone: _phone,
        type: _type,
        reference: _reference,
        notes: _notes,
      );
      final updated = store.orders
          .where((o) => o.number == widget.order!.number)
          .firstOrNull;
      store.ordersFilter.value = updated?.status ?? widget.order!.status;
      if (!mounted) return;
      showToast(context, 'Pedido ${widget.order!.folio} actualizado');
      Navigator.of(context).pop();
      return;
    }
    final o = await store.addOrder(
      List.of(_cart),
      customer: _customer,
      phone: _phone,
      type: _type,
      reference: _reference,
      notes: _notes,
      sinJornada: _sinJornada,
    );
    store.ordersFilter.value = OrderStatus.pending;
    if (!mounted) return;
    showToast(
      context,
      'Pedido ${o.folio} guardado${o.jornadaId == null ? ' sin jornada' : ''} · ${money(o.total)}',
    );
    Navigator.of(context).pop();
  });

  Future<void> _pickCustomer() async {
    final data = await showGlassSheet<Map<String, String>>(
      context,
      builder: (_) => _CustomerSheet(
        current: _customer,
        phone: _phone,
        type: _type,
        reference: _reference,
        notes: _notes,
      ),
    );
    if (data == null || !mounted) return;
    setState(() {
      _customer = data['name'];
      _phone = data['phone'];
      _type = data['type']!;
      _reference = data['reference'];
      _notes = data['notes'];
    });
  }

  Future<void> _openCart() async {
    await showGlassSheet<void>(
      context,
      builder: (_) => StatefulBuilder(
        builder: (context, setSheet) => SheetBody(
          title: 'Pedido ($_items)',
          child: _CartContents(
            lines: _cart,
            locked: _locked,
            clearLabel: _started ? 'Quitar agregados' : 'Vaciar pedido',
            saveLabel: _editing ? 'Guardar cambios' : 'Guardar pedido',
            onQty: (l, q) {
              _changeQty(l, q);
              setSheet(() {});
              if (_cart.isEmpty) Navigator.of(context).pop();
            },
            onClear: () {
              _clearCart();
              Navigator.of(context).pop();
            },
            total: _total,
            onSave: () {
              Navigator.of(context).pop();
              _save();
            },
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final tablet = context.isTablet;
    final catalog = Column(
      children: [
        PageHeader(
          title: _editing ? 'Editar ${widget.order!.folio}' : 'Nuevo pedido',
          back: true,
          actions: [
            if (_cart.any((l) => !_locked(l)))
              CircleIconButton(
                icon: KIcons.trash,
                color: KColors.danger,
                semanticLabel: 'Vaciar',
                onTap: _clearCart,
              ),
          ],
        ),
        Padding(
          padding: EdgeInsets.symmetric(horizontal: context.gutter),
          child: Row(
            children: [
              Expanded(
                child: Pressable(
                  onTap: _pickCustomer,
                  child: Container(
                    height: 44,
                    padding: const EdgeInsets.symmetric(horizontal: KSpace.m),
                    decoration: BoxDecoration(
                      color: KColors.mist,
                      borderRadius: BorderRadius.circular(KRadius.chip),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          KIcons.user,
                          size: 18,
                          color: KColors.inkSoft,
                        ),
                        const SizedBox(width: KSpace.s),
                        Expanded(
                          child: Text(
                            _customer ?? 'Sin nombre',
                            style: KText.body.copyWith(fontSize: 14),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const Icon(
                          KIcons.pencilSimple,
                          size: 16,
                          color: KColors.inkMuted,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: KSpace.m),
        Padding(
          padding: EdgeInsets.symmetric(horizontal: context.gutter),
          child: _editing
              ? Text(
                  _started
                      ? 'Agrega productos · lo que ya se prepara se conserva'
                      : 'Conserva su jornada y los precios ya acordados',
                  style: KText.caption,
                )
              : store.jornadaAbiertaId == null
              ? Text(
                  'Sin jornada · podrás asignarlo después',
                  style: KText.caption,
                )
              : Row(
                  children: [
                    CategoryChip(
                      label: 'Jornada actual',
                      selected: !_sinJornada,
                      onTap: () => setState(() => _sinJornada = false),
                    ),
                    const SizedBox(width: KSpace.s),
                    CategoryChip(
                      label: 'Para después',
                      selected: _sinJornada,
                      onTap: () => setState(() => _sinJornada = true),
                    ),
                  ],
                ),
        ),
        const SizedBox(height: KSpace.m),
        Padding(
          padding: EdgeInsets.symmetric(horizontal: context.gutter),
          child: KTextField(
            controller: _query,
            hint: 'Buscar platillo',
            icon: KIcons.magnifyingGlass,
            onChanged: (_) => setState(() {}),
          ),
        ),
        const SizedBox(height: KSpace.xs),
        ChipBar(
          children: [
            for (final c in productCategories)
              CategoryChip(
                label: c,
                selected: c == _category,
                onTap: () => setState(() => _category = c),
              ),
          ],
        ),
        Expanded(
          child: LayoutBuilder(
            builder: (context, c) {
              final cols = (c.maxWidth / 180).floor().clamp(2, 5);
              final items = _visible;
              return AnimatedSwitcher(
                duration: KMotion.base,
                child: GridView.builder(
                  key: ValueKey('$_category${_query.text}'),
                  padding: EdgeInsets.fromLTRB(
                    context.gutter,
                    KSpace.s,
                    context.gutter,
                    tablet ? KSpace.xl : 120,
                  ),
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: cols,
                    mainAxisSpacing: KSpace.m,
                    crossAxisSpacing: KSpace.m,
                    childAspectRatio: 0.7,
                  ),
                  itemCount: items.length,
                  itemBuilder: (_, i) => FadeSlideIn(
                    index: i,
                    child: ListenableBuilder(
                      listenable: store, // refresca cuando cambia la foto
                      builder: (context, _) => ProductCard(
                        product: items[i],
                        inCart: _inCart(items[i]),
                        size: _sizeOf(items[i]),
                        onSize: (s) => setState(() => _sizes[items[i]] = s),
                        onAdd: () => _add(items[i]),
                        onLongPress: () => editDishPhoto(context, items[i]),
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );

    if (tablet) {
      return KScaffold(
        body: Row(
          children: [
            Expanded(child: catalog),
            Padding(
              padding: EdgeInsets.fromLTRB(
                0,
                KSpace.l,
                context.gutter,
                KSpace.l,
              ),
              child: SizedBox(
                width: context.isWide ? 400 : 340,
                child: KosteoCard(
                  padding: const EdgeInsets.all(KSpace.xl),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          Text('Pedido', style: KText.title),
                          const SizedBox(width: KSpace.s),
                          PopSwitcher(
                            child: Text(
                              '($_items)',
                              key: ValueKey(_items),
                              style: KText.title.copyWith(
                                color: KColors.inkMuted,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: KSpace.l),
                      Expanded(
                        child: _cart.isEmpty
                            ? const Center(
                                child: EmptyState(
                                  icon: KIcons.shrimp,
                                  title: 'Pedido vacío',
                                  message: 'Toca un platillo para agregarlo.',
                                ),
                              )
                            : SingleChildScrollView(
                                child: _CartContents(
                                  lines: _cart,
                                  locked: _locked,
                                  onQty: _changeQty,
                                  onClear: _clearCart,
                                  total: _total,
                                  showFooter: false,
                                ),
                              ),
                      ),
                      _TotalRow(total: _total),
                      const SizedBox(height: KSpace.l),
                      PrimaryButton(
                        label: _editing ? 'Guardar cambios' : 'Guardar pedido',
                        icon: KIcons.checkStrong,
                        onTap: _cart.isEmpty ? null : _save,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    }

    return KScaffold(
      body: catalog,
      bottom: AnimatedSlide(
        offset: _cart.isEmpty ? const Offset(0, 1.4) : Offset.zero,
        duration: KMotion.slow,
        curve: KMotion.spring,
        child: BottomActionBar(
          child: Row(
            children: [
              Expanded(
                child: Pressable(
                  onTap: _openCart,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: KSpace.m),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                '$_items ${_items == 1 ? 'producto' : 'productos'}',
                                style: KText.caption,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(width: 4),
                            const Icon(
                              KIcons.caretUpStrong,
                              size: 12,
                              color: KColors.inkMuted,
                            ),
                          ],
                        ),
                        AnimatedMoney(_total, style: KText.title),
                      ],
                    ),
                  ),
                ),
              ),
              PrimaryButton(
                label: _editing ? 'Guardar' : 'Guardar pedido',
                expand: false,
                onTap: _save,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TotalRow extends StatelessWidget {
  const _TotalRow({required this.total});
  final num total;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: KSpace.m),
    child: Row(
      children: [
        Text('Total', style: KText.body.copyWith(color: KColors.inkSoft)),
        const Spacer(),
        AnimatedMoney(total, style: KText.display.copyWith(fontSize: 28)),
      ],
    ),
  );
}

/// Líneas del carrito con stepper; se reutiliza en sheet (teléfono) y panel (tablet).
class _CartContents extends StatelessWidget {
  const _CartContents({
    required this.lines,
    required this.onQty,
    required this.onClear,
    required this.total,
    this.onSave,
    this.showFooter = true,
    this.locked,
    this.saveLabel = 'Guardar pedido',
    this.clearLabel = 'Vaciar pedido',
  });

  final List<OrderLine> lines;
  final void Function(OrderLine, int) onQty;
  final VoidCallback onClear;
  final num total;
  final VoidCallback? onSave;
  final bool showFooter;
  final bool Function(OrderLine)? locked;
  final String saveLabel;
  final String clearLabel;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final l in lines)
          Padding(
            padding: const EdgeInsets.only(bottom: KSpace.m),
            child: Row(
              children: [
                SizedBox.square(
                  dimension: 44,
                  child: DishImage(product: l.product, radius: 14),
                ),
                const SizedBox(width: KSpace.m),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l.name,
                        style: KText.bodyStrong.copyWith(fontSize: 14),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        [
                          if (l.detail.isNotEmpty) l.detail,
                          money(l.total),
                        ].join(' · '),
                        style: KText.caption,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                if (locked?.call(l) ?? false)
                  Text('×${l.qty}', style: KText.bodyStrong)
                else
                  QtyStepper(
                    value: l.qty,
                    compact: true,
                    onChanged: (q) => onQty(l, q.toInt()),
                  ),
              ],
            ),
          ),
        if (showFooter) ...[
          Align(
            alignment: Alignment.centerLeft,
            child: SoftButton(
              label: clearLabel,
              icon: KIcons.trash,
              color: KColors.danger,
              expand: false,
              height: 40,
              onTap: onClear,
            ),
          ),
          _TotalRow(total: total),
          const SizedBox(height: KSpace.l),
          PrimaryButton(
            label: saveLabel,
            icon: KIcons.checkStrong,
            onTap: onSave,
          ),
        ],
      ],
    );
  }
}

/// Sheet pequeña: complementos, extras y cantidad. Todo con toques.
class _ProductOptionsSheet extends StatefulWidget {
  const _ProductOptionsSheet({required this.product, this.size});
  final Product product;
  final String? size;

  @override
  State<_ProductOptionsSheet> createState() => _ProductOptionsSheetState();
}

class _ProductOptionsSheetState extends State<_ProductOptionsSheet> {
  late final Set<String> _sides = {
    if (widget.product.sides.isNotEmpty) widget.product.sides.first,
  };
  final Set<String> _extras = {};
  int _qty = 1;

  num get _total =>
      ((widget.product.priceFor(widget.size) ?? 0) +
          _extras.fold<num>(0, (v, e) => v + widget.product.optionPrice(e)) +
          _sides.fold<num>(0, (v, s) => v + widget.product.optionPrice(s))) *
      _qty;

  @override
  Widget build(BuildContext context) {
    final p = widget.product;
    return SheetBody(
      title: p.name,
      subtitle: [?widget.size, money(p.priceFor(widget.size))].join(' · '),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            height: 140,
            child: DishImage(product: p, radius: KRadius.card),
          ),
          const SizedBox(height: KSpace.xl),
          const FieldLabel('Complementos'),
          if (p.sides.length > 1)
            Row(
              children: [
                for (final s in p.sides) ...[
                  if (s != p.sides.first) const SizedBox(width: KSpace.s),
                  Expanded(
                    child: ChoiceTile(
                      label: s,
                      icon: s == 'Tostitos' ? KIcons.chips : KIcons.tostada,
                      selected: _sides.contains(s),
                      onTap: () => setState(() {
                        if (!_sides.add(s)) _sides.remove(s);
                      }),
                    ),
                  ),
                ],
              ],
            ),
          const SizedBox(height: KSpace.xl),
          const FieldLabel('Extras', optional: true),
          Wrap(
            spacing: KSpace.s,
            runSpacing: KSpace.s,
            children: [
              for (final e in p.extras)
                ChoiceTile(
                  label: e,
                  caption: isOptionalIngredient(e)
                      ? 'Ingrediente opcional'
                      : p.optionPriceOrNull(e) == null
                      ? 'Precio pendiente'
                      : '+${money(p.optionPrice(e))}',
                  icon: KIcons.fruit,
                  selected: _extras.contains(e),
                  onTap: () {
                    if (p.optionPriceOrNull(e) == null) {
                      showErrorToast(
                        context,
                        'Configura primero el precio del extra.',
                      );
                      return;
                    }
                    setState(
                      () => _extras.contains(e)
                          ? _extras.remove(e)
                          : _extras.add(e),
                    );
                  },
                ),
            ],
          ),
          const SizedBox(height: KSpace.xl),
          Row(
            children: [
              QtyStepper(
                value: _qty,
                min: 1,
                onChanged: (q) => setState(() => _qty = q.toInt().clamp(1, 99)),
              ),
              const SizedBox(width: KSpace.m),
              Expanded(
                child: PrimaryButton(
                  label: 'Agregar · ${money(_total)}',
                  onTap: p.sides.isNotEmpty && _sides.isEmpty
                      ? null
                      : () => Navigator.of(context).pop(
                          OrderLine(
                            p,
                            _qty,
                            size: widget.size,
                            sides: p.sides.where(_sides.contains).toList(),
                            extras: _extras.toList(),
                          ),
                        ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _CustomerSheet extends StatefulWidget {
  const _CustomerSheet({
    this.current,
    this.phone,
    this.reference,
    this.notes,
    this.type = 'RECOGER',
  });
  final String? current, phone, reference, notes;
  final String type;
  @override
  State<_CustomerSheet> createState() => _CustomerSheetState();
}

class _CustomerSheetState extends State<_CustomerSheet> {
  late final _name = TextEditingController(text: widget.current),
      _phone = TextEditingController(text: widget.phone),
      _ref = TextEditingController(text: widget.reference),
      _notes = TextEditingController(text: widget.notes);
  late String _type = widget.type;
  @override
  void dispose() {
    for (final c in [_name, _phone, _ref, _notes]) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => SheetBody(
    title: '¿Para quién es?',
    subtitle: 'Nombre y teléfono opcionales',
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        KTextField(controller: _name, hint: 'Nombre', icon: KIcons.user),
        const SizedBox(height: KSpace.m),
        KTextField(
          controller: _phone,
          hint: 'Teléfono',
          keyboardType: TextInputType.phone,
        ),
        const SizedBox(height: KSpace.m),
        SegmentedPill<String>(
          values: const ['RECOGER', 'ENTREGA'],
          selected: _type,
          labelOf: (v) => v == 'RECOGER' ? 'Recoger' : 'Entrega',
          onChanged: (v) => setState(() => _type = v),
        ),
        if (_type == 'ENTREGA') ...[
          const SizedBox(height: KSpace.m),
          KTextField(controller: _ref, hint: 'Referencia corta'),
        ],
        const SizedBox(height: KSpace.m),
        KTextField(controller: _notes, hint: 'Notas (opcional)'),
        const SizedBox(height: KSpace.m),
        Wrap(
          spacing: KSpace.s,
          children: [
            for (final r in store.recentClients)
              ChoiceTile(
                label: r['cliente'] ?? r['telefono'] ?? '',
                selected: false,
                onTap: () {
                  _name.text = r['cliente'] ?? '';
                  _phone.text = r['telefono'] ?? '';
                },
              ),
          ],
        ),
        const SizedBox(height: KSpace.l),
        PrimaryButton(
          label: 'Listo',
          onTap: () => Navigator.of(context).pop({
            'name': _name.text.trim(),
            'phone': _phone.text.trim(),
            'type': _type,
            'reference': _type == 'ENTREGA' ? _ref.text.trim() : '',
            'notes': _notes.text.trim(),
          }),
        ),
      ],
    ),
  );
}
