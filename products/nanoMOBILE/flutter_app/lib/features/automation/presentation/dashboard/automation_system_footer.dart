/// AUTOMATION-SYSTEM-FOOTER — Footer de acceso a Automatización y Sistema.
///
/// QUÉ HACE:
/// Agrupa de forma discreta y elegante las opciones de control operativo:
/// Nivel de automatización/reglas y Sistema/Ajustes avanzados.
///
/// CÓMO FUNCIONA:
/// Renderiza dos filas limpias estilo Apple/Linear, evitando saturar la
/// pantalla con tarjetas gigantes o listas de 10 botones técnicos.
///
/// POR QUÉ:
/// Cumple la regla de Divulgación Progresiva: las configuraciones avanzadas
/// quedan a un toque sin obstruir la vista diaria de agentes y mensajes.
library;

import 'package:flutter/material.dart';
import '../automation_visual_theme.dart';

class AutomationSystemFooter extends StatelessWidget {
  final String automationModeLabel;
  final int activeRulesCount;
  final VoidCallback onRulesTap;
  final VoidCallback onSystemTap;

  const AutomationSystemFooter({
    super.key,
    required this.automationModeLabel,
    required this.activeRulesCount,
    required this.onRulesTap,
    required this.onSystemTap,
  });

  @override
  Widget build(BuildContext context) {
    final visual = AutomationVisual.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Fila 1: Automatización y Reglas
        InkWell(
          onTap: onRulesTap,
          borderRadius: BorderRadius.circular(16),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: visual.surface.withValues(alpha: 0.50),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: visual.outline.withValues(alpha: 0.15),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.auto_mode_rounded,
                  size: 20,
                  color: visual.accent,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Automatización y Reglas',
                        style: TextStyle(
                          color: visual.text,
                          fontSize: 13.5,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Modo $automationModeLabel · $activeRulesCount regla${activeRulesCount == 1 ? '' : 's'} activa${activeRulesCount == 1 ? '' : 's'}',
                        style: TextStyle(
                          color: visual.textMuted,
                          fontSize: 11.5,
                        ),
                      ),
                    ],
                  ),
                ),
                Text(
                  'Gestionar',
                  style: TextStyle(
                    color: visual.accent,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(width: 4),
                Icon(
                  Icons.chevron_right_rounded,
                  size: 16,
                  color: visual.accent,
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 10),

        // Fila 2: Sistema y Configuración Avanzada
        InkWell(
          onTap: onSystemTap,
          borderRadius: BorderRadius.circular(16),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: visual.surface.withValues(alpha: 0.50),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: visual.outline.withValues(alpha: 0.15),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.tune_rounded,
                  size: 20,
                  color: visual.textMuted,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Sistema y Herramientas',
                        style: TextStyle(
                          color: visual.text,
                          fontSize: 13.5,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Modelos IA, MCP, permisos y bots personalizados',
                        style: TextStyle(
                          color: visual.textMuted,
                          fontSize: 11.5,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.settings_outlined,
                  size: 18,
                  color: visual.textMuted.withValues(alpha: 0.7),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
