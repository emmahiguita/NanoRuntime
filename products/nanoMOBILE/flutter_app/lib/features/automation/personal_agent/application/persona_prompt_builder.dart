// persona_prompt_builder.dart
//
// QUÉ HACE:
// Construye el bloque `<DATOS DE LA PERSONA>` para alimentar el prompt del modelo de lenguaje.
//
// CÓMO FUNCIONA:
// - Valida restricciones de estilo del dueño y tono del contacto.
// - Concatena instrucciones de brevedad y naturalidad ("bien, gracias a Dios", "¿y tú?").
// - Filtra memorias personales relevantes sin exceder el límite de 3000 caracteres de prompt.
// - Formatea pares condicionados y ejemplos históricos sin alucinaciones de hechos vivos.
//
// POR QUÉ:
// Desacopla la lógica de formateo y serialización de prompt del estado en memoria (SOLID - SRP),
// garantizando archivos estructurados y de menos de 200 líneas.

library;

import '../../engine/language/dialogue_state.dart' show linguisticAnalyzer;
import '../../engine/messaging/social_context_retriever.dart';
import '../domain/conversation_agent_role.dart' show isLiveStateQuestion;
import '../domain/owner_live_fact_guard.dart' show FactualEvidenceLevel;
import '../domain/personal_memory.dart';
import '../domain/personal_style_constraints.dart';
import '../domain/persona_example.dart';
import '../domain/persona_profile.dart';
import '../domain/relationship_register.dart';
import 'persona_repository.dart';
import 'persona_retriever.dart';
import 'persona_validator.dart';

abstract final class PersonaPromptBuilder {
  static Future<String> buildBlock({
    required String messageText,
    required String sender,
    required String ownerName,
    required String ownerNotes,
    required Map<String, String> ownerFacts,
    required Map<String, RelationshipProfile> relationships,
    required PersonaRetriever retriever,
    required PersonaRepository repository,
    String conversationId = '',
    String role = 'personal',
  }) async {
    final scope = personalizationScope(conversationId);
    final storedProfile = relationships[conversationId.isEmpty ? sender.trim().toLowerCase() : scope];
    final relationship = storedProfile?.facts['profileEnabled'] == 'false' ? null : storedProfile;
    final contactEnabled = storedProfile?.facts['profileEnabled'] != 'false';
    final learningEnabled = contactEnabled && storedProfile?.facts['learnStyle'] != 'false';
    final roleProfile = relationships['role:$role'];
    final roleEnabled = roleProfile?.facts['profileEnabled'] != 'false';
    final roleScope = roleEnabled && roleProfile?.facts['learnStyle'] != 'false' ? 'role:$role' : 'owner';

    final liveState = isLiveStateQuestion(messageText);
    final examples = liveState
        ? <PersonaExample>[]
        : await retriever.retrieve(
            messageText,
            scopeKey: learningEnabled ? scope : 'owner',
            roleKey: roleScope,
          );

    final valid = const PersonaValidator().validate(
      ownerName: ownerName,
      ownerNotes: liveState || role != 'personal' ? '' : ownerNotes,
      relationshipName: relationship?.displayName,
      relationshipNotes: liveState || role != 'personal' ? null : relationship?.facts['notas'],
      examples: examples,
    );

    final parts = <String>[];
    parts.add(PersonalStyleConstraints.defaultEmmanuel.toPromptInstruction());
    final ownerStyle = RelationshipRegister.styleLine(ownerFacts);
    if (ownerStyle.isNotEmpty) parts.add('Estilo global del dueño: $ownerStyle');
    if (relationship == null) {
      parts.add('Contacto sin relación declarada: trato neutral y respetuoso; no inventes intimidad ni fuerces slang.');
    }
    if (valid.ownerName.isNotEmpty) {
      parts.add(
        'El dueño es ${valid.ownerName}; responde como lo haría él. '
        'Respuestas cortas, directas y naturales (1-2 frases). '
        'Usa "bien, gracias a Dios", "¿y tú?" de forma natural. '
        'Jamás te presentes como asistente ni uses frases robóticas o de soporte corporativo. '
        'Solo si preguntan explícitamente quién eres, responde tu nombre: Nano.',
      );
    }
    if (valid.ownerNotes.isNotEmpty) {
      parts.add('Hechos estables del dueño (Nivel 3 - ${FactualEvidenceLevel.knownStableFact.label}): ${valid.ownerNotes}');
    }

    final roleStyle = RelationshipRegister.styleLine(roleEnabled ? roleProfile?.facts ?? const {} : const {});
    if (roleStyle.isNotEmpty) parts.add('Estilo de este rol: $roleStyle');
    final relationLine = RelationshipRegister.relationLineFor(profile: relationship);
    if (relationLine != null) {
      parts.add('$relationLine Si difiere del estilo global o del rol, prevalece este trato del contacto.');
    }
    if (valid.relationshipNotes != null && valid.relationshipNotes!.isNotEmpty) {
      parts.add('Sobre el contacto ${valid.relationshipName ?? 'el remitente'}: ${valid.relationshipNotes}');
    }

    final signals = linguisticAnalyzer.analyze(messageText);
    if (signals.detectedIntents.length >= 2) {
      parts.add(
        'Intenciones compuestas detectadas (${signals.detectedIntents.join(' + ')}): '
        'conserva cada intención del mensaje y responde de forma integrada sin reducirlo solo al saludo.',
      );
    }

    // Ciclo 19: Prioridad de presupuesto de prompt:
    // 1. Estado actual / 2. Hechos estables y relación / 3. Conversación actual /
    // 4. Memoria relevante (con supersession y degradación temporal) / 5. Ejemplos de estilo al final.
    if (!liveState) {
      await _appendMemories(parts, repository, scope, contactEnabled, roleEnabled, role, messageText);
    }

    if (valid.examples.isNotEmpty) {
      parts.add('Ejemplos de estilo (Nivel 4 - menor prioridad que hechos; jamás contradigas hechos actuales o estables):');
      parts.addAll(valid.examples.map((e) => _exampleLine(e, sender: sender)).where((line) => line.isNotEmpty));
    }

    if (parts.isEmpty) return '';
    var remaining = 3000;
    final bounded = <String>[];
    final seenLines = <String>{};
    for (final part in parts) {
      final norm = part.trim();
      if (norm.isEmpty || !seenLines.add(norm)) continue;
      if (norm.length + 1 <= remaining) {
        bounded.add(norm);
        remaining -= norm.length + 1;
      }
    }
    return '<DATOS DE LA PERSONA>\n'
        '${bounded.join('\n')}\n'
        'Jerarquía factual: 1.estado_actual_observado > 2.estado_actual_explicito > 3.hecho_estable_conocido > 4.memoria_historica_contextual > 5.inferencia > 6.desconocido. '
        'PROHIBIDO convertir memoria histórica o expirada (nivel 4) en hecho actual (niveles 1-2).\n'
        '</DATOS DE LA PERSONA>';
  }

