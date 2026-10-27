// pdf_product_proposal.dart
//
// QUÉ HACE:
// Modelo inmutable para productos extraídos de documentos PDF en la Biblioteca
// en estado de borrador/propuesta (Draft Proposal).
//
// CÓMO FUNCIONA:
// - Almacena nombre sugerido, precio detectado, categoría, descripción y página fuente.
// - Incluye flag `isSelected` y `isApproved` para control en la interfaz de revisión.
//
// POR QUÉ:
// Mantiene aislada la información no estructurada de los documentos PDF de la fuente
// oficial de verdad (BusinessFacts), exigiendo autorización explícita del dueño.

library;

import '../business_product.dart';

final class PdfProductProposal {
  final String id;
  final String sourceDocumentName;
  final int pageNumber;
  final String suggestedName;
  final int suggestedPrice;
  final String? suggestedCategory;
  final String suggestedDetails;
  final bool isSelected;

  const PdfProductProposal({
    required this.id,
    required this.sourceDocumentName,
    required this.pageNumber,
    required this.suggestedName,
    required this.suggestedPrice,
    this.suggestedCategory,
    this.suggestedDetails = '',
    this.isSelected = true,
  });

  PdfProductProposal copyWith({
    String? suggestedName,
    int? suggestedPrice,
    String? suggestedCategory,
    String suggestedDetails = '',
    bool? isSelected,
  }) => PdfProductProposal(
    id: id,
    sourceDocumentName: sourceDocumentName,
    pageNumber: pageNumber,
    suggestedName: suggestedName ?? this.suggestedName,
    suggestedPrice: suggestedPrice ?? this.suggestedPrice,
    suggestedCategory: suggestedCategory ?? this.suggestedCategory,
    suggestedDetails: suggestedDetails.isNotEmpty ? suggestedDetails : this.suggestedDetails,
    isSelected: isSelected ?? this.isSelected,
  );

  /// Convierte la propuesta aprobada en un BusinessProduct oficial para la Tienda.
  BusinessProduct toBusinessProduct() => BusinessProduct(
    id: 'prod_${DateTime.now().millisecondsSinceEpoch}_${id.hashCode.abs() % 10000}',
    name: suggestedName.trim(),
    details: suggestedDetails.trim(),
    price: suggestedPrice,
    category: suggestedCategory?.trim(),
    isAvailable: true,
    isManualEdit: true,
  );
}
