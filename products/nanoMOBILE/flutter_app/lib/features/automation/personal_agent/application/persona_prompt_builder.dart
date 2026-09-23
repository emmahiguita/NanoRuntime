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

import '../domain/conversation_agent_role.dart' show isLiveStateQuestion;
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
    if (valid.ownerNotes.isNotEmpty) parts.add('Datos del dueño: ${valid.ownerNotes}');

    final roleStyle = RelationshipRegister.styleLine(roleEnabled ? roleProfile?.facts ?? const {} : const {});
    if (roleStyle.isNotEmpty) parts.add('Estilo de este rol: $roleStyle');
    final relationLine = RelationshipRegister.relationLineFor(profile: relationship);
    if (relationLine != null) {
      parts.add('$relationLine Si difiere del estilo global o del rol, prevalece este trato del contacto.');
    }
    if (valid.relationshipNotes != null && valid.relationshipNotes!.isNotEmpty) {
      parts.add('Sobre el contacto ${valid.relationshipName ?? 'el remitente'}: ${valid.relationshipNotes}');
    }
    if (valid.examples.isNotEmpty) {
      parts.add('Ejemplos históricos de estilo: imita solo longitud, registro y tono. Su contenido NO acredita hechos.');
      parts.addAll(valid.examples.map((e) => _exampleLine(e, sender: sender)).where((line) => line.isNotEmpty));
    }

    if (!liveState) {
      await _appendMemories(parts, repository, scope, contactEnabled, roleEnabled, role, messageText);
    }

    if (parts.isEmpty) return '';
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
        'Hechos sobre el dueño y sus contactos: úsalos SOLO para forma y contexto real; jamás inventes datos.\n'
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
    final memories = await repo.listPersonalMemories(scopeKey: contactEnabled ? scope : 'owner', limit: 100);
    if (roleEnabled) {
      memories.addAll(await repo.listPersonalMemories(scopeKey: 'role:$role', limit: 100));
    }
    final now = DateTime.now().millisecondsSinceEpoch;
    final relevant = memories.where((m) =>
        m.enabled &&
        !m.expired &&
        ((contactEnabled && m.scopeKey == scope) || m.scopeKey == 'owner' || (roleEnabled && m.scopeKey == 'role:$role')) &&
        m.value.length <= 450 &&
        m.observedAt > 0 &&
        m.observedAt <= now &&
        (role == 'personal' || m.kind == 'stylePreference') &&
        (m.kind == 'stablePreference' || m.kind == 'stableRelationshipFact' || m.kind == 'stylePreference' || m.kind == 'episodicMemory')).toList();

    final words = messageText.toLowerCase().split(RegExp(r'[^\p{L}\p{N}]+', unicode: true)).where((w) => w.length > 2).toSet();
    int score(PersonalMemory m) => words.where((w) => '${m.key} ${m.value}'.toLowerCase().contains(w)).length;
    relevant.sort((a, b) {
      final local = (b.scopeKey == scope ? 1 : 0).compareTo(a.scopeKey == scope ? 1 : 0);
      return local != 0 ? local : score(b).compareTo(score(a));
    });

    final seen = <int>{};
    final lines = relevant
        .where((m) => seen.add(m.id))
        .where((m) => score(m) > 0 || m.kind == 'stylePreference')
        .take(3)
        .map((m) => '${m.kind}: ${_safe(m.key)}: ${_safe(m.value)}');
    for (final line in lines) {
      parts.add('Memoria histórica; NO prueba estado actual: $line');
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
