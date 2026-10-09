import 'dart:typed_data';
import 'dart:convert';

import 'api_client.dart';

import 'package:flutter/material.dart';

import '../theme/icons.dart';
import '../theme/tokens.dart';

// ─────────────────────────── Modelos ───────────────────────────

bool isOptionalIngredient(String name) => name.trim().toLowerCase() == 'piña';

enum OrderStatus { pending, preparing, ready, delivering, delivered, cancelled }

extension OrderStatusX on OrderStatus {
  String get label => switch (this) {
    OrderStatus.pending => 'Pendiente',
    OrderStatus.preparing => 'Preparando',
    OrderStatus.ready => 'Listo',
    OrderStatus.delivering => 'En reparto',
    OrderStatus.delivered => 'Entregado',
    OrderStatus.cancelled => 'Cancelado',
  };

  String get filterLabel => switch (this) {
    OrderStatus.pending => 'Pendientes',
    OrderStatus.preparing => 'Preparando',
    OrderStatus.ready => 'Listos',
    OrderStatus.delivering => 'En reparto',
    OrderStatus.delivered => 'Entregados',
    OrderStatus.cancelled => 'Cancelados',
  };

  Color get color => switch (this) {
    OrderStatus.pending => KColors.coral,
    OrderStatus.preparing => KColors.sea,
    OrderStatus.ready => KColors.lagoon,
    OrderStatus.delivering => KColors.sun,
    OrderStatus.delivered => KColors.success,
    OrderStatus.cancelled => KColors.inkMuted,
  };
}

enum Period { today, week, shift }

extension PeriodX on Period {
  String get label => switch (this) {
    Period.today => 'Hoy',
    Period.week => 'Semana',
    Period.shift => 'Jornada',
  };
}

class Product {
  Product(
    this.name,
    this.price,
    this.category,
    this.icon,
    this.tint, {
    this.hasOptions = true,
    this.sizes,
  });

  // Editables desde la pestaña Productos.
  String name;

  /// Precio base (o de la primera presentación si hay tamaños).
  num? price;

  /// Presentaciones con su precio, p. ej. Individual $120 / Pa Compartir $190.
  Map<String, num?>? sizes;

  /// Foto persistida en SQL como Base64; si es null se usa su icono.
  Uint8List? image;

  String category;

  /// Pide complemento (tostadas/tostitos) y extras al agregarlo.
  bool hasOptions;

  /// Pausado: no aparece en Nuevo pedido (p. ej. se acabó el insumo).
  bool paused = false;

  final IconData icon;
  final Color tint;

  num? priceFor(String? size) => size == null ? price : sizes?[size];
  int id = 0;
  bool draft = false;
  Map<String, int> presentationIds = {};
  List<Map<String, dynamic>> options = [];
  List<String> get sides => options
      .where((o) => o['tipo'] == 'COMPLEMENTO')
      .map((o) => o['nombre'] as String)
      .toList();
  List<String> get extras => options
      .where((o) => o['tipo'] == 'EXTRA')
      .map((o) => o['nombre'] as String)
      .toList();
  num? optionPriceOrNull(String name) => isOptionalIngredient(name)
      ? 0
      : options.firstWhere((o) => o['nombre'] == name)['precioAdicional']
            as num?;
  num optionPrice(String name) => isOptionalIngredient(name)
      ? 0
      : options.firstWhere((o) => o['nombre'] == name)['precioAdicional']
                as num? ??
            0;
  int presentationId(String? size) =>
      presentationIds[size] ?? presentationIds.values.first;
  Product copy() =>
      Product(
          name,
          price,
          category,
          icon,
          tint,
          hasOptions: hasOptions,
          sizes: sizes == null ? null : Map.of(sizes!),
        )
        ..id = id
        ..draft = true
        ..image = image
        ..paused = paused
        ..presentationIds = Map.of(presentationIds)
        ..options = List.of(options);
}

class OrderLine {
  OrderLine(
    this.product,
    this.qty, {
    this.size,
    this.side,
    this.extras = const [],
  });
  final Product product;
  int qty;
  final String? size;
  final String? side;
  final List<String> extras;

