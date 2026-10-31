import 'package:flutter/services.dart';
import '../../../core/services/owl_surface_bridge.dart';
import '../../automation/engine/planning/whatsapp_component_requests.dart';

/// Prepara texto literal cuando Accesibilidad no puede escribir en otra app.
/// El portapapeles es del sistema: el usuario elige dónde pegar y enviar.
abstract final class NanoInputFallback {
  /// Consulta la habilitación y selección reales sin activar servicios.
  static Future<Map<Object?, Object?>> status() async =>
      await OwlSurfaceBridge.channel.invokeMapMethod<Object?, Object?>(
        'inputStatus',
      ) ??
      const {};

  /// Abre los ajustes oficiales; Android conserva la elección del usuario.
  static Future<void> openKeyboardSettings() async {
    await OwlSurfaceBridge.channel.invokeMethod<bool>('openInputSettings');
  }

  /// Reconoce únicamente órdenes explícitas al chat actual; no inventa destino.
  static Future<bool> copyCurrentChatDraft(String instruction) async {
    final text = WhatsAppComponentRequests.currentChatDraft(instruction) ??
        WhatsAppComponentRequests.currentReply(instruction);
    if (text == null || text.isEmpty) return false;
    await Clipboard.setData(ClipboardData(text: text));
    return true;
  }
}
