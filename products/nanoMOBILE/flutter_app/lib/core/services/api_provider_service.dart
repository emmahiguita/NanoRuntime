import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;

enum ApiProviderKind {
  local,
  openAi,
  anthropic,
  gemini,
  deepSeek,
  groq,
  openRouter,
  openAiCompatible,
}

extension ApiProviderKindDetails on ApiProviderKind {
  String get label => switch (this) {
    ApiProviderKind.local => 'Nano local (sin API)',
    ApiProviderKind.openAi => 'OpenAI API (GPT / modelos Codex)',
    ApiProviderKind.anthropic => 'Anthropic API (Claude)',
    ApiProviderKind.gemini => 'Google AI API (Gemini)',
    ApiProviderKind.deepSeek => 'DeepSeek API',
    ApiProviderKind.groq => 'Groq API',
    ApiProviderKind.openRouter => 'OpenRouter API',
    ApiProviderKind.openAiCompatible => 'Otro proveedor compatible',
  };

  String get defaultModel => switch (this) {
    ApiProviderKind.local => '',
    ApiProviderKind.openAi => 'gpt-5.6',
    ApiProviderKind.anthropic => 'claude-sonnet-5',
    ApiProviderKind.gemini => 'gemini-3.8-flash',
    ApiProviderKind.deepSeek => 'deepseek-flash',
    ApiProviderKind.groq => 'openai/gpt-oss-20b',
    ApiProviderKind.openRouter => 'openai/gpt-oss-20b',
    ApiProviderKind.openAiCompatible => '',
  };

  String get defaultBaseUrl => switch (this) {
    ApiProviderKind.local => '',
    ApiProviderKind.openAi => 'https://api.openai.com/v1',
    ApiProviderKind.anthropic => 'https://api.anthropic.com',
    ApiProviderKind.gemini =>
      'https://generativelanguage.googleapis.com/v1beta',
    ApiProviderKind.deepSeek => 'https://api.deepseek.com',
    ApiProviderKind.groq => 'https://api.groq.com/openai/v1',
    ApiProviderKind.openRouter => 'https://openrouter.ai/api/v1',
    ApiProviderKind.openAiCompatible => '',
  };
}

final class ApiProviderConfig {
  const ApiProviderConfig({
    required this.provider,
    required this.model,
    required this.baseUrl,
    required this.hasApiKey,
  });

  final ApiProviderKind provider;
  final String model;
  final String baseUrl;
  final bool hasApiKey;

  ApiProviderConfig copyWith({
    ApiProviderKind? provider,
    String? model,
    String? baseUrl,
    bool? hasApiKey,
  }) => ApiProviderConfig(
    provider: provider ?? this.provider,
    model: model ?? this.model,
    baseUrl: baseUrl ?? this.baseUrl,
    hasApiKey: hasApiKey ?? this.hasApiKey,
  );
}

/// API credentials use the platform-backed encrypted store. Provider, model,
/// and endpoint are non-secret but stored beside the credential for a single
/// installation-scoped configuration lifecycle.
final class ApiProviderSettingsStore {
  ApiProviderSettingsStore({FlutterSecureStorage? storage})
    : _storage = storage ?? const FlutterSecureStorage();

  static const _providerKey = 'nanoai.api.provider.v1';
  static const _configPrefix = 'nanoai.api.config.v1.';
  static const _credentialPrefix = 'nanoai.api.credential.v1.';

  final FlutterSecureStorage _storage;

  String _credentialKey(ApiProviderKind provider) =>
      '$_credentialPrefix${provider.name}';
  String _modelKey(ApiProviderKind provider) =>
      '$_configPrefix${provider.name}.model';
  String _baseUrlKey(ApiProviderKind provider) =>
      '$_configPrefix${provider.name}.base_url';

  Future<ApiProviderConfig> load() async {
    final savedProvider = await _storage.read(key: _providerKey);
    final provider = ApiProviderKind.values.firstWhere(
      (candidate) => candidate.name == savedProvider,
      orElse: () => ApiProviderKind.local,
    );
    return loadForProvider(provider);
  }

