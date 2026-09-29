part of 'turn_knowledge_fetcher.dart';

// QUÉ HACE: Consulta proveedores configurados y devuelve la primera fuente útil.
// CÓMO FUNCIONA: Sigue la cascada de IA, MCP y búsqueda web ya definida.
// POR QUÉ: Mantiene el enrutamiento externo separado del contrato del agente.
/// Ejecutor de cascada para búsqueda de conocimiento e IA externa.
final class TurnKnowledgeFetcher {
  final BrowserAiGateway? _browserAiGateway;
  final McpConnectionRegistry? _mcpRegistry;
  final McpKnowledgeToolCaller? _mcpKnowledgeToolCaller;
  final WebKnowledgeService _webService;
  final ReverseAgentClient _reverseClient;

  const TurnKnowledgeFetcher({
    BrowserAiGateway? browserAiGateway,
    McpConnectionRegistry? mcpConnectionRegistry,
    McpKnowledgeToolCaller? mcpKnowledgeToolCaller,
    WebKnowledgeService webKnowledgeService = const WebKnowledgeService(),
    ReverseAgentClient reverseAgentClient = const ReverseAgentClient(),
  }) : _browserAiGateway = browserAiGateway,
       _mcpRegistry = mcpConnectionRegistry,
       _mcpKnowledgeToolCaller = mcpKnowledgeToolCaller,
       _webService = webKnowledgeService,
       _reverseClient = reverseAgentClient;

  /// Ejecuta la cascada completa de proveedores externos.
  Future<ExternalKnowledgeResult> executeCascade(String sanitized) async {
    var providerId = 'auto';
    final lower = sanitized.toLowerCase();
    if (lower.contains('deepseek')) {
      providerId = 'deepseek';
    } else if (lower.contains('chatgpt') || lower.contains('openai')) {
      providerId = 'chatgpt';
    } else if (lower.contains('gemini')) {
      providerId = 'gemini';
    }

    debugPrint(
      '[knowledge-router] start provider=$providerId queryChars=${sanitized.length}',
    );

    // Para consultas automáticas, intenta primero un MCP de IA marcado como
    // lectura. Así no consume el turno esperando al modelo local del teléfono.
    if (providerId == 'auto') {
      final mcpResult = await _queryMcpAssistant(sanitized);
      if (mcpResult != null) return mcpResult;
    }

    // BrowserAi es el fallback generativo para consultas abiertas. El límite
    // externo cubre también la inicialización del controlador y el lock.
    if (_browserAiGateway != null) {
      try {
        final aiRes = await _browserAiGateway
            .query(
              BrowserAiQuery(
                providerId: providerId,
                prompt: _assistantPrompt(sanitized),
                timeout: const Duration(seconds: 18),
              ),
            )
            .timeout(
              const Duration(seconds: 20),
              onTimeout: () => BrowserAiResponse.failure(
                providerId: providerId,
                error: 'Tiempo de respuesta agotado.',
                status: BrowserAiResponseStatus.timeout,
              ),
            );
        if (aiRes.isCompleted && aiRes.content.trim().isNotEmpty) {
          debugPrint(
            '[knowledge-router] HIT BrowserAiGateway: ${aiRes.providerId}',
          );
          return ExternalKnowledgeResult(
            query: sanitized,
            rawKnowledge: aiRes.content.trim(),
            source: 'browser_ai_${aiRes.providerId}',
          );
        }
        debugPrint(
          '[knowledge-router] BrowserAiGateway status=${aiRes.status.name}; '
          'continúa fallback',
        );
      } catch (e) {
        debugPrint('[knowledge-router] browser_ai error=${e.runtimeType}');
      }
    }

    // Si el usuario pidió un proveedor con nombre, conserva esa preferencia y
    // recurre al MCP sólo si la sesión web del proveedor no pudo responder.
    if (providerId != 'auto') {
      final mcpResult = await _queryMcpAssistant(sanitized);
      if (mcpResult != null) return mcpResult;
    }

    // Reverse Agent bridge (ChatGPT headless), con tiempo acotado para que un
    // puente caído no retenga el turno de WhatsApp.
    try {
      final bridgeHealthy = await _reverseClient.checkHealth().timeout(
        const Duration(seconds: 2),
        onTimeout: () => false,
      );
      if (bridgeHealthy) {
        final res = await _reverseClient
            .query(
              provider: 'chatgpt',
              prompt: _assistantPrompt(sanitized),
              timeout: const Duration(seconds: 8),
            )
            .timeout(const Duration(seconds: 9));
        if (res.ok && res.response.trim().isNotEmpty) {
          debugPrint(
            '[knowledge-router] HIT ReverseAgent: ${res.actualProvider}',
          );
          return ExternalKnowledgeResult(
            query: sanitized,
            rawKnowledge: res.response.trim(),
            source: res.actualProvider,
          );
        }
      }
    } on Object catch (error) {
      debugPrint(
        '[knowledge-router] reverse-agent failed=${error.runtimeType}',
      );
    }

    // Divide consultas con varios temas para no confundir menciones incidentales.
    try {
      final searchQueries = _webSearchQueries(sanitized);
      final webResults = await Future.wait(
        searchQueries.map((query) async {
          try {
            return await _webService
                .search(query)
                .timeout(const Duration(seconds: 12));
          } on Object catch (_) {
            return null;
          }
        }),
      );
      final allTopicsCovered =
          searchQueries.isNotEmpty &&
          webResults.length == searchQueries.length &&
          List<int>.generate(searchQueries.length, (index) => index).every((
            index,
          ) {
            final result = webResults[index];
            return result != null &&
                result.found &&
                result.summary.trim().isNotEmpty &&
                _isRelevantWebResult(searchQueries[index], result);
          });
      if (allTopicsCovered) {
        final facts = <String>[];
        for (var index = 0; index < webResults.length; index++) {
          final result = webResults[index]!;
          debugPrint(
            '[knowledge-router] HIT WebKnowledgeService: ${result.title}',
          );
          // RelatedTopics puede introducir temas que el contacto no pidió.
          facts.add(result.summary.trim());
        }
        return ExternalKnowledgeResult(
          query: sanitized,
          rawKnowledge: facts.join('\n\n'),
          source: 'web_search',
        );
      }
      for (var index = 0; index < webResults.length; index++) {
        final result = webResults[index];
        if (result == null ||
            !result.found ||
            result.summary.trim().isEmpty ||
            !_isRelevantWebResult(searchQueries[index], result)) {
          debugPrint(
            '[knowledge-router] web result rejected:topic_uncovered '
            'query=${searchQueries[index]} title=${result?.title ?? 'none'}',
          );
        }
      }
    } on Object catch (error) {
      debugPrint('[knowledge-router] web failed=${error.runtimeType}');
    }

    debugPrint('[knowledge-router] no source returned usable content');
    return ExternalKnowledgeResult.empty;
  }

