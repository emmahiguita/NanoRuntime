/// Redacción contextual de una respuesta a notificación (A14.7).
///
/// Lee el contenido REAL de la notificación y produce un borrador entendido
/// con el runtime local. El LLM es OPCIONAL y está gateado por política: sin
/// modelo permitido o sin motor disponible devuelve null (la automatización
/// NO responde con texto genérico — pediría clarificación al humano). El
/// contenido de la notificación es dato no confiable; el prompt lo aísla.
library;

import 'package:flutter/foundation.dart' show debugPrint;
import 'package:nanoai/core/services/llm_engine_client.dart';

import '../../personal_agent/domain/conversation_agent_role.dart'
    show
        ConversationAgentRole,
        ConversationAgentRouting,
        isCorrectionMessage,
        isSocialReactionMessage,
        productMentionedWithoutCommerce;
import '../messaging/conv_turn_state.dart' show isPureGreeting;
import '../messaging/conversation_key.dart' show resolveConversationIdentity;
import '../messaging/conversation_memory.dart'
    show
        ConversationMemoryEntry,
        ConversationMemoryEntryKind,
        ConversationMemoryStore;
import '../model/cold_start_retry.dart';
import '../scheduling/event_dedupe_store.dart' show normalizeDedupeText;
import 'conversation_understanding.dart';
import 'notification_draft_prompt.dart';
import 'notification_object.dart';

/// Fuente de borrador contextual. null = no se puede redactar hoy.
///
/// PERSONA-CORE-01 — devuelve el resultado COMPLETO, no solo el texto: el
/// entendimiento estructurado (intent/requiresAction/missingFacts) acompaña
/// al reply para que el DecisionEngine decida con señales verificables en
/// vez de descartarlas justo antes de necesitarlas.
typedef NotificationDraftSource =
    Future<NotificationDraftResult?> Function(NotificationObject notification);

/// Resultado del borrador contextual: reply listo para enviar + entendimiento
/// tipado que lo produjo.
final class NotificationDraftResult {
  /// Entendimiento estructurado del mensaje. Con el escalón de JSON roto
  /// (salida recortada por maxTokens) los campos no-reply quedan vacíos:
  /// honesto, jamás se inventa intent ni requiresAction.
  final ConversationUnderstanding understanding;

  /// Texto listo para enviar (recortado a 2000 chars; el reply del
  /// [understanding] queda SIN recortar para que la decisión vea el texto
  /// completo del modelo).
  final String reply;

  const NotificationDraftResult({
    required this.understanding,
    required this.reply,
  });

  bool get hasReply => reply.isNotEmpty;
}

final class RuntimeNotificationDraftWriter {
  RuntimeNotificationDraftWriter({
    required LLMEngineClient client,
    required bool Function() llmAllowed,
    // WA-LIVE-01 — Future<bool>: el writer valida el resultado (antes el
    // typedef era Future<void> y el bool se descartaba en silencio).
    required Future<bool> Function(String? modelPath) ensureReady,
    required String? Function() modelPath,
    required bool Function() styleEnabled,
    required String Function() styleText,
    String Function(String messageText)? businessBlock,
    String Function()? toneBlock,
    String Function(String conversationId, String messageText)?
    clientContextFor,
    Future<String> Function(String messageText, String sender)? personaBlock,
    // P0-ROUTE — rol del turno por dominio (router determinista AUTO-02,
    // jamás LLM). null = rutas legacy: negocio y persona entran por match
    // léxico como antes. Con routing, el ROL manda sobre el contexto:
    // SALES → hechos del negocio; PERSONAL → persona+relación; el resto
    // no recibe bloque comercial (NO COMMERCIAL = NO SALES CONTEXT).
    ConversationAgentRouting Function(
      String conversationId,
      String messageText,
      String sender,
    )?
    routeFor,
    ConversationMemoryStore? memory,
  }) : _client = client,
       _llmAllowed = llmAllowed,
       _ensureReady = ensureReady,
       _modelPath = modelPath,
       _styleEnabled = styleEnabled,
       _styleText = styleText,
       _businessBlock = businessBlock,
       _toneBlock = toneBlock,
       _clientContextFor = clientContextFor,
       _personaBlock = personaBlock,
       _routeFor = routeFor,
       _memory = memory;

  final LLMEngineClient _client;
  final bool Function() _llmAllowed;
  final Future<bool> Function(String? modelPath) _ensureReady;
  final String? Function() _modelPath;

