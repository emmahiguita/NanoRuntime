import '../../../database/domain/data_models.dart';
import '../business/business_facts.dart';
import '../business/business_text_matcher.dart';
import 'business_data_value_parser.dart';
import 'business_connector_models.dart';

// business_data_normalizer.dart
//
// QUÉ HACE:
// Normaliza y valida filas de una tabla externa contra el modelo de catálogo comercial,
// detectando duplicados, precios inválidos y formatos numéricos regionales (ej: 1.200.000).
//
// CÓMO FUNCIONA:
// - Extrae valores según el BusinessColumnMapping configurado.
// - Sanitiza precios eliminando símbolos de moneda y gestionando separadores de miles y decimales.
// - Genera un BusinessValidationReport con métricas de calidad antes de impactar el catálogo.
//
// POR QUÉ:
// Asegura que el bot de WhatsApp nunca reciba datos corruptos, precios en cero no deseados
// o existencias negativas que generen promesas comerciales erróneas (SOLID - SRP).

class BusinessDataNormalizer {
  /// Procesa una tabla de datos y genera el reporte de validación y lista de productos.
  static BusinessValidationReport normalize({
    required DataTable table,
    required BusinessColumnMapping mapping,
    List<BusinessProduct>? existingProducts,
  }) {
    if (!mapping.isValid || table.isEmpty) {
      return const BusinessValidationReport(
        totalRows: 0,
        validCount: 0,
        invalidCount: 0,
        duplicateCount: 0,
        warnings: ['El mapeo de columnas no contiene Nombre o Precio.'],
        validProducts: [],
      );
    }

    final nameIdx = table.columns.indexOf(mapping.nameColumn!);
    final priceIdx = table.columns.indexOf(mapping.priceColumn!);
    final stockIdx = mapping.stockColumn != null
        ? table.columns.indexOf(mapping.stockColumn!)
        : -1;
    final skuIdx = mapping.skuColumn != null
        ? table.columns.indexOf(mapping.skuColumn!)
        : -1;
    final categoryIdx = mapping.categoryColumn != null
        ? table.columns.indexOf(mapping.categoryColumn!)
        : -1;
    final detailsIdx = mapping.detailsColumn != null
        ? table.columns.indexOf(mapping.detailsColumn!)
        : -1;

    final existingMapById = {
      for (final p in existingProducts ?? const <BusinessProduct>[]) p.id: p,
    };
    final existingMapByName = {
      for (final p in existingProducts ?? const <BusinessProduct>[])
        normalizeText(p.name.trim()): p,
    };

    final seenIds = <String>{};
    final seenNames = <String>{};
    final validProducts = <BusinessProduct>[];
    final warnings = <String>[];
    int invalidCount = 0;
    int duplicateCount = 0;

    for (int i = 0; i < table.rows.length; i++) {
      final row = table.rows[i];
      final rawName = dataCellValue(row, nameIdx);
      final rawPrice = dataCellValue(row, priceIdx);
      final rawStock = dataCellValue(row, stockIdx);
      final rawSku = dataCellValue(row, skuIdx);
      final rawCategory = dataCellValue(row, categoryIdx);
      final rawDetails = dataCellValue(row, detailsIdx);

      final cleanName = rawName.trim();
      final nameKey = normalizeText(cleanName);
      if (cleanName.isEmpty) {
        invalidCount++;
        continue;
      }

      final parsedPrice = parseRegionalPriceValue(rawPrice);
      if (parsedPrice <= 0) {
        invalidCount++;
        warnings.add(
          'Fila ${i + 1}: "$cleanName" tiene precio inválido o cero ("$rawPrice").',
        );
        continue;
      }

      final parsedStock = parseStockValue(rawStock);
      if (parsedStock != null && parsedStock < 0) {
        warnings.add(
          'Fila ${i + 1}: "$cleanName" tiene existencias negativas ($parsedStock). Ajustado a 0.',
        );
      }

      final generatedId = rawSku.trim().isNotEmpty
          ? rawSku.trim()
          : 'PRD_${nameKey.replaceAll(RegExp(r'[^a-z0-9]'), '_')}';
      final existing =
          existingMapById[generatedId] ?? existingMapByName[nameKey];
      // Conserva la identidad durable al coincidir por nombre tras una importación.
      final productId = existing?.id ?? generatedId;

      if (seenIds.contains(productId) || seenNames.contains(nameKey)) {
        duplicateCount++;
        warnings.add(
          'Fila ${i + 1}: Producto duplicado detectado ("$cleanName").',
        );
        continue;
      }

      seenIds.add(productId);
      seenNames.add(nameKey);

      int finalPrice = parsedPrice;
      int? finalStock = parsedStock != null
          ? (parsedStock < 0 ? 0 : parsedStock)
          : null;
      bool isManual = false;

      // Safe Merge: Preservar ediciones manuales previas hechas en el móvil
      if (existing != null && existing.isManualEdit) {
        isManual = true;
        if (existing.price != parsedPrice) {
          warnings.add(
            'Fila ${i + 1}: "$cleanName" fue editado manualmente en el móvil (\$${existing.price}). Se conservó tu edición manual.',
          );
          finalPrice = existing.price;
        }
        if (existing.stock != null) {
          finalStock = existing.stock;
        }
      }

      validProducts.add(
        BusinessProduct(
          id: productId,
          name: cleanName,
          details: rawDetails.trim().isNotEmpty
              ? rawDetails.trim()
              : (existing?.details ?? ''),
          price: finalPrice,
          stock: finalStock,
          sku: rawSku.trim().isNotEmpty ? rawSku.trim() : existing?.sku,
          category: rawCategory.trim().isNotEmpty
              ? rawCategory.trim()
              : existing?.category,
          isAvailable: existing?.isAvailable ?? true,
          variants: existing?.variants ?? const [],
          imagePath: existing?.imagePath,
          isManualEdit: isManual,
        ),
      );
    }

    return BusinessValidationReport(
      totalRows: table.rows.length,
      validCount: validProducts.length,
      invalidCount: invalidCount,
      duplicateCount: duplicateCount,
      warnings: warnings,
      validProducts: validProducts,
    );
  }
}
