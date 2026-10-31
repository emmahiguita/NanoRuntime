// business_store_product_actions.dart
//
// QUÉ HACE:
// Acciones comerciales de productos: exportación y compartición nativa mediante NanoContactPicker y NanoShareCoordinator.
//
// CÓMO FUNCIONA:
// - Genera una ficha formateada con emojis, negritas y precio destacado.
// - Si el producto tiene foto o video (asset o archivo local), extrae el archivo y lo adjunta a la carga.
// - Despliega la ventana flotante in-app NanoContactPicker para seleccionar contacto de WhatsApp o compartir con el sistema.
//
// POR QUÉ:
// Aplica SOLID aislando el formateo y despacho comercial en < 140 líneas.

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../../../engine/business/business_product.dart';
import '../../../application/nano_share_coordinator.dart';
import '../../../domain/nano_share_payload.dart';

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

  /// Abre la ventana flotante de compartición con el selector de contactos integrado de Nano.
  static Future<void> shareProduct({required BuildContext context, required BusinessProduct product}) async {
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

      final payload = NanoSharePayload(
        title: product.name.trim(),
        text: caption,
        type: NanoShareContentType.product,
        mediaFile: mediaFile,
        subtitle: product.priceLabel,
      );

      if (context.mounted) {
        await NanoShareCoordinator.showPicker(context: context, payload: payload);
      }
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(content: Text('No se pudo preparar el producto para compartir: $e'), behavior: SnackBarBehavior.floating),
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