  /// WA-PERSONA-01 — estilo declarado por el dueño. Leído EN VIVO en cada
  /// borrador (closures sobre settingsProvider): cambiar el toggle o el texto
  /// aplica desde el siguiente mensaje, sin reconstruir el writer.
  final bool Function() _styleEnabled;
  final String Function() _styleText;

  /// WA-BUSINESS-01/02 — bloque <DATOS DEL NEGOCIO> leído EN VIVO por
  /// mensaje: el selector determinista elige el subconjunto relevante del
  /// catálogo (el texto del mensaje decide qué hechos entran al prompt).
  final String Function(String messageText)? _businessBlock;

  /// WA-NATURAL-01 — bloque <TONO DE RESPUESTA> (frases deterministas del
  /// perfil; '' si deshabilitado). Leído EN VIVO en cada borrador.
  final String Function()? _toneBlock;

  /// WA-STATE-01 + CONTEXT-GATE-01 — recuerdo estructurado de la consulta
  /// anterior de ESTA conversación, gated por el mensaje actual
  /// (<CONTEXTO DEL CLIENTE>; '' si no hay nada que recordar o el recuerdo
  /// no aplica al turno).
  final String Function(String conversationId, String messageText)?
  _clientContextFor;

  /// PERSONA-COMPOSE-08 — bloque <DATOS DE LA PERSONA> (dueño, relación con
  /// el remitente y ejemplos FTS4). Async: el retriever consulta SQLite por
  /// mensaje; '' si no hay perfil ni ejemplos. Remitente factual, jamás LLM.
  final Future<String> Function(String messageText, String sender)?
  _personaBlock;

  /// P0-ROUTE — router de dominio por turno. null = comportamiento legacy.
  final ConversationAgentRouting Function(
    String conversationId,
    String messageText,
    String sender,
  )?
  _routeFor;

  /// WA-MEM-08/WA-AGENT-09 — memoria factual de la conversación (contexto
  /// para el borrador). null = el writer conserva el prompt sin historial.
  final ConversationMemoryStore? _memory;

  /// Drafts en vuelo por INPUT LÓGICO. Single-flight solo para la
  /// reemisión del MISMO evento: un notify duplicado de Android (misma
  /// notification.key + mismo timestamp + mismo texto) reutiliza el draft
  /// en curso en vez de lanzar un segundo POST al motor, que lo rechaza
  /// instantáneo (modelo ocupado) y produce un terminal failed falso.
  /// Verificado en dispositivo: notify duplicado a los 10.5s marcó failed
  /// mientras el borrador real llegó 35s después y se envió bien.
  ///
  /// P1-FIX (2026-09-06) — antes la clave era SOLO conversationId: un
  /// mensaje nuevo que llegaba durante un borrador en curso recibía el
  /// Future ANTERIOR y el dispatcher podía enviar el draft del mensaje A
  /// como respuesta al mensaje B (evidencia física: "hola" → "Déjame
  /// confirmar el stock del negro y te digo"). Invariante: 1 INPUT = 1
  /// DRAFT. La clave es conversationId + fingerprint del input (la MISMA
  /// evidencia del dedupe: notification.key, timestamp y texto).
  static final Map<String, Future<NotificationDraftResult?>> _inFlight = {};

  /// P1-FIX — fingerprint del input lógico. Reutiliza la evidencia real
  /// del evento (no se inventa identidad): la misma notification.key con
  /// el mismo timestamp y texto ES el mismo evento; cualquier diferencia
  /// es un mensaje distinto.
  static String _flightFingerprint(NotificationObject n) =>
      '${n.key}|${n.messageTimestamp}|${normalizeDedupeText(n.text)}';

  Future<NotificationDraftResult?> call(NotificationObject notification) async {
    if (!_llmAllowed()) return null;
    final conversationId = resolveConversationIdentity(notification).key.id;
    final flightKey = '$conversationId|${_flightFingerprint(notification)}';
    final inFlight = _inFlight[flightKey];
    if (inFlight != null) {
      debugPrint(
        '[draft:flight] HIT conv=${_shortId(conversationId)} '
        'input="${_sample(notification.text)}"',
      );
      return inFlight;
    }
    debugPrint(
      '[draft:flight] MISS conv=${_shortId(conversationId)} '
      'input="${_sample(notification.text)}"',
    );
    final future = _draft(notification, conversationId);
    _inFlight[flightKey] = future;
    try {
      return await future;
    } finally {
      if (identical(_inFlight[flightKey], future)) {
        _inFlight.remove(flightKey);
      }
    }
  }

