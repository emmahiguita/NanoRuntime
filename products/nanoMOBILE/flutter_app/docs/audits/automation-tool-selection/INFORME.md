# Selección de WhatsApp por icono y bitácora de acciones

## Comportamiento implementado

1. Abrir la barra de escritura de Automatización y tocar el icono WhatsApp. Seleccionarlo no abre aplicaciones ni envía contenido.
2. Escribir una instrucción explícita sin prefijo: `Abre el chat de Emm`, `Envía a Emm: texto exacto`, `Envía a (Nombre completo) (texto exacto)` o `Regresa a Nano`.
3. Pulsar Ejecutar. La traducción determinista llama al router existente; no añade otro agente, runtime ni API comercial. Las órdenes incompletas devuelven ayuda y no se convierten arbitrariamente en mensajes.
4. El icono sustituye la escritura manual de `@whatsapp`. Los comandos antiguos permanecen compatibles. El texto y el destinatario no se inventan a partir de una frase conversacional.
5. El acceso Historial de acciones está en el dashboard y en la barra. Cada ejecución muestra las llamadas iniciadas, resolución de destinatario observada cuando existe, aceptación de apertura por Android y resultados devueltos. Las observaciones de clic y regreso solo aparecen si el monitor nativo las produce.
6. La bitácora usa una sección del SQLite existente, con cola de escritura y un máximo de 400 eventos. No altera el journal de autorización ni sus reintentos. Un fallo al guardar se muestra como memoria de sesión sin persistencia confirmada.
7. El panel nativo flotante añade el selector por icono y consulta el mismo historial. Conserva el modo seleccionado al apartar/reabrir el panel durante la sesión. Las acciones se despachan por AutomationEngine/coordinator y no por un proveedor web.

## Qué se comprobó

- Análisis de las áreas modificadas: sin problemas (`analysis.log`, `preview-analysis.log`).
- Gradle fullSideloadDebug: compilación correcta (`build.log`).
- Instalación con conservación de datos: `Success` (`install.log`, huella en `installation.json`).
- Borrador visible sin `@whatsapp`, icono dentro del campo y destinatario Emm (`natural-draft.png`, `current-screen.png`).
- La lectura ARTEMIS confirmó el texto `Abre el chat de Emm`, el control `Desactivar WhatsApp` y `Ejecutar`.

## Comprobación pendiente, sin resultados inventados

La revisión automática de permisos bloqueó las pulsaciones por coordenadas. Primero señaló una jerarquía desactualizada; tras obtener una lectura actual, señaló la diferencia entre coordenadas normalizadas de ARTEMIS y píxeles físicos. No se continuó con pulsaciones ambiguas. El usuario eligió «Lo revisaré después».

Por tanto, NO se acredita en esta entrega la apertura desde el nuevo selector, un envío nuevo, el recorrido completo del flotante, la persistencia del historial tras reiniciar ni todos los temas/orientaciones. No se crearon pruebas automatizadas nuevas. No se enviaron mensajes ni documentos durante esta revisión.

Los XML iniciales que se reutilizaron desde `/sdcard/nano_selection.xml` no sirven como evidencia actual: UIAutomator devolvió `ERROR: could not get idle state` y conservó el archivo anterior. Las capturas visuales posteriores y la lectura ARTEMIS sí reflejan el borrador actual. Se conservan los archivos para diagnóstico, sin atribuirles una ejecución.

## Alcance y límites

- Nivel: automatización Android local supervisada y trazable para las acciones cubiertas; no un porcentaje universal de autonomía.
- El historial registra llamadas de comando y observaciones nativas disponibles desde esta versión. No reconstruye acciones antiguas ni todos los pasos internos de planes que nunca pasaron por esos puntos de registro.
- La apertura aceptada por Android no demuestra envío. Un clic de envío observado no demuestra entrega ni lectura.
- Los documentos mantienen las validaciones del flujo existente: archivo local real, identidad y metadatos requeridos. Esta entrega no añade un buscador universal de archivos ni valida nuevos envíos.
- Formularios genéricos requieren instrucciones y escenarios específicos con comprobación de cada campo y resultado. No se anuncia cobertura de todos los formularios o apps.
- El flotante usa el engine Flutter vivo y los permisos Android existentes. No garantiza continuidad después de forzar el cierre, revocar accesibilidad o una terminación del proceso por el sistema.
- El comportamiento de regreso de los envíos existentes se conserva; no se cambió por una política implícita de permanencia en WhatsApp.

## Revisión manual pendiente

1. Activar WhatsApp, escribir `Abre el chat de Emm` y comprobar aplicación y cabecera reales.
2. Volver a Nano, abrir Historial de acciones y desplegar la ejecución. Revisar su ID, rutas y estados; no confundir «llamada» con «resultado verificado».
3. Reiniciar Nano sin tareas activas y comprobar que la misma ejecución sigue presente.
4. Con WhatsApp abierto y el asistente nativo autorizado, activar WhatsApp en el flotante. Ejecutar únicamente una apertura de prueba, reabrir el panel y consultar Historial.
5. Los envíos de mensajes/documentos y los formularios necesitan su propia comprobación con destinatarios, contenido y resultados autorizados.

Inventario y huellas: `files.json`. No se modificó SmartAttendance ni se introdujo un bridge ajeno a Nano.
