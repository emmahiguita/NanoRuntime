import '../perception/nano_snapshot.dart';

/// Precondición de contexto para planes ligados a una ventana observada.
/// Se comprueba con una lectura nueva antes de cada tap, incluida una reanudación.
abstract final class UiContextGuard {
  /// Sin contrato conserva las acciones existentes. Un contrato incompleto,
  /// lectura parcial o cambio de raíz/cabecera detiene la acción, sin reintento.
  static String? failure(NanoSnapshot? snapshot, Object? contract) {
    if (contract == null) return null;
    if (contract is! Map || snapshot == null || snapshot.truncated) {
      return '[error] No se pudo revalidar el contexto de la acción.';
    }
    final pkg = contract['package'];
    final root = contract['rootIdentity'];
    final label = contract['headerText'];
    final id = contract['headerId'];
    final window = contract['windowId'];
    if (pkg is! String ||
        root is! String ||
        root.isEmpty ||
        label is! String ||
        label.isEmpty ||
        id is! String ||
        id.isEmpty ||
        window is! int ||
        snapshot.package != pkg) {
      return '[error] El contrato de ventana ya no es válido.';
    }
    final matches = snapshot.visibleNodes.where(
      (node) =>
          node.packageName == pkg &&
          node.windowId == window &&
          node.rootIdentity == root &&
          node.id == id &&
          node.text == label,
    );
    return matches.length == 1
        ? null
        : '[error] Cambió el chat o su ventana. No se ejecutó el siguiente paso.';
  }
}
