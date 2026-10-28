# Nano Personal: implementación y evidencias

Fecha: 18 de octubre de 2026. Dispositivo: CPH2557, VGL7MVFMDYQG8T55.

## Qué quedó conectado

El turno usa identidad y relación con el contacto existentes, preferencias guardadas,
estado declarado con fecha y agenda efectiva. El estado de ayer vence; guardar otra
preferencia no lo renueva. Las comidas interrumpen trabajo según el calendario
existente. Tener una agenda cualquiera no demuestra que estés almorzando.

En Nano Personal → Identidad están nombre, apodo, ocupación, descripción, etiquetas
de mención, estilo, calendario y «Mis preferencias y estado de hoy». Los campos
pasan de una a dos columnas según el ancho, con desplazamiento y controles Material
3 existentes. No se sustituyó el tema global ni se afirma una migración completa
de toda la app a Material Expressive.

Las claves permanecen en la configuración compartida de proveedores/Hub. La opción
«Permitir Gemini para comprender adjuntos» autoriza subir archivos cuando haga
falta y existe configuración compatible; también respeta el modo solo local.
Está desactivada de forma predeterminada. No crea claves ni cambia el modelo elegido.

Se retiraron vetos generales por palabras como Nequi, banco o parce. Se mantienen
el análisis de intención y los controles de hechos y acciones. Una respuesta que
repite exactamente la pregunta más «¿y tú?» se considera eco y puede regenerarse;
no se reemplaza por una frase prefabricada. En grupos se conserva la condición de
mención antes de procesar contenido y antes del envío.

## Flujo y componentes para mantenimiento

Todos los nombres siguientes son rutas relativas a `nanoMOBILE/flutter_app/lib`.

| Componente | Responsabilidad |
| --- | --- |
| `features/automation/personal_agent/domain/owner_declared_context.dart` | Vigencia diaria, preferencias y actividad horaria efectiva. |
| `features/automation/personal_agent/domain/owner_activity_evidence.dart` | Contrastar una afirmación concreta con actividad declarada; excluir negaciones y futuro. |
| `features/automation/engine/language/runtime_personal_live_context.dart` | Añadir el contexto temporal al turno con la fuente disponible. |
| `features/automation/engine/notifications/cloud_turn_context.dart` | Transportar sistema, autores e historial reciente también al cambiar a nube. |
| `features/automation/domain/notification_attachment_codec.dart` | Conservar archivo nativo, MIME, fecha y procedencia, sin leer rutas escritas en el chat. |
| `features/automation/engine/notifications/notification_object.dart` y sus partes | Separar texto original, petición y evidencia enriquecida sin cambiar la identidad del evento. |
| `features/automation/data/media/attachment_content_reader.dart` | Audio real disponible, OCR, etiquetas visuales y PDF, con límites explícitos. |
| `features/automation/engine/conversation/conversation_media_enricher.dart` | Incorporar contenido al contexto del modelo sin fabricar comprensión ni preguntas. |
| `features/automation/data/media/attachment_evidence_cache.dart` | Evitar releer lo mismo; acotar caché, caducidad y tareas simultáneas. |
| `features/automation/data/media/conversation_media_history.dart` | Recuperar solo adjuntos vinculados a esa conversación cuando el contacto los referencia. |
| `features/automation/data/media/conversation_link_reader.dart` y `public_link_target.dart` | Leer texto público con límites; validar destinos y redirecciones y fijar resolución DNS. |
| `core/services/shared_gemini_media_reader.dart` | Percepción opcional con proveedor compartido, consentimiento, tiempo y tamaño máximos. |
| `core/services/bounded_process.dart` | Terminar el proceso de transcripción al cancelar o vencer el tiempo, no solo abandonar su espera. |

En Android, `MessageImageReader.kt` usa OCR y etiquetas reales de ML Kit;
`MessagePdfReader.kt` extrae texto digital y aplica OCR a páginas sin texto.
`PdfTextExtractionChannelHandler.kt` comparte una cola acotada y cancela tareas
propias al cerrar el canal. Se registra también en el motor en segundo plano.

El texto encontrado en un PDF no decide por sí mismo que el dueño pregunta por
mañana, que cambió de rol o que fue mencionado. Una transcripción del audio
adjunto actual sí representa una petición; releer un audio histórico solo aporta
evidencia. Se conserva una instrucción escrita que acompañe a la voz.

Los fragmentos agrupados conservan autor, fecha y texto original para no repetirse
en el historial. La lectura multimedia no cambia el identificador del mensaje.

## Rendimiento y ciclo de vida

No se cambiaron pesos, backend, hilos, lotes ni KV de los modelos existentes. Para
el paquete LiteRT concreto con KV1280 se limita el extracto multimedia y se marca
como parcial; la pregunta permanece. La caché evita repeticiones, no elimina el
costo de leer un archivo por primera vez.

La revisión de `EngineSupervisor.kt`, `worker_daemon_registry.c`, el servidor Rust
y su FFI encontró supervisión, cancelación y recolección de procesos ya existentes.
Se conservaron. No se atribuye una mejora de llama.cpp sin una medición comparativa.
La corrección demostrada de procesos afecta al subproceso de Whisper lanzado por
Dart: un límite de espera anterior podía dejarlo ejecutándose.

