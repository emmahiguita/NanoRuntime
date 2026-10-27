# Nano Mobile: Overlay, comprensión y borradores

Fecha: 16 de octubre de 2026. Alcance: WhatsApp Personal/Negocio.

## Causas y correcciones

- Los Overlay creados con initialEntries conservaban closures del primer montaje.
  Se usa Overlay.wrap del SDK instalado: actualiza el hijo y elimina/libera la entrada.
  Se conserva la superficie transparente, sin sustituir el diseño por otro tema.
- ErrorWidget afirmaba «resuelto automáticamente». Ahora informa el fallo sin
  fingir reparación ni exponer el texto técnico de la excepción en pantalla.
- El Hero creaba CurvedAnimation sin dueño de dispose. CurveTween evita ese
  listener de estado; AnimatedBuilder administra la suscripción de animación.
- Los callbacks post-frame de la raíz comprueban mounted antes de utilizar Ref.
- Personal podía enviar saludos fijos, reconstruir aclaraciones con prefijos
  estáticos y reutilizar ejemplos de estilo como respuestas. Se retiraron esas
  salidas del resolver; la conversación cotidiana pasa a la inferencia real.
  Se conserva la recuperación de hechos observados y proveedores configurados.
- Saludar descartaba historial en una ruta del prompt. Ya no reinicia el chat.
- Un mensaje anterior mayor al presupuesto descartaba toda la ventana nativa.
  Ahora se conserva un extracto explícitamente parcial dentro de 6000 caracteres.
  El mensaje actual se incorpora aparte, sin recorte adicional en este compositor.
- Un JSON cortado podía perder requiresAction y habilitar envío automático.
  El texto recuperado ahora exige revisión humana.
- El parser marcaba preguntas como respondidas por encontrar números o cualquier
  texto. Sin cobertura explícita, esas obligaciones quedan pendientes.
- La generación manual consumía deduplicación del flujo automático. Ahora usa
  el origen real de borradores y las mismas guardas, sin consumir eventos ni
  registrar un nuevo turno. No envía nada al contacto.
- Se conectó esa distinción también en ToolRoutedConversationReplyComposer:
  las vistas previas mantienen ToolRouter/permisos y no vuelven al flujo automático.
  Un contexto no proporcionado queda null, permitiendo resolver Personal/Negocio
  desde la asignación real en vez de imponer Personal en el adaptador.
- Se reutiliza el cotejo de identidad, aliases y paquete para elegir notificación.
  Sin notificación activa, el último entrante observado prevalece sobre el resumen.
- Las sugerencias no sobrescriben texto del dueño y no agregan variantes fijas.
  La UI admite hasta tres opciones reales; si el modelo solo produce una, muestra una.
- Los controles de opciones usan Wrap sin altura fija de 32dp, texto Inter local
  y controles Material. Seleccionar copia el texto al editor, no lo envía.
- La compilación encontró una extracción previa de providers incompleta:
  export colocado después de declaraciones y falta de import local del pipeline.
  Se corrigieron las directivas y retiraron 37 imports sobrantes.

## Verificación

- Sin tests automatizados, por solicitud del usuario.
- Análisis estático final de las doce unidades principales revisadas: sin incidencias.
- Componentes nuevos extraídos: menos de 200 líneas por archivo.
- Resolver personal: 172 líneas; compositor: 154; parser: 168.
- Skill de respuestas reales actualizada y validada para evitar estas regresiones.
- APK fullSideloadProfile compilado correctamente (128.9 MB).
- Instalación con conservación de datos: Success en VGL7MVFMDYQG8T55.
- Apertura: Status ok, proceso 17375; Android reportó WARM y TotalTime 661 ms.
  Ese dato no mide la carga de mensajes, la inferencia ni los fotogramas Flutter.
- Fecha de actualización observada en Android: 2026-10-16 05:40:43.
- En la muestra de Logcat del PID 17375 no aparecieron No Overlay, excepciones
  no controladas, MissingPluginException, SQLiteException, RenderFlex overflow
  ni _assertNotOutdated. El proceso seguía activo al terminar la consulta.
  Esta observación de arranque no verifica todos los diálogos ni todos los chats.

## Revisión manual pendiente

1. Abrir/cerrar diálogos, seleccionar texto y mostrar menús en ambas orientaciones.
2. Saludar dentro de una conversación y preguntar por algo que ya se había hablado.
3. Enviar un párrafo real con varias preguntas; comprobar cada respuesta y autor.
4. Solicitar borrador dos veces y comprobar que no borra una redacción manual.
5. Recibir simultáneamente por Web y Android, comprobando que no duplica envíos.

## Límites

Esta revisión no demuestra cero lags, ausencia total de fugas ni comprensión
perfecta del modelo. No se realizaron nuevos perfiles de RAM o fotogramas.
El historial está acotado; una notificación truncada no recupera contenido que
Android no expuso. Multimedia completa, Meta Cloud, Flows y entrega real siguen
necesitando su validación E2E. No se realizaron envíos de prueba a contactos.
