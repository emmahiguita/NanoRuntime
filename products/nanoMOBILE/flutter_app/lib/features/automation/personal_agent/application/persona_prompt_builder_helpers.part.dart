part of 'persona_prompt_builder.dart';

// QUÉ HACE: Formatea memoria y ejemplos antes de incluirlos en el prompt.
// CÓMO FUNCIONA: Puntúa datos, elimina duplicados y escapa texto de usuario.
// POR QUÉ: Aísla los detalles de formato sin cambiar la selección de recuerdos.
Future<void> _appendMemories(
  List<String> parts,
  PersonaRepository repo,
  String scope,
  bool contactEnabled,
  bool roleEnabled,
  String role,
  String messageText,
) async {
  final rawMemories = await repo.listPersonalMemories(
    scopeKey: contactEnabled ? scope : 'owner',
    limit: 100,
  );
  if (roleEnabled) {
    rawMemories.addAll(
      await repo.listPersonalMemories(scopeKey: 'role:$role', limit: 100),
    );
  }
  final now = DateTime.now().millisecondsSinceEpoch;
  final resolved = PersonalMemory.resolveSupersession(rawMemories);
  final relevant = resolved
      .where(
        (m) =>
            m.enabled &&
            m.kind != 'pendingObservation' &&
            m.lifecycleAt(now) != MemoryLifecycleState.superseded &&
            ((contactEnabled && m.scopeKey == scope) ||
                m.scopeKey == 'owner' ||
                (roleEnabled && m.scopeKey == 'role:$role')) &&
            m.value.length <= 450 &&
            (role == 'personal' || m.kind == 'stylePreference'),
      )
      .toList();

  double score(PersonalMemory m) {
    final thematic = SocialContextRetriever.scoreThematicRelevance(
      messageText,
      '${m.key} ${m.value}',
    );
    final ageMs = m.hasReliableTimestamp
        ? (now - m.observedAt).clamp(0, 31536000000)
        : 31536000000;
    final recencyDays = (ageMs / 86400000).clamp(0.0, 365.0);
    final recencyBonus = 0.5 / (1.0 + (recencyDays / 30.0));
    final lifecycleBonus = m.lifecycleAt(now) == MemoryLifecycleState.current
        ? 0.35
        : 0.0;
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
      .where(
        (m) =>
            SocialContextRetriever.scoreThematicRelevance(
                  messageText,
                  '${m.key} ${m.value}',
                ) >
                0 ||
            m.kind == 'stylePreference' ||
            m.kind == 'stableRelationshipFact',
      )
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

String _exampleLine(PersonaExample example, {String sender = ''}) {
  if (example.isTemplate) {
    if (sender.trim().isEmpty &&
        RegExp(r'\{nombre\}|\[nombre\]').hasMatch(example.body)) {
      return '';
    }
    final body = example.body
        .replaceAll('{nombre}', _safe(sender))
        .replaceAll('[nombre]', _safe(sender));
    if (RegExp(r'\{[^}]+\}|\[[^\]]+\]').hasMatch(body)) return '';
    return 'Plantilla orientativa de forma: $body';
  }
  if (example.isPaired) {
    final incoming = example.incomingText.replaceAll('\n', ' ').trim();
    return 'Entrada histórica "$incoming"; respuesta histórica: ${example.body}';
  }
  return '- ${example.body}';
}

String _safe(String val) => val
    .replaceAll('<', '‹')
    .replaceAll('>', '›')
    .replaceAll(RegExp(r'[\r\n]+'), ' ');
