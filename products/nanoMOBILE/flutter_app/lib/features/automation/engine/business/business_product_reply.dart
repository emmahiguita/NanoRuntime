// QUÉ HACE: redacta productos reales con un estado de inventario explícito.
// CÓMO: diferencia stock confirmado, agotado y disponibilidad por verificar.
// POR QUÉ: evita ofrecer artículos pausados o prometer existencias desconocidas.

import 'business_product.dart';
import 'business_response_templates.dart';

typedef BusinessProductReply = ({String text, String suggestion});

BusinessProductReply buildMatchedProductReply({
  required List<BusinessProduct> products,
  required int limit,
  required bool informal,
  BusinessResponseTemplates? templates,
}) {
  final visible = products.take(limit).toList(growable: false);
  final list = visible.map(_productLine).join(', ');
  final hasConfirmedStock = visible.any((p) => (p.stock ?? 0) > 0);
  final hasUnknownStock = visible.any((p) => p.stock == null);
  final suggestion = hasConfirmedStock
      ? 'Confirmar pedido'
      : hasUnknownStock
      ? 'Consultar disponibilidad'
      : 'Ver alternativas';
  final defaultIntro = informal
      ? 'Según el catálogo registrado: $list.'
      : 'Según la información registrada en el catálogo: $list.';
  // El texto se personaliza, pero la lista e inventario salen del catálogo real.
  final intro =
      templates?.render(BusinessResponseTemplates.productMatch, {
        'productos': list,
      }) ??
      defaultIntro;
  return (text: intro, suggestion: suggestion);
}

String buildCatalogReply({
  required List<BusinessProduct> products,
  required int limit,
  required bool informal,
  BusinessResponseTemplates? templates,
}) {
  final list = products.take(limit).map(_productLine).join(' · ');
  final defaultReply = informal
      ? 'En nuestro catálogo manejamos: $list.'
      : 'En nuestro catálogo disponemos de: $list.';
  // Conserva el contenido de catálogo al permitir editar solo su presentación.
  return templates?.render(BusinessResponseTemplates.productCatalog, {
        'productos': list,
      }) ??
      defaultReply;
}

String _productLine(BusinessProduct product) {
  final stock = product.stock;
  final status = stock == null
      ? 'disponibilidad por confirmar'
      : stock > 0
      ? '$stock unidades disponibles'
      : 'agotado';
  return '${product.name} por ${product.priceLabel} ($status)';
}