  Future<ApiProviderConfig> loadForProvider(ApiProviderKind provider) async {
    final savedModel = await _storage.read(key: _modelKey(provider));
    final savedBaseUrl = await _storage.read(key: _baseUrlKey(provider));
    final key = provider == ApiProviderKind.local
        ? null
        : await readApiKey(provider);
    return ApiProviderConfig(
      provider: provider,
      model: savedModel ?? provider.defaultModel,
      baseUrl: savedBaseUrl ?? provider.defaultBaseUrl,
      hasApiKey: key?.trim().isNotEmpty ?? false,
    );
  }

  Future<void> save(ApiProviderConfig config, {String? apiKey}) async {
    await _storage.write(key: _providerKey, value: config.provider.name);
    await _storage.write(
      key: _modelKey(config.provider),
      value: config.model.trim(),
    );
    await _storage.write(
      key: _baseUrlKey(config.provider),
      value: config.baseUrl.trim(),
    );
    final trimmedKey = apiKey?.trim();
    if (config.provider != ApiProviderKind.local &&
        trimmedKey != null &&
        trimmedKey.isNotEmpty) {
      await _storage.write(
        key: _credentialKey(config.provider),
        value: trimmedKey,
      );
    }
  }

  Future<String?> readApiKey(ApiProviderKind provider) async {
    if (provider == ApiProviderKind.local) return null;
    return _storage.read(key: _credentialKey(provider));
  }

  Future<void> deleteApiKey(ApiProviderKind provider) =>
      _storage.delete(key: _credentialKey(provider));
}

final class ApiProviderException implements Exception {
  const ApiProviderException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// Direct REST client for the mobile chat. It intentionally does not log
/// requests or credentials; the selected service receives the chat context.
final class ApiProviderChatService {
  ApiProviderChatService({
    required ApiProviderSettingsStore store,
    http.Client? client,
  }) : _store = store,
       _client = client ?? http.Client();

  final ApiProviderSettingsStore _store;
  final http.Client _client;

  Future<String> generate({
    required String prompt,
    List<Map<String, String>> history = const [],
    double temperature = 0.7,
    int maxTokens = 1024,
  }) async {
    final config = await _store.load();
    if (config.provider == ApiProviderKind.local) {
      throw const ApiProviderException(
        'El chat está configurado en modo local.',
      );
    }
    final apiKey = await _store.readApiKey(config.provider);
    if (apiKey == null || apiKey.trim().isEmpty) {
      throw ApiProviderException(
        'Agrega la clave de ${config.provider.label} en Ajustes > Proveedores de IA.',
      );
    }
    if (config.model.trim().isEmpty) {
      throw ApiProviderException(
        'Escribe el identificador del modelo de ${config.provider.label}.',
      );
    }

    final safeHistory = history
        .where((message) => message['content']?.trim().isNotEmpty ?? false)
        .map(
          (message) => {
            'role': message['role'] == 'assistant' ? 'assistant' : 'user',
            'content': message['content']!.trim(),
          },
        )
        .toList(growable: false);
    final cleanPrompt = prompt.trim();
    if (cleanPrompt.isEmpty) {
      throw const ApiProviderException('El mensaje no puede estar vacío.');
    }

    final result = switch (config.provider) {
      ApiProviderKind.local => throw const ApiProviderException(
        'El chat está configurado en modo local.',
      ),
      ApiProviderKind.openAi => await _generateOpenAi(
        config: config,
        apiKey: apiKey,
        prompt: cleanPrompt,
        history: safeHistory,
        maxTokens: maxTokens,
      ),
      ApiProviderKind.anthropic => await _generateAnthropic(
        config: config,
        apiKey: apiKey,
        prompt: cleanPrompt,
        history: safeHistory,
        maxTokens: maxTokens,
      ),
      ApiProviderKind.gemini => await _generateGemini(
        config: config,
        apiKey: apiKey,
        prompt: cleanPrompt,
        history: safeHistory,
        temperature: temperature,
        maxTokens: maxTokens,
      ),
      ApiProviderKind.deepSeek ||
      ApiProviderKind.groq ||
      ApiProviderKind.openRouter ||
      ApiProviderKind.openAiCompatible => await _generateOpenAiCompatible(
        config: config,
        apiKey: apiKey,
        prompt: cleanPrompt,
        history: safeHistory,
        temperature: temperature,
        maxTokens: maxTokens,
      ),
    };
    if (result.trim().isEmpty) {
      throw ApiProviderException(
        '${config.provider.label} respondió sin texto. Revisa el modelo y los permisos de la clave.',
      );
    }
    return result.trim();
  }