  num? historicalPrice;
  String? historicalName;
  num? cost;
  num? fixedCondimentsApplied;
  String costState = 'INCOMPLETO';
  num get unitPrice =>
      historicalPrice ??
      (product.priceFor(size) ?? 0) +
          extras.fold<num>(0, (v, e) => v + product.optionPrice(e)) +
          (side == null ? 0 : product.optionPrice(side!));
  num get total => unitPrice * qty;
  String get name =>
      historicalName ??
      (size == null ? product.name : '${product.name} ${size!.toLowerCase()}');
  String get detail => [?side, ...extras.map((e) => '+ $e')].join(' · ');
}

class Order {
  Order(this.number, this.customer, this.time, this.lines, this.status);
  final int number;
  final String? customer;
  final String time;
  final List<OrderLine> lines;
  OrderStatus status;

  String get folio => '#${number.toString().padLeft(4, '0')}';
  num get total => lines.fold<num>(0, (s, l) => s + l.total);
  String tipoEntrega = 'RECOGER';
  String? phone, reference, notes;
  int? jornadaId;

  /// Siguiente estado y la acción contextual que lo dispara.
  (OrderStatus, String)? get nextStep => switch (status) {
    OrderStatus.pending => (OrderStatus.preparing, 'Iniciar preparación'),
    OrderStatus.preparing => (OrderStatus.ready, 'Marcar listo'),
    OrderStatus.ready =>
      tipoEntrega == 'ENTREGA'
          ? (OrderStatus.delivering, 'Enviar')
          : (OrderStatus.delivered, 'Entregado'),
    OrderStatus.delivering => (OrderStatus.delivered, 'Entregado'),
    OrderStatus.delivered || OrderStatus.cancelled => null,
  };
}

enum IngredientCategory { seafood, produce, extras, packaging }

extension IngredientCategoryX on IngredientCategory {
  String get label => switch (this) {
    IngredientCategory.seafood => 'Mariscos',
    IngredientCategory.produce => 'Frutería',
    IngredientCategory.extras => 'Extras',
    IngredientCategory.packaging => 'Empaque',
  };

  IconData get icon => switch (this) {
    IngredientCategory.seafood => KIcons.shrimp,
    IngredientCategory.produce => KIcons.greens,
    IngredientCategory.extras => KIcons.bottle,
    IngredientCategory.packaging => KIcons.box,
  };

  Color get tint => switch (this) {
    IngredientCategory.seafood => KColors.coral,
    IngredientCategory.produce => KColors.success,
    IngredientCategory.extras => KColors.sun,
    IngredientCategory.packaging => KColors.sea,
  };
}

class Ingredient {
  Ingredient(
    this.name,
    this.category,
    this.icon,
    this.buyUnit,
    this.useUnit, {
    this.hasYield = false,
    this.lastCost,
  });
  final String name;
  final IngredientCategory category;
  final IconData icon;
  final String buyUnit;
  final String useUnit;
  final bool hasYield;
  final num? lastCost;
  int id = 0;
  int categoryId = 0;
  bool measurable = true;
  bool get requiresUseful =>
      hasYield ||
      buyUnit != useUnit &&
          !(['kg', 'g'].contains(buyUnit) && useUnit == 'g') &&
          !(['L', 'ml'].contains(buyUnit) && useUnit == 'ml') &&
          name != 'Tostitos';
}

class Purchase {
  Purchase(this.ingredient, this.qty, this.total, this.time, {this.yieldValue});
  final Ingredient ingredient;
  final String time;

  // Editables después (p. ej. el rendimiento se conoce hasta pelar el camarón).
  num qty;
  num total;

  /// Rendimiento final en la unidad de uso (g, ml...). null = aún no capturado.
  num? yieldValue;

  int id = 0;
  int? jornadaId;
  DateTime date = DateTime.now();
  bool get needsYield => ingredient.measurable && yieldValue == null;

  String get qtyLabel =>
      '${_fmtQty(qty)} ${unitLabel(ingredient.buyUnit, qty)}';
}

class LeftoverItem {
  LeftoverItem(this.ingredient, this.theoretical) : counted = theoretical ?? 0;
  final Ingredient ingredient;
  final num? theoretical;
  num counted;
  bool touched = false;

  bool dirty = false;
  num? get diff => theoretical == null ? null : counted - theoretical!;
  int get step => switch (ingredient.useUnit) {
    'g' || 'ml' => 10,
    _ => 1,
  };
}

String statusCode(OrderStatus s) => const [
  'PENDIENTE',
  'EN_PREPARACION',
  'LISTO',
  'EN_REPARTO',
  'ENTREGADO',
  'CANCELADO',
][s.index];
OrderStatus parseStatus(String s) =>
    OrderStatus.values.firstWhere((v) => statusCode(v) == s);

