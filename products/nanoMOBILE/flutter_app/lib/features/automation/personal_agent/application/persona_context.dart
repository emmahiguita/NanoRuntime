/// PERSONA-COMPOSE-08 — contexto del agente personal para el prompt.
///
/// Cache en memoria (hidratada por la barrera global) para las lecturas del
/// perfil del dueño y las relaciones; retriever FTS4 (async) para los
/// ejemplos de estilo. Regla FACTS → DECISION → PERSONA → SEND: este bloque
/// es SOLO forma y hechos del dueño — la decisión de enviar ya corrió en el
/// DecisionEngine antes de llegar aquí.
library;

import 'package:flutter/foundation.dart' show debugPrint;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/persona_example.dart';
import '../domain/personal_memory.dart';
import '../domain/conversation_agent_role.dart' show isLiveStateQuestion;
import '../domain/persona_profile.dart';
import '../domain/relationship_register.dart';
import 'persona_repository.dart';
import 'persona_retriever.dart';
import 'persona_validator.dart';

/// Única instancia del contexto personal: la UI de Ajustes refresca este
/// cache tras editar y el writer lo lee EN VIVO por borrador. Hidratación
/// bajo la barrera global de stores (coordinator).
final personaContextProvider = Provider<PersonaContext>((ref) {
  return PersonaContext();
});

final class PersonaContext {
  PersonaContext({PersonaRepository? repository, PersonaRetriever? retriever})
    : _repository = repository ?? PersonaRepository.instance,
      _retriever = retriever ?? PersonaRetriever();

  final PersonaRepository _repository;
  final PersonaRetriever _retriever;

  String _ownerName = '';
  String _ownerNotes = '';
  final Map<String, RelationshipProfile> _relationships = {};

  /// Hidratación (barrera global): perfiles y relaciones en cache. Los
  /// ejemplos NO se cachean: el retriever los busca por mensaje.
  Map<String, String> _ownerFacts = {};

  Future<void> load() async {
    // Publish a complete snapshot only after both durable reads succeed.
    final personas = await _repository.listPersonas();
    final relationships = await _repository.listRelationships();
    final owner = personas.where((p) => p.personaKey == 'owner').firstOrNull;
    _ownerName = owner?.displayName ?? '';
    _ownerNotes = owner?.facts['notas'] ?? '';
    _ownerFacts = owner?.facts ?? {};
    _relationships.clear();
    for (final relationship in relationships) {
      _relationships[relationship.relationshipKey] = relationship;
    }
  }

  /// Recarga tras editar en la UI (misma vía que [load]).
  Future<void> refresh() => load();

  /// AUTO-02 — ¿hay relación registrada para este remitente factual?
  /// Señal determinista del router (jamás el LLM): con relación, el turno
  /// de un contacto sin señales comerciales es PERSONAL.
  bool hasRelationshipFor(String sender, {String conversationId = ''}) =>
      relationshipFor(sender, conversationId: conversationId) != null;

  RelationshipProfile? relationshipFor(
    String sender, {
    String conversationId = '',
  }) {
    final profile =
        _relationships[conversationId.isEmpty
            ? sender.trim().toLowerCase()
            : personalizationScope(conversationId)];
    return profile?.facts['profileEnabled'] == 'false' ? null : profile;
  }

  /// P0-ROUTE — nombre del dueño ('' si no hay perfil owner). El router lo
  /// usa para detectar identidad ("¿está Emmanuel?") → PERSONAL siempre.
  String get ownerName => _ownerName;