  Future<String> testConnection() => generate(
    prompt: 'Responde exactamente: conexión API correcta.',
    maxTokens: 32,
  );

  Future<String> _generateOpenAi({
    required ApiProviderConfig config,
    required String apiKey,
    required String prompt,
    required List<Map<String, dynamic>> history,
    required int maxTokens,
  }) async {
    final response = await _post(
      uri: Uri.parse('${_trimTrailingSlash(config.baseUrl)}/responses'),
      headers: {
        'Authorization': 'Bearer ${apiKey.trim()}',
        'Content-Type': 'application/json',
      },
      body: {
        'model': config.model.trim(),
        'instructions':
            'Eres Nano AI, un asistente útil y claro. Responde en el idioma del usuario.',
        'input': [
          ...history,
          {'role': 'user', 'content': prompt},
        ],
        'max_output_tokens': maxTokens.clamp(32, 8192),
      },
      provider: config.provider,
    );
    final directText = response['output_text'];
    if (directText is String && directText.trim().isNotEmpty) return directText;
    final output = response['output'];
    if (output is List) {
      final chunks = <String>[];
      for (final item in output.whereType<Map>()) {
        final content = item['content'];
        if (content is! List) continue;
        for (final part in content.whereType<Map>()) {
          if (part['type'] == 'output_text' && part['text'] is String) {
            chunks.add(part['text'] as String);
          }
        }
      }
      return chunks.join();
    }
    return '';
  }

  Future<String> _generateAnthropic({
    required ApiProviderConfig config,
    required String apiKey,
    required String prompt,
    required List<Map<String, dynamic>> history,
    required int maxTokens,
  }) async {
    final response = await _post(
      uri: Uri.parse('${_trimTrailingSlash(config.baseUrl)}/v1/messages'),
      headers: {
        'x-api-key': apiKey.trim(),
        'anthropic-version': '2023-06-01',
        'Content-Type': 'application/json',
      },
      body: {
        'model': config.model.trim(),
        'max_tokens': maxTokens.clamp(32, 8192),
        'system':
            'Eres Nano AI, un asistente útil y claro. Responde en el idioma del usuario.',
        'messages': [
          ...history,
          {'role': 'user', 'content': prompt},
        ],
      },
      provider: config.provider,
    );
    final content = response['content'];
    if (content is! List) return '';
    return content
        .whereType<Map>()
        .where((part) => part['type'] == 'text')
        .map((part) => part['text'] is String ? part['text'] as String : '')
        .join();
  }

  Future<String> _generateGemini({
    required ApiProviderConfig config,
    required String apiKey,
    required String prompt,
    required List<Map<String, dynamic>> history,
    required double temperature,
    required int maxTokens,
  }) async {
    final model = Uri.encodeComponent(config.model.trim());
    final baseUrl = _trimTrailingSlash(config.baseUrl);
    final response = await _post(
      uri: Uri.parse('$baseUrl/models/$model:generateContent'),
      headers: {
        'x-goog-api-key': apiKey.trim(),
        'Content-Type': 'application/json',
      },
      body: {
        'systemInstruction': {
          'parts': [
            {
              'text':
                  'Eres Nano AI, un asistente útil y claro. Responde en el idioma del usuario.',
            },
          ],
        },
        'contents': [
          ...history.map(
            (message) => {
              'role': message['role'] == 'assistant' ? 'model' : 'user',
              'parts': [
                {'text': message['content']},
              ],
            },
          ),
          {
            'role': 'user',
            'parts': [
              {'text': prompt},
            ],
          },
        ],
        'generationConfig': {
          'temperature': temperature.clamp(0, 2),
          'maxOutputTokens': maxTokens.clamp(32, 8192),
        },
      },
      provider: config.provider,
    );
    final candidates = response['candidates'];
    if (candidates is! List || candidates.isEmpty) return '';
    final content = candidates.first is Map
        ? (candidates.first as Map)['content']
        : null;
    final parts = content is Map ? content['parts'] : null;
    if (parts is! List) return '';
    return parts
        .whereType<Map>()
        .map((part) => part['text'] is String ? part['text'] as String : '')
        .join();
  }

