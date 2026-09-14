import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'llm_engine_client.dart';

/// Contrato abstracto SOLID (Dependency Inversion Principle - DIP)
/// para proveedores de modelos de lenguaje en NanoAI.
abstract interface class ILLMProvider {
  /// Identidad del proveedor (ej: 'local', 'gemini', 'chatgpt')
  String get providerId;

  /// Indica si el proveedor está listo y configurado (API Key presente o servidor local activo)
  Future<bool> isAvailable();

  /// Genera una respuesta completa en un solo turno (non-streaming).
  Future<LLMResult> generate({
    required String prompt,
    String? systemPrompt,
    double temperature = 0.7,
    int maxTokens = 1024,
    List<Map<String, String>>? history,
  });

  /// Genera respuesta con streaming en tiempo real vía Server-Sent Events (SSE).
  Stream<String> stream({
    required String prompt,
    String? systemPrompt,
    double temperature = 0.7,
    int maxTokens = 2048,
    List<Map<String, String>>? history,
  });
}

// ============================================================================
// 1. PROVEEDOR GOOGLE GEMINI (v1beta API)
// ============================================================================

/// Proveedor para la API de Google Gemini (Gemini 2.5 Flash / 1.5 Pro).
class GeminiAIProvider implements ILLMProvider {
  final String apiKey;
  final String model;
  final http.Client _client;

  GeminiAIProvider({
    required this.apiKey,
    this.model = 'gemini-2.5-flash',
    http.Client? client,
  }) : _client = client ?? http.Client();

  @override
  String get providerId => 'gemini:$model';

  @override
  Future<bool> isAvailable() async => apiKey.trim().isNotEmpty;

  Uri _buildUri(bool isStream) {
    final action = isStream ? 'streamGenerateContent' : 'generateContent';
    final alt = isStream ? '&alt=sse' : '';
    return Uri.parse(
      'https://generativelanguage.googleapis.com/v1beta/models/$model:$action?key=$apiKey$alt',
    );
  }

  Map<String, dynamic> _buildRequestBody({
    required String prompt,
    String? systemPrompt,
    double temperature = 0.7,
    int maxTokens = 2048,
    List<Map<String, String>>? history,
  }) {
    final contents = <Map<String, dynamic>>[];

    if (history != null) {
      for (final msg in history) {
        final role = msg['role'] == 'user' ? 'user' : 'model';
        contents.add({
          'role': role,
          'parts': [
            {'text': msg['content'] ?? ''},
          ],
        });
      }
    }

    contents.add({
      'role': 'user',
      'parts': [
        {'text': prompt},
      ],
    });

    final body = <String, dynamic>{
      'contents': contents,
      'generationConfig': {
        'temperature': temperature,
        'maxOutputTokens': maxTokens,
      },
    };

    if (systemPrompt != null && systemPrompt.trim().isNotEmpty) {
      body['systemInstruction'] = {
        'parts': [
          {'text': systemPrompt},
        ],
      };
    }

    return body;
  }

  @override
  Future<LLMResult> generate({
    required String prompt,
    String? systemPrompt,
    double temperature = 0.7,
    int maxTokens = 1024,
    List<Map<String, String>>? history,
  }) async {
    final response = await _client.post(
      _buildUri(false),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(
        _buildRequestBody(
          prompt: prompt,
          systemPrompt: systemPrompt,
          temperature: temperature,
          maxTokens: maxTokens,
          history: history,
        ),
      ),
    );

    if (response.statusCode != 200) {
      throw LLMEngineException(
        'Gemini API error [${response.statusCode}]: ${response.body}',
      );
    }

    final json = jsonDecode(response.body) as Map<String, dynamic>;
    final candidates = json['candidates'] as List?;
    if (candidates == null || candidates.isEmpty) {
      return const LLMResult(text: '');
    }

    final parts = candidates.first['content']?['parts'] as List?;
    final text = parts?.map((p) => p['text'] as String? ?? '').join('') ?? '';
    return LLMResult(text: text);
  }

