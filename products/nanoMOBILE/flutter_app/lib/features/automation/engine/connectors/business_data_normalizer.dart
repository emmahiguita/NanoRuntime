import '../../../database/domain/data_models.dart';
import '../business/business_facts.dart';
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
    final stockIdx = mapping.stockColumn != null ? table.columns.indexOf(mapping.stockColumn!) : -1;
    final skuIdx = mapping.skuColumn != null ? table.columns.indexOf(mapping.skuColumn!) : -1;
    final detailsIdx = mapping.detailsColumn != null ? table.columns.indexOf(mapping.detailsColumn!) : -1;

    final seenIds = <String>{};
    final seenNames = <String>{};
    final validProducts = <BusinessProduct>[];
    final warnings = <String>[];
    int invalidCount = 0;
    int duplicateCount = 0;

    for (int i = 0; i < table.rows.length; i++) {
      final row = table.rows[i];
      final rawName = _getValue(row, nameIdx);
      final rawPrice = _getValue(row, priceIdx);
      final rawStock = _getValue(row, stockIdx);
      final rawSku = _getValue(row, skuIdx);
      final rawDetails = _getValue(row, detailsIdx);

      final cleanName = rawName.trim();
      if (cleanName.isEmpty) {
        invalidCount++;
        continue;
      }

      final parsedPrice = parseRegionalPrice(rawPrice);
      if (parsedPrice <= 0) {
        invalidCount++;
        warnings.add('Fila ${i + 1}: "$cleanName" tiene precio inválido o cero ("$rawPrice").');
        continue;
      }

      final parsedStock = _parseStock(rawStock);
      if (parsedStock != null && parsedStock < 0) {
        warnings.add('Fila ${i + 1}: "$cleanName" tiene existencias negativas ($parsedStock). Ajustado a 0.');
      }

      final productId = rawSku.trim().isNotEmpty
          ? rawSku.trim()
          : 'PRD_${cleanName.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '_')}';

      if (seenIds.contains(productId) || seenNames.contains(cleanName.toLowerCase())) {
        duplicateCount++;
        warnings.add('Fila ${i + 1}: Producto duplicado detectado ("$cleanName").');
        continue;
      }

      seenIds.add(productId);
      seenNames.add(cleanName.toLowerCase());

      validProducts.add(
        BusinessProduct(
          id: productId,
          name: cleanName,
          details: rawDetails.trim(),
          price: parsedPrice,
          stock: parsedStock != null ? (parsedStock < 0 ? 0 : parsedStock) : null,
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

  /// Parsea cadenas de precio en formatos como "$ 1.200.000", "1200000", "1,200.50".
  static int parseRegionalPrice(String raw) {
    if (raw.trim().isEmpty) return 0;
    var clean = raw.replaceAll(RegExp(r'[^\d.,]'), '').trim();
    if (clean.isEmpty) return 0;

    // Caso: formato hispano con puntos de miles (ej: 1.200.000 o 1.200.000,00)
    if (clean.contains('.') && clean.contains(',')) {
      if (clean.lastIndexOf(',') > clean.lastIndexOf('.')) {
        clean = clean.split(',')[0].replaceAll('.', '');
      } else {
        clean = clean.split('.')[0].replaceAll(',', '');
      }
    } else if (clean.contains('.')) {
      final parts = clean.split('.');
      if (parts.length > 2 || (parts.length == 2 && parts.last.length == 3)) {
        clean = clean.replaceAll('.', '');
      } else {
        clean = parts[0];
      }
    } else if (clean.contains(',')) {
      final parts = clean.split(',');
      if (parts.length > 2 || (parts.length == 2 && parts.last.length == 3)) {
        clean = clean.replaceAll(',', '');
      } else {
        clean = parts[0];
      }
    }

    return int.tryParse(clean) ?? 0;
  }

  static int? _parseStock(String raw) {
    final clean = raw.replaceAll(RegExp(r'[^\d-]'), '').trim();
    return clean.isNotEmpty ? int.tryParse(clean) : null;
  }

  static String _getValue(List<dynamic> row, int index) {
    if (index >= 0 && index < row.length) {
      return row[index]?.toString() ?? '';
    }
    return '';
  }
}
