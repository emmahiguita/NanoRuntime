# Auditoría del componente Búho AI

Fecha: 26 de octubre de 2026. Alcance: botón, panel, modos, despacho,
resultados, cristal y propiedad de recursos. No incluye otros productos.

## Dictamen y evidencia

El componente tiene conexiones reales, pero no cumple todavía un contrato claro
de interacción ni permite certificar todas sus funciones como completas.

- Captura real del panel Flutter instalado: [09-nano-panel.png](09-nano-panel.png).
- Inspección de los consumidores Dart y del panel Android sobre otras apps.
- Análisis estático final: `dart analyze lib/features/chat/nano_everywhere`,
  salida `No issues found!`, código de salida 0.
- No se enviaron mensajes, ejecutaron órdenes externas ni escribieron tests
  durante esta auditoría. El ensayo previo de envío/regreso sigue pendiente.
- La captura corresponde a la versión instalada. Las correcciones de movimiento
  y cristal descritas más abajo están en fuente, sin compilar ni instalar en esta
  revisión. No se presenta la captura antigua como evidencia de esas correcciones.
- El grafo devolvió algunos fragmentos desactualizados; se contrastaron los
  archivos actuales antes de concluir.

## Qué hace cada opción realmente

| Control | Conexión actual | Límite y estado de comprobación |
| --- | --- | --- |
| Pulsar búho | Abre el panel Flutter; en otras apps, WindowManager abre el panel nativo. | Observado abierto en Nano; existe más de una implementación visual. |
| Arrastrar búho | Cambia posición y acopla al borde; pulsación larga lo oculta. | Código inspeccionado; no se midieron latencia ni fluidez. |
| Chat | Consulta el primer proveedor programático de la lista. | El local va primero sin comprobar disponibilidad. No se probó inferencia aquí. |
| Pantalla | Dart manda `@leer_pantalla`; Android usa `NanoScreenReader`. | Lee texto accesible, no comprende imágenes ni responde una pregunta sobre ellas. |
| Acciones | Pasa órdenes a `NanoActionPortAdapter` y al ejecutor existente. | Es un router de órdenes concretas, no prueba de navegación libre o QA completo. |
| WhatsApp | Normaliza una instrucción con el parser WhatsApp existente. | Seleccionar no ejecuta. Envío y regreso necesitan comprobación independiente. |
| Multimedia/Media | Detecta recursos de un enlace y ofrece descarga. | Detección no prueba disponibilidad ni conversión MP3/MP4. |
| Micrófono Flutter | Invoca el callback de dictado inyectado. | Esta revisión no activó grabación; el parámetro audioLevel no se consume en el editor actual. |
| Historial | Flutter abre el historial de automatización; Android pide sus últimas entradas. | Es historial de acciones, no historial completo del chat del búho. |
| Flecha diagonal | Navega a Chat o Automatización. | No amplía la misma conversación ni transfiere su borrador al otro editor. |
| X | Contrae el panel. | No significa detener la ejecución. |

## Fallos funcionales prioritarios

### F01 — Un enlace desvía las órdenes WhatsApp hacia multimedia (P1)

`android/app/src/main/kotlin/dev/nanoai/mobile/services/NanoOverlayActions.kt:45`
evalúa `detectedUrl != null || tool == "Media"` antes del despacho por herramienta.
Una instrucción WhatsApp con URL termina mostrando enlaces, sin llegar al motor
WhatsApp. También se lee la pantalla por detectar una URL aunque no se solicitó.
Corrección necesaria: la herramienta elegida debe poseer la ruta; una URL es
contenido del mensaje salvo selección explícita de descarga.

### F02 — Una solicitud concurrente puede recibir un resultado anterior (P1)

`nano_overlay_runtime.dart:48` cambia el modo y después espera `submit`.
`nano_ai_controller_submission.dart` retorna inmediatamente si ya está ocupado.
El puente lee entonces answers/status compartidos, sin identidad del turno
aceptado. Puede responder con datos de otra petición. El panel nativo tampoco
bloquea envío ni incorpora Detener. Se necesita admisión explícita por solicitud
y una respuesta ocupada, sin cambiar el modo de una tarea activa.

### F03 — Terminar el router no equivale a cumplir la orden (P1)

`nano_action_port_adapter.dart:125` transforma una orden desconocida en
`@pantalla`. El resultado de esa lectura puede tratarse como éxito de la orden.
El mismo adaptador devuelve errores sin prefijo tipado en su catch y devuelve
peticiones de aclaración como texto normal. El controlador clasifica por prefijos;
por ello no distingue siempre aclaración, observación, error y objetivo cumplido.
No se afirma que los estados ya tipados como `[completedUnverified]` sean éxito:
el clasificador existente sí los detecta. El problema son las salidas sin tipo.

### F04 — Chat prioriza una ruta sin verificarla (P1)

`nano_providers.dart:31,76` crea y antepone `local_litert` incondicionalmente.
`nano_ai_controller_submission.dart:73` selecciona por callback existente, no por
disponibilidad del modelo. La llamada usa el cliente enrutado actual, por lo que
el nombre LiteRT tampoco acredita el backend seleccionado. Se necesita resolver
la ruta antes de consultar y mostrar su estado real, sin cambiar modelos ni
transmitir el texto a otro proveedor de forma silenciosa.

### F05 — Detener una consulta no acredita detener la inferencia (P1)

