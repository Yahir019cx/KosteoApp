import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../data/app_store.dart';
import '../theme/icons.dart';
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
import 'product_cost_sheet.dart';

/// Alta o edición de un producto del menú: foto, nombre, categoría, precio
/// (o Individual/Pa Compartir), si pide complemento y disponibilidad.
class ProductEditScreen extends StatefulWidget {
  const ProductEditScreen({super.key, this.product});

  /// null = producto nuevo.
  final Product? product;

  @override
  State<ProductEditScreen> createState() => _ProductEditScreenState();
}

class _ProductEditScreenState extends State<ProductEditScreen> {
  // Borrador: los cambios se aplican al guardar (incluida la foto).
  late final Product _draft =
      widget.product?.copy() ??
      Product(
        '',
        0,
        menuCategories.first,
        KIcons.menu,
        const Color(0xFFE6F3FA),
        sizes: null,
      );

  late final _name = TextEditingController(text: _draft.name);
  late final _price = TextEditingController(
    text: _draft.price == null || _draft.price == 0 ? '' : '${_draft.price}',
  );
  late final _single = TextEditingController(
    text: '${_draft.sizes?['Individual'] ?? ''}',
  );
  late final _double = TextEditingController(
    text: '${_draft.sizes?['Pa Compartir'] ?? ''}',
  );
  late String _category = _draft.category;
  late bool _hasSizes = _draft.sizes != null;
  late bool _hasOptions = _draft.hasOptions;
  late bool _available = !_draft.paused;

  bool get _isNew => widget.product == null;

  @override
  void initState() {
    super.initState();
    for (final c in [_name, _price, _single, _double]) {
      c.addListener(() => setState(() {}));
    }
  }

  @override
  void dispose() {
    for (final c in [_name, _price, _single, _double]) {
      c.dispose();
    }
    super.dispose();
  }

  num? _int(TextEditingController c) =>
      num.tryParse(c.text.replaceAll(',', '.'));

  bool get _valid =>
      _name.text.trim().isNotEmpty &&
      (_hasSizes
          ? (_int(_single) ?? 0) > 0 && (_int(_double) ?? 0) > 0
          : (_int(_price) ?? 0) > 0);

  Future<void> _save() => runAction(context, () async {
    final p = _draft
      ..name = _name.text.trim()
      ..category = _category
      ..hasOptions = _hasOptions
      ..paused = !_available;
    if (_hasSizes) {
      p
        ..sizes = {'Individual': _int(_single)!, 'Pa Compartir': _int(_double)!}
        ..price = _int(_single)!;
    } else {
      p
        ..sizes = null
        ..price = _int(_price)!;
    }
    await store.saveProduct(p);
    if (!mounted) return;
    showToast(
      context,
      _isNew ? '${p.name} agregado al menú' : 'Cambios guardados',
    );
    Navigator.of(context).pop();
  });

  Future<void> _delete() async {
    final ok = await showGlassSheet<bool>(
      context,
      builder: (context) => SheetBody(
        title: '¿Eliminar ${_draft.name}?',
        subtitle: 'Si solo se acabó por hoy, mejor páusalo.',
        child: Row(
          children: [
            Expanded(
              child: SoftButton(
                label: 'Cancelar',
                height: 56,
                onTap: () => Navigator.of(context).pop(false),
              ),
            ),
            const SizedBox(width: KSpace.m),
            Expanded(
              child: PrimaryButton(
                label: 'Eliminar',
                color: KColors.danger,
                onTap: () => Navigator.of(context).pop(true),
              ),
            ),
          ],
        ),
      ),
    );
    if (ok != true || !mounted) return;
    await runAction(context, () async {
      await store.removeProduct(_draft);
      if (!mounted) return;
      showToast(context, '${_draft.name} eliminado', color: KColors.danger);
      Navigator.of(context).pop();
    });
  }

