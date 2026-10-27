// QUÉ: convierte celdas externas en valores seguros para el catálogo.
// CÓMO: interpreta precios regionales, stock y posiciones ausentes sin lanzar excepciones.
// POR QUÉ: aisla reglas de formato del orquestador de importación.
library;

/// Parsea formatos como "$ 1.200.000", "1200000" o "1,200.50".
int parseRegionalPriceValue(String raw) {
  if (raw.trim().isEmpty) return 0;
  var clean = raw.replaceAll(RegExp(r'[^\d.,]'), '').trim();
  if (clean.isEmpty) return 0;
  if (clean.contains('.') && clean.contains(',')) {
    clean = clean
        .split(clean.lastIndexOf(',') > clean.lastIndexOf('.') ? ',' : '.')
        .first
        .replaceAll(RegExp(r'[.,]'), '');
  } else if (clean.contains('.') || clean.contains(',')) {
    final separator = clean.contains('.') ? '.' : ',';
    final parts = clean.split(separator);
    clean = parts.length > 2 || (parts.length == 2 && parts.last.length == 3)
        ? clean.replaceAll(separator, '')
        : parts.first;
  }
  return int.tryParse(clean) ?? 0;
}

int? parseStockValue(String raw) {
  final clean = raw.replaceAll(RegExp(r'[^\d-]'), '').trim();
  return clean.isNotEmpty ? int.tryParse(clean) : null;
}

String dataCellValue(List<dynamic> row, int index) {
  if (index >= 0 && index < row.length) return row[index]?.toString() ?? '';
  return '';
}
