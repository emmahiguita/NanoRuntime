# Inicio móvil y conexiones de Nano

18 de octubre de 2026. Revisión de código, análisis estático y revisión manual;
sin pruebas automatizadas, sin servicios de pago y sin cambiar modelos.

## Cambios

- Inicio organizado en Mensajes, asistentes, espacio compartido, herramientas y
  configuración. Se retiró de esta pantalla la publicidad giratoria, la promoción
  editorial repetida de modelos y el carrusel de sugerencias. Modelos conserva su
  entrada funcional. Las acciones de texto/voz permanecen en el input existente.
- Tarjetas con superficie estable y un acento; altura natural, texto adaptable,
  acciones nativas y sin blur por tarjeta. Herramientas usan dos columnas solo
  cuando hay espacio; el contenido mantiene desplazamiento y reserva del dock.
- Cabecera con protección del área del reloj/cámara y controles accesibles.
- Nano Personal deja de usar un estado activo fijo en Inicio: muestra el estado
  real de su regla. Regla habilitada no equivale a permisos o entrega comprobada.
- Cabecera de Personal compacta en ventanas bajas, incluyendo horizontal.
- Inicio y Personal abren la misma Biblioteca/Tienda mediante
  NanoWorkspaceResources. El catálogo se hidrata antes de abrir; se impide abrir
  modales duplicados. initialSection selecciona realmente documentos o tienda.
- Un fallo de archivos ya no bloquea la sección independiente de Tienda.
- La biblioteca desde un chat también espera hidratación. Los errores de compartir
  presentan un mensaje legible sin mostrar excepciones o rutas internas.

## Conexiones revisadas

| Flujo | Evidencia en código | Alcance |
|---|---|---|
| Identidad y estilo | NanoPersonalIdentityTab → PersonalOwnerProfileEditor → PersonaRepository → PersonaContext.refresh/personaBlockFor | Datos guardados y recuperados para el turno; no respuesta prefabricada. |
| Agenda y estado diario | NanoPersonalAgendaCard → perfil owner → RuntimePersonalLiveContext con allowDeclaredAgenda | Hora, fecha, actividad y agenda declaradas; la agenda no confirma dinero o compromisos desconocidos. |
| Contactos y grupos | PersonaContext → ConversationDecisionContextBuilder → ConversationReplyFlow y RuleDispatcher | Relación por conversación; grupos requieren mención antes de multimedia y despacho. |
| Local/nube | NotificationDraftWriter → CloudTurnContext | Conserva sistema/historial bajo límites; no cambia motor/modelo. |
| Multimedia | ConversationReplyFlow → ConversationMediaEnricher → borrador contextual | Usa contenido disponible; Android/WhatsApp pueden no exponer el archivo. |
| Tienda | BusinessDocumentLibraryDialog → BusinessFactsNotifier → selectFactsForMessage en agent_dependencies | El mismo catálogo alimenta Nano Negocio; no se inventan productos ni se mezclan como datos personales. |
| PDF importado | importFile → PdfTextExtractionService → propuestas → aprobación → importProducts | Importar un PDF no significa indexar semánticamente toda la biblioteca. |
| Documento en chat | ConversationDetailLibrary → biblioteca → destinatario verificado → WhatsAppMediaShare | Se distingue solicitud de envío de entrega confirmada; no se enviaron archivos a contactos en esta revisión. |

## Límites

No se declara el sistema completo al 100% solo por revisar código. La selección de
cuenta Google, la extracción multimedia bajo condiciones reales y la respuesta/entrega
con un contacto requieren revisión manual en el teléfono. No se han concedido nuevos
permisos Android, cerrado sesiones ni modificado datos personales para esta revisión.

## Resultado en dispositivo

Compilación fullSideload release correcta: 284,3 segundos, APK de 101,9 MB.
Actualización mediante `adb install -r`: Success. Android registra la actualización
el 18 de octubre de 2026 a las 15:04:22 en VGL7MVFMDYQG8T55, sin desinstalar ni
borrar los datos actuales. Análisis estático de archivos modificados sin problemas.

Revisión manual mediante apertura y capturas, sin suites automatizadas:

- Inicio: `nanoMOBILE/flutter_app/build/nano_home_after.png`.
- Biblioteca abierta desde Inicio: `build/nano_library_connected.png`.
- Tienda abierta directamente en su sección: `build/nano_store_connected.png`.
- Pestaña compartida de Personal: `build/nano_personal_resources.png`.

Los archivos mostraron cero documentos y el catálogo cero productos, sin datos de
demostración. No se importó, borró, guardó o envió contenido para esta revisión.
El comportamiento horizontal se adaptó en código; esta sesión no incluye captura
horizontal ni validación de entrega o respuesta con un contacto real.
No se actualizó el índice externo. La guía existente de biblioteca conserva las
reglas aprendidas sobre entradas compartidas, hidratación y errores por sección.
