# Auditoría del Búho y WhatsApp — 28 de octubre de 2026

## Dictamen

El estado actual no está listo para instalarse ni permite afirmar que las cuatro
capacidades solicitadas estén integradas. Hay archivos de implementación, pero
sus consumidores actuales no los conectan. La existencia de una clase no demuestra
una función disponible en la app.

Alcance: revisión de código actual, referencias y análisis estático; comprobación
de compilación guardada por separado. No se ejecutaron pruebas, recorridos de
teléfono, mensajes, exportaciones ni escenarios QA. No se modificó código de la
app durante esta auditoría. Los resultados anteriores no acreditan este estado.

## Hallazgos prioritarios

### P0 — El código actual no supera el análisis estático

El comando acotado devuelve 59 errores, 4 advertencias y 38 observaciones.
Evidencia completa: `ANALISIS_ESTATICO.txt`.

La compilación fresca `fullSideloadDebug` también falló en
`:app:compileFlutterBuildFullSideloadDebug`, salida 1, tras 64,6 segundos.
Log: `COMPILACION.txt`. No se instaló esta versión. Un APK anterior presente
en la carpeta de build no acredita la compilación del código auditado.

- `nano_ai_controller.dart:44,49`: campo `onLoginRequired` duplicado.
- `nano_external_surface.dart:29,108`: consume `externalSession` y
  `externalRevision`, ausentes en `NanoFloatingWrapper` actual.
- `nano_external_surface.dart:152`: pasa `onDismiss`, `onOpenApp` y
  `onShowHistory`, ausentes en el constructor actual del panel.
- `owl_workspace_store.dart:23`: llama `section(strict: true)`, pero
  `AutomationDbStoreClient.section` no tiene ese parámetro.
- `nano_assistant_workspace_menu.dart`: no está incluido entre los `part` de
  `nano_assistant_panel.dart`; sus símbolos privados no se resuelven.

Estos son errores de integración, no defectos meramente visuales. Algunos errores
son cascadas; 59 errores no significa necesariamente 59 causas independientes.

### P1 — El panel Flutter externo no está conectado al arranque real

`NanoFloatingService.kt:19` sigue extendiendo `Service` y utiliza
`NanoGeminiOverlayView`, `NanoOverlayActions` y `NanoOverlaySession`.
No utiliza `NanoOwlWindowService`. `MainActivity` no llama a `register`,
`bindActivity` ni `release` de `NanoFlutterPanelHost`.
`nano_platform_app.dart:124` monta el Stack anterior, sin `NanoExternalSurface`.

Además, `MainActivity.kt:588` detiene el servicio al regresar a Nano. Por tanto,
la unificación y conservación del acceso externo no están completadas. Corregir
solo el aspecto de un panel no elimina esta duplicación de rutas.

### P1 — Historial, lectura nueva y QA no llegan al ejecutor del búho

`nano_providers.dart:71` construye `NanoActionPortAdapter` sin workspace;
el adaptador actual tampoco conecta `NanoWorkspaceCommands`.
Hay clases nuevas para captura, análisis y QA, pero eso no las hace accesibles
desde el panel actual. Tampoco aparecen las nuevas secciones `owl_exports_v1`,
`owl_qa_scenarios_v1`, `owl_qa_runs_v1` en la lista nativa de secciones aceptadas.
`NanoWhatsAppImportActivity` no está declarada en el manifiesto actual.

### P1 — La apertura normal no verifica el destinatario final

`whatsapp_chat_opener.dart:77` sigue devolviendo `completedUnverified` después
de solicitar apertura. No llama a `WhatsAppOpenVerifier`.
El verificador existe, pero no cubre por sí solo todas las rutas de apertura,
envío de texto, adjuntos o respuesta sobre un chat ya abierto.

El verificador también carece de callback de cancelación: podría pulsar perfil
o Atrás después de que el dueño del turno haya cancelado. Su retorno valida el
título del chat, no una nueva identidad de destinatario independiente. Los IDs
de perfil/usuario deben contrastarse manualmente con WhatsApp instalado.

### P1 — Una importación inválida bloquea las siguientes

`owl_export_inbox.dart:26`: el bucle no aísla fallos por archivo. Un archivo
ausente, ZIP inválido o TXT no reconocido lanza una excepción antes del ack y
permanece primero en la cola. Los posteriores vuelven a quedar sin procesar.
Debe conservarse el diagnóstico del rechazado y permitir continuar con los demás.

### P2 — El texto parseado puede no corresponder al original guardado

`owl_export_library.dart:42` hace que el isolate lea el archivo; en la línea 46
vuelve a leerlo para hash y original. Si cambia entre ambas lecturas, el JSON
puede corresponder a A y su SHA-256/original a B. Parser, hash y original deben
usar una misma instantánea de bytes.

### P2 — Captura/OCR todavía no equivale a comprensión visual multimodal

`owl_screen_evidence.dart:59` usa `MlKitChatVisionAdapter`: OCR y etiquetas.
Es una ruta de píxeles reales, pero no conecta un VLM que comprenda arbitrariamente
imágenes, vídeos o toda la interfaz. El propio componente declara esa limitación.
También guarda un PNG por captura sin una política de limpieza de temporales.

### P2 — QA cubre navegación acotada, no todo WhatsApp

`owl_qa_scenario.dart` contiene abrir WhatsApp, opcionalmente un destinatario y
volver a Nano. No contiene aserciones de mensaje escrito/enviado, PDF, fotos,
vídeos, exportación ni reanudación tras cierre del proceso. El runner guarda
esperado, observado y capturas, y ya rechaza códigos de error del comando; aun
así no está integrado ni ejecutado sobre el teléfono en esta auditoría.

## Comprobación manual pendiente tras reparar P0/P1

| Caso | Resultado exigido |
| --- | --- |
| Abrir búho sobre WhatsApp | Mismo panel, borrador y tema; sin segunda sesión |
| Minimizar, cerrar, Atrás y teclado | Sin ventanas invisibles ni controles duplicados |
| Regresar a Nano y salir de nuevo | Acceso externo coherente, sin reapertura espontánea |
| Número, nombre único, homónimo y usuario | Destino exacto o aclaración; nunca elegir el primero |
| Cancelar durante verificación | Ninguna acción posterior del turno cancelado |
| Leer pantalla con/sin permiso de captura | Evidencia real o limitación explícita |
| Exportación oficial → compartir con Nano | Original, JSON e índice duraderos tras reinicio |
| Importar inválido y luego válido | El inválido no bloquea la cola |
| QA | Esperado/observado, PNG y hashes; fallo/bloqueo/no verificable separados |
| Claro, oscuro, gris, horizontal y texto grande | Contraste, tamaño y accesibilidad sin overflow |

No se debe llamar «completo» hasta reparar los bloqueos y observar estos flujos
en el dispositivo. No hay evidencia nueva para prometer menor temperatura,
ausencia de bugs, envíos correctos ni compatibilidad universal de ventanas.
