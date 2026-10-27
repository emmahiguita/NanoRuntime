# WhatsApp: fuentes, apertura y contexto personal

## Cambios comprobables en código

- Apertura Web verifica cabecera y cuenta mediante lectura ligera; no solicita
  todo el transcript para comprobar el destinatario. Conserva el WebView vinculado.
- Ingesta Web no bloquea la preparación visual. Callbacks verifican `mounted`;
  errores de preparación se muestran con reintento.
- Fuentes identificadas como Web, instalado o móvil + Web. El detalle permite
  elegir Web/instalado cuando existen evidencias compatibles de ambos.
- Identidad conserva agenda y otros hechos mediante escrituras serializadas.
- Agenda diaria con autorización explícita y caducidad por fecha local; el motor
  vuelve a leer el perfil para evitar memoria headless obsoleta.
- Frases alimentan el estilo del modelo; no son respuestas fijas. CRUD muestra
  errores de almacenamiento y sus controladores se liberan al cerrar.
- Resolución multimedia coalescida y acotada; fallos caducan. Eliminada búsqueda
  insegura de archivos por tiempo aproximado en carpetas generales de WhatsApp.
- Android conserva el adjunto de cada mensaje mediante su propia URI y clave
  estable de caché. Ya no replica el último audio en todo el lote de mensajes.
  Una imagen global sin URI individual no se atribuye como archivo del chat.

## Límites que siguen abiertos

- Notificaciones no reconstruyen conversaciones anteriores nunca observadas.
- WhatsApp puede omitir URI o permisos de fotos, vídeos y audios; se muestra
  solo contenido realmente accesible. Caché temporal no equivale a archivo permanente.
- Los registros erróneos ya guardados no se borran automáticamente: requieren
  reconciliación con una fuente verificable, no eliminación por parecido.
- Sesión Web requiere vinculación, red y sincronización del proveedor. Aún falta
  medir apertura y scroll del historial real después de instalar esta versión.
- Agenda es contexto declarado, no prueba de ubicación/actividad actual. Las
  afirmaciones automáticas siguen sujetas a revisión de seguridad.
- Se soportan paquetes oficiales normal y Business; no se promete soporte para
  clones ni modificaciones arbitrarias de WhatsApp.
- Multimedia Web saliente, Flows y Meta Cloud con credenciales reales siguen
  necesitando cierre y validación física. No se declara producción ni «100 %».

## Validación

Análisis estático Dart focalizado sin incidencias antes de la compilación.
No se ejecutaron pruebas automatizadas por instrucción del usuario.
Compilación e instalación se informan por separado de la prueba manual del chat.

- APK `fullSideloadProfile` compilado después del cambio Kotlin: correcto.
- Instalación con conservación de datos en `VGL7MVFMDYQG8T55`: correcta.
- Arranque observado del PID 22473: `Status: ok`; apertura caliente de Activity
  627 ms, que NO mide apertura del chat ni sincronización de WhatsApp Web.
- En el registro consultado del PID no aparecen `FATAL EXCEPTION`, errores
  Flutter no manejados, `MissingPluginException`, `SQLITE_ERROR` ni `No Overlay`.
  Hay avisos GPUAUX del fabricante; esta revisión no prueba ausencia de jank.