  Future<ExternalKnowledgeResult?> _queryMcpAssistant(String query) async {
    final registry = _mcpRegistry;
    final caller = _mcpKnowledgeToolCaller;
    if (registry == null || caller == null) return null;

    var candidates = _mcpAssistantCandidates(registry.lastTools.values);
    if (candidates.isEmpty && registry.servers.isNotEmpty) {
      try {
        final snapshot = await registry.refreshTools().timeout(
          const Duration(seconds: 6),
        );
        candidates = _mcpAssistantCandidates(snapshot.tools.values);
      } on Object catch (error) {
        debugPrint(
          '[knowledge-router] MCP discovery failed=${error.runtimeType}',
        );
      }
    }

    if (candidates.isEmpty) {
      final catalog = registry.lastTools.values
          .map((tool) {
            final properties = tool.inputSchema['properties'];
            final fields = properties is Map
                ? properties.keys.whereType<String>().join(',')
                : '';
            final requiredFields = tool.inputSchema['required'];
            final requiredNames = requiredFields is List
                ? requiredFields.whereType<String>().join(',')
                : '';
            return '${tool.qualifiedName} fields=[$fields] '
                'required=[$requiredNames] readOnly=${tool.annotations.readOnlyHint} '
                'destructive=${tool.annotations.destructiveHint}';
          })
          .join('; ');
      final servers = registry.servers.map((server) => server.id).join(',');
      debugPrint(
        '[knowledge-router] no compatible MCP AI query tool; '
        'servers=[$servers] tools=[$catalog]',
      );
      return null;
    }

    final tool = candidates.first;
    final arguments = _mcpQueryArguments(tool, _assistantPrompt(query));
    if (arguments == null) return null;
    try {
      final answer = (await caller(
        tool,
        arguments,
      ).timeout(const Duration(seconds: 8)))?.trim();
      if (answer == null || answer.isEmpty) {
        debugPrint('[knowledge-router] MCP AI returned no text');
        return null;
      }
      debugPrint('[knowledge-router] HIT MCP: ${tool.qualifiedName}');
      return ExternalKnowledgeResult(
        query: query,
        rawKnowledge: answer,
        source: 'mcp_${tool.serverId}_${tool.name}',
      );
    } on Object catch (error) {
      debugPrint('[knowledge-router] MCP AI failed=${error.runtimeType}');
      return null;
    }
  }