  Future<String> _generateOpenAiCompatible({
    required ApiProviderConfig config,
    required String apiKey,
    required String prompt,
    required List<Map<String, dynamic>> history,
    required double temperature,
    required int maxTokens,
  }) async {
    final baseUrl = _trimTrailingSlash(config.baseUrl);
    if (config.provider == ApiProviderKind.openAiCompatible) {
      _validateCustomEndpoint(baseUrl);
    }
    final messages = <Map<String, dynamic>>[
      {
        'role': 'system',
        'content':
            'Eres Nano AI, un asistente útil y claro. Responde en el idioma del usuario.',
      },
      ...history,
      {'role': 'user', 'content': prompt},
    ];
    final body = <String, dynamic>{
      'model': config.model.trim(),
      'messages': messages,
      'temperature': temperature.clamp(0, 2),
    };
    if (config.provider == ApiProviderKind.groq) {
      body['max_completion_tokens'] = maxTokens.clamp(32, 8192);
    } else {
      body['max_tokens'] = maxTokens.clamp(32, 8192);
    }
    final response = await _post(
      uri: Uri.parse('$baseUrl/chat/completions'),
      headers: {
        'Authorization': 'Bearer ${apiKey.trim()}',
        'Content-Type': 'application/json',
      },
      body: body,
      provider: config.provider,
    );
    final choices = response['choices'];
    if (choices is! List || choices.isEmpty || choices.first is! Map) return '';
    final message = (choices.first as Map)['message'];
    final content = message is Map ? message['content'] : null;
    if (content is String) return content;
    if (content is List) {
      return content
          .whereType<Map>()
          .map((part) => part['text'] is String ? part['text'] as String : '')
          .join();
    }
    return '';
  }

  Future<Map<String, dynamic>> _post({
    required Uri uri,
    required Map<String, String> headers,
    required Map<String, dynamic> body,
    required ApiProviderKind provider,
  }) async {
    try {
      final response = await _client
          .post(uri, headers: headers, body: jsonEncode(body))
          .timeout(const Duration(seconds: 45));
      final decoded = jsonDecode(response.body);
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw ApiProviderException(
          _formatHttpError(provider, response.statusCode, decoded),
        );
      }
      if (decoded is! Map<String, dynamic>) {
        throw ApiProviderException(
          '${provider.label} devolvió una respuesta inválida.',
        );
      }
      return decoded;
    } on ApiProviderException {
      rethrow;
    } catch (error) {
      throw ApiProviderException(
        'No se pudo conectar con ${provider.label}: ${_safeNetworkError(error)}',
      );
    }
  }

  String _formatHttpError(
    ApiProviderKind provider,
    int statusCode,
    Object? decoded,
  ) {
    String? detail;
    if (decoded is Map) {
      final error = decoded['error'];
      if (error is Map && error['message'] is String) {
        detail = error['message'] as String;
      } else if (decoded['message'] is String) {
        detail = decoded['message'] as String;
      }
    }
    final clean = detail?.replaceAll(RegExp(r'\s+'), ' ').trim();
    final suffix = clean == null || clean.isEmpty
        ? ''
        : ': ${clean.substring(0, clean.length.clamp(0, 180).toInt())}';
    return '${provider.label} respondió HTTP $statusCode$suffix';
  }

  String _safeNetworkError(Object error) {
    final message = error.toString().replaceAll(RegExp(r'\s+'), ' ').trim();
    if (message.isEmpty) return 'revisa la conexión a Internet';
    return message.substring(0, message.length.clamp(0, 180).toInt());
  }

  void _validateCustomEndpoint(String baseUrl) {
    final uri = Uri.tryParse(baseUrl);
    if (uri == null ||
        uri.scheme != 'https' ||
        uri.host.isEmpty ||
        uri.userInfo.isNotEmpty ||
        uri.hasQuery ||
        uri.hasFragment) {
      throw const ApiProviderException(
        'El endpoint personalizado debe ser una URL HTTPS válida sin usuario, parámetros ni fragmento.',
      );
    }
  }

  String _trimTrailingSlash(String value) =>
      value.trim().replaceFirst(RegExp(r'/+$'), '');
}