class Metrics {
  const Metrics(
    this.sales,
    this.profit,
    this.cost,
    this.gas,
    this.salesDelta, {
    this.investment = 0,
    this.inventory,
    this.states = const [],
    this.sellers = const [],
  });
  final num sales, gas, investment;
  final num? profit, cost, salesDelta, inventory;
  final List<dynamic> states, sellers;
  int get orderCount =>
      states.fold<int>(0, (v, s) => v + (s['cantidad'] as num).toInt());
  int count(OrderStatus status) => states
      .where((s) => s['estado'] == statusCode(status))
      .fold<int>(0, (v, s) => v + (s['cantidad'] as num).toInt());
}

const productCategories = ['Todos', 'Aguachiles', 'Especiales', 'Bebidas'];

/// Categorías reales (sin "Todos").
List<String> get menuCategories => productCategories.skip(1).toList();

final List<Product> products = [];
const buyUnits = ['kg', 'g', 'L', 'ml', 'pza', 'bolsa', 'caja', 'paquete'];
const useUnits = ['g', 'ml', 'pza'];

/// Unidad de uso sugerida según cómo se compra.
String suggestedUseUnit(String buy) => switch (buy) {
  'kg' || 'g' => 'g',
  'L' || 'ml' => 'ml',
  _ => 'pza',
};

String unitLabel(String unit, num qty) => switch (unit) {
  'bolsa' => qty == 1 ? 'bolsa' : 'bolsas',
  'caja' => qty == 1 ? 'caja' : 'cajas',
  'paquete' => qty == 1 ? 'paquete' : 'paquetes',
  'pza' => qty == 1 ? 'pieza' : 'piezas',
  _ => unit,
};

String _fmtQty(num q) =>
    q == q.roundToDouble() ? q.toInt().toString() : q.toString();

String money(num? value) {
  if (value == null) return 'Pendiente';
  final parts = value.abs().toStringAsFixed(2).split('.');
  final whole = parts[0].replaceAllMapped(
    RegExp(r'\B(?=(\d{3})+(?!\d))'),
    (_) => ',',
  );
  return '${value < 0 ? '-' : ''}\$$whole${parts[1] == '00' ? '' : '.${parts[1]}'}';
}

String todayLabel() {
  const days = [
    'Lunes',
    'Martes',
    'Miércoles',
    'Jueves',
    'Viernes',
    'Sábado',
    'Domingo',
  ];
  const months = [
    'ene',
    'feb',
    'mar',
    'abr',
    'may',
    'jun',
    'jul',
    'ago',
    'sep',
    'oct',
    'nov',
    'dic',
  ];
  final d = DateTime.now();
  return '${days[d.weekday - 1]} ${d.day} ${months[d.month - 1]}, ${d.year}';
}

String greeting() {
  final h = DateTime.now().hour;
  return h < 12
      ? 'Buenos días Yahir'
      : (h < 19 ? 'Buenas tardes Yahir' : 'Buenas noches Yahir');
}

String nowTime() {
  final d = DateTime.now();
  final h = d.hour % 12 == 0 ? 12 : d.hour % 12;
  return '$h:${d.minute.toString().padLeft(2, '0')} ${d.hour < 12 ? 'a.m.' : 'p.m.'}';
}

