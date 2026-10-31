import '../../perception/nano_snapshot.dart';

enum WhatsAppComposerState { empty, draft, ambiguous }

/// Combina capacidades, texto literal y controles de la misma ventana.
/// Sin evidencia suficiente detiene la escritura en lugar de suponer vacio.
WhatsAppComposerState classifyWhatsAppComposer(
  NanoNode editor,
  NanoSnapshot snapshot,
) {
  if (!editor.editable ||
      !editor.enabled ||
      !editor.visible ||
      editor.password ||
      !editor.supportsSetText ||
      editor.rawText == null) {
    return WhatsAppComposerState.ambiguous;
  }
  final raw = editor.rawText!;
  if (editor.showingHint || raw.isEmpty) return WhatsAppComposerState.empty;
  // Kotlin corroboró la ayuda con cursor y controles de la misma fila.
  // El texto plano vacío por sí solo no sirve como evidencia de este caso.
  if (editor.emptyEditor && editor.text.isEmpty) {
    return WhatsAppComposerState.empty;
  }
  // Coincidir con la ayuda no demuestra que el usuario no haya escrito eso.
  if (editor.hint.isNotEmpty && raw == editor.hint) {
    return WhatsAppComposerState.ambiguous;
  }
  final send = snapshot.nodes.any(
    (node) =>
        node.packageName == editor.packageName &&
        node.windowId == editor.windowId &&
        node.rootIdentity == editor.rootIdentity &&
        node.id == '${editor.packageName}:id/send' &&
        node.visible &&
        node.enabled,
  );
  return send ? WhatsAppComposerState.draft : WhatsAppComposerState.ambiguous;
}
