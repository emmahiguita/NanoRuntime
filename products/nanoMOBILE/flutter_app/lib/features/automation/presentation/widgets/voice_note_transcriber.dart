import 'dart:io';
import '../../data/media/attachment_content_reader.dart';
import '../../data/media/attachment_evidence_cache.dart';
import '../../domain/incoming_attachment.dart';
import '../../personal_agent/application/persona_repository.dart';

/// QUÉ: transcripción manual del mismo archivo mostrado por el mensaje.
/// CÓMO: reutiliza percepción local y Gemini canónico con autorización guardada.
/// POR QUÉ: evita claves duplicadas, HTTP sin cerrar y transcripciones concurrentes.
abstract final class VoiceNoteTranscriber {
  static final _reader = AttachmentContentReader();
  static final _evidence = AttachmentEvidenceCache();
  static final _display = <String, (DateTime, String)>{};
  static final _active = <String, Future<String>>{};

  static String? getCached(String key) {
    final cached = _display[key];
    if (cached == null ||
        DateTime.now().difference(cached.$1) > const Duration(minutes: 20)) {
      return null;
    }
    return cached.$2;
  }

  static Future<String> transcribe({
    required String audioPathOrUrl,
    void Function(String partial)? onPartialText,
    bool force = false,
  }) {
    // «Reintentar» no debe separar dos llamadas del mismo trabajo aún activo.
    if (_active.containsKey(audioPathOrUrl)) return _active[audioPathOrUrl]!;
    if (_active.length >= 4) {
      return Future.value('Hay una transcripción en curso. Intenta de nuevo.');
    }
    final work = _read(audioPathOrUrl, force, onPartialText);
    _active[audioPathOrUrl] = work;
    return work.whenComplete(() => _active.remove(audioPathOrUrl));
  }

  static Future<String> _read(
    String path,
    bool force,
    void Function(String)? progress,
  ) async {
    try {
      final local = path.startsWith('file:')
          ? Uri.parse(path).toFilePath()
          : path;
      if (!await File(local).exists()) {
        return 'Audio no disponible en el almacenamiento.';
      }
      final profiles = await PersonaRepository.instance.listPersonas();
      final allowed =
          profiles
              .where((p) => p.personaKey == 'owner')
              .firstOrNull
              ?.facts['allowCloudMedia'] ==
          'true';
      final mime = local.endsWith('.wav')
          ? 'audio/wav'
          : local.endsWith('.m4a')
          ? 'audio/mp4'
          : local.endsWith('.mp3')
          ? 'audio/mpeg'
          : 'audio/ogg';
      final file = IncomingAttachment(
        type: AttachmentType.voice,
        localPath: local,
        mimeType: mime,
        observedAt: 0,
        confidence: AttachmentConfidence.resolvedExact,
      );
      progress?.call('Transcribiendo el archivo real…');
      final result = force
          ? await _reader.read(file, allowCloud: allowed)
          : await _evidence.read(
              'manual-audio',
              file,
              _reader,
              allowCloud: allowed,
            );
      if (result.available) {
        if (_display.length >= 48) _display.remove(_display.keys.first);
        _display[path] = (DateTime.now(), result.text);
      }
      return result.text;
    } catch (_) {
      return 'No se pudo transcribir este archivo. No se ha interpretado su contenido.';
    }
  }
}