  /// Bloque <DATOS DE LA PERSONA> para el prompt ('' si no hay nada).
  ///
  /// [messageText] alimenta el retriever (ejemplos parecidos al contexto);
  /// [sender] es el remitente FACTUAL de la notificación (jamás el LLM) y
  /// matchea la relación por clave normalizada (nombre en minúsculas).
  Future<String> personaBlockFor(
    String messageText,
    String sender, {
    String conversationId = '',
    String role = 'personal',
  }) async {
    final relationship = relationshipFor(
      sender,
      conversationId: conversationId,
    );
    final scope = personalizationScope(conversationId);
    final storedProfile = _relationships[scope];
    final contactEnabled = storedProfile?.facts['profileEnabled'] != 'false';
    final learningEnabled =
        contactEnabled && storedProfile?.facts['learnStyle'] != 'false';
    final roleProfile = _relationships['role:$role'];
    final roleEnabled = roleProfile?.facts['profileEnabled'] != 'false';
    final roleScope = roleEnabled && roleProfile?.facts['learnStyle'] != 'false'
        ? 'role:$role'
        : 'owner';
    // A08 — traza del registro de relación (evidencia física T04/T16):
    // nivel derivado de evidencia del dueño, jamás del tono del mensaje.
    final relationLevel = RelationshipRegister.derive(profile: relationship);
    debugPrint(
      '[relation] senderHash=${_hash(sender)} level=${relationLevel.name}',
    );
    final liveState = isLiveStateQuestion(messageText);
    final examples = liveState
        ? <PersonaExample>[]
        : await _retriever.retrieve(
            messageText,
            scopeKey: learningEnabled ? scope : 'owner',
            roleKey: roleScope,
          );
    // R5-02/R5-03 — traza TEMPORAL del retrieval (brief R5 §26; se quita
    // tras la evidencia física): demuestra qué entra al prompt y de qué
    // tipo. R5-03: los pares condicionados vienen primeros; el legacy
    // (incomingText vacío) solo rellena cupos como estilo suelto.
    final pairedCount = examples.where((e) => e.isPaired).length;
    final legacyCount = examples.length - pairedCount;
    debugPrint(
      '[persona:retrieve] queryHash=${_hash(messageText)} '
      'pairedCandidates=$pairedCount legacyCandidates=$legacyCount '
      'selected=${examples.length}',
    );
    // PERSONA-VALIDATE-09 — todo lo que entra al prompt pasa por el
    // validador determinista: etiquetas neutralizadas, tamaños acotados,
    // ejemplos dedupe. Sin LLM: chequeos mecánicos.
    final valid = const PersonaValidator().validate(
      ownerName: _ownerName,
      ownerNotes: liveState || role != 'personal' ? '' : _ownerNotes,
      relationshipName: relationship?.displayName,
      relationshipNotes: liveState || role != 'personal'
          ? null
          : relationship?.facts['notas'],
      examples: examples,
    );
    final parts = <String>[];
    final ownerStyle = RelationshipRegister.styleLine(_ownerFacts);
    if (ownerStyle.isNotEmpty) {
      parts.add('Estilo global del dueño: $ownerStyle');
    }
    if (relationship == null) {
      parts.add(
        'Contacto sin relación declarada: trato neutral y respetuoso; no inventes intimidad ni fuerces slang.',
      );
    }
    if (valid.ownerName.isNotEmpty) {
      // CONV-PROMPT-02 — framing alineado con la regla 5 del prompt: el
      // dueño NO es un rol que presentar ni un "negocio"; hablar por él es
      // la forma natural del turno. La versión anterior ("Preséntate como
      // su asistente") contradecía la regla dura y empujaba al 1.5B al
      // modo asistente en turnos personales.
      parts.add(
        'El dueño es ${valid.ownerName}; responde como lo haría él. Jamás '
        'te presentes como asistente ni menciones tu rol. Solo si preguntan '
        'explícitamente quién eres, responde tu nombre: Nano.',
      );
    }
    if (valid.ownerNotes.isNotEmpty) {
      parts.add('Datos del dueño: ${valid.ownerNotes}');
    }
    // A08 — línea de trato SOLO cuando hay nivel distinto de unknown:
    // forma del turno, jamás hechos nuevos. Sin relación, el prompt
    // social mínimo queda intacto (R5-PROMPT-ECO-01).
    final roleStyle = RelationshipRegister.styleLine(
      roleEnabled ? roleProfile?.facts ?? const {} : const {},
    );
    if (roleStyle.isNotEmpty) parts.add('Estilo de este rol: $roleStyle');
    final relationLine = RelationshipRegister.relationLineFor(
      profile: relationship,
    );
    if (relationLine != null) {
      parts.add(
        '$relationLine Si difiere del estilo global o del rol, prevalece este trato del contacto.',
      );
    }
    if (valid.relationshipNotes != null &&
        valid.relationshipNotes!.isNotEmpty) {
      parts.add(
        'Sobre el contacto '
        '${valid.relationshipName ?? 'el remitente'}: '
        '${valid.relationshipNotes}',
      );
    }
    if (valid.examples.isNotEmpty) {
      parts.add(
        'Ejemplos históricos de estilo: imita solo longitud, registro y tono. '
        'Su contenido NO acredita hechos, disponibilidad ni estado actuales.',
      );
      parts.addAll(
        valid.examples
            .map((e) => _exampleLine(e, sender: sender))
            .where((line) => line.isNotEmpty),
      );
    }
    if (!liveState) {
      final memories = await _repository.listPersonalMemories(
        scopeKey: contactEnabled ? scope : 'owner',
        limit: 100,
      );
      if (roleEnabled) {
        memories.addAll(
          await _repository.listPersonalMemories(
            scopeKey: 'role:$role',
            limit: 100,
          ),
        );
      }
      final relevant = memories
          .where(
            (m) =>
                m.enabled &&
                !m.expired &&
                ((contactEnabled && m.scopeKey == scope) ||
                    m.scopeKey == 'owner' ||
                    (roleEnabled && m.scopeKey == 'role:$role')) &&
                // Whole records only: never cut a qualification or negation.
                m.value.length <= 450 &&
                m.observedAt > 0 &&
                m.observedAt <= DateTime.now().millisecondsSinceEpoch &&
                (role == 'personal' || m.kind == 'stylePreference') &&
                (m.kind == 'stablePreference' ||
                    m.kind == 'stableRelationshipFact' ||
                    m.kind == 'stylePreference' ||
                    m.kind == 'episodicMemory'),
          )
          .toList();
      final words = messageText
          .toLowerCase()
          .split(RegExp(r'[^\p{L}\p{N}]+', unicode: true))
          .where((w) => w.length > 2)
          .toSet();
      int score(PersonalMemory m) => words
          .where((w) => '${m.key} ${m.value}'.toLowerCase().contains(w))
          .length;
      relevant.sort((a, b) {
        final local = (b.scopeKey == scope ? 1 : 0).compareTo(
          a.scopeKey == scope ? 1 : 0,
        );
        return local != 0 ? local : score(b).compareTo(score(a));
      });
      final seenMemories = <int>{};
      final lines = relevant
          .where((m) => seenMemories.add(m.id))
          .where((m) => score(m) > 0 || m.kind == 'stylePreference')
          .take(3)
          .map(
            (m) =>
                '${m.kind} (registrado ${DateTime.fromMillisecondsSinceEpoch(m.observedAt).toIso8601String().split('T').first}): ${_safe(m.key)}: ${_safe(m.value)}',
          );
      for (final line in lines) {
        parts.add('Memoria histórica; NO prueba estado actual: $line');
      }
    }
    if (parts.isEmpty) return '';
    // The entire prompt contribution, including labels, stays under 3400
    // characters. Drop complete lower-priority records; keep style first.
    var remaining = 3000;
    final bounded = <String>[];
    for (final part in parts) {
      if (part.length + 1 <= remaining) {
        bounded.add(part);
        remaining -= part.length + 1;
      }
    }
    return '<DATOS DE LA PERSONA>\n'
        '${bounded.join('\n')}\n'
        'Hechos sobre el dueño y sus contactos: úsalos SOLO para forma y '
        'contexto real; jamás inventes datos a partir de ellos.\n'
        '</DATOS DE LA PERSONA>';
  }

