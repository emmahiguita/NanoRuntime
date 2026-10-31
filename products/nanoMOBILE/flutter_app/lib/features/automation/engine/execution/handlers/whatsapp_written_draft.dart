import '../../perception/nano_snapshot.dart';
import '../../voice/execution_cancellation.dart';
import 'whatsapp_reply_context.dart';

/// Espera lecturas del texto escrito y su control Enviar; nunca repite SET_TEXT.
/// Una transición de app/chat o cancelación detiene la espera sin pulsar nada.
Future<bool> waitForWhatsAppDraft({
  required Future<NanoSnapshot?> Function() observe,
  required bool Function(NanoSnapshot?) matches,
  required NanoNode editor,
  required String text,
  ExecutionCancellationToken? cancellation,
}) async {
  for (var attempt = 0; attempt < 5; attempt++) {
    if (cancellation?.isCancelled == true) return false;
    final snap = await observe();
    if (!matches(snap) || snap == null || snap.truncated) return false;
    final nodes = snap.nodes.where(
      (n) =>
          n.packageName == editor.packageName &&
          n.windowId == editor.windowId &&
          WhatsAppReplyContext.rootKey(n.rootIdentity) ==
              WhatsAppReplyContext.rootKey(editor.rootIdentity) &&
          n.visible,
    );
    final drafts = nodes.where((n) => n.id == editor.id && n.editable);
    if (drafts.length == 1 &&
        !drafts.single.showingHint &&
        drafts.single.rawText == text &&
        nodes.any(
          (n) => n.id == '${editor.packageName}:id/send' && n.enabled,
        )) {
      return true;
    }
    if (attempt < 4) {
      await Future<void>.delayed(const Duration(milliseconds: 150));
    }
  }
  return false;
}