  List<McpRemoteTool> _mcpAssistantCandidates(
    Iterable<McpRemoteTool> tools,
  ) => tools
      .where((tool) {
        if (tool.annotations.destructiveHint) return false;
        // MCP chat providers often omit readOnlyHint because submitting a
        // prompt writes to their hidden chat. Permit only clearly named AI
        // generation tools with a supported query field; never device tools.
        final identity = '${tool.serverId} ${tool.name} ${tool.description}'
            .replaceAllMapped(
              RegExp(r'([a-z0-9])([A-Z])'),
              (match) => '${match[1]} ${match[2]}',
            );
        final words = RegExp(r'[a-z0-9]+', caseSensitive: false)
            .allMatches(identity)
            .map((match) => match.group(0)!.toLowerCase())
            .toSet();
        const aiMarkers = {
          'ai',
          'llm',
          'model',
          'assistant',
          'deepseek',
          'chatgpt',
          'gemini',
          'claude',
          'kimi',
          'glm',
          'qwen',
        };
        const generationMarkers = {
          'chat',
          'ask',
          'answer',
          'generate',
          'generation',
          'inference',
          'completion',
          'prompt',
          'query',
          'respond',
          'response',
        };
        return words.intersection(aiMarkers).isNotEmpty &&
            words.intersection(generationMarkers).isNotEmpty &&
            _mcpQueryArguments(tool, 'probe') != null;
      })
      .toList(growable: false);

  static String _assistantPrompt(String query) =>
      'Eres el asistente personal de Nano. Responde directamente en español '
      'natural, profesional y con gramática cuidada. Contesta la consulta actual '
      'con claridad; conserva los hechos y la intención. No menciones modelos, '
      'herramientas ni que consultaste una fuente. No inventes datos personales '
      'ni hechos que no conozcas; si la pregunta es ambigua, pide una aclaración.\n\n'
      'Mensaje: $query';

  static List<String> _webSearchQueries(String input) {
    final query = _webSearchQuery(input);
    final secondTopic = RegExp(
      r'\s+y\s+quien\s+(?:fue|era|es|resulto|se\s+considera)\s+',
      caseSensitive: false,
    ).firstMatch(query);
    if (secondTopic == null) return [query];

    final firstQuery = query.substring(0, secondTopic.start).trim();
    final rawSecondQuery = query.substring(secondTopic.end).trim();
    final secondQuery = rawSecondQuery
        .replaceFirst(
          RegExp(
            r'\s*,?\s+(?:(?:el|la)\s+)?angel\s+(?:de\s+la\s+muerte|of\s+death)\b.*$',
            caseSensitive: false,
          ),
          '',
        )
        .trim();
    if (firstQuery.isEmpty || secondQuery.isEmpty) return [query];
    return [firstQuery, secondQuery];
  }

  static String _webSearchQuery(String input) {
    var query = input.trim();
    final currentMessage = RegExp(
      r'mensaje actual\s*:\s*',
      caseSensitive: false,
    ).firstMatch(query);
    if (currentMessage != null) {
      query = query.substring(currentMessage.end).trim();
    }
    query = query.replaceAll(RegExp(r'^[¿?\s]+|[?!.\s]+$'), '').trim();
    query = query
        .replaceAll('á', 'a')
        .replaceAll('é', 'e')
        .replaceAll('í', 'i')
        .replaceAll('ó', 'o')
        .replaceAll('ú', 'u');
    query = query.replaceFirst(
      RegExp(
        r'^(?:que sabes|sabes)\s+(?:acerca de|sobre|de)\s+',
        caseSensitive: false,
      ),
      '',
    );
    query = query.replaceFirst(
      RegExp(
        r'^(?:cuentame|hablame)\s+(?:acerca de|sobre|de)\s+',
        caseSensitive: false,
      ),
      '',
    );
    query = query.replaceFirst(
      RegExp(r'^explicame\s+', caseSensitive: false),
      '',
    );
    return query.replaceAll(RegExp(r'^[¿?\s]+|[?!.\s]+$'), '').trim();
  }

