part of 'business_profile_edit_dialog.dart';

extension _BusinessProfileEditParsers on _BusinessProfileEditDialogState {
  BusinessProfile _parseProfile() {
    final locale = _locale.text.trim();
    final timezone = _timezone.text.trim();
    final currency = _currency.text.trim().toUpperCase();
    final confidence = double.tryParse(_confidence.text.trim());
    final maxSteps = int.tryParse(_maxSteps.text.trim());
    final approval = int.tryParse(_approval.text.trim());
    if (locale.isEmpty || timezone.isEmpty || currency.isEmpty) {
      throw const FormatException(
        'Idioma, zona horaria y moneda son obligatorios.',
      );
    }
    if (confidence == null || confidence < 0 || confidence > 1) {
      throw const FormatException('La confianza debe estar entre 0 y 1.');
    }
    if (maxSteps == null || maxSteps < 1 || maxSteps > 8) {
      throw const FormatException(
        'Los pasos permitidos deben estar entre 1 y 8.',
      );
    }
    if (approval == null || approval < 0) {
      throw const FormatException('El monto de aprobación no es válido.');
    }
    return widget.initial.copyWith(
      locale: locale,
      timezone: timezone,
      currency: currency,
      intents: _csv(_intents.text),
      tools: _csv(_tools.text),
      blockedAutomation: _csv(_blocked.text),
      faq: _parseFaq(_faq.text),
      dialogues: _parseDialogues(_dialogues.text),
      rules: _parseRules(_rules.text),
      handoffMessage: _handoff.text.trim(),
      handoffConfidence: confidence,
      autoReply: _autoReply,
      maxToolSteps: maxSteps,
      approvalAmount: approval,
      revision: widget.initial.revision + 1,
    );
  }

  List<String> _csv(String raw) => {
    for (final value in raw.split(','))
      if (value.trim().isNotEmpty) value.trim(),
  }.toList();

  List<BusinessFaq> _parseFaq(String raw) => [
    for (final entry in _lines(raw)) _faqEntry(entry),
  ];

  BusinessFaq _faqEntry(String line) {
    final parts = line.split('=>');
    if (parts.length != 2) {
      throw FormatException(
        'FAQ inválida: "$line". Usa patrones => respuesta.',
      );
    }
    final patterns = parts.first
        .split(';')
        .map((item) => item.trim())
        .where((item) => item.isNotEmpty)
        .toList();
    final answer = parts.last.trim();
    if (patterns.isEmpty || answer.isEmpty) {
      throw FormatException('FAQ incompleta: "$line".');
    }
    return BusinessFaq(
      id: 'faq-${patterns.first.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '-')}',
      questionPatterns: patterns,
      answer: answer,
    );
  }

  List<BusinessDialogue> _parseDialogues(String raw) => [
    for (final entry in _lines(raw)) _dialogueEntry(entry),
  ];

  BusinessDialogue _dialogueEntry(String line) {
    final parts = _parts(line, 4, 'flujo');
    return BusinessDialogue(
      id: parts[0],
      intent: parts[1],
      requiredSlots: _csv(parts[2]),
      steps: _csv(parts[3]),
    );
  }

  List<BusinessRule> _parseRules(String raw) => [
    for (final entry in _lines(raw)) _ruleEntry(entry),
  ];

  BusinessRule _ruleEntry(String line) {
    final parts = _parts(line, 4, 'regla');
    return BusinessRule(
      id: parts[0],
      condition: parts[1],
      action: parts[2],
      priority: parts[3].toUpperCase(),
    );
  }

  List<String> _parts(String line, int count, String label) {
    final parts = line.split('|').map((item) => item.trim()).toList();
    if (parts.length != count || parts.any((item) => item.isEmpty)) {
      throw FormatException('Formato de $label inválido: "$line".');
    }
    return parts;
  }

  Iterable<String> _lines(String raw) => raw
      .split('\n')
      .map((line) => line.trim())
      .where((line) => line.isNotEmpty);

  String _formatFaq(List<BusinessFaq> items) => items
      .map((item) => '${item.questionPatterns.join(' ; ')} => ${item.answer}')
      .join('\n');

  String _formatDialogues(List<BusinessDialogue> items) => items
      .map(
        (item) =>
            '${item.id} | ${item.intent} | '
            '${item.requiredSlots.join(', ')} | ${item.steps.join(', ')}',
      )
      .join('\n');

  String _formatRules(List<BusinessRule> items) => items
      .map(
        (item) =>
            '${item.id} | ${item.condition} | '
            '${item.action} | ${item.priority}',
      )
      .join('\n');
}
