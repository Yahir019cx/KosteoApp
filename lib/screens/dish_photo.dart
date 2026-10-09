import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../data/app_store.dart';
import '../theme/icons.dart';
import '../theme/tokens.dart';
import '../widgets/basics.dart';
import '../widgets/glass_sheet.dart';
import '../widgets/product_card.dart';
import '../widgets/toast.dart';
import 'common.dart';

/// Sheet para poner, cambiar o quitar la foto de un platillo.
/// El editor conserva un borrador; al guardar se envía Base64 a SQL.
Future<void> editDishPhoto(BuildContext context, Product product) async {
  final source = await showGlassSheet<Object>(
    context,
    builder: (_) => _PhotoSheet(product: product),
  );
  if (!context.mounted || source == null) return;
  if (source == _remove) {
    await runAction(
      context,
      () => store.setProductImage(product, null),
      successMessage: product.draft
          ? 'Foto quitada del borrador'
          : 'Foto eliminada',
    );
    return;
  }
  final file = await ImagePicker().pickImage(
    source: source as ImageSource,
    maxWidth: 1200,
    imageQuality: 85,
  );
  if (file == null) return;
  final bytes = await file.readAsBytes();
  if (!context.mounted) return;
  await runAction(context, () async {
    await store.setProductImage(product, bytes);
    if (context.mounted) {
      showToast(
        context,
        product.draft ? 'Foto lista para guardar' : 'Foto actualizada',
      );
    }
  });
}

const _remove = #remove;

class _PhotoSheet extends StatelessWidget {
  const _PhotoSheet({required this.product});
  final Product product;

  @override
  Widget build(BuildContext context) {
    // La cámara solo existe en móvil; en Windows y web se elige un archivo.
    final hasCamera =
        !kIsWeb &&
        (defaultTargetPlatform == TargetPlatform.android ||
            defaultTargetPlatform == TargetPlatform.iOS);
    return SheetBody(
      title: product.name,
      subtitle: 'Foto del platillo',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AspectRatio(
            aspectRatio: 4 / 3,
            child: DishImage(product: product, radius: KRadius.card),
          ),
          const SizedBox(height: KSpace.xl),
          Row(
            children: [
              Expanded(
                child: PrimaryButton(
                  label: hasCamera ? 'Galería' : 'Elegir imagen',
                  icon: KIcons.imagePlus,
                  onTap: () => Navigator.of(context).pop(ImageSource.gallery),
                ),
              ),
              if (hasCamera) ...[
                const SizedBox(width: KSpace.m),
                Expanded(
                  child: PrimaryButton(
                    label: 'Cámara',
                    icon: KIcons.camera,
                    onTap: () => Navigator.of(context).pop(ImageSource.camera),
                  ),
                ),
              ],
            ],
          ),
          if (product.image != null) ...[
            const SizedBox(height: KSpace.m),
            SoftButton(
              label: 'Quitar foto',
              icon: KIcons.trash,
              color: KColors.danger,
              height: 52,
              onTap: () => Navigator.of(context).pop(_remove),
            ),
          ],
        ],
      ),
    );
  }
}