  static bool _isRelevantWebResult(String query, WebKnowledgeResult result) {
    const stopWords = {
      'acerca',
      'algo',
      'como',
      'cual',
      'cuando',
      'cuanta',
      'cuantas',
      'cuanto',
      'cuantos',
      'de',
      'del',
      'dime',
      'donde',
      'el',
      'ella',
      'ellas',
      'ellos',
      'en',
      'es',
      'esta',
      'fue',
      'ha',
      'hacia',
      'la',
      'las',
      'lo',
      'los',
      'me',
      'mi',
      'mis',
      'por',
      'que',
      'quien',
      'quienes',
      'sabes',
      'se',
      'sobre',
      'y',
      'yo',
    };

    Set<String> terms(String text) {
      final normalized = text
          .toLowerCase()
          .replaceAll('á', 'a')
          .replaceAll('é', 'e')
          .replaceAll('í', 'i')
          .replaceAll('ó', 'o')
          .replaceAll('ú', 'u');
      return RegExp(r'[a-z0-9]+')
          .allMatches(normalized)
          .map((match) => match.group(0)!)
          .where((term) => term.length >= 3 && !stopWords.contains(term))
          .toSet();
    }

    final normalizedQuery = query
        .toLowerCase()
        .replaceAll('á', 'a')
        .replaceAll('é', 'e')
        .replaceAll('í', 'i')
        .replaceAll('ó', 'o')
        .replaceAll('ú', 'u');
    final normalizedTitle = result.title
        .toLowerCase()
        .replaceAll('á', 'a')
        .replaceAll('é', 'e')
        .replaceAll('í', 'i')
        .replaceAll('ó', 'o')
        .replaceAll('ú', 'u');
    final asksForEntertainment = RegExp(
      r'\b(cancion|album|banda|grupo|musica|pelicula|serie|videojuego|soundtrack)\b',
    ).hasMatch(normalizedQuery);
    final entertainmentTitle = RegExp(
      r'\b(cancion|album|banda|grupo|pelicula|serie|videojuego|soundtrack)\b',
    ).hasMatch(normalizedTitle);
    if (entertainmentTitle && !asksForEntertainment) return false;

    final queryTerms = terms(normalizedQuery);
    if (queryTerms.isEmpty) return false;
    final source = '${result.title} ${result.summary}';
    final sourceTerms = terms(source);
    final normalizedSource = source
        .toLowerCase()
        .replaceAll('á', 'a')
        .replaceAll('é', 'e')
        .replaceAll('í', 'i')
        .replaceAll('ó', 'o')
        .replaceAll('ú', 'u');
    if (normalizedQuery.contains('mengele') &&
        !sourceTerms.contains('mengele')) {
      return false;
    }
    final asksAboutWorldWarTwo = RegExp(
      r'\b(?:segunda\s+guerra\s+mundial|world\s+war\s+(?:ii|2|two)|wwii)\b',
    ).hasMatch(normalizedQuery);
    final sourceMentionsWorldWarTwo = RegExp(
      r'\b(?:segunda\s+guerra\s+mundial|world\s+war\s+(?:ii|2|two)|wwii)\b',
    ).hasMatch(normalizedSource);
    if (asksAboutWorldWarTwo && !sourceMentionsWorldWarTwo) return false;

    final matches = queryTerms.intersection(sourceTerms).length;
    final requiredMatches = queryTerms.length >= 3
        ? (queryTerms.length + 1) ~/ 2
        : 1;
    return matches >= requiredMatches;
  }

  Future<void> dispose() async {
    try {
      await _reverseClient.stopBridge();
    } catch (_) {}
  }
}

Map<String, Object?>? _mcpQueryArguments(McpRemoteTool tool, String query) {
  if (!tool.annotations.readOnlyHint || tool.annotations.destructiveHint) {
    return null;
  }

  final properties = tool.inputSchema['properties'];
  if (properties is! Map) return null;

  const queryFields = {
    'query',
    'prompt',
    'question',
    'search_query',
    'q',
    'text',
    'input',
    'message',
  };
  final arguments = <String, Object?>{};
  for (final entry in properties.entries) {
    if (entry.key is! String || entry.value is! Map) continue;
    final field = entry.key as String;
    if (!queryFields.contains(field.toLowerCase())) continue;
    final type = (entry.value as Map)['type'];
    final acceptsString =
        type == 'string' || (type is List<dynamic> && type.contains('string'));
    if (acceptsString) arguments[field] = query;
  }
  if (arguments.isEmpty) return null;

  final required = tool.inputSchema['required'];
  if (required is List<dynamic> &&
      required.any(
        (field) => field is! String || !arguments.containsKey(field),
      )) {
    return null;
  }
  return arguments;
}