(IconData, Color) appearance(String name) => switch (name) {
  'Aguachile Verde' => (KIcons.greens, const Color(0xFFE3F4E6)),
  'Aguachile Rojo' => (KIcons.chili, const Color(0xFFFDE6DD)),
  'Aguachile Negro' => (KIcons.shrimp, const Color(0xFFE8E6EF)),
  'Marea Brava' => (KIcons.waves, const Color(0xFFDDF0FA)),
  'Tormenta del Mar' => (KIcons.octopus, const Color(0xFFF8E4EC)),
  'Tostada de Atún' => (KIcons.fish, const Color(0xFFFFF0D9)),
  'Vaso preparado' => (KIcons.cup, const Color(0xFFFFE9DC)),
  'Clamato preparado' => (KIcons.glass, const Color(0xFFFDE3E1)),
  'Agua de piña' => (KIcons.fruit, const Color(0xFFFFF4D2)),
  _ => (KIcons.menu, const Color(0xFFE6F3FA)),
};
IconData ingredientAppearance(String name, IngredientCategory category) =>
    switch (name) {
      'Camarón' => KIcons.shrimp,
      'Atún' => KIcons.fish,
      'Callo de hacha' => KIcons.shell,
      'Pulpo' => KIcons.octopus,
      'Pepino' => KIcons.greens,
      'Cebolla morada' || 'Cebolla blanca' => KIcons.sprout,
      'Limón' => KIcons.citrus,
      'Chiltepín' ||
      'Serrano' ||
      'Habanero' ||
      'Chile mulato' ||
      'Chile poblano' => KIcons.chili,
      'Cilantro' => KIcons.leaf,
      'Piña' => KIcons.fruit,
      'Clamato' => KIcons.drop,
      'Salsa Maggi' || 'Salsa inglesa' => KIcons.bottle,
      'Tostitos' => KIcons.chips,
      'Tostadas' => KIcons.tostada,
      'Envase individual' || 'Envase compartir' => KIcons.box,
      'Vaso' => KIcons.cup,
      'Tenedor' => KIcons.menu,
      'Servilleta' => KIcons.napkin,
      'Bolsa' => KIcons.bag,
      'Etiqueta' => KIcons.tag,
      _ => category.icon,
    };
String dateOnly(DateTime d) =>
    '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
String timeOf(dynamic v) {
  final d = DateTime.parse(v as String).toLocal();
  return '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
}

class KosteoStore extends ChangeNotifier {
  KosteoStore({ApiClient? client}) : api = client ?? ApiClient();
  final ApiClient api;
  bool saving = false;
  bool loading = false, loaded = false;
  String? error;
  final Map<Period, Metrics> metrics = {
    for (final p in Period.values) p: const Metrics(0, null, null, 0, null),
  };
  final List<Ingredient> ingredients = [];
  final List<Order> orders = [];
  final List<Purchase> purchases = [];
  final List<LeftoverItem> leftovers = [];
  final List<num> gasEntries = [];
  List<dynamic> units = [], categories = [], jornadas = [], recentClients = [];
  Map<String, dynamic>? jornada;
  int? selectedJornadaId;
  String? inventoryRead;
  Period dashboardPeriod = Period.today;
  final ordersFilter = ValueNotifier(OrderStatus.pending);
  int? get jornadaId => selectedJornadaId ?? jornada?['jornadaId'] as int?;
  int? get jornadaAbiertaId {
    for (final j in jornadas) {
      if (j['estado'] == 'ABIERTA') return j['jornadaId'] as int;
    }
    return null;
  }

