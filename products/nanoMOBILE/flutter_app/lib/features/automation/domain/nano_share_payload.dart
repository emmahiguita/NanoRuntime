import 'package:share_plus/share_plus.dart';

/// Tipo de contenido que Nano está preparando para compartir.
enum NanoShareContentType {
  product,
  document,
  media,
  text,
}

/// Representa el contenido inmutable a compartir desde Nano hacia WhatsApp o aplicaciones externas.
///
/// QUÉ HACE:
/// - Encapsula el texto, archivos adjuntos y metadatos del contenido comercial o documental.
///
/// CÓMO SE CONECTA:
/// - Consumido por NanoShareCoordinator y presentado en NanoContactPickerSheet.
///
/// POR QUÉ:
/// - Estandariza el envío desacoplando la UI origen del destino técnico (< 80 líneas).
final class NanoSharePayload {
  final String title;
  final String text;
  final NanoShareContentType type;
  final XFile? mediaFile;
  final String? subtitle;
  final Map<String, dynamic> metadata;

  const NanoSharePayload({
    required this.title,
    required this.text,
    this.type = NanoShareContentType.text,
    this.mediaFile,
    this.subtitle,
    this.metadata = const {},
  });

  bool get hasMedia => mediaFile != null;

  @override
  String toString() => 'NanoSharePayload(title: $title, type: $type, hasMedia: $hasMedia)';
}
