# Auditoría del Búho: diseño, órdenes y WhatsApp
Fecha: 27/10/2026. Alcance: panel Flutter, esfera externa Android y sus rutas de WhatsApp. No es una certificación del resto de Nano.

## Dictamen

**Está conectado al motor real de Automatización, pero esta parte todavía no está completa.** Recibir una orden no acredita cumplirla. Leer accesibilidad no equivale a ver toda la pantalla, comprender una imagen o disponer del historial completo.

Desde la última instrucción del usuario no se ejecutan recorridos, órdenes, benchmarks ni nuevas pruebas. La instalación autorizada se registra por separado. La guía adjunta está pendiente de ejecución manual; no contiene aprobaciones inventadas.

## Diseño: corregido y pendiente

- Se conservan sprites, respiración y parpadeo originales. La esfera Android usa una lente circular; el acople compacto conserva el búho visible.
- Se elimina la leyenda inferior repetida y el subtítulo redundante de ambos paneles. Se reducen símbolos y placas; cerrar, minimizar e historial siguen siendo acciones distintas.
- El avatar conserva zona táctil de 48 dp, aunque su imagen sea pequeña. El editor mantiene adjuntos, dictado, borrador y envío explícito.
- El OPPO informó `ro.surface_flinger.supports_background_blur=0`. La capa nativa consulta además `isCrossWindowBlurEnabled`: si no hay desenfoque real, aumenta el respaldo del material para que no se mezclen las letras de WhatsApp. No se simula ni se promete refracción iOS nativa.
- Android tiene texto de alto contraste activado. No se cambió esa preferencia. El contraste y el tema guardado se respetan.
- **Falta unificar completamente la presentación**: dentro de Nano se usa Flutter/GlassSurface; sobre WhatsApp se usa WindowManager con vistas Android. Comparten motor y paleta, pero todavía son dos implementaciones de UI. Esta entrega aproxima y limpia el aspecto; no las convierte en un único widget Flutter.
- El cuadrado lateral de Accesibilidad pertenece a Android. La preferencia anterior era conservarlo; ahora el usuario pide un único acceso visual. Para dejar solo la esfera, debe desactivarse únicamente ese atajo en los ajustes de Android, conservando el servicio. No se cambian esos ajustes ni se retira a ciegas el flag del servicio, porque puede alterar el acceso de automatización.
- No se ha observado en dispositivo el acabado final después de la última orden de no automatizar. Se requiere la revisión manual de ambos temas, gris espacial, teclado, horizontal y texto ampliado.

## Conexión real de órdenes

Ruta externa comprobada en código:
`NanoFloatingService → NanoOverlayActions → NanoOverlayBridge → NanoOverlayRuntime → NanoAiController → NanoActionPortAdapter → NanoAutomationGoalRunner/AutomationEngine`.

`nano_providers.dart` inyecta el mismo coordinador y `WhatsAppUiGoalPreparer`. No se añade otro motor de modelos ni otro ejecutor de WhatsApp.

| Función | Estado real y límite |
| --- | --- |
| Recibir texto | Conectado. Conversar consulta al modelo; WhatsApp/Controlar apps ejecutan objetivos. Elegir una opción no ejecuta nada. |
| Abrir WhatsApp y entrar a un chat | Implementado. Por número se observó anteriormente Conversation y cabecera Emm desde el búho. El abridor aún informa `completedUnverified`: no acredita por sí mismo el número final del perfil. |
| Nombre de contacto | Resuelve agenda exacta y única; no elige una coincidencia ambigua o fonética. No garantiza todos los grupos. |
| @usuario | Hay ruta de usuario explícito, distinta del teléfono. Su funcionamiento final depende de la versión/cuenta de WhatsApp y necesita prueba manual; no está certificado aquí. |
| Responder en el chat actual | Hay preparación contextual con ventana, raíz, cabecera y borrador. No debe resolver otro chat por un título parecido. Pendiente de prueba manual final. |
| Enviar texto y adjuntos | Hay rutas reales, permisos y cancelación. Archivo preparado, apertura, clic, retorno y entrega son estados diferentes. No se envió nada nuevo para certificar esta entrega. |
| Volver a Nano | Avatar y comando de retorno existentes. Se observó anteriormente el retorno a MainActivity sin panel externo duplicado. |
| Leer pantalla | Solo texto accesible visible. El lector limita a 2500 caracteres; la consulta de modelo acota contexto a 600. No es el chat completo. |
| Analizar lo que ve | Conversar puede recibir contexto textual cuando se pide pantalla/chat actual. Se corrigió la referencia a «esta conversación» y se informa al modelo de que la lectura es parcial y sin imágenes. No es observación continua. |
| Fotos, vídeos, botones sin accesibilidad | Esta ruta externa no recibe imagen ni vídeo del contenido visible. No se demuestra OCR/VLM externo ni navegación universal por píxeles. |
| Exportar historial completo | Nueva orden contextual abre el menú oficial del chat actual: Más opciones → Más → Exportar chat. Se detiene en la elección oficial de multimedia; no afirma que ya guardó el archivo. |
| Analizar todo el historial exportado | Falta recibir/importar TXT o ZIP oficial, descomprimir/normalizar, conservar autor/fecha y adjuntar fragmentos completos al modelo. El búho no lo hace automáticamente por haber abierto Exportar. |
| Borrador, resultado y ocupado | Se conservan al minimizar/reabrir dentro del mismo servicio. Un turno nuevo invalida el resultado viejo y restaura ocupado. Esto no es persistencia después de matar el proceso. |
| Historial de acciones | Usa la bitácora SQLite existente. No es una segunda copia completa del historial de WhatsApp. |

