// pdf_product_extractor.dart
//
// QUÉ HACE:
// Extractor heurístico y estructurado de candidatos a productos desde el texto de un PDF.
//
// CÓMO FUNCIONA:
// - Analiza líneas de texto buscando patrones de nombre seguido de precios monetarios
//   con símbolo de moneda o separadores de miles ($XX.XXX, USD XX, 120.000, etc.).
// - Genera instancias de `PdfProductProposal` en estado de borrador sin tocar BusinessFacts.
//
// POR QUÉ:
// Separa la heurística de extracción de la base de datos oficial.

library;

import 'pdf_product_proposal.dart';

class PdfProductExtractor {
  const PdfProductExtractor();

  /// Extrae candidatos de productos desde el contenido textual de un documento.
  List<PdfProductProposal> extractFromText({
    required String documentName,
    required String textContent,
    int pageNumber = 1,
  }) {
    if (textContent.trim().isEmpty) return const [];

    final proposals = <PdfProductProposal>[];
    final lines = textContent.split('\n');

    // Patrón estricto: requiere símbolo de moneda ($|€|USD|COP) o número con punto de miles (ej: 45.000)
    final priceRegex = RegExp(
      r'(?:[\$€]|USD\s*|COP\s*)\s*([0-9]{1,3}(?:[.,][0-9]{3})*|[0-9]+)|([0-9]{1,3}\.[0-9]{3}(?:\.[0-9]{3})*)',
      caseSensitive: false,
    );

    for (var i = 0; i < lines.length; i++) {
      final line = lines[i].trim();
      if (line.isEmpty || line.length < 4) continue;

      final match = priceRegex.firstMatch(line);
      if (match != null) {
        final rawPrice = (match.group(1) ?? match.group(2))
            ?.replaceAll('.', '')
            .replaceAll(',', '')
            .trim() ?? '';
        final parsedPrice = int.tryParse(rawPrice);

        if (parsedPrice != null && parsedPrice > 0 && parsedPrice < 100000000) {
          var candidateName = line.replaceAll(match.group(0)!, '').replaceAll(RegExp(r'[-:•–]'), '').trim();
          if (candidateName.length >= 3) {
            proposals.add(
              PdfProductProposal(
                id: 'prop_${documentName.hashCode}_${pageNumber}_$i',
                sourceDocumentName: documentName,
                pageNumber: pageNumber,
                suggestedName: candidateName,
                suggestedPrice: parsedPrice,
                suggestedDetails: 'Extraído de $documentName (Pág. $pageNumber)',
              ),
            );
          }
        }
      }
    }

    return proposals;
  }
}
