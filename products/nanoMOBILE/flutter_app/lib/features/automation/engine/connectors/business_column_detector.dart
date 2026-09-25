import 'business_connector_models.dart';

// business_column_detector.dart
//
// QUÉ HACE:
// Detecta heurísticamente la correspondencia entre los encabezados de una hoja
// o base de datos externa y los campos estándar del catálogo comercial de Nano.
//
// CÓMO FUNCIONA:
// - Normaliza nombres de columna (sin acentos, mayúsculas, guiones).
// - Compara con listas de sinónimos comunes en facturación e inventario hispano e internacional.
// - Retorna una sugerencia inicial de BusinessColumnMapping para revisión del usuario.
//
// POR QUÉ:
// Evita obligar al usuario a renombrar sus hojas de cálculo existentes, facilitando
// la adopción rápida en cualquier tienda o negocio (SOLID - SRP).

class BusinessColumnDetector {
  static const _nameSynonyms = [
    'articulo', 'artículo', 'producto', 'item', 'nombre', 'descripcion',
    'descripción', 'title', 'name', 'product', 'servicio',
  ];

  static const _priceSynonyms = [
    'valor', 'precio', 'costo', 'price', 'rate', 'p.venta', 'p_venta',
    'unitario', 'valor_unitario', 'precio_venta', 'pvp',
  ];

  static const _stockSynonyms = [
    'existencias', 'cantidad', 'stock', 'inventario', 'disponible',
    'qty', 'cant', 'unidades', 'saldo',
  ];

  static const _skuSynonyms = [
    'referencia', 'sku', 'codigo', 'código', 'id', 'ref', 'code',
    'barcode', 'cod_barra', 'item_code',
  ];

  static const _detailsSynonyms = [
    'detalles', 'caracteristicas', 'características', 'observaciones',
    'variante', 'especificaciones', 'presentacion', 'presentación',
  ];

  static const _categorySynonyms = [
    'categoria', 'categoría', 'category', 'rubro', 'grupo', 'linea', 'línea',
    'departamento', 'seccion', 'sección', 'tipo',
  ];

  /// Detecta automáticamente el mapeo más probable a partir de la lista de columnas.
  static BusinessColumnMapping detect(List<String> availableColumns) {
    String? matchedName;
    String? matchedPrice;
    String? matchedStock;
    String? matchedSku;
    String? matchedCategory;
    String? matchedDetails;

    for (final col in availableColumns) {
      final norm = _normalize(col);

      if (matchedName == null && _matchesAny(norm, _nameSynonyms)) {
        matchedName = col;
        continue;
      }
      if (matchedPrice == null && _matchesAny(norm, _priceSynonyms)) {
        matchedPrice = col;
        continue;
      }
      if (matchedStock == null && _matchesAny(norm, _stockSynonyms)) {
        matchedStock = col;
        continue;
      }
      if (matchedSku == null && _matchesAny(norm, _skuSynonyms)) {
        matchedSku = col;
        continue;
      }
      if (matchedCategory == null && _matchesAny(norm, _categorySynonyms)) {
        matchedCategory = col;
        continue;
      }
      if (matchedDetails == null && _matchesAny(norm, _detailsSynonyms)) {
        matchedDetails = col;
        continue;
      }
    }

    // Si aún no hay nombre pero hay columnas, sugerir la primera columna de texto
    matchedName ??= availableColumns.isNotEmpty ? availableColumns.first : null;

    return BusinessColumnMapping(
      nameColumn: matchedName,
      priceColumn: matchedPrice,
      stockColumn: matchedStock,
      skuColumn: matchedSku,
      categoryColumn: matchedCategory,
      detailsColumn: matchedDetails,
    );
  }

  static bool _matchesAny(String target, List<String> synonyms) {
    for (final s in synonyms) {
      final cleanS = _normalize(s);
      if (target == cleanS || target.contains(cleanS)) {
        return true;
      }
    }
    return false;
  }

  static String _normalize(String input) {
    return input
        .toLowerCase()
        .replaceAll(RegExp(r'[áàäâ]'), 'a')
        .replaceAll(RegExp(r'[éèëê]'), 'e')
        .replaceAll(RegExp(r'[íìïî]'), 'i')
        .replaceAll(RegExp(r'[óòöô]'), 'o')
        .replaceAll(RegExp(r'[úùüû]'), 'u')
        .replaceAll(RegExp(r'[^a-z0-9]'), '');
  }
}
