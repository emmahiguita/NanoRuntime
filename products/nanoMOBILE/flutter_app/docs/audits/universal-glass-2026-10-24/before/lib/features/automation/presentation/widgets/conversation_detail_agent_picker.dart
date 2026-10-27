part of 'conversation_detail_sheet.dart';

/// [ConversationDetailAgentPicker]
///
/// QUÉ HACE:
/// Despliega el modal interactivo de selección y cambio de agente / bot especializado
/// (ej: Soporte al Cliente, Asistente de Ventas, Personal, Logística).
///
/// CÓMO FUNCIONA:
/// Itera sobre los valores de `ConversationAgentId`, resaltando el agente actualmente
/// asignado. Al seleccionar uno nuevo, cierra el modal e invoca `_transferAgent`
/// para migrar la conversación con contexto mínimo sin cruzar memorias.
///
/// POR QUÉ:
/// Desacopla el selector de bots de la cabecera visual, garantizando cumplimiento estricto
/// de la regla de modularidad (< 200 líneas) y Single Responsibility.
extension ConversationDetailAgentPicker on _ConversationDetailSheetState {
  void _showTransferAgentPicker(
    BuildContext context,
    AutomationVisualPalette visual,
  ) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 24),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: visual.isDark ? const Color(0xF2101726) : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Asignar a otro agente',
              style: TextStyle(
                fontFamily: 'Inter',
                fontWeight: FontWeight.bold,
                fontSize: 16,
                color: visual.text,
              ),
            ),
            const SizedBox(height: 12),
            for (final agent in ConversationAgentId.values)
              ListTile(
                dense: true,
                leading: Icon(
                  _agentId == agent
                      ? Icons.check_circle_rounded
                      : Icons.radio_button_unchecked,
                  color: _agentId == agent
                      ? const Color(0xFF10B981)
                      : visual.textMuted,
                  size: 20,
                ),
                title: Text(
                  agent.displayName,
                  style: TextStyle(color: visual.text, fontSize: 14),
                ),
                onTap: () {
                  Navigator.pop(ctx);
                  _transferAgent(agent);
                },
              ),
          ],
        ),
      ),
    );
  }
}
