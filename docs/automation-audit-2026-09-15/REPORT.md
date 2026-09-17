# Auditoría real de Automatización, agentes y navegador

Fecha: 2026-09-15  
Alcance: `products/nanoMOBILE/flutter_app`, runtime Android y pruebas asociadas.

## Resultado ejecutivo

El problema principal no era “falta de prompt”. El modelo de conversación
permitía que una misma memoria se reutilizara aunque cambiara el rol inferido en
el último turno. Eso mezclaba identidad, objetivos y contexto entre Personal y
Negocios. La corrección mueve la decisión al dominio: cada dirección de
conversación recibe una asignación persistente de agente y cada agente posee un
`scopeKey` distinto. El prompt consume esa decisión; no la inventa.

También se eliminó la deuda estructural de ocho archivos de Automatización que
superaban 900 líneas. El límite ahora está cubierto por una prueba ejecutable.

En navegador, el carrusel que estaba en el worktree no compilaba: el orquestador
pasaba catorce parámetros inexistentes a `SingleBrowserInstanceWidget`. Además,
el supuesto PiP creaba un segundo WebView y falseaba la Page Visibility API,
causando pérdida de posición, audio doble y comportamiento no soportado. Se
reemplazó por WebViews con identidad estable, transferencia explícita de medio,
overlay global visible y PiP nativo Android.

## Hallazgos de Automatización

### P0 — contaminación cruzada entre agentes

- La clave histórica estaba centrada en `conversationId`, no en
  dueño/canal/app/cuenta/conversación/agente.
- El rol podía volver a inferirse desde el contenido de cada turno.
- Una frase comercial en un chat personal podía habilitar contexto de negocio;
  una frase social en Business podía empujar el comportamiento opuesto.

Corrección:

- `ConversationAddress`: dueño, canal, aplicación, cuenta y conversación.
- `AgentConversationScope`: dirección + agente.
- `ConversationAssignmentStore`: asignación durable y transferencia explícita.
- Memoria normalizada por `scopeKey`, sin copiar historial entre agentes.
- Contratos Personal y Negocios insertados como instrucción, nunca como memoria.

### P0 — base de datos insuficiente para reconstrucción y auditoría

El JSON histórico permitía lectura práctica, pero no separaba de forma robusta
asignación, scope, mensajes, estado de diálogo y transferencias.

Corrección SQLite normalizada:

- `conversation_assignments`
- `conversation_scopes`
- `conversation_messages`
- `conversation_dialogue_state`
- `conversation_transfers`

La escritura mantiene compatibilidad con el estado anterior y hace backfill al
hidratar. La transferencia registra procedencia y no altera la memoria fuente.

### P1 — tamaño y responsabilidad

Ocho archivos excedían el máximo solicitado de 900 líneas. Se separaron por
responsabilidad mediante `part`/extensiones internas, preservando la API pública:

- coordinación de ejecución y resultados;
- pasos, acciones y navegación del orquestador;
- intenciones del fast path;
- acciones y diálogos del estudio de personalización;
- componentes de dashboard, reglas, notificaciones y detalle de conversación.

La prueba `automation_architecture_compliance_test.dart` falla si cualquier
archivo de `lib/features/automation` vuelve a superar 900 líneas.

## Ingeniería inversa aplicada

No se copió código externo. Se adoptaron patrones compatibles y se verificaron
licencias antes de usarlos como referencia conceptual:

- Chatwoot (MIT): conversación separada de inbox, cuenta y asignatario. Referencia:
  https://github.com/chatwoot/chatwoot/blob/develop/app/models/conversation.rb
- Rasa (Apache-2.0): estado de diálogo reconstruible desde eventos, no desde un
  único blob opaco. Referencia:
  https://github.com/RasaHQ/rasa/blob/main/rasa/shared/core/trackers.py
- LangGraph (MIT): `thread_id` estable y checkpoints por hilo. Referencia:
  https://github.com/langchain-ai/langgraph

La equivalencia local es `ConversationAddress` + `AgentConversationScope` +
mensajes/estado/transferencias normalizados. No se importó una base de datos de
terceros ni contenido privado.

## Prompt operativo

El contrato completo y copiable está en `AGENT_PROMPTS_ES.md`. Sus invariantes:

- agente seleccionado antes del prompt;
- memoria de un solo scope;
- hechos con procedencia;
- entrada externa como datos no confiables;
- salida JSON compatible con el parser actual;
- pregunta mínima o transferencia ante datos faltantes;
- ausencia total de cadena de pensamiento visible.

## Navegador y carrusel 3D

- `BrowserWindowWidget` vuelve a ser el orquestador, no el dueño de WebViews
  duplicados.
- `BrowserWebAreaWidget` mantiene un WebView estable por `tab.id` y presenta las
  mismas instancias en navegación normal y vista cilíndrica 3D.
- La barra de pestañas, selección por swipe, cierre y retorno desde carrusel usan
  una única fuente de estado.
- El navegador vive en Inicio; las ramas del shell conservan esa rama al cambiar
  de sección, evitando recargas por navegación interna.
- El overlay multimedia se monta por encima del router completo, así también es
  visible en rutas globales.

## Multimedia y YouTube

La política oficial de YouTube prohíbe implementar reproducción oculta en
segundo plano o separar el audio del video. Por eso se eliminó el script que
falseaba `document.hidden`/`visibilityState`.

Implementación admitida:

- el usuario activa PiP explícitamente;
- se lee posición y estado del medio HTML;
- se pausa la fuente antes de montar el destino;
- se restaura la posición en un reproductor visible;
- dentro de Nano, el reproductor permanece visible sobre cualquier pantalla;
- fuera de Nano, Android usa Picture-in-Picture nativo y conserva visible el
  contenido audiovisual.

No se promete audio de YouTube con pantalla apagada ni reproductor oculto. Eso
corresponde a las funciones oficiales de YouTube/Premium, no a un bypass de la
aplicación.

Referencias:

- Android PiP: https://developer.android.com/develop/ui/views/picture-in-picture
- YouTube Developer Policies:
  https://developers.google.com/youtube/terms/developer-policies
- Funcionalidad mínima del reproductor:
  https://developers.google.com/youtube/terms/required-minimum-functionality

## Evidencia de verificación

- `flutter analyze` focalizado en navegador, Inicio y overlay: sin hallazgos.
- Suite Flutter completa: 83 pruebas aprobadas (62 de Automatización/agentes y
  21 de navegador/resolución/seguridad).
- Compilación Android/Kotlin `:app:compileDebugKotlin`: exitosa.
- Límite de 900 líneas en Automatización: aprobado.

La prueba física de gesto, WebView real, transferencia de YouTube y PiP del
sistema requiere un dispositivo/emulador Android con WebView instalado. Compilar
y probar lógica no sustituye esa validación visual y de ciclo de vida.
