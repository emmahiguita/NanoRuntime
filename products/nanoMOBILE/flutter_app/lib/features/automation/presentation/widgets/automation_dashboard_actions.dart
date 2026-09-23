/// AUTOMATION-DASHBOARD-ACTIONS — Secciones de acción del Dashboard unificado.
///
/// QUÉ HACE:
/// Presenta los 4 pilares limpios de Nano AI en el dashboard operativo:
/// 1. Universal AI Inbox (Centro de Mensajería).
/// 2. Tus Agentes (Nano Personal + Nano Negocio).
/// 3. Control y Sistema (Reglas + Ajustes del Motor).
/// 4. Carrusel de sugerencias rápidas.
///
/// CÓMO FUNCIONA:
/// Reemplaza la antigua lista desordenada de 7 tiles por componentes semánticos.
///
/// POR QUÉ:
/// Termina con la duplicación visual de Bot Studio y la fragmentación de configuraciones.
library;

import 'package:flutter/material.dart';
import '../../../../core/widgets/feather_core_icon.dart';
import '../../../../core/widgets/navigation/nano_glyph.dart';
import '../automation_visual_theme.dart';
import '../dashboard/automation_agent_card.dart';
import '../dashboard/automation_inbox_card.dart';
import '../dashboard/automation_system_footer.dart';
import 'automation_suggestion_carousel.dart';

class QuickAutomationActions extends StatelessWidget {
  const QuickAutomationActions({
    super.key,
    required this.onRun,
    this.onMessagesTap,
    this.onSettingsTap,
    this.onRulesTap,
    this.onBusinessTap,
    this.onPersonalAgentTap,
    this.onBotStudioTap,
    this.onSkillsMcpTap,
    this.onTimeRuleTap,
    this.suppressSuggestions = false,
    this.pendingDraftsCount = 0,
    this.activeRulesCount = 0,
    this.businessProductsCount = 0,
    this.isW4bActive = false,
    this.modeLabel = 'Supervisado',
  });

  final ValueChanged<String> onRun;
  final bool suppressSuggestions;
  final int pendingDraftsCount;
  final int activeRulesCount;
  final int businessProductsCount;
  final bool isW4bActive;
  final String modeLabel;

  final VoidCallback? onMessagesTap;
  final VoidCallback? onSettingsTap;
  final VoidCallback? onRulesTap;
  final VoidCallback? onBusinessTap;
  final VoidCallback? onPersonalAgentTap;
  final VoidCallback? onBotStudioTap;
  final VoidCallback? onSkillsMcpTap;
  final VoidCallback? onTimeRuleTap;

  static const _actions = [
    ('Abrir Bluetooth', 'abrir Bluetooth', NanoGlyphType.bluetooth),
    ('Abrir Chrome', 'abrir Chrome', NanoGlyphType.browser),
    ('Abrir Linux', 'abrir la terminal Linux', NanoGlyphType.linux),
    ('Leer notificaciones', 'leer las notificaciones', NanoGlyphType.notification),
    ('Analizar archivos', 'analizar los archivos', NanoGlyphType.files),
  ];

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (onMessagesTap != null) ...[
          AutomationInboxCard(onTap: onMessagesTap!),
          const SizedBox(height: 18),
        ],
        const AutomationSectionLabel('Tus Agentes'),
        Row(
          children: [
            if (onPersonalAgentTap != null)
              Expanded(
                child: AutomationAgentCard(
                  title: 'Nano Personal',
                  subtitle: 'Habla como tú',
                  isActive: true,
                  iconWidget: const FeatherCoreIcon(
                    type: FeatherCoreType.personalAgent,
                    size: 24,
                  ),
                  channels: const ['WhatsApp', 'Telegram'],
                  metricLabel: 'Estilo & Memoria',
                  onTap: onPersonalAgentTap!,
                ),
              ),
            if (onPersonalAgentTap != null && onBusinessTap != null)
              const SizedBox(width: 12),
            if (onBusinessTap != null)
              Expanded(
                child: AutomationAgentCard(
                  title: 'Nano Negocio',
                  subtitle: 'Atiende clientes',
                  isActive: isW4bActive,
                  iconWidget: const FeatherCoreIcon(
                    type: FeatherCoreType.whatsappBusiness,
                    size: 24,
                  ),
                  channels: const ['WhatsApp Business', 'Catálogo'],
                  metricLabel: businessProductsCount > 0
                      ? '$businessProductsCount prod.'
                      : 'Catálogo',
                  onTap: onBusinessTap!,
                ),
              ),
          ],
        ),
        const SizedBox(height: 18),
        const AutomationSectionLabel('Control y Sistema'),
        AutomationSystemFooter(
          automationModeLabel: modeLabel,
          activeRulesCount: activeRulesCount,
          onRulesTap: onRulesTap ?? () {},
          onSystemTap: onSettingsTap ?? () {},
        ),
        const SizedBox(height: 16),
        AutomationSuggestionCarousel(
          suppressed: suppressSuggestions,
          suggestions: [
            for (final (label, goal, glyph) in _actions)
              AutomationSuggestion(
                label: label,
                leading: NanoIcon(
                  type: glyph,
                  size: 20,
                  color: AutomationVisual.of(context).accent,
                ),
                onSelected: () => onRun(goal),
              ),
          ],
        ),
      ],
    );
  }
}