  @override
  Widget build(BuildContext context) {
    final digits = [FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]'))];
    return KScaffold(
      body: ContentWidth(
        maxWidth: 680,
        child: Column(
          children: [
            PageHeader(
              title: _isNew ? 'Nuevo producto' : 'Editar producto',
              back: true,
              actions: [
                if (!_isNew)
                  CircleIconButton(
                    icon: KIcons.trash,
                    color: KColors.danger,
                    semanticLabel: 'Eliminar',
                    onTap: _delete,
                  ),
              ],
            ),
            Expanded(
              child: ListView(
                padding: EdgeInsets.fromLTRB(
                  context.gutter,
                  0,
                  context.gutter,
                  140,
                ),
                children: [
                  // Foto: tocar para poner o cambiar.
                  FadeSlideIn(
                    child: ListenableBuilder(
                      listenable: store,
                      builder: (context, _) => Pressable(
                        onTap: () => editDishPhoto(context, _draft),
                        scale: 0.98,
                        child: AspectRatio(
                          aspectRatio: 16 / 10,
                          child: Stack(
                            fit: StackFit.expand,
                            children: [
                              DishImage(product: _draft, radius: KRadius.card),
                              Positioned(
                                right: KSpace.m,
                                bottom: KSpace.m,
                                child: Container(
                                  height: 36,
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: KSpace.m,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(
                                      KRadius.chip,
                                    ),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(
                                        KIcons.camera,
                                        size: 16,
                                        color: KColors.ink,
                                      ),
                                      const SizedBox(width: 6),
                                      Text(
                                        _draft.image == null
                                            ? 'Agregar foto'
                                            : 'Cambiar foto',
                                        style: KText.caption.copyWith(
                                          color: KColors.ink,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: KSpace.xl),
                  _Block(
                    label: 'Nombre',
                    child: KTextField(
                      controller: _name,
                      hint: 'Ej. Aguachile Mango',
                      autofocus: _isNew,
                    ),
                  ),
                  _Block(
                    label: 'Categoría',
                    child: Wrap(
                      spacing: KSpace.s,
                      runSpacing: KSpace.s,
                      children: [
                        for (final c in menuCategories)
                          ChoiceTile(
                            label: c,
                            selected: c == _category,
                            onTap: () => setState(() => _category = c),
                          ),
                      ],
                    ),
                  ),
                  _Block(
                    label: '¿Tiene individual y para compartir?',
                    child: _YesNo(
                      value: _hasSizes,
                      onChanged: (v) => setState(() => _hasSizes = v),
                    ),
                  ),
                  AnimatedSize(
                    duration: KMotion.base,
                    curve: KMotion.ease,
                    alignment: Alignment.topCenter,
                    child: _hasSizes
                        ? _Block(
                            label: 'Precios',
                            child: Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text('Individual', style: KText.caption),
                                      const SizedBox(height: 6),
                                      KTextField(
                                        controller: _single,
                                        hint: '0',
                                        prefix: '\$',
                                        keyboardType:
                                            const TextInputType.numberWithOptions(
                                              decimal: true,
                                            ),
                                        inputFormatters: digits,
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: KSpace.m),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Pa Compartir',
                                        style: KText.caption,
                                      ),
                                      const SizedBox(height: 6),
                                      KTextField(
                                        controller: _double,
                                        hint: '0',
                                        prefix: '\$',
                                        keyboardType:
                                            const TextInputType.numberWithOptions(
                                              decimal: true,
                                            ),
                                        inputFormatters: digits,
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          )
                        : _Block(
                            label: 'Precio',
                            child: KTextField(
                              controller: _price,
                              hint: '0',
                              prefix: '\$',
                              keyboardType:
                                  const TextInputType.numberWithOptions(
                                    decimal: true,
                                  ),
                              inputFormatters: digits,
                            ),
                          ),
                  ),
                  _Block(
                    label: '¿Lleva complemento?',
                    hint: 'Tostadas o Tostitos, y extras como piña.',
                    child: _YesNo(
                      value: _hasOptions,
                      onChanged: (v) => setState(() => _hasOptions = v),
                    ),
                  ),
                  if (!_isNew)
                    _Block(
                      label: 'Cantidades y costo',
                      child: SoftButton(
                        label: 'Configurar costeo',
                        icon: KIcons.gear,
                        onTap: () async {
                          await showProductCost(context, widget.product!);
                          _draft.options = List.of(
                            store.product(_draft.id).options,
                          );
                        },
                      ),
                    ),
                  _Block(
                    label: 'Disponibilidad',
                    hint: 'Pausado no aparece al tomar pedidos.',
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: SizedBox(
                        width: 260,
                        child: SegmentedPill<bool>(
                          values: const [true, false],
                          selected: _available,
                          labelOf: (v) => v ? 'Disponible' : 'Pausado',
                          onChanged: (v) => setState(() => _available = v),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      bottom: BottomActionBar(
        child: PrimaryButton(
          label: _isNew ? 'Agregar al menú' : 'Guardar cambios',
          icon: KIcons.checkStrong,
          onTap: _valid ? _save : null,
        ),
      ),
    );
  }
}

class _Block extends StatelessWidget {
  const _Block({required this.label, required this.child, this.hint});
  final String label;
  final String? hint;
  final Widget child;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: KSpace.xl),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        FieldLabel(label),
        child,
        if (hint != null)
          Padding(
            padding: const EdgeInsets.only(top: KSpace.s, left: 4),
            child: Text(hint!, style: KText.caption),
          ),
      ],
    ),
  );
}

class _YesNo extends StatelessWidget {
  const _YesNo({required this.value, required this.onChanged});
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) => Align(
    alignment: Alignment.centerLeft,
    child: SizedBox(
      width: 200,
      child: SegmentedPill<bool>(
        values: const [false, true],
        selected: value,
        labelOf: (v) => v ? 'Sí' : 'No',
        onChanged: onChanged,
      ),
    ),
  );
}
