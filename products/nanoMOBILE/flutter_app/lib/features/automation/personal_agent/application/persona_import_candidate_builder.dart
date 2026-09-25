// QUÉ HACE: valida y construye candidatos derivados de un historial.
// CÓMO: rechaza ruido, clasifica la sección y crea una huella normalizada.
// POR QUÉ: impide aprender enlaces, estados o duplicados sin contexto.

part of 'persona_import.dart';

extension _PersonaImportCandidateBuilder on PersonaImportPipeline {
  void _addExampleCandidate({
    required String incoming,
    required String body,
    required String kind,
    required int at,
    required String source,
    required Object? originalTimestamp,
    required String scopeKey,
    required String fileName,
    required List<PersonaImportCandidate> candidates,
    required List<String> warnings,
  }) {
    final cleanIncoming = incoming.trim();
    final cleanBody = body.trim();
    if (cleanBody.isEmpty) return;
    if (_PersonaImportUtils._excludedBody(cleanBody) ||
        (cleanIncoming.isNotEmpty &&
            _PersonaImportUtils._excludedBody(cleanIncoming))) {
      warnings.add('Contenido omitido, eliminado o multimedia excluido.');
      return;
    }
    if (!isLearnablePersonalPrompt(cleanBody) ||
        (cleanIncoming.isNotEmpty &&
            !isLearnablePersonalPrompt(cleanIncoming))) {
      warnings.add(
        'Enlace aislado, reacción de estado o contenido sin contexto excluido.',
      );
      return;
    }
    if (cleanIncoming.length > 2000 || cleanBody.length > 2000) {
      warnings.add(
        'Un par supera 2000 caracteres por mensaje y necesita revisión manual.',
      );
      return;
    }
    if (_PersonaImportUtils._generatedSource(source)) {
      warnings.add('Salida generada excluida del aprendizaje del dueño.');
      return;
    }

    final semantic = ConversationSemanticClassifier.classify(
      cleanIncoming.isEmpty ? cleanBody : cleanIncoming,
    );
    final fingerprint = _PersonaImportUtils._hash(
      jsonEncode([
        kind,
        normalizePersonalLearningText(cleanIncoming),
        normalizePersonalLearningText(cleanBody),
      ]),
    );
    candidates.add(
      PersonaImportCandidate(
        kind: kind,
        title: kind == 'template'
            ? 'Plantilla de orientación'
            : kind == 'style'
            ? 'Solo estilo: sin entrada original'
            : 'Par real recibido → dueño',
        preview: cleanIncoming.isEmpty
            ? cleanBody
            : '$cleanIncoming\n→ $cleanBody',
        example: {
          'personaKey': scopeKey,
          'incomingText': cleanIncoming,
          'body': cleanBody,
          'source': kind == 'template' ? 'template' : 'owner_import',
          'tone': <String, String>{
            'kind': kind,
            'intent': semantic.storageKey,
            'title': semantic.label,
            'category': semantic.label,
            'fingerprint': fingerprint,
            'sourceContact': scopeKey,
            'observedAt': '$at',
            if (originalTimestamp != null &&
                '$originalTimestamp'.trim().isNotEmpty)
              'originalTimestamp': '$originalTimestamp',
            'sourceName': fileName,
            'ownerVerified': 'false',
            'enabled': 'true',
          },
        },
      ),
    );
  }

  void _addMessage({
    required String role,
    required String text,
    required int at,
    required List<_Message> messages,
    required List<String> warnings,
  }) {
    if (text.length > 2000) {
      messages.add(const _Message('break', '', 0));
      warnings.add(
        'Mensaje de más de 2000 caracteres excluido; se separaron sus pares.',
      );
    } else if (text.trim().isEmpty ||
        _PersonaImportUtils._excludedBody(text)) {
      messages.add(const _Message('break', '', 0));
      warnings.add(
        'Mensaje vacío, eliminado o multimedia excluido; se separaron sus pares.',
      );
    } else {
      messages.add(_Message(role, text.trim(), at));
    }
  }
}
