import 'dart:async';
import 'package:flutter/foundation.dart';
import '../../../../core/widgets/navigation/nano_input_tool_context.dart';
import '../../domain/automation_result.dart';
import '../../engine/planning/whatsapp_automation_input.dart';
import 'automation_input_preview.dart';
import '../../engine/platform/whatsapp_execution_activity.dart';

/// Adapta selección y observaciones reales al único editor del dashboard.
/// La selección no certifica instalación ni conexión. La suscripción termina
/// con el módulo y nunca consulta Android ni vuelve a ejecutar una acción.
class AutomationInputContextController
    extends ValueNotifier<NanoInputToolContext?> {
  AutomationInputContextController() : super(null) {
    _subscription = WhatsAppExecutionActivity.events.listen(observe);
  }
  late final StreamSubscription<WhatsAppExecutionActivity> _subscription;
  String? _executionId;
  int? _operationId;
  bool _returned = false;

  static const _asset = 'assets/automation/whatsapp_personal_icon.png';

  /// Previsualiza únicamente gramáticas existentes; no cambia el texto enviado.
  void updateDraft(String text) {
    if (_executionId != null) return;
    _draft = text;
    value = _draftContext(text);
  }

  static NanoInputToolContext? preview(String text) =>
      AutomationInputPreview.parse(text);

  bool _selected = false;
  String _draft = '';
  bool get selected => _selected;

  /// Cambiar de herramienta nunca envía el borrador ni altera su contenido.
  void toggleWhatsApp() {
    if (_executionId != null) return;
    _selected = !_selected;
    final previous = value;
    updateDraft(_draft);
    if (previous == value) notifyListeners();
  }

  String commandFor(String text) =>
      _selected ? WhatsAppAutomationInput.command(text) : text.trim();

  NanoInputToolContext? _draftContext(String text) {
    final command = _selected
        ? WhatsAppAutomationInput.previewCommand(text)
        : text;
    return (command == null ? null : preview(command)) ??
        (_selected
            ? const NanoInputToolContext(
                name: 'WhatsApp',
                asset: _asset,
                action: 'Escribe una acción y su destinatario',
                status: 'Activado',
                detail: 'Ejemplo: Abre el chat de Emm',
              )
            : null);
  }

  /// El ID es el mismo que posee el coordinator y usa Detener.
  void begin(String executionId, String text) {
    _executionId = executionId;
    _operationId = null;
    _returned = false;
    final selected = _draftContext(text);
    value = selected == null
        ? null
        : NanoInputToolContext(
            name: selected.name,
            asset: selected.asset,
            target: selected.target,
            action: selected.action,
            status: 'Preparando',
            active: true,
            detail: 'Resolviendo la tarea y el destinatario',
          );
  }

  /// Acepta solo la tarea propia y el primer intento nativo de esa tarea.
  /// Una acción ajena (chat, voz u otra ejecución) no modifica esta cabecera.
  @visibleForTesting
  void observe(WhatsAppExecutionActivity event) {
    if (_executionId == null || event.executionId != _executionId) return;
    if (event.packageName != 'com.whatsapp' &&
        event.packageName != 'com.whatsapp.w4b') {
      return;
    }
    _operationId ??= event.operationId;
    if (_operationId != event.operationId) return;
    _returned = event.state == 'returned';
    final business = event.packageName == 'com.whatsapp.w4b';
    final status = switch (event.state) {
      'waiting' => 'Verificando en WhatsApp',
      'clicked' => 'Volviendo a Nano',
      'returned' => 'Regreso comprobado',
      'stopped' || 'return_unverified' => 'Revisión necesaria',
      _ => 'Estado no verificable',
    };
    value = NanoInputToolContext(
      name: business ? 'WhatsApp Business' : 'WhatsApp',
      asset: business ? 'assets/automation/whatsapp_business_icon.png' : _asset,
      target: AutomationInputPreview.identity(event.recipient),
      action: event.action,
      status: status,
      active: true,
      detail: _returned
          ? 'Clic y regreso observados · entrega no confirmada'
          : event.state == 'clicked'
          ? 'Clic observado · comprobando el regreso'
          : 'App Android · observación del intento actual',
    );
  }

  /// Conserva un recibo compacto, con el mismo veredicto honesto del motor.
  void finish(AutomationResultStatus? status, String reason) {
    _executionId = null;
    final current = value;
    if (current == null) return;
    final label = switch (status) {
      AutomationResultStatus.completed => 'Acción terminada',
      AutomationResultStatus.completedUnverified =>
        _returned ? 'Regreso comprobado' : 'Por verificar',
      AutomationResultStatus.paused => 'Requiere confirmación',
      AutomationResultStatus.cancelled => 'Cancelado',
      AutomationResultStatus.outcomeUnknown => 'Resultado incierto',
      _ => 'No completado',
    };
    value = NanoInputToolContext(
      name: current.name,
      asset: current.asset,
      target: current.target,
      action: current.action,
      status: label,
      detail: reason.replaceFirst(RegExp(r'^\[[^\]]+\]\s*'), ''),
    );
  }

  @override
  void dispose() {
    _subscription.cancel();
    super.dispose();
  }
}