  bool get shiftClosed => jornada?['estado'] == 'CERRADA';
  List<Order> get ordersDeJornada => orders
      .where((o) => jornadaId != null && o.jornadaId == jornadaId)
      .toList();
  int countByJornada(OrderStatus status) =>
      ordersDeJornada.where((o) => o.status == status).length;
  int unitId(String code) =>
      units.firstWhere((u) => u['codigo'] == code)['unidadId'] as int;
  Ingredient ingredient(int id) => ingredients.firstWhere((i) => i.id == id);
  Product product(int id) => products.firstWhere(
    (p) => p.id == id,
    orElse: () => Product(
      'Producto histórico',
      null,
      'Especiales',
      KIcons.menu,
      KColors.mist,
    )..id = id,
  );
  Future<void> load() async {
    if (loading) return;
    loading = true;
    error = null;
    notifyListeners();
    try {
      await catalogs();
      await menu();
      await refresh();
      loaded = true;
    } catch (e) {
      error = e.toString();
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  Future<void> catalogs() async {
    final c = await api.get('/insumos/catalogos');
    categories = c['categorias'];
    units = c['unidades'];
    ingredients.clear();
    for (final r in await api.get('/insumos') as List) {
      final cat = IngredientCategory.values.firstWhere(
        (v) => categories.any(
          (c) =>
              c['categoriaInsumoId'] == r['categoriaInsumoId'] &&
              c['orden'] == v.index + 1,
        ),
        orElse: () => IngredientCategory.extras,
      );
      ingredients.add(
        Ingredient(
            r['nombre'],
            cat,
            ingredientAppearance(r['nombre'], cat),
            r['unidadCompra'],
            r['unidadUso'],
            hasYield: r['manejaRendimiento'] == true,
            lastCost: r['ultimoCostoCompra'],
          )
          ..id = r['insumoId']
          ..categoryId = r['categoriaInsumoId']
          ..measurable = r['tratamientoCosteo'] == 'MEDIBLE',
      );
    }
  }

  Future<void> menu() async {
    final rows = await api.get('/platillos') as List;
    products.clear();
    for (final r in rows) {
      // Individual siempre primero: es la presentación por defecto al pedir.
      final ps =
          (r['presentaciones'] as List)
              .where((s) => s['activa'] == true)
              .toList()
            ..sort(
              (a, b) =>
                  (a['nombre'] == 'Individual' ? 0 : 1) -
                  (b['nombre'] == 'Individual' ? 0 : 1),
            );
      final primary = ps.firstOrNull;
      final cat =
          const {
            'AGUACHILES': 'Aguachiles',
            'ESPECIALES': 'Especiales',
            'BEBIDAS': 'Bebidas',
          }[r['categoria']] ??
          'Especiales';
      final opts = (r['opciones'] as List)
          .where((o) => o['activa'] == true)
          .map((o) => Map<String, dynamic>.from(o))
          .toList();
      products.add(
        Product(
            r['nombre'],
            primary?['precioVenta'],
            cat,
            appearance(r['nombre']).$1,
            appearance(r['nombre']).$2,
            hasOptions: opts.isNotEmpty,
            sizes: ps.length > 1
                ? {
                    for (final s in ps)
                      s['nombre'] as String: s['precioVenta'] as num?,
                  }
                : null,
          )
          ..id = r['platilloId']
          ..paused = r['pausado'] == true
          ..options = opts
          ..presentationIds = {
            for (final s in ps)
              s['nombre'] as String: s['presentacionId'] as int,
          }
          ..image = r['fotoBase64'] == null
              ? null
              : base64Decode(r['fotoBase64']),
      );
    }
  }

  Future<void> refresh() async {
    jornadas = await api.get('/jornadas') as List;
    jornada = selectedJornadaId == null
        ? await api.get('/jornadas/activa')
        : Map<String, dynamic>.from(
            jornadas.firstWhere((j) => j['jornadaId'] == selectedJornadaId),
          );
    if (jornada == null && jornadas.isNotEmpty) {
      jornada = Map<String, dynamic>.from(jornadas.first);
    }
    purchases.clear();
    for (final r in await api.get('/compras') as List) {
      purchases.add(
        Purchase(
            ingredient(r['insumoId']),
            r['cantidadCompra'],
            r['importeTotal'],
            timeOf(r['fechaCompra']),
            yieldValue: r['cantidadUtil'],
          )
          ..id = r['compraId']
          ..jornadaId = r['jornadaId']
          ..date = DateTime.parse(r['fechaCompra']).toLocal(),
      );
    }
    orders.clear();
    final data = await api.get('/pedidos', {
      'jornadaId': jornadaId,
      'incluirSinJornada': true,
    });
    for (final r in data['pedidos']) {
      final lines = <OrderLine>[];
      for (final l in r['lineas']) {
        final opts = l['opciones'] as List;
        final pr =
            products
                .where(
                  (p) => p.presentationIds.values.contains(l['presentacionId']),
                )
                .firstOrNull ??
            Product(
              l['nombrePlatillo'],
              l['precioUnitario'],
              'Especiales',
              KIcons.menu,
              KColors.mist,
            );
        lines.add(
          OrderLine(
              pr,
              (l['cantidad'] as num).toInt(),
              size: l['nombrePresentacion'],
              side: opts
                  .where((o) => o['tipo'] == 'COMPLEMENTO')
                  .map((o) => o['nombre'] as String)
                  .firstOrNull,
              extras: opts
                  .where((o) => o['tipo'] == 'EXTRA')
                  .map((o) => o['nombre'] as String)
                  .toList(),
            )
            ..historicalName =
                '${l['nombrePlatillo']} ${l['nombrePresentacion']}'
            ..historicalPrice =
                (l['precioUnitario'] as num) +
                opts.fold<num>(
                  0,
                  (v, o) => v + (o['precioAdicionalAplicado'] as num),
                )
            ..cost = l['costoUnitarioEstimado']
            ..costState = l['estadoCosteo']
            ..fixedCondimentsApplied = l['costoFijoCondimentosAplicado'],
        );
      }
      orders.add(
        Order(
            r['pedidoId'],
            r['cliente'],
            timeOf(r['fechaPedido']),
            lines,
            parseStatus(r['estado']),
          )
          ..tipoEntrega = r['tipoEntrega']
          ..phone = r['telefono']
          ..reference = r['referenciaEntrega']
          ..notes = r['notas']
          ..jornadaId = r['jornadaId'],
      );
    }
    recentClients = await api.get('/pedidos/clientes-recientes');
    gasEntries.clear();
    for (final g
        in await api.get('/gastos-reparto', {'jornadaId': jornadaId}) as List) {
      gasEntries.add(g['monto']);
    }
    await inventory();
    for (final p in Period.values) {
      final m = await api.get('/dashboard', {
        'periodo': const ['HOY', 'SEMANA', 'JORNADA'][p.index],
        'jornadaId': p == Period.shift ? jornadaId : null,
      });
      metrics[p] = Metrics(
        m['ventas'],
        m['gananciaEstimada'],
        m['costoConsumido'],
        m['gasolina'],
        m['variacionVentas'],
        investment: m['inversion'],
        inventory: m['inventarioSobrante'],
        states: m['estados'],
        sellers: m['topSellers'],
      );
    }
    notifyListeners();
  }

  Future<void> inventory() async {
    final d = await api.get('/inventario', {'jornadaId': jornadaId});
    inventoryRead = d['fechaLectura'];
    leftovers.clear();
    for (final r in d['items']) {
      leftovers.add(
        LeftoverItem(ingredient(r['insumoId']), r['cantidadTeorica'])
          ..counted = (r['cantidadFisica'] ?? r['cantidadTeorica'] ?? 0)
          ..touched = r['cantidadFisica'] != null,
      );
    }
  }

  Future<void> mutate(
    String method,
    String path,
    Map<String, dynamic>? body,
  ) async {
    await api.request(method, path, body: body);
    try {
      await catalogs();
      await menu();
      await refresh();
      error = null;
    } catch (e) {
      error = 'Guardado. No se pudo actualizar la vista: $e';
      notifyListeners();
    }
  }

  List<dynamic> yieldUnits(Ingredient i) {
    final base = units.firstWhere((u) => u['codigo'] == i.useUnit);
    return units
        .where(
          (u) => u['dimension'] == base['dimension'] && u['factorBase'] != null,
        )
        .toList();
  }

  num yieldFactor(String? code) => code == null
      ? 1
      : units.firstWhere((u) => u['codigo'] == code)['factorBase'] as num;
  List<Ingredient> ingredientsIn(IngredientCategory c) =>
      ingredients.where((i) => i.category == c).toList();
  Future<void> addIngredient(Ingredient i) async {
    final r = await api.request(
      'POST',
      '/insumos',
      body: {
        'nombre': i.name,
        'categoriaInsumoId': categories.firstWhere(
          (c) => c['orden'] == i.category.index + 1,
        )['categoriaInsumoId'],
        'unidadCompraId': unitId(i.buyUnit),
        'unidadUsoId': unitId(i.useUnit),
        'manejaRendimiento': i.hasYield,
      },
    );
    i.id = r['insumoId'];
    try {
      await catalogs();
    } catch (e) {
      error = 'Insumo guardado. Reintenta actualizar la vista.';
    }
    notifyListeners();
  }

  List<Purchase> purchasesFor(Period p) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    return purchases
        .where(
          (x) => p == Period.shift
              ? x.jornadaId == jornadaId
              : p == Period.today
              ? dateOnly(x.date) == dateOnly(now)
              : !x.date.isBefore(
                      today.subtract(Duration(days: now.weekday - 1)),
                    ) &&
                    x.date.isBefore(today.add(Duration(days: 8 - now.weekday))),
        )
        .toList();
  }

  num get purchasesTotal => purchases.fold<num>(0, (v, p) => v + p.total);
  Map<IngredientCategory, num> purchasesCategories(Period period) {
    final map = <IngredientCategory, num>{};
    for (final p in purchasesFor(period)) {
      map[p.ingredient.category] = (map[p.ingredient.category] ?? 0) + p.total;
    }
    return map;
  }

  int get purchasesMissingYield => purchases.where((p) => p.needsYield).length;
  Future<void> addPurchase(
    Ingredient i,
    num qty,
    num total, {
    num? yieldValue,
    String? yieldUnit,
  }) => mutate('POST', '/compras', {
    'claveOperacion': operationKey(),
    'insumoId': i.id,
    'cantidadCompra': qty,
    'importeTotal': total,
    'cantidadUtil': yieldValue,
    'unidadRendimientoId': unitId(yieldUnit ?? i.useUnit),
    'jornadaId': shiftClosed ? null : jornadaId,
  });
  Future<void> updatePurchase(
    Purchase p, {
    required num qty,
    required num total,
    num? yieldValue,
    String? yieldUnit,
  }) => mutate('PATCH', '/compras/${p.id}', {
    'cantidadCompra': qty,
    'importeTotal': total,
    'cantidadUtil': p.ingredient.requiresUseful ? yieldValue : null,
    'unidadRendimientoId': unitId(yieldUnit ?? p.ingredient.useUnit),
  });
  Future<void> removePurchase(Purchase p) =>
      mutate('DELETE', '/compras/${p.id}', null);
  int countBy(OrderStatus s) => orders.where((o) => o.status == s).length;
  List<Order> ordersBy(OrderStatus s) =>
      orders.where((o) => o.status == s).toList();
  Future<void> advance(Order o) async {
    if (o.nextStep != null) await changeStatus(o, o.nextStep!.$1);
  }

  Future<void> changeStatus(Order o, OrderStatus state) =>
      mutate('PATCH', '/pedidos/${o.number}/estado', {
        'claveOperacion': operationKey(),
        'estadoNuevo': statusCode(state),
        'estadoAnterior': statusCode(o.status),
      });
  Future<Order> addOrder(
    List<OrderLine> lines, {
    String? customer,
    String? phone,
    String type = 'RECOGER',
    String? reference,
    String? notes,
    bool sinJornada = false,
  }) async {
    final destino = sinJornada ? null : jornadaAbiertaId;
    final r = await api.request(
      'POST',
      '/pedidos',
      body: {
        'claveOperacion': operationKey(),
        'jornadaId': destino,
        'sinJornada': destino == null,
        'cliente': customer,
        'telefono': phone,
        'tipoEntrega': type,
        'referenciaEntrega': reference,
        'notas': notes,
        'lineas': lines
            .map(
              (l) => {
                'presentacionId': l.product.presentationId(l.size),
                'cantidad': l.qty,
                'opciones': l.product.options
                    .where(
                      (o) =>
                          o['nombre'] == l.side ||
                          l.extras.contains(o['nombre']),
                    )
                    .map((o) => o['opcionId'])
                    .toList(),
              },
            )
            .toList(),
      },
    );
    try {
      await refresh();
      return orders.firstWhere((o) => o.number == r['pedidoId']);
    } catch (e) {
      error = 'Pedido guardado. Reintenta actualizar la vista.';
      notifyListeners();
      return Order(
          r['pedidoId'],
          customer,
          nowTime(),
          lines,
          OrderStatus.pending,
        )
        ..tipoEntrega = type
        ..phone = phone
        ..reference = reference
        ..notes = notes
        ..jornadaId = destino;
    }
  }

  Future<void> asignarPedidos(List<int> ids, int jornada) => mutate(
    'PATCH',
    '/pedidos/jornada',
    {'pedidoIds': ids, 'jornadaId': jornada},
  );

  List<(Product, int)> get topSellers => metrics[dashboardPeriod]!.sellers
      .map(
        (r) => (
          products.firstWhere(
            (p) => p.id == r['platilloId'],
            orElse: () => Product(
              r['nombrePlatillo'],
              null,
              'Especiales',
              KIcons.menu,
              KColors.mist,
            )..id = r['platilloId'],
          ),
          (r['cantidad'] as num).toInt(),
        ),
      )
      .toList();
  Future<void> saveProduct(Product p) async {
    final body = <String, dynamic>{
      'nombre': p.name,
      'categoria': const {
        'Aguachiles': 'AGUACHILES',
        'Especiales': 'ESPECIALES',
        'Bebidas': 'BEBIDAS',
      }[p.category],
      'pausado': p.paused,
      'presentaciones':
          (p.sizes ?? {p.presentationIds.keys.firstOrNull ?? 'Única': p.price})
              .entries
              .map((e) => {'nombre': e.key, 'precio': e.value})
              .toList(),
      'opciones': p.hasOptions
          ? (p.options.isEmpty
                ? [
                    {
                      'tipo': 'COMPLEMENTO',
                      'nombre': 'Tostitos',
                      'precioAdicional': 0,
                    },
                    {
                      'tipo': 'COMPLEMENTO',
                      'nombre': 'Tostadas',
                      'precioAdicional': 0,
                    },
                    {'tipo': 'EXTRA', 'nombre': 'Piña', 'precioAdicional': 0},
                  ]
                : p.options
                      .map(
                        (o) => {
                          'tipo': o['tipo'],
                          'nombre': o['nombre'],
                          'precioAdicional': isOptionalIngredient(o['nombre'])
                              ? 0
                              : o['precioAdicional'],
                        },
                      )
                      .toList())
          : [],
    };
    final r = await api.request(
      p.id == 0 ? 'POST' : 'PATCH',
      p.id == 0 ? '/platillos' : '/platillos/${p.id}',
      body: body,
    );
    p.id = r['platilloId'];
    try {
      await persistPhoto(p);
    } on ApiException catch (e) {
      throw ApiException(
        'Producto guardado, pero no se pudo guardar la foto. ${e.message}',
        e.status,
      );
    }
    try {
      await menu();
      await refresh();
      error = null;
    } catch (_) {
      error = 'Producto guardado. No se pudo actualizar la vista; vuelve a cargarla.';
      notifyListeners();
    }
  }

  Future<void> addProduct(Product p) => saveProduct(p);
  Future<void> removeProduct(Product p) =>
      mutate('DELETE', '/platillos/${p.id}', null);
  Future<void> togglePaused(Product p) =>
      mutate('PATCH', '/platillos/${p.id}', {'pausado': !p.paused});
  void productChanged() => notifyListeners();
  Future<void> persistPhoto(Product p) async {
    if (p.image == null) {
      await api.request('DELETE', '/platillos/${p.id}/foto');
      return;
    }
    final b = p.image!;
    if (b.length > 2097152) {
      throw ApiException('La foto debe pesar menos de 2 MB.');
    }
    final mime = b.length > 8 && b[0] == 137
        ? 'image/png'
        : b.length > 3 && b[0] == 255
        ? 'image/jpeg'
        : 'image/webp';
    await api.request(
      'PUT',
      '/platillos/${p.id}/foto',
      body: {'fotoBase64': base64Encode(b), 'fotoMime': mime},
    );
  }

  Future<void> setProductImage(Product p, Uint8List? bytes) async {
    if (bytes != null && bytes.length > 2097152) {
      throw ApiException('La foto debe pesar menos de 2 MB.');
    }
    final previous = p.image;
    p.image = bytes;
    try {
      if (!p.draft && p.id != 0) await persistPhoto(p);
    } catch (e) {
      p.image = previous;
      rethrow;
    }
    notifyListeners();
  }

  List<LeftoverItem> leftoversIn(IngredientCategory c) =>
      leftovers.where((l) => l.ingredient.category == c).toList();
  void setCount(LeftoverItem l, num v) {
    l
      ..counted = num.parse(v.clamp(0, 999999999).toStringAsFixed(8))
      ..touched = true
      ..dirty = true;
    notifyListeners();
  }

  Future<void> saveCounts() async {
    try {
      for (final l in leftovers.where((l) => l.dirty)) {
        await api.request(
          'PUT',
          '/jornadas/$jornadaId/conteo',
          body: {
            'insumoId': l.ingredient.id,
            'cantidadFisica': l.counted,
            'teoricoLeido': l.theoretical,
            'fechaLectura': inventoryRead,
          },
        );
        l.dirty = false;
      }
      await refresh();
    } on ApiException catch (e) {
      if (e.status == 409) {
        await inventory();
        notifyListeners();
      }
      rethrow;
    }
  }

  num get gasTotal => gasEntries.fold<num>(0, (v, g) => v + g);
  Future<void> addGas(num amount, {String? comment}) =>
      mutate('POST', '/gastos-reparto', {
        'claveOperacion': operationKey(),
        'monto': amount,
        'comentario': comment,
        'jornadaId': jornadaId,
      });
  Future<void> closeShift() =>
      mutate('POST', '/jornadas/$jornadaId/cierre', {});
  Future<void> noGas() => mutate('PATCH', '/jornadas/$jornadaId/sin-gasolina', {
    'confirmado': true,
  });
  Future<void> openShift(DateTime start, DateTime end) async {
    selectedJornadaId = null;
    await mutate('POST', '/jornadas', {
      'fechaInicio': dateOnly(start),
      'fechaFin': dateOnly(end),
    });
  }

  Future<void> selectShift(int id) async {
    selectedJornadaId = id;
    await refresh();
  }
}

KosteoStore store = KosteoStore();
