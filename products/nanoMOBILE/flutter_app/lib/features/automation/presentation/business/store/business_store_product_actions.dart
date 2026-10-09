// business_store_product_actions.dart
//
// QUÉ HACE:
// Acciones comerciales de productos: exportación y compartición nativa hacia WhatsApp, Telegram y apps externas.
//
// CÓMO FUNCIONA:
// - Genera una ficha formateada con emojis, negritas y precio destacado.
// - Si el producto tiene foto o video (asset o archivo local), extrae el archivo y lo adjunta al share sheet nativo.
// - WhatsApp y Telegram reciben la foto real con el texto formateado en el pie de foto (caption).
//
// POR QUÉ:
// Aplica SOLID aislando el formateo y despacho comercial en < 140 líneas.

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../../../engine/business/business_product.dart';

final class BusinessStoreProductActions {
  BusinessStoreProductActions._();

  /// Formatea la ficha comercial con sintaxis compatible con WhatsApp y Telegram.
  static String formatProductCaption(BusinessProduct product) {
    final buffer = StringBuffer();
    buffer.writeln('🛍️ *${product.name.trim()}*');
    buffer.writeln('💰 *Precio:* ${product.priceLabel}');
    if (product.category != null && product.category!.trim().isNotEmpty) {
      buffer.writeln('🏷️ *Categoría:* ${product.category!.trim()}');
    }
    final stockText = !product.isAvailable
        ? '⛔ Temporalmente agotado / pausado'
        : (product.stock != null ? '✅ ${product.stock} unidades disponibles' : '✅ Disponible');
    buffer.writeln('📦 *Estado:* $stockText');
    if (product.sku != null && product.sku!.trim().isNotEmpty) {
      buffer.writeln('🔖 *SKU:* ${product.sku!.trim()}');
    }
    if (product.details.trim().isNotEmpty) {
      buffer.writeln('\n📝 *Detalles:*');
      buffer.writeln(product.details.trim());
    }
    if (product.variants.isNotEmpty) {
      buffer.writeln('\n🎨 *Variantes disponibles:*');
      buffer.writeln(product.variants.join(' · '));
    }
    return buffer.toString().trim();
  }

  /// Comparte el producto adjuntando su foto/video real y el texto de venta.
  static Future<void> shareProduct({
    required BuildContext context,
    required BusinessProduct product,
  }) async {
    final caption = formatProductCaption(product);
    final messenger = ScaffoldMessenger.of(context);
    try {
      XFile? mediaFile;
      final path = product.imagePath?.trim() ?? '';
      if (path.isNotEmpty) {
        if (path.startsWith('assets/')) {
          mediaFile = await _extractAssetToTemp(path, product.id);
        } else if (File(path).existsSync()) {
          mediaFile = XFile(path);
        }
      }

      if (mediaFile != null) {
        await SharePlus.instance.share(
          ShareParams(
            files: [mediaFile],
            text: caption,
          ),
        );
      } else {
        await SharePlus.instance.share(
          ShareParams(text: caption),
        );
      }
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(
          content: Text('No se pudo compartir el producto: $e'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  static Future<XFile?> _extractAssetToTemp(String assetPath, String id) async {
    try {
      final byteData = await rootBundle.load(assetPath);
      final tempDir = await getTemporaryDirectory();
      final ext = assetPath.contains('.') ? assetPath.split('.').last : 'jpg';
      final file = File('${tempDir.path}/prod_$id.$ext');
      await file.writeAsBytes(byteData.buffer.asUint8List());
      return XFile(file.path);
    } catch (_) {
      return null;
    }
  }
}
