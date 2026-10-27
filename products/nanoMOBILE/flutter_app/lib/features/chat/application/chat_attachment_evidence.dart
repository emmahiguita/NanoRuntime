import '../../../core/models/chat_models.dart';

/// Valida lo que el chat puede entregar realmente al motor de texto actual.
/// Una etiqueta de archivo no equivale a haber escuchado o visto su contenido.
abstract final class ChatAttachmentEvidence {
  /// Permite texto extraído y etiquetas reales de ML Kit, cuya descripción
  /// ya explica sus límites. La ruta MNN actual también carga solo texto;
  /// admitir binarios exige primero una capacidad multimedia nativa comprobada.
  static String? unavailableReason(List<ChatAttachment> attachments) {
    for (final attachment in attachments) {
      switch (attachment.kind) {
        case ChatAttachmentKind.audio:
          return 'Este motor de chat todavía no recibe audio. '
              'Usa el dictado para enviar una transcripción o adjunta texto.';
        case ChatAttachmentKind.video:
          return 'Este motor de chat todavía no analiza video. '
              'Adjunta texto o una imagen con observaciones locales disponibles.';
        case ChatAttachmentKind.photo:
          if (!attachment.content.startsWith('[Observación visual local: ')) {
            return 'La imagen no produjo observaciones visuales utilizables. '
                'Este motor recibe texto y no puede interpretar la foto directamente.';
          }
        case ChatAttachmentKind.text:
        case ChatAttachmentKind.document:
          break;
      }
    }
    return null;
  }
}
