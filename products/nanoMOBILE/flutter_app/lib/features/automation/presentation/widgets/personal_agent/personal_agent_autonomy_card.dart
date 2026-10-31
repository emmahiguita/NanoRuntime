// personal_agent_autonomy_card.dart — Configuración del agente personal con MenuAnchor M3.
// QUÉ HACE:
// Integra el control de activación de WhatsApp Personal y el selector interactivo
// de Nivel de Autonomía desplegable mediante MenuAnchor de Material 3.
//
// CÓMO FUNCIONA:
// Presenta la fila de servicio y aloja AutonomyModeMenuAnchor, permitiendo cambiar el nivel
// (Supervisado, Auto Seguro, Autónomo, En pausa) directamente desde un menú contextual flotante.
//
// POR QUÉ:
// Reemplaza el selector estático de botones segmentados por un menú M3 compacto y fluido,
// cumpliendo estrictamente con menos de 120 líneas y alta respuesta háptica.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nanoai/features/automation/application/automation_coordinator_provider.dart'
    show ruleRegistryProvider;
import 'package:nanoai/features/automation/engine/messaging/messaging_package.dart';
import '../../automation_visual_theme.dart';
import '../settings_tile_components.dart';
import 'autonomy_mode_menu_anchor.dart';

export 'autonomy_mode_menu_anchor.dart' show AutonomyModeMenuAnchor;

class PersonalAgentAutonomyCard extends ConsumerWidget {
  const PersonalAgentAutonomyCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final visual = AutomationVisual.of(context);
    final isWaActive = ref
        .watch(ruleRegistryProvider)
        .isWhatsAppRuleActive(MessagingPackage.whatsapp);

    return SettingsCard(
      children: [
        SettingsRow(
          imageAsset: 'assets/automation/whatsapp_personal_icon.png',
          title: 'WhatsApp Personal',
          subtitle: isWaActive
              ? 'Activo — Nano procesa y responde mensajes'
              : 'Inactivo — Toca para activar el agente',
          trailing: Switch(
            value: isWaActive,
            onChanged: (v) {
              final reg = ref.read(ruleRegistryProvider);
              v
                  ? reg.seedWhatsAppRule(MessagingPackage.whatsapp)
                  : reg.removeWhatsAppRule(MessagingPackage.whatsapp);
            },
          ),
          showChevron: false,
        ),
        Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Cómo escribe Nano por ti',
                style: TextStyle(
                  color: visual.text,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Selecciona el nivel de supervisión para respuestas automáticas en WhatsApp.',
                style: TextStyle(
                  color: visual.isDark
                      ? const Color(0xFFD6DEE8)
                      : visual.textMuted,
                  fontSize: 12,
                  height: 1.35,
                ),
              ),
              const SizedBox(height: 12),
              // Selector de Nivel de Autonomía mediante MenuAnchor M3
              const AutonomyModeMenuAnchor(),
            ],
          ),
        ),
      ],
    );
  }
}