### Protección de la exportación

La preparación exige chat identificado, paquete personal/Business, raíz y ventana coherentes y lectura no truncada. Cada tap conserva el contrato en ToolCall. Se comprueba antes del paso y llega, aislado por Zone, al canal Android. `NanoClickContextGuard` lo revalida justo antes de ACTION_CLICK; si cambia o falla, no recurre a coordenadas. Esto protege el flujo observado, no convierte la cabecera en un JID verificado.

Se deriva el texto final del idioma del menú observado. Otras versiones, idiomas o menús distintos deben fallar sin elegir una opción por posición. La ruta nueva no ha sido ejecutada de extremo a extremo en el dispositivo tras la última restricción.

## Hallazgo importante sobre QA

`BenchmarkToolHandler → AutomationBenchmarkRunner` **no equivale a probar WhatsApp**:

- El runner clasifica rectángulos e IDs constantes para envío/búsqueda.
- Su fase de reparación usa una entrada sintética; no repara una interfaz rota.
- Que exista fabricante, telemetría o un paso en memoria no demuestra enviar, volver o persistir después de reiniciar.
- El runner contiene una clasificación «Nivel 6» fija. Se eliminó del texto visible de esta herramienta la superioridad no demostrada y se identificó el carácter interno/sintético.
- La etiqueta y los consumidores restantes del modelo de reporte requieren revisión si se reutilizan fuera de esta herramienta.

Existe C14 por separado en `features/automation/benchmark/`. No se ejecutó ahora ni se certificó su cobertura completa. **No usar @benchmark como prueba aprobada de una conversación real.**

## Qué falta, en orden

1. **Diseño único:** consolidar contrato visual y estados entre Flutter y Android; validar manualmente una sola superficie por contexto y retirar el atajo visual de Android solo si se desea.
2. **Fiabilidad de destino:** verificar la identidad final de aperturas por número, nombre y usuario; cubrir ambigüedad, Business y grupos sin inventar metadatos.
3. **Exportación hasta archivo útil:** completar guardado/importación del TXT/ZIP oficial y su lectura estructurada; respetar lo que WhatsApp realmente incluya. No extraer ni prometer acceso a su base privada.
4. **Percepción real:** separar lectura textual, captura autorizada, OCR y modelo visual compatible. Reobservar por condición después de actuar; no añadir sondeos permanentes para fingir que siempre sabe todo.
5. **QA desde el búho:** escenario determinista, aplicación autorizada, datos de prueba, pasos, esperado/observado, aserciones, evidencias, cancelación e informe persistente. Reutilizar el motor y SQLite; no llamar suite a un diagnóstico sintético.
6. **Proceso y reconexión:** definir recuperación si Android mata Flutter/servicio, plazo del transporte y estado incierto sin reintentar envíos. El puente depende de que el engine esté disponible.
7. **Persistencia durable:** acordar qué borradores/resultados se guardan y su privacidad. La sesión actual es memoria del servicio, no supervivencia garantizada al cierre forzado.
8. **Mediciones y compatibilidad:** comprobar manualmente orientación/fuentes/teclado; medir fluidez/temperatura solo cuando se autorice. Compilar no prueba FPS ni ausencia de calor.

## Validación de esta entrega

- 42 pruebas de lógica/widgets aprobaron **antes** de la última prohibición de automatizar. Usan dobles identificados y no acreditan WhatsApp real.
- Análisis final y compilación: consultar los logs de esta carpeta.
- Instalación final y huella: consultar VERIFICACION.json.
- Revisión independiente: cerró el defecto de contexto hasta el clic nativo; el área del avatar se corrigió a 48 dp.
- Nuevos helpers y componentes pequeños: inventario adjunto. Las fachadas heredadas extensas se tocaron mínimamente para transportar el contrato; **no se declara que todo el código heredado ya tenga menos de 200 líneas**.
- No se ejecutó una nueva prueba de envío ni una nueva navegación desde la última instrucción del usuario.

Guía para la comprobación del usuario: [PRUEBAS_MANUALES.md](PRUEBAS_MANUALES.md).
