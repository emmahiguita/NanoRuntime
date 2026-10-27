import '../../automation/engine/planning/whatsapp_automation_input.dart';
import '../../automation/engine/planning/whatsapp_component_requests.dart';

/// Adaptador del búho al contrato del componente usado por Automatización.
/// Seleccionar herramienta no ejecuta; todos los controles son explícitos.
abstract final class NanoActionInput {
  /// La confirmación devuelve el token exacto al dueño del turno pendiente.
  static bool isConfirm(String text) =>
      WhatsAppComponentRequests.isConfirm(text);

  /// Cancelar no consulta un modelo ni interpreta contenido de pantalla.
  static bool isCancel(String text) => WhatsAppComponentRequests.isCancel(text);

  /// Conserva secuencias fuera del payload antes del despacho al motor.
  static bool isNavigationSequence(String text) =>
      WhatsAppComponentRequests.isNavigationSequence(text);

  /// Un único normalizador mantiene adjuntos, identidades y destinos iguales.
  static String prepare(String input, {required bool whatsApp}) =>
      isConfirm(input) || isCancel(input)
      ? input.trim()
      : whatsApp
      ? WhatsAppAutomationInput.command(input)
      : WhatsAppComponentRequests.normalize(input);
}