  Future<NotificationDraftResult?> _draft(
    NotificationObject notification,
    String conversationId,
  ) async {
    try {
      // El motor local se asegura bajo demanda (mismo patrón que el draft
      // writer de mensajes): sin motor cargado no hay entendimiento.
      // WA-LIVE-01 — el retorno se VALIDA: antes se ignoraba y el writer
      // generaba contra un motor no listo (o con otro modelo cargado).
      final ready = await _ensureReady(_modelPath()).timeout(
        // AUTO-03 — el arranque del motor no puede colgar el turno: al
        // agotarse, el borrador se declara fallido y el pipeline sigue
        // (estado terminal honesto en vez de await eterno — el drenado
        // headless espera submitAll sin timeout propio).
        const Duration(seconds: 60),
        onTimeout: () {
          debugPrint('[draft] ensureReady agotó 60s; sin borrador (honesto)');
          return false;
        },
      );
      if (!ready) {
        debugPrint('[draft] motor no quedó listo; sin borrador (honesto)');
        return null;
      }
      // P1-FIX — traza TEMPORAL del invariante 1 INPUT = 1 DRAFT: start y
      // end llevan el MISMO input, y el dispatcher traza el reply final.
      debugPrint(
        '[draft:start] conv=${_shortId(conversationId)} '
        'input="${_sample(notification.text)}"',
      );
      final historyEntries =
          _memory?.memoryFor(conversationId)?.entries ?? const [];
      // CONTEXT-GATE-01 — saludo puro: el historial comercial anterior NO
      // entra (el 1.5B ecoea la respuesta vieja del Negro en un "Hola");
      // referencias y respuestas cortas sí necesitan la conversación.
      // P0-CORRECTION — corrección ("¿cuál negro de qué hablas?"): el
      // cliente está deshaciendo el turno anterior; el historial del tema
      // viejo solo incita eco. Mismo tratamiento que el saludo puro.
      final history =
          isPureGreeting(notification.text) ||
              isCorrectionMessage(notification.text)
          ? '(sin historial previo)'
          : formatConversationHistory(historyEntries);
      // CONV-SOC-01 — ventana social relevante para el prompt social mínimo:
      // solo el intercambio SOCIAL previo (saludo/reacción), jamás el
      // comercial. MEMORIA DISPONIBLE != MEMORIA RELEVANTE: un "¿y vos?"
      // tras "todo bien" necesita el turno social anterior; un "Hola" tras
      // una venta NO necesita el Negro (eco verificado en vivo).
      final socialEntries = _socialWindow(historyEntries);
      // P0-ROUTE — UNDERSTANDING → ROUTER → CONTEXT: el rol decide QUÉ
      // contexto entra al prompt. Antes negocio y persona entraban por
      // match léxico independiente del routing: una broma con "crema
      // alpina" recibía <DATOS DEL NEGOCIO> y respondía stock (evidencia
      // física). Ahora el invariante manda: SIN intención comercial NO hay
      // bloque comercial; persona+relación SOLO en turnos personales
      // (incluida identidad y correcciones). null routing = legacy.
      final routing = _routeFor?.call(
        conversationId,
        notification.text,
        notification.sender,
      );
      final role = routing?.role ?? ConversationAgentRole.general;
      debugPrint(
        '[route] rol=${role.name} '
        'commercial=${routing?.commercialIntent == true} '
        '${routing?.reasons.join(' | ') ?? 'legacy (sin router)'}',
      );
      // PERSONA-COMPOSE-08 — bloque persona antes del prompt (FTS4 local,
      // no consume turno del motor). Sin perfil ni ejemplos: cadena vacía y
      // el prompt queda idéntico al de WA-CTX-01.
      final persona =
          (routing == null || role == ConversationAgentRole.personal)
          ? await _personaBlock?.call(notification.text, notification.sender) ??
                ''
          : '';
      // WA-CONV-01 — salida JSON estructurada: el razonamiento textual ya no
      // se pide (quemaba tokens antes de "Respuesta:" y el extractor podía
      // devolver el análisis como mensaje con salidas recortadas). El parser
      // tolerante recupera `reply` de JSON completo, JSON roto o legacy.
      // P0-KV (2026-09-06) — sessionId ÚNICO POR TURNO, no por conversación.
      // Forense del runtime (master): con sessionId=conversationId el motor
      // reutilizaba el KV cache de llama.cpp entre turnos de la MISMA
      // conversación (model_manager.rs:1548-1555 — reuse_kv sin
      // clear_kv_cache) y el prompt completo del turno anterior (incluido
      // <DATOS DEL NEGOCIO> del Negro) quedaba en la ventana de atención
      // del turno siguiente: segunda memoria SIN gate, inmune al
      // CONTEXT-GATE-01. Evidencia física: "hola" → reply del Negro.
      // Con sessionId por input (la MISMA identidad del dedupe P1) el gate
      // R5 nunca reutiliza KV: cada turno arranca limpio y el prefix cache
      // V1.1 del motor restaura el system estático desde snapshot (solo se
      // prefilléa el turno dinámico — sin pagar los ~125s completos). El
      // retry frío conserva la MISMA sesión: mismo input = mismo turno.
      // CONV-CTX-01 — firewall por rol: el recuerdo <CONTEXTO DEL CLIENTE>
      // entra SOLO en turnos de venta (rol sales o intención comercial
      // mixta), con el MISMO gate del bloque <DATOS DEL NEGOCIO>. Antes un
      // turno GENERAL con respuesta corta ("sí") recibía el recuerdo del
      // producto sin los facts del negocio: el modelo inventaba precios
      // sobre un contexto a medias.
      final clientContext =
          (routing == null ||
              role == ConversationAgentRole.sales ||
              routing.commercialIntent ||
              // CONV-STATE-02 — respuesta a la pregunta pendiente: el gate
              // determinista devuelve el bloque <PREGUNTA PENDIENTE> (no el
              // recuerdo de producto) para mensajes cortos; es diálogo del
              // propio dueño, entra también en turnos personales.
              routing.pendingReply)
          ? _clientContextFor?.call(conversationId, notification.text) ?? ''
          : '';
      // P0-ROUTE — hechos del negocio SOLO en turnos de venta. El selector
      // léxico (WA-BUSINESS-02) elige el subconjunto; el ROL decide si
      // entra. NO COMMERCIAL INTENT = NO SALES CONTEXT.
      // P0-MULTI — turno mixto ("¿está Emmanuel y todavía tienen el
      // Negro?"): rol personal por identidad PERO commercialIntent true →
      // <DATOS DEL NEGOCIO> entra igual: UNA respuesta con estilo del dueño
      // y facts reales (jamás un chat entre agentes).
      final business =
          (routing == null ||
              role == ConversationAgentRole.sales ||
              routing.commercialIntent)
          ? _businessBlock?.call(notification.text) ?? ''
          : '';
      final turnSession = '$conversationId|${_flightFingerprint(notification)}';
      // CONTEXT-GATE-01 — traza diagnóstica TEMPORAL (se quita tras la
      // validación física M01-M10): una línea antes de llamar al modelo con
      // todo lo que entra al prompt.
      debugPrint(
        '[ctx:prompt] conv=${_shortId(conversationId)} '
        'current="${_sample(notification.text)}" '
        'greeting=${isPureGreeting(notification.text)} '
        'clientContext=${clientContext.isNotEmpty} '
        'historyEntries=${historyEntries.length} '
        'businessChars=${business.length} '
        'session=${_shortId(turnSession)}',
      );
      // P0-PERSONA-BASE — saludo puro: prompt SOCIAL mínimo (sin JSON ni
      // reglas largas) + maxTokens 128. Evidencia física: con el prompt
      // completo el 1.5B devuelve operador aunque la regla dura lo prohíba;
      // el guard lo retiene, pero el objetivo es respuesta cotidiana. El
      // social prompt no necesita estructura: el escalón legacy del parser
      // toma el texto tras "Respuesta:".
      // P0-SOCIAL-2 — reacción social pura ("me alegra", "gracias",
      // "dale") usa el MISMO prompt mínimo: el router ya la marcó personal
      // y el prompt completo la empujó a operador (evidencia 19:49:51
      // "¿Cómo puedo ayudarte hoy?" retenido por el guard). Excepción:
      // turno mixto con producto mencionado conserva el prompt completo
      // para responder al producto.
      final social =
          isPureGreeting(notification.text) ||
          (role == ConversationAgentRole.personal &&
              isSocialReactionMessage(notification.text) &&
              !(routing?.reasons.contains(productMentionedWithoutCommerce) ??
                  false));
      final raw = await generateWithColdRetry(
        _client,
        prompt: social
            ? conversationSocialPromptFor(
                text: notification.text,
                style: _styleEnabled() ? _styleText() : null,
                persona: persona,
                tone: _toneBlock?.call(),
                history: formatConversationHistory(socialEntries),
              )
            : conversationAgentPromptFor(
                history: history,
                text: notification.text,
                style: _styleEnabled() ? _styleText() : null,
                business: business,
                tone: _toneBlock?.call(),
                persona: persona,
                clientContext: clientContext,
              ),
        temperature: 0.3,
        maxTokens: social ? 128 : 320,
        sessionId: turnSession,
      );
      // PERSONA-CORE-01 — el entendimiento COMPLETO viaja con el reply:
      // el DecisionEngine consume intent/requiresAction/missingFacts (antes
      // se descartaban aquí y la decisión quedaba ciega).
      final understanding = parseConversationUnderstanding(raw);
      final draft = understanding?.reply ?? '';
      // CONV-SEM-03 — traza diagnóstica del entendimiento (temporal, como
      // [ctx:gate]): sin ella la relación declarada por el modelo era
      // invisible en logcat y los fallos de continuidad no se podían
      // verificar en dispositivo. Una línea por turno.
      if (understanding != null) {
        debugPrint(
          '[understanding] conv=${_shortId(conversationId)} '
          'relation="${understanding.relation}" intent="${_sample(understanding.intent)}" '
          'questions=${understanding.questions.length} '
          'missingFacts=${understanding.missingFacts.length} '
          'requiresAction=${understanding.requiresAction}',
        );
      }
      if (draft.isEmpty && raw.trim().isNotEmpty) {
        // WA-PHYS-11: sin reply recuperable la traza cruda (acotada) hace
        // el fallo diagnosticable en dispositivo.
        debugPrint('[draft] sin reply parseable; raw=${_sample(raw)}');
      }
      if (draft.isEmpty || understanding == null) return null;
      final reply = draft.length <= 2000 ? draft : draft.substring(0, 2000);
      debugPrint(
        '[draft:end] conv=${_shortId(conversationId)} '
        'input="${_sample(notification.text)}" reply="${_sample(reply)}"',
      );
      return NotificationDraftResult(
        understanding: understanding,
        reply: reply,
      );
    } on Object catch (e) {
      // Motor local no disponible o falló → sin borrador (honesto).
      // WA-LIVE-01 — el catch mudo escondía la razón real del fallo
      // (evidencia device: 7 min de turno colgado sin una sola traza).
      debugPrint('[draft] falló: ${e.runtimeType}: $e');
      return null;
    }
  }

