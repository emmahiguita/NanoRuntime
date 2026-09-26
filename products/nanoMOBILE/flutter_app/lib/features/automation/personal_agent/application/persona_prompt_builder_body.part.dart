part of 'persona_prompt_builder.dart';

// QUÉ HACE: Construye instrucciones de persona con memoria y ejemplos disponibles.
// CÓMO FUNCIONA: Filtra datos por contacto antes de añadirlos al prompt.
// POR QUÉ: Mantiene explícito el límite factual de la personalización.
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
    final storedProfile =
        relationships[conversationId.isEmpty
            ? sender.trim().toLowerCase()
            : scope];
    final relationship = storedProfile?.facts['profileEnabled'] == 'false'
        ? null
        : storedProfile;
    final contactEnabled = storedProfile?.facts['profileEnabled'] != 'false';
    final learningEnabled =
        contactEnabled && storedProfile?.facts['learnStyle'] != 'false';
    final roleProfile = relationships['role:$role'];
    final roleEnabled = roleProfile?.facts['profileEnabled'] != 'false';
    final roleScope = roleEnabled && roleProfile?.facts['learnStyle'] != 'false'
        ? 'role:$role'
        : 'owner';

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
      relationshipNotes: liveState || role != 'personal'
          ? null
          : relationship?.facts['notas'],
      examples: examples,
    );

    final parts = <String>[];
    parts.add(PersonalStyleConstraints.defaultEmmanuel.toPromptInstruction());
    final ownerStyle = RelationshipRegister.styleLine(ownerFacts);
    if (ownerStyle.isNotEmpty) {
      parts.add('Estilo global del dueño: $ownerStyle');
    }
    if (relationship == null) {
      parts.add(
        'Contacto sin relación declarada: trato neutral y respetuoso; no inventes intimidad ni fuerces slang.',
      );
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
      parts.add(
        'Hechos estables del dueño (Nivel 3 - ${FactualEvidenceLevel.knownStableFact.label}): ${valid.ownerNotes}',
      );
    }

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
        'Sobre el contacto ${valid.relationshipName ?? 'el remitente'}: ${valid.relationshipNotes}',
      );
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
      await _appendMemories(
        parts,
        repository,
        scope,
        contactEnabled,
        roleEnabled,
        role,
        messageText,
      );
    }

    if (valid.examples.isNotEmpty) {
      parts.add(
        'Ejemplos de estilo (Nivel 4 - menor prioridad que hechos; jamás contradigas hechos actuales o estables):',
      );
      parts.addAll(
        valid.examples
            .map((e) => _exampleLine(e, sender: sender))
            .where((line) => line.isNotEmpty),
      );
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
}