`NanoAiController.cancel` invalida resultados y cancela acciones cooperativas,
pero `NanoAsk` no expone cancelación. El proveedor local no conserva/cancela el
handle de generación y una consulta web ya despachada puede continuar.
No debe confundirse descartar una respuesta con detener su trabajo subyacente.
Se necesita propiedad de la generación sin cancelar tareas de otros módulos.

### F06 — Pantalla elimina la pregunta y no realiza análisis visual (P2)

`nano_assistant_panel_actions.dart:9` sustituye todo lo escrito por
`@leer_pantalla` y luego limpia el editor. El modo nativo llamado internamente
Resumir solo muestra texto: no lo resume mediante un modelo. Además,
`NanoScreenReader` recorre todas las ventanas ajenas a Nano; no selecciona
estrictamente una única app y puede mezclar teclado o ventanas del sistema.

### F07 — Borradores y sugerencias tienen acciones poco claras (P2)

La flecha de ampliar navega sin transferir borrador/respuestas. Enviar limpia
la entrada antes de conocer aceptación/resultado. Una sugerencia llama a `_send`
inmediatamente en el modo activo; debería preparar texto cuando pueda causar
efectos externos. Copiar permanece habilitado incluso en tarjetas de error,
donde answer.text puede estar vacío.

### F08 — Descargas ofrecen formatos sin acreditarlos (P2)

El detector construye opciones sociales MP4 y MP3 incluso cuando falla la
resolución nativa. El estado dice «listas para descargar» aunque son candidatos.
Un mismo stream se presenta como audio/vídeo; esta inspección no acredita
conversión. El guardado HTTP directo usa una ruta pública y no demuestra por sí
solo compatibilidad con Scoped Storage. El panel nativo tiene otra ruta de
descarga; ambas requieren contrato de formato, almacenamiento y resultado real.

## Auditoría visual

1. La captura muestra opciones cortadas y desplazamiento horizontal sin una
   indicación clara: WhatsApp y Multimedia quedan fuera de la primera vista.
2. El historial ocupa una fila casi vacía. Debe ser un único icono compacto de
   cabecera, conservando un área táctil accesible.
3. La barra de agarre sugiere arrastrar el panel, pero no tiene gesto asociado.
   Debe retirarse o conectarse; no añadir gestos sin necesidad.
4. El panel instalado tiene una placa gris oscura sobre tema claro. El texto
   hereda otra paleta; cristal y contenido no siguen la misma superficie.
5. «Asistente personal» puede confundirse con Nano Personal, que es otro flujo.
6. «Pantalla completa» describe incorrectamente una navegación a otro módulo.
7. Las implementaciones Dart y Android mantienen controles, tema, tamaños y
   estados distintos. Cambiar solo Flutter no arregla el panel sobre WhatsApp.

## Organización recomendada, sin funciones nuevas

Una cabecera compacta Búho AI, historial pequeño y acción de contraer. Debajo,
un selector de modo que no corte opciones, una sola explicación contextual
breve y un editor. Reutilizar cristal y menús anclados de Nano.

Nombres propuestos: Conversar, Leer pantalla, Controlar apps, WhatsApp con su
icono real y Descargar enlace. La explicación debe aclarar límites; seleccionar
solo prepara contexto. La acción principal debe decir Consultar, Leer o Ejecutar
según el modo y mostrar ocupado/detener sin duplicar botones.

No introducir otra tarjeta de órdenes ni otro historial en la barra. No cambiar
sprites, poses, parpadeo, respiración, vuelo ni curvas de apertura existentes.

## Correcciones de fuente de la iteración en curso

No están instaladas ni resuelven los hallazgos F01–F08 completos:

- Política compartida para suspensión, TickerMode y movimiento reducido.
- Un solo interpolador de acople y límites válidos en ventanas pequeñas.
- Despertar del sprite al interactuar, conservando sus secuencias.
- Adaptación de NanoGlass y lente orbital a GlassSurface compartida, sin otro blur.
- Corrección del bloqueo de reenvío tras login; aún falta acotar reintentos de login.
- Propiedad/cierre del cliente HTTP, cancelación de lotes y descarte de resultados
  tardíos. La descarga nativa ya entregada a Android puede continuar.
- Comentarios corregidos: los sprites no son geometría 3D, no hay giroscopio en
  ese componente y el router no garantiza tiempos de inferencia de 0 ms.

Archivos de esta iteración: nano_animation_policy; nano_3d_flip_transition;
nano_ai_controller y submission; nano_media_downloader y download_transfer;
nano_floating_assistant, policy y view; nano_floating_orb; nano_glass y
shimmer_painter; nano_owl_alive, policy y view; nano_owl_3d_turntable, gestures y
view; nano_owl_orbital_ring, view y painter. Todos bajo
`lib/features/chat/nano_everywhere/`, extensión `.dart`, menos de 200 líneas.

## Condiciones pendientes para aprobar el componente

Corregir F01–F08; comprobar cada ruta desde ambos paneles, incluyendo error,
ocupado y cancelación; conservar borrador; validar claro/oscuro/gris, horizontal,
teclado y texto ampliado; verificar envío único y retorno WhatsApp con evidencia.
No se midieron temperatura, batería, FPS ni tiempo de envío. El análisis estático
no sustituye estas observaciones ni acredita ausencia de bugs.