  @override
  Stream<String> stream({
    required String prompt,
    String? systemPrompt,
    double temperature = 0.7,
    int maxTokens = 2048,
    List<Map<String, String>>? history,
  }) async* {
    final request = http.Request('POST', _buildUri(true))
      ..headers['Content-Type'] = 'application/json'
      ..body = jsonEncode(
        _buildRequestBody(
          prompt: prompt,
          systemPrompt: systemPrompt,
          temperature: temperature,
          maxTokens: maxTokens,
          history: history,
        ),
      );

    final response = await _client.send(request);
    if (response.statusCode != 200) {
      final errBody = await response.stream.bytesToString();
      throw LLMEngineException(
        'Gemini Stream error [${response.statusCode}]: $errBody',
      );
    }

    final streamLines = response.stream
        .transform(utf8.decoder)
        .transform(const LineSplitter());

    await for (final line in streamLines) {
      if (line.startsWith('data: ')) {
        final dataStr = line.substring(6).trim();
        if (dataStr == '[DONE]') break;
        try {
          final json = jsonDecode(dataStr) as Map<String, dynamic>;
          final candidates = json['candidates'] as List?;
          if (candidates != null && candidates.isNotEmpty) {
            final parts = candidates.first['content']?['parts'] as List?;
            if (parts != null) {
              for (final part in parts) {
                final chunk = part['text'] as String?;
                if (chunk != null && chunk.isNotEmpty) {
                  yield chunk;
                }
              }
            }
          }
        } catch (_) {}
      }
    }
  }
}

// ============================================================================
// 2. PROVEEDOR OPENAI / CHATGPT (v1/chat/completions API)
// ============================================================================

/// Proveedor para la API de ChatGPT / OpenAI (GPT-4o, GPT-4o-mini, DeepSeek, Groq).
class ChatGPTAIProvider implements ILLMProvider {
  final String apiKey;
  final String model;
  final String baseUrl;
  final http.Client _client;

  ChatGPTAIProvider({
    required this.apiKey,
    this.model = 'gpt-4o-mini',
    this.baseUrl = 'https://api.openai.com/v1',
    http.Client? client,
  }) : _client = client ?? http.Client();

  @override
  String get providerId => 'chatgpt:$model';

  @override
  Future<bool> isAvailable() async => apiKey.trim().isNotEmpty;

  List<Map<String, String>> _buildMessages({
    required String prompt,
    String? systemPrompt,
    List<Map<String, String>>? history,
  }) {
    final messages = <Map<String, String>>[];
    if (systemPrompt != null && systemPrompt.trim().isNotEmpty) {
      messages.add({'role': 'system', 'content': systemPrompt});
    }
    if (history != null) {
      messages.addAll(history);
    }
    messages.add({'role': 'user', 'content': prompt});
    return messages;
  }

  @override
  Future<LLMResult> generate({
    required String prompt,
    String? systemPrompt,
    double temperature = 0.7,
    int maxTokens = 1024,
    List<Map<String, String>>? history,
  }) async {
    final response = await _client.post(
      Uri.parse('$baseUrl/chat/completions'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $apiKey',
      },
      body: jsonEncode({
        'model': model,
        'messages': _buildMessages(
          prompt: prompt,
          systemPrompt: systemPrompt,
          history: history,
        ),
        'temperature': temperature,
        'max_tokens': maxTokens,
      }),
    );

    if (response.statusCode != 200) {
      throw LLMEngineException(
        'ChatGPT API error [${response.statusCode}]: ${response.body}',
      );
    }

    final json = jsonDecode(response.body) as Map<String, dynamic>;
    final choices = json['choices'] as List?;
    if (choices == null || choices.isEmpty) {
      return const LLMResult(text: '');
    }

    final content = choices.first['message']?['content'] as String? ?? '';
    return LLMResult(text: content);
  }

  @override
  Stream<String> stream({
    required String prompt,
    String? systemPrompt,
    double temperature = 0.7,
    int maxTokens = 2048,
    List<Map<String, String>>? history,
  }) async* {
    final request = http.Request('POST', Uri.parse('$baseUrl/chat/completions'))
      ..headers['Content-Type'] = 'application/json'
      ..headers['Authorization'] = 'Bearer $apiKey'
      ..body = jsonEncode({
        'model': model,
        'messages': _buildMessages(
          prompt: prompt,
          systemPrompt: systemPrompt,
          history: history,
        ),
        'temperature': temperature,
        'max_tokens': maxTokens,
        'stream': true,
      });

    final response = await _client.send(request);
    if (response.statusCode != 200) {
      final errBody = await response.stream.bytesToString();
      throw LLMEngineException(
        'ChatGPT Stream error [${response.statusCode}]: $errBody',
      );
    }

    final streamLines = response.stream
        .transform(utf8.decoder)
        .transform(const LineSplitter());

    await for (final line in streamLines) {
      if (line.startsWith('data: ')) {
        final dataStr = line.substring(6).trim();
        if (dataStr == '[DONE]') break;
        try {
          final json = jsonDecode(dataStr) as Map<String, dynamic>;
          final choices = json['choices'] as List?;
          if (choices != null && choices.isNotEmpty) {
            final delta = choices.first['delta']?['content'] as String?;
            if (delta != null && delta.isNotEmpty) {
              yield delta;
            }
          }
        } catch (_) {}
      }
    }
  }
}