  static Future<void> _appendMemories(
    List<String> parts,
    PersonaRepository repo,
    String scope,
    bool contactEnabled,
    bool roleEnabled,
    String role,
    String messageText,
  ) async {
    final rawMemories = await repo.listPersonalMemories(scopeKey: contactEnabled ? scope : 'owner', limit: 100);
    if (roleEnabled) {
      rawMemories.addAll(await repo.listPersonalMemories(scopeKey: 'role:$role', limit: 100));
    }
    final now = DateTime.now().millisecondsSinceEpoch;
    final resolved = PersonalMemory.resolveSupersession(rawMemories);
    final relevant = resolved.where((m) =>
        m.enabled &&
        m.kind != 'pendingObservation' &&
        m.lifecycleAt(now) != MemoryLifecycleState.superseded &&
        ((contactEnabled && m.scopeKey == scope) || m.scopeKey == 'owner' || (roleEnabled && m.scopeKey == 'role:$role')) &&
        m.value.length <= 450 &&
        (role == 'personal' || m.kind == 'stylePreference')).toList();

    double score(PersonalMemory m) {
      final thematic = SocialContextRetriever.scoreThematicRelevance(
        messageText,
        '${m.key} ${m.value}',
      );
      final ageMs = m.hasReliableTimestamp ? (now - m.observedAt).clamp(0, 31536000000) : 31536000000;
      final recencyDays = (ageMs / 86400000).clamp(0.0, 365.0);
      final recencyBonus = 0.5 / (1.0 + (recencyDays / 30.0));
      final lifecycleBonus = m.lifecycleAt(now) == MemoryLifecycleState.current ? 0.35 : 0.0;
      return thematic + (m.confidence * 0.4) + recencyBonus + lifecycleBonus;
    }
    relevant.sort((a, b) {
      final relevance = score(b).compareTo(score(a));
      if (relevance != 0) return relevance;
      return (b.scopeKey == scope ? 1 : 0).compareTo(a.scopeKey == scope ? 1 : 0);
    });

    final seen = <int>{};
    final selected = relevant
        .where((m) => seen.add(m.id))
        .where((m) =>
            SocialContextRetriever.scoreThematicRelevance(messageText, '${m.key} ${m.value}') > 0 ||
            m.kind == 'stylePreference' ||
            m.kind == 'stableRelationshipFact')
        .take(3);
    for (final m in selected) {
      final lifecycle = m.lifecycleAt(now);
      final effKind = m.effectiveKind(now);
      final level = FactualEvidenceLevel.fromMemoryKind(
        effKind,
        hasReliableTimestamp: m.hasReliableTimestamp,
        isExpiredOrSuperseded: lifecycle != MemoryLifecycleState.current,
      );
      final prefix = level.canAssertCurrentOwnerState
          ? 'Estado actual vigente (${level.label})'
          : level.canAssertStableFact
          ? 'Hecho estable vigente (${level.label})'
          : 'Evento/memoria histórica (${level.label}; NO afirma estado actual)';
      parts.add('$prefix: $effKind: ${_safe(m.key)}: ${_safe(m.value)}');
    }
  }

  static String _exampleLine(PersonaExample example, {String sender = ''}) {
    if (example.isTemplate) {
      if (sender.trim().isEmpty && RegExp(r'\{nombre\}|\[nombre\]').hasMatch(example.body)) return '';
      final body = example.body.replaceAll('{nombre}', _safe(sender)).replaceAll('[nombre]', _safe(sender));
      if (RegExp(r'\{[^}]+\}|\[[^\]]+\]').hasMatch(body)) return '';
      return 'Plantilla orientativa de forma: $body';
    }
    if (example.isPaired) {
      final incoming = example.incomingText.replaceAll('\n', ' ').trim();
      return 'Entrada histórica "$incoming"; respuesta histórica: ${example.body}';
    }
    return '- ${example.body}';
  }

  static String _safe(String val) => val.replaceAll('<', '‹').replaceAll('>', '›').replaceAll(RegExp(r'[\r\n]+'), ' ');
}
