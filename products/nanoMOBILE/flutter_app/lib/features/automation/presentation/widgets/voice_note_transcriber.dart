// voice_note_transcriber.dart - Motor de transcripción real para notas de voz de WhatsApp.
library;

import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../../../../core/services/whisper_stt_service.dart';

/// Administra la transcripción de notas de voz de mensajería sin generar textos simulados.
abstract final class VoiceNoteTranscriber {
  static final _cache = <String, String>{};
  static final _activeSessions = <String, Future<String>>{};

  static String? getCached(String key) => _cache[key];

  /// Transcribe una nota de voz local a texto.
  static Future<String> transcribe({
    required String audioPathOrUrl,
    void Function(String partial)? onPartialText,
    bool force = false,
  }) {
    if (force) {
      _cache.remove(audioPathOrUrl);
      _activeSessions.remove(audioPathOrUrl);
    } else {
      final cached = _cache[audioPathOrUrl];
      if (cached != null && !cached.contains('descarga Whisper')) {
        return Future.value(cached);
      }
    }
    if (_activeSessions.containsKey(audioPathOrUrl)) {
      return _activeSessions[audioPathOrUrl]!;
    }

    final future = _doTranscribe(audioPathOrUrl, onPartialText);
    _activeSessions[audioPathOrUrl] = future;
    return future;
  }

  static Future<String> _doTranscribe(
    String path,
    void Function(String partial)? onPartial,
  ) async {
    try {
      final clean = path.replaceFirst('file://', '');
      final file = File(clean);

      if (!file.existsSync()) {
        const err = 'Audio no encontrado en el almacenamiento.';
        _activeSessions.remove(path);
        return err;
      }

      final bytes = await file.readAsBytes();
      if (bytes.isEmpty) {
        const err = 'El archivo de audio está vacío (0 bytes).';
        _activeSessions.remove(path);
        return err;
      }

      onPartial?.call('Analizando audio...');

      // 1. Prioridad local: Whisper.cpp offline (Licencia libre MIT, privacidad total)
      final localTranscript = await WhisperSttService.instance.transcribeAudio(
        audioFile: file,
        onProgress: onPartial,
      );
      if (localTranscript != null && localTranscript.isNotEmpty) {
        _cache[path] = localTranscript;
        _activeSessions.remove(path);
        return localTranscript;
      }

      // 2. Fallback cloud opcional: si el usuario configuró API keys externas
      final prefs = await SharedPreferences.getInstance();
      final geminiKey =
          prefs.getString('gemini_api_key') ?? prefs.getString('google_api_key');
      final openAiKey = prefs.getString('openai_api_key');

      if (geminiKey != null && geminiKey.trim().isNotEmpty) {
        onPartial?.call('Transcribiendo con Gemini...');
        final transcript = await _transcribeWithGemini(bytes, geminiKey.trim(), path);
        if (transcript != null && transcript.isNotEmpty) {
          _cache[path] = transcript;
          _activeSessions.remove(path);
          return transcript;
        }
      }

      if (openAiKey != null && openAiKey.trim().isNotEmpty) {
        onPartial?.call('Transcribiendo con OpenAI Whisper...');
        final transcript = await _transcribeWithWhisperOpenAi(file, openAiKey.trim());
        if (transcript != null && transcript.isNotEmpty) {
          _cache[path] = transcript;
          _activeSessions.remove(path);
          return transcript;
        }
      }

      // 3. Diagnóstico factual sin inventar texto (sin cache permanente para permitir reintento)
      final sizeKb = (bytes.length / 1024).toStringAsFixed(1);
      final ext = clean.split('.').last.toUpperCase();
      final report = 'Audio $ext ($sizeKb KB) verificado y listo. '
          'Para transcripción offline gratuita (MIT), descarga Whisper-Tiny (75MB) en la pestaña Modelos.';

      _activeSessions.remove(path);
      return report;
    } catch (e) {
      debugPrint('[VoiceNoteTranscriber] Error: $e');
      _activeSessions.remove(path);
      return 'Error al procesar el audio: $e';
    }
  }

  static Future<String?> _transcribeWithGemini(
    List<int> bytes,
    String apiKey,
    String path,
  ) async {
    try {
      final mime = path.toLowerCase().endsWith('.m4a')
          ? 'audio/mp4'
          : (path.toLowerCase().endsWith('.mp3') ? 'audio/mp3' : 'audio/ogg');

      final base64Audio = base64Encode(bytes);
      final uri = Uri.parse(
        'https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash:generateContent?key=$apiKey',
      );

      final response = await http.post(
        uri,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'contents': [
            {
              'role': 'user',
              'parts': [
                {
                  'inlineData': {'mimeType': mime, 'data': base64Audio},
                },
                {
                  'text':
                      'Transcribe fielmente en español el contenido hablado en este audio. '
                      'Devuelve ÚNICAMENTE las palabras dichas sin explicaciones ni notas adicionales.',
                },
              ],
            },
          ],
          'generationConfig': {'temperature': 0.1, 'maxOutputTokens': 500},
        }),
      );

      if (response.statusCode == 200) {
        final json = jsonDecode(response.body) as Map<String, dynamic>;
        final cand = json['candidates'] as List?;
        final parts = cand?.firstOrNull?['content']?['parts'] as List?;
        return parts?.map((p) => p['text'] as String? ?? '').join('').trim();
      }
    } catch (e) {
      debugPrint('[VoiceNoteTranscriber] Gemini error: $e');
    }
    return null;
  }

  static Future<String?> _transcribeWithWhisperOpenAi(
    File file,
    String apiKey,
  ) async {
    try {
      final uri = Uri.parse('https://api.openai.com/v1/audio/transcriptions');
      final req = http.MultipartRequest('POST', uri)
        ..headers['Authorization'] = 'Bearer $apiKey'
        ..fields['model'] = 'whisper-1'
        ..fields['language'] = 'es'
        ..files.add(await http.MultipartFile.fromPath('file', file.path));

      final res = await req.send();
      if (res.statusCode == 200) {
        final body = await res.stream.bytesToString();
        final json = jsonDecode(body) as Map<String, dynamic>;
        return json['text'] as String?;
      }
    } catch (e) {
      debugPrint('[VoiceNoteTranscriber] Whisper error: $e');
    }
    return null;
  }
}