// ============================================================================
// 3. ENRUTADOR HÍBRIDO (LOCAL + CLOUD FALLBACK ROUTER)
// ============================================================================

/// Strategy Pattern: Enrutador inteligente de inferencia para Nano.
///
/// Selecciona automáticamente el mejor proveedor disponible:
/// 1. Preferencia local en el dispositivo (llama.cpp / nanortime local).
/// 2. Si la tarea requiere capacidades avanzadas (ej: razonamiento complejo)
///    o si el motor local está sin modelo / offline, enruta transparentemente a Gemini o ChatGPT.
class HybridLLMRouter implements ILLMProvider {
  final LLMEngineClient localEngine;
  final ILLMProvider? primaryCloudProvider;
  final bool preferCloudForComplexTasks;

  HybridLLMRouter({
    required this.localEngine,
    this.primaryCloudProvider,
    this.preferCloudForComplexTasks = false,
  });

  @override
  String get providerId => 'hybrid(local+${primaryCloudProvider?.providerId ?? 'none'})';

  @override
  Future<bool> isAvailable() async {
    final localOk = await localEngine.isOnline();
    if (localOk) return true;
    if (primaryCloudProvider != null) {
      return await primaryCloudProvider!.isAvailable();
    }
    return false;
  }

  bool _isComplexPrompt(String prompt) {
    if (!preferCloudForComplexTasks) return false;
    final p = prompt.toLowerCase();
    return prompt.length > 1500 ||
        p.contains('analiza') ||
        p.contains('auditoria') ||
        p.contains('refactor') ||
        p.contains('explicación detallada');
  }

  @override
  Future<LLMResult> generate({
    required String prompt,
    String? systemPrompt,
    double temperature = 0.7,
    int maxTokens = 1024,
    List<Map<String, String>>? history,
  }) async {
    final cloudAvailable = primaryCloudProvider != null && await primaryCloudProvider!.isAvailable();

    if (_isComplexPrompt(prompt) && cloudAvailable) {
      debugPrint('[HybridRouter] Enrutando tarea compleja a Nube (${primaryCloudProvider!.providerId})');
      return primaryCloudProvider!.generate(
        prompt: prompt,
        systemPrompt: systemPrompt,
        temperature: temperature,
        maxTokens: maxTokens,
        history: history,
      );
    }

    final localOnline = await localEngine.isOnline();
    if (localOnline) {
      try {
        final fullPrompt = systemPrompt != null ? '$systemPrompt\n\n$prompt' : prompt;
        return await localEngine.generate(
          prompt: fullPrompt,
          temperature: temperature,
          maxTokens: maxTokens,
        );
      } catch (e) {
        debugPrint('[HybridRouter] Error en motor local, intentando fallback a nube: $e');
      }
    }

    if (cloudAvailable) {
      return primaryCloudProvider!.generate(
        prompt: prompt,
        systemPrompt: systemPrompt,
        temperature: temperature,
        maxTokens: maxTokens,
        history: history,
      );
    }

    throw LLMEngineException('Sin motores disponibles (ni local ni nube).');
  }

  @override
  Stream<String> stream({
    required String prompt,
    String? systemPrompt,
    double temperature = 0.7,
    int maxTokens = 2048,
    List<Map<String, String>>? history,
  }) async* {
    final cloudAvailable = primaryCloudProvider != null && await primaryCloudProvider!.isAvailable();

    if (_isComplexPrompt(prompt) && cloudAvailable) {
      yield* primaryCloudProvider!.stream(
        prompt: prompt,
        systemPrompt: systemPrompt,
        temperature: temperature,
        maxTokens: maxTokens,
        history: history,
      );
      return;
    }

    final localOnline = await localEngine.isOnline();
    if (localOnline) {
      try {
        final fullPrompt = systemPrompt != null ? '$systemPrompt\n\n$prompt' : prompt;
        final res = localEngine.generateStream(
          prompt: fullPrompt,
          temperature: temperature,
          maxTokens: maxTokens,
        );
        await for (final token in res.stream) {
          if (token.content.isNotEmpty) {
            yield token.content;
          }
        }
        return;
      } catch (e) {
        debugPrint('[HybridRouter] Error en stream local, intentando fallback a nube: $e');
      }
    }

    if (cloudAvailable) {
      yield* primaryCloudProvider!.stream(
        prompt: prompt,
        systemPrompt: systemPrompt,
        temperature: temperature,
        maxTokens: maxTokens,
        history: history,
      );
      return;
    }

    throw LLMEngineException('Sin motores disponibles para streaming.');
  }
}
