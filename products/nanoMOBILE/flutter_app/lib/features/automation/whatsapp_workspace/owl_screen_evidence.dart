import 'dart:io';
import 'package:crypto/crypto.dart';
import 'package:path_provider/path_provider.dart';
import '../../../core/services/nano_runtime_api.dart';
import '../../../core/services/owl_surface_bridge.dart';
import '../../chat/domain/chat_vision_adapter.dart';
import '../engine/perception/nano_snapshot.dart';
import 'owl_screen_retention.dart';

/// Captura píxeles reales y jerarquía en una observación. OCR/etiquetas usan
/// el lector local existente; no se presenta como un VLM ni se sube a la nube.
class OwlScreenEvidence {
  /// Oculta solo el adorno propio durante la captura y siempre lo restaura.
  /// Una ventana segura o fallo PNG se publica, nunca se sustituye por imagen falsa.
  Future<({NanoAtomicSnapshot snapshot, String? imagePath, String? sha256})>
  capture() async {
    await OwlSurfaceBridge.hideDecorations(true);
    try {
      final raw = await NanoRuntimeApi.instance.agentDumpAtomicSnapshot(
        includeScreenshot: true,
      );
      if (raw == null) {
        throw StateError('No hubo respuesta del servicio de Accesibilidad.');
      }
      final snapshot = NanoAtomicSnapshot.fromRaw(raw);
      final bytes = snapshot.screenshotPng;
      if (bytes == null || bytes.isEmpty || !snapshot.screenshotIncluded) {
        return (snapshot: snapshot, imagePath: null, sha256: null);
      }
      final directory = Directory(
        '${(await getApplicationSupportDirectory()).path}/owl/screens',
      );
      await directory.create(recursive: true);
      await trimOwlScreens(directory);
      final file = File(
        '${directory.path}/screen_${DateTime.now().microsecondsSinceEpoch}.png',
      );
      await file.writeAsBytes(bytes, flush: true);
      return (
        snapshot: snapshot,
        imagePath: file.path,
        sha256: sha256.convert(bytes).toString(),
      );
    } finally {
      await OwlSurfaceBridge.hideDecorations(false);
    }
  }

  /// La salida declara alcance, origen y errores. Las etiquetas no identifican
  /// personas ni demuestran intención; un vídeo no se comprende por su fotograma.
  Future<String> read() async {
    final evidence = await capture();
    final snapshot = evidence.snapshot;
    final text = snapshot.hierarchy.visibleNodes
        .where((n) => !n.password)
        .map((n) => n.label)
        .where((s) => s.isNotEmpty)
        .toSet()
        .join('\n');
    final visual = evidence.imagePath == null
        ? null
        : await MlKitChatVisionAdapter().describe(evidence.imagePath!);
    return 'App observada: ${snapshot.hierarchy.package}.\n'
        'Texto accesible visible${snapshot.hierarchy.truncated ? ' (parcial)' : ''}:\n$text\n\n'
        '${evidence.imagePath == null ? 'Captura no disponible (Android: ${snapshot.screenshotErrorCode}).' : 'Captura real guardada: ${evidence.imagePath}'}\n'
        '${visual ?? 'No se obtuvieron observaciones OCR/etiquetas de la captura.'}\n'
        'Esto no es el historial completo ni comprensión semántica de un VLM. '
        'No se observan mensajes fuera de pantalla ni un vídeo completo.';
  }
}
