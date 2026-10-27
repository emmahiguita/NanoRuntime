# Historial local primero y catálogo multimedia autorizado

## Implementación

- El detalle Web presenta `SavedWhatsAppHistoryView` sin esperar a que la Web
  esté lista. Usa archivo local, paginación y caché de diez páginas por alias
  de cuenta/conversación; no convierte previews en mensajes confirmados.
- La vista original sigue disponible en «Vista Web». No hay salto automático
  que cambie el scroll del usuario al terminar una sincronización.
- `VisibleWhatsAppHistorySync` captura únicamente la conversación visible,
  después de comprobar su cuenta. No navega ni envía. Tiene una sola captura
  activa, reintento espaciado y cancela su temporizador al cerrar.
- Una revisión cambia solo después de persistir un snapshot diferente: no
  relee SQLite cada dos segundos si el DOM no cambió.
- El lector nativo canónico excluye previews de dirección desconocida y fechas
  ausentes antes de paginar. No presenta una preview como burbuja entrante.
- La comparación física con Web reveló registros heredados de texto repetido,
  dirección y horas incorrectas. Se conservan, pero quedan fuera de la vista
  rápida y del contexto del modelo hasta recapturar su ID real contra el DOM.
- La recaptura marca `dom_verified_v1` y actualiza solo el mismo ID Web dentro
  de la misma conversación. No une por contenido, minuto ni nombre.
- No hay fallback al archivo heredado cuando la página verificada está vacía.
  En ese caso, al verificarse la sesión se muestra automáticamente el original
  Web; «Guardados» sigue accesible para consultar el estado local explícitamente.
- Se retiró el recorrido completo de migración Web en cada creación de motor.
  Las capturas nuevas usan una transacción por lote, no un commit por mensaje.
- Biblioteca ofrece «Multimedia autorizada de WhatsApp». Su índice SQLite
  almacena metadatos por URI, separado del historial y del catálogo comercial.
- El indexador usa MediaStore, versión del proveedor y cursor generación/ID;
  procesa hasta 120 cambios por tipo y lote. No recorre carpetas al abrir chats.
- Consulta solamente las rutas Media de los paquetes oficiales normal/Business
  en el almacenamiento principal, con permisos concedidos actualmente.
- Miniaturas nativas de 320 px para fotos/vídeos, peticiones coalescidas y caché
  Flutter de hasta 80 resultados. El original se abre por acción del usuario,
  con revalidación del permiso y de la URI indexada.
- Las fotos del chat se decodifican a 480 px para la tarjeta; el visor conserva
  el original. Se retiró existsSync del build de esa tarjeta.
- Avisos multimedia sin archivo explícito ya no ofrecen un visor vacío ni
  buscan por hora: abren Biblioteca con la leyenda «archivo no vinculado».

## Límites explícitos

- Historial local significa mensajes previamente observados y guardados.
  No recupera la base privada de WhatsApp ni todo el historial antiguo.
- La sincronización Web conserva mensajes cuyo ID, dirección y fecha el DOM
  expone. Si faltan, conserva cobertura parcial y acceso a la vista original.
- No se prometen miniaturas/descargas de todos los adjuntos de la Web en el
  archivo local: la Web puede omitir una URI reutilizable autorizada.
- Indexación incremental requiere Android 11+. No indexa base privada, caché
  privada, todos los archivos ocultos/.nomedia, todos los PDF ni tarjetas SD.
- Si solo se autorizaron imágenes seleccionadas, no se interpreta ese permiso
  como acceso a toda la biblioteca. No añade solicitudes de permisos amplios.
- El cursor de cambios detecta altas/actualizaciones. La reconciliación completa
  de archivos borrados/movidos no está cerrada; abrir un archivo ausente falla
  explícitamente y no se sustituye por otro.
- Registros Web sin ID real expuesto por el DOM no se etiquetan artificialmente
  como verificados. Esto puede dejar algunos archivos locales vacíos: el original
  Web sigue siendo la fuente visual, no se reconstruye con previews.
- Un archivo en MediaStore no recibe conversación, remitente ni fecha de mensaje.
  Su modified es metadato del archivo, no hora del chat.
- Cerrar Biblioteca impide pedir el siguiente lote; una operación nativa ya
  iniciada puede terminar. El trabajador es acotado y termina tras inactividad.

## Validación

- Análisis estático de 12 unidades finales: sin incidencias.
- Extracción de tarjetas: análisis antes/después sin incidencias; API de
  consumidores preservada, archivos nuevos menores de 200 líneas.
- Sin pruebas automatizadas por instrucción del usuario.
- Compilación, instalación y comprobación física se informan separadamente.
- APK `fullSideloadProfile` compilado e instalado conservando datos en
  `VGL7MVFMDYQG8T55`; PID de la primera revisión 18633, arranque correcto.
- Biblioteca abierta físicamente: miniaturas reales de imágenes y vídeos de
  WhatsApp normal/Business, con fuente y sin chat asignado. No hubo excepciones
  Flutter, SQLite, MissingPlugin ni No Overlay en el registro consultado.
- La revisión visual descubrió transparencia que dejaba ver el texto del modal
  inferior. Se aislaron ambas superficies (biblioteca y archivo local) con fondo
  opaco; no se cambió el diseño de las otras pantallas.
- Consulta local observada de 20 registros heredados: 285 ms; apertura Web 522 ms.
  NO se usa la primera muestra como validación del historial: esos datos fueron
  puestos en cuarentena tras compararlos con el original.
- No se declara rendimiento de historiales grandes, ausencia absoluta de
  duplicados ni funcionalidad al 100 % con análisis y compilación solamente.

## Entrega final

- Última compilación después de la cuarentena, transacción por lote y fallback
  seguro al original: correcta, 76,9 s, APK de 129 MB.
- Instalada con `Success`, conservando datos. Arranque `Status: ok`, PID 23569.
- Análisis final de la vista local/Web, su consumidor y contexto del modelo:
  sin incidencias. Ninguna prueba automatizada ejecutada.
- La separación de tarjetas mantuvo sus interfaces públicas; los componentes
  nuevos y las vistas pequeñas revisadas permanecen por debajo de 200 líneas.
- Pendiente comprobación física final de la cuarentena y de grandes historiales;
  la evidencia física anterior confirmó el problema heredado y las miniaturas,
  no una recuperación completa del archivo Web ni de todos los adjuntos.
