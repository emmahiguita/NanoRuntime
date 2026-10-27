import '../../engine/business/business_response_templates.dart';

/// Contrato de campos del editor: cada clave corresponde a una frase del motor.
/// Las ayudas muestran únicamente variables que el resolver sabe completar.
const businessSalesMessageFields = <({String key, String title, String help})>[
  (key: BusinessResponseTemplates.greeting, title: 'Saludo', help: '{negocio}'),
  (
    key: BusinessResponseTemplates.greetingPrefix,
    title: 'Saludo con consulta',
    help: '{negocio}',
  ),
  (
    key: BusinessResponseTemplates.productMatch,
    title: 'Respuesta de producto',
    help: '{productos}',
  ),
  (
    key: BusinessResponseTemplates.productCatalog,
    title: 'Respuesta de catálogo',
    help: '{productos}',
  ),
  (
    key: BusinessResponseTemplates.salesClosing,
    title: 'Cierre comercial',
    help: 'Sin variables',
  ),
  (
    key: BusinessResponseTemplates.humanHandoff,
    title: 'Pase a un asesor',
    help: 'Sin variables',
  ),
  (
    key: BusinessResponseTemplates.missingFacts,
    title: 'Dato aún no configurado',
    help: '{datos}',
  ),
  (
    key: BusinessResponseTemplates.unknownMessage,
    title: 'Consulta no entendida',
    help: '{motivo}',
  ),
];