Los módulos nuevos de producción se mantuvieron por debajo de 200 líneas con
comentarios de qué hacen, cómo y por qué. Se reutilizaron componentes existentes;
varios archivos antiguos siguen superando ese límite. No se declara una refactorización
completa del repositorio ni ausencia universal de procesos zombis.

## Verificación

- Análisis estático de los archivos modificados: sin problemas detectados.
- Pruebas de contexto, autoría, archivos, permisos, interfaz y procesos reales:
  **102 aprobadas**, ninguna fallida en la ejecución final. Registro en
  `nanoMOBILE/flutter_app/build/nano_personal_validation.log`.
- Prueba de integración en Android: imagen con texto conocido, PDF digital y PDF
  escaneado generados para la prueba; usa canales nativos y limpia sus propios archivos.
- Segunda ejecución en el teléfono: OCR **489 ms**, PDF digital **333 ms**, PDF
  escaneado **358 ms**, imagen hasta contexto **200 ms** en el siguiente paso de prueba.
  Son pasos separados; no deben sumarse ni confundirse con latencia de respuesta del modelo.
- Registro: `build/nano_personal_android_validation.log`. No se enviaron mensajes a contactos.

Las cinco fallas de la auditoría anterior se investigaron. Algunas pruebas exigían
respuestas fijas de fecha/agenda o bancos de frases que el flujo actual delega al
modelo. Se actualizaron esas expectativas y se añadieron pruebas del contexto real;
no se hicieron pasar implementando respuestas prefabricadas.

## Límites que siguen pendientes de demostración

- La prueba de Android demuestra extracción de esos archivos y entrada al contexto,
  no comprensión universal ni naturalidad garantizada.
- Audio requiere Whisper utilizable o Gemini configurado y autorizado. Sus contratos
  se probaron con adaptadores de prueba; no se transcribió una grabación real en esta validación.
- Gemini multimedia tiene pruebas de petición, autorización y respuesta con cliente
  controlado; no se consumió una API real. Se conservó el modelo configurado.
- OCR y etiquetas locales no equivalen a visión completa ni identifican personas.
  Los videos conservan metadatos, pero no tienen comprensión implementada en este lector.
- Cuando WhatsApp no expone el archivo, Nano informa la falta de contenido disponible.
- PDF limitado por páginas, tamaño, tiempo y contexto; los recortes se declaran.
- Enlaces verificados con pruebas de lectura y redirección; no se demuestra acceso a
  cualquier sitio, contenido autenticado o protegido.
- Falta medir conversaciones completas con los modelos instalados y comprobar
  entrega real de WhatsApp con un contacto autorizado. No se garantiza rapidez igual
  para todos los adjuntos ni se afirma «100 % natural».
- El estado libre vence por día; usa el calendario para intervalos horarios exactos.
  No demuestra ubicación, saldo disponible ni aceptación de una invitación.

Contratos oficiales consultados para la integración opcional:
[imágenes](https://ai.google.dev/gemini-api/docs/image-understanding) y
[audio](https://ai.google.dev/gemini-api/docs/audio).

La guía reutilizable de regresiones está en
`.agents/skills/nano-personal-evidence-flow/SKILL.md`. Se respetó la decisión de
conservar el índice de búsqueda actual, sin actualizarlo externamente.

## Incidente de la validación Android

La prueba se ejecutó con el identificador principal. Se comprobó en el código de
Flutter que `IntegrationTestDevice.kill` llama `uninstallApp`, que ejecuta
`adb uninstall` sin conservar datos. Tras la prueba solo quedaba el paquete de
instrumentación. Por tanto, se eliminó la instalación principal y sus datos locales.
No hay un respaldo verificado con el que restaurar la configuración anterior.
Se informó al usuario y se reinstaló release. No se debe afirmar que se conservaron
identidad, permisos, claves o modelos guardados dentro del espacio privado anterior.

Para impedir repetirlo se añadió el flavor `personalValidation`, con identificador
`dev.nanoai.mobile.validation`, distinto de `dev.nanoai.mobile`. Las próximas pruebas
de integración deben usar exclusivamente ese flavor, comprobar el identificador del
APK antes de instalar y utilizar datos desechables. Las pruebas de widgets de la
pantalla de acceso se ejecutan en escritorio y no desinstalan nada del teléfono.

## Ajuste posterior de la pantalla de acceso

Se retiraron de LoginScreen la mascota animada, superficie de cristal, textos en
mayúsculas y afirmaciones de privacidad absolutas. Se conservaron las rutas de correo,
Google y acceso local existentes. Los componentes LoginPageLayout, LoginAuthHeader
y LoginAccessForm separan distribución, marca y campos; ninguno supera 200 líneas.
Se añadieron tres verificaciones de diseño: 360×780, 840×390 y 320×568 con letra 1,35.
Todas pasaron con la tipografía Inter real. No prueban la autenticación de una cuenta
externa ni una migración visual de las demás pantallas.

La versión con el nuevo acceso se compiló como fullSideload release y se actualizó
con instalación `-r` a las 11:19:41 del 18 de octubre. El proceso continuó activo
y no aparecieron errores fatales en la lectura final de AndroidRuntime. El teléfono
estaba en el panel principal con una solicitud de permisos: no se cerró la sesión
para forzar una captura del acceso. Las imágenes `build/login_portrait.png` y
`build/login_landscape.png` son vistas renderizadas, no capturas de esa sesión.