  /// CONV-SOC-01 — ventana social relevante para el prompt social mínimo.
  /// Recorre de atrás hacia adelante: un inbound NO social corta la ventana
  /// (la conversación giró a otro tema — el saludo actual no continúa una
  /// venta); un outbound entra solo acompañado de su inbound social previo
  /// (un outbound HUÉRFANO — Nano respondió social sin mensaje social del
  /// cliente — se salta: no hay continuidad que mostrar). Tras un outbound
  /// la bandera se reinicia: el siguiente outbound necesita OTRO inbound
  /// social. Máx [maxEntries] para el presupuesto del prompt chico.
  static List<ConversationMemoryEntry> _socialWindow(
    List<ConversationMemoryEntry> entries, {
    int maxEntries = 2,
  }) {
    final out = <ConversationMemoryEntry>[];
    var socialInboundSeen = false;
    for (final e in entries.reversed) {
      if (e.kind == ConversationMemoryEntryKind.inbound) {
        if (!(isPureGreeting(e.text) || isSocialReactionMessage(e.text))) {
          break;
        }
        out.add(e);
        socialInboundSeen = true;
      } else if (socialInboundSeen) {
        out.add(e);
        socialInboundSeen = false;
      }
      if (out.length >= maxEntries) break;
    }
    return out.reversed.toList();
  }

  /// Muestra acotada de la salida cruda para trazas físicas (200 chars,
  /// una línea: el raw completo con saltos inundaba el logcat).
  static String _sample(String raw) {
    final single = raw.replaceAll('\n', ' ').trim();
    return single.length <= 200 ? single : single.substring(0, 200);
  }

  /// CONTEXT-GATE-01 — hash corto del id de conversación para la traza.
  static String _shortId(String id) => id.length <= 8 ? id : id.substring(0, 8);
}
