import 'dart:io';
import '../../domain/incoming_attachment.dart';
import 'attachment_content_reader.dart';

/// QUÉ: evita repetir OCR/transcripción del mismo archivo dentro de un chat.
/// CÓMO: clave por chat, tipo, ruta y revisión real del archivo; TTL y cupo.
/// POR QUÉ: ni caché negativa eterna ni archivos de otros chats por cercanía.
final class AttachmentEvidenceCache {
  final _cached = <String, (DateTime, AttachmentReadEvidence)>{};
  final _running = <String, Future<AttachmentReadEvidence>>{};

  Future<AttachmentReadEvidence> read(
    String scope,
    IncomingAttachment attachment,
    AttachmentContentReader reader, {
    bool allowCloud = false,
    bool detailedVisual = false,
  }) async {
    final stat = attachment.localPath == null
        ? null
        : await File(attachment.localPath!).stat();
    final key =
        '$scope|${attachment.type}|${attachment.localPath}|${stat?.size}|${stat?.modified}|$allowCloud|$detailedVisual';
    final now = DateTime.now();
    _cached.removeWhere(
      (_, value) =>
          now.difference(value.$1) >
          (value.$2.available
              ? const Duration(minutes: 20)
              : const Duration(seconds: 8)),
    );
    if (_cached.containsKey(key)) return _cached[key]!.$2;
    if (_running.containsKey(key)) return _running[key]!;
    if (_running.length >= 4) {
      return const AttachmentReadEvidence(
        'Lectura multimedia ocupada; este adjunto sigue sin procesarse.',
        available: false,
      );
    }
    final work = () async {
      try {
        final evidence = await reader.read(
          attachment,
          allowCloud: allowCloud,
          detailedVisual: detailedVisual,
        );
        if (_cached.length >= 48) _cached.remove(_cached.keys.first);
        _cached[key] = (now, evidence);
        return evidence;
      } catch (_) {
        return const AttachmentReadEvidence(
          'No se pudo procesar el adjunto; contenido desconocido.',
          available: false,
        );
      }
    }();
    _running[key] = work;
    try {
      return await work;
    } finally {
      _running.remove(key);
    }
  }
}