  /// R5-03 — par condicionado: entrada y respuesta ligadas (el modelo ve la
  /// cadena completa PAST INPUT → PAST OWNER OUTPUT). Legacy sin par: solo
  /// estilo suelto, una línea de forma sin condicionar el turno.
  static String _exampleLine(PersonaExample example, {String sender = ''}) {
    if (example.isTemplate) {
      if (sender.trim().isEmpty &&
          RegExp(r'\{nombre\}|\[nombre\]').hasMatch(example.body)) {
        return '';
      }
      var body = example.body
          .replaceAll('{nombre}', _safe(sender))
          .replaceAll('[nombre]', _safe(sender));
      if (RegExp(r'\{[^}]+\}|\[[^\]]+\]').hasMatch(body)) return '';
      return 'Plantilla orientativa de forma (no acredita hechos ni obliga a respuesta fija): $body';
    }
    if (example.isPaired) {
      final incoming = example.incomingText.replaceAll('\n', ' ').trim();
      return 'Entrada histórica "$incoming"; respuesta histórica: ${example.body}';
    }
    return '- ${example.body}';
  }

  static String _safe(String value) => value
      .replaceAll('<', '‹')
      .replaceAll('>', '›')
      .replaceAll(RegExp(r'[\r\n]+'), ' ');

  /// R5-02 — hash corto sin PII para la traza temporal del retrieval.
  static String _hash(String s) {
    var h = 0;
    for (final c in s.codeUnits) {
      h = (h * 31 + c) & 0x7fffffff;
    }
    return h.toRadixString(16);
  }
}
