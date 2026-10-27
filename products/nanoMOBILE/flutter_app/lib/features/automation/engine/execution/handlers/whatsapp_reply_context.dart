import '../../governance/action_confirmation.dart';
import '../../perception/nano_snapshot.dart';

/// Evidencia local de «este chat». La huella describe contenido visible, no
/// un JID oculto. Un cambio observable exige una nueva petición del usuario.
abstract final class WhatsAppReplyContext {
  /// Quita únicamente bounds de nodeIdentity: el teclado puede redimensionar
  /// la misma raíz. Conserva ventana, resourceId y clase publicados por Android.
  static String rootKey(String identity) {
    final separator = identity.lastIndexOf('|');
    return separator < 0 ? identity : identity.substring(0, separator);
  }

  /// Huella de cabecera/contenido por encima del editor, sin su borrador ni
  /// geometría. No se envía este contenido al modelo ni se guarda texto bruto.
  static String? fingerprint(NanoSnapshot snapshot, int windowId, String root) {
    if (snapshot.truncated) return null;
    final editors = snapshot.nodes
        .where(
          (n) =>
              n.visible &&
              n.editable &&
              n.id == '${snapshot.package}:id/entry' &&
              n.windowId == windowId &&
              rootKey(n.rootIdentity) == rootKey(root),
        )
        .toList();
    if (editors.length != 1) return null;
    final top = editors.single.bounds.top;
    final content = snapshot.nodes
        .where(
          (n) =>
              n.visible &&
              !n.password &&
              n.packageName == snapshot.package &&
              n.windowId == windowId &&
              rootKey(n.rootIdentity) == rootKey(root) &&
              n.bounds.bottom <= top,
        )
        .map(
          (n) => {
            'id': n.id,
            'type': n.type,
            'text': n.text,
            'description': n.description,
          },
        )
        .toList();
    if (content.isEmpty) return null;
    return canonicalFingerprint({
      'package': snapshot.package,
      'window': windowId,
      'root': rootKey(root),
      'content': content,
    });
  }
}
