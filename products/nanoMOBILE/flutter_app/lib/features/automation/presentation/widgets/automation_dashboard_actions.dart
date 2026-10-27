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
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../application/automation_coordinator_provider.dart'
    show ruleRegistryProvider;
import '../../engine/messaging/messaging_package.dart';
import '../../../../core/widgets/feather_core_icon.dart';
import '../../../../core/theme/nano_hero_source.dart';
import '../automation_visual_theme.dart';
import '../dashboard/automation_agent_card.dart';
import '../dashboard/automation_discover_nano_section.dart';
import '../dashboard/automation_inbox_card.dart';
import '../dashboard/automation_system_footer.dart';
import 'nano_models_editorial.dart';

class QuickAutomationActions extends ConsumerWidget {
  const QuickAutomationActions({
    super.key,
    required this.onRun,
    this.onMessagesTap,
    this.onSettingsTap,
    this.onRulesTap,
    this.onBusinessTap,
    this.onPersonalAgentTap,
    this.onMcpTap,
    this.onModelsTap,
    this.onAiWebTap,
    this.onBrowserTap,
    this.onChatTap,
    this.onTerminalTap,
    this.onWhatsAppWebTap,
    this.suppressSuggestions = false,
    this.activeRulesCount = 0,
    this.businessProductsCount = 0,
    this.isW4bActive = false,
    this.modeLabel = 'Supervisado',
  });

  final ValueChanged<String> onRun;
  final bool suppressSuggestions;
  final int activeRulesCount;
  final int businessProductsCount;
  final bool isW4bActive;
  final String modeLabel;

  final VoidCallback? onMessagesTap,
      onSettingsTap,
      onRulesTap,
      onMcpTap,
      onModelsTap;
  final ValueChanged<BuildContext>? onBusinessTap, onPersonalAgentTap;
  final VoidCallback? onAiWebTap,
      onBrowserTap,
      onChatTap,
      onTerminalTap,
      onWhatsAppWebTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (onMessagesTap != null) ...[
          AutomationInboxCard(onTap: onMessagesTap!),
          const SizedBox(height: 18),
        ],
        const AutomationSectionLabel('Tus Agentes'),
        _buildAgentCards(context, ref),
        const SizedBox(height: 20),
        const NanoModelsEditorial(),
        const SizedBox(height: 18),
        const AutomationSectionLabel('Herramientas y Capacidades'),
        AutomationDiscoverNanoSection(
          onMcpTap: onMcpTap,
          onAiWebTap: onAiWebTap,
          onBrowserTap: onBrowserTap,
          onChatTap: onChatTap,
          onTerminalTap: onTerminalTap,
          onModelsTap: onModelsTap,
          onWhatsAppWebTap: onWhatsAppWebTap,
        ),
        const SizedBox(height: 18),
        const AutomationSectionLabel('Control y Sistema'),
        AutomationSystemFooter(
          automationModeLabel: modeLabel,
          activeRulesCount: activeRulesCount,
          onRulesTap: onRulesTap ?? () {},
          onSystemTap: onSettingsTap ?? () {},
        ),
      ],
    );
  }

  Widget _buildAgentCards(BuildContext context, WidgetRef ref) {
    final personal = onPersonalAgentTap == null
        ? null
        : NanoHeroSource(
            tag: nanoPersonalHeroTag,
            builder: (origin) => AutomationAgentCard(
              title: 'Nano Personal',
              subtitle: 'Habla como tú',
              isActive: ref
                  .watch(ruleRegistryProvider)
                  .isWhatsAppRuleActive(MessagingPackage.whatsapp),
              iconWidget: const FeatherCoreIcon(
                type: FeatherCoreType.personalAgent,
                size: 24,
              ),
              channels: const ['WhatsApp', 'Telegram'],
              metricLabel: 'Estilo & Memoria',
              onTap: () => onPersonalAgentTap!(origin),
            ),
          );
    final business = onBusinessTap == null
        ? null
        : NanoHeroSource(
            tag: nanoBusinessHeroTag,
            builder: (origin) => AutomationAgentCard(
              title: 'Nano Negocio',
              showStatus: true,
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
              onTap: () => onBusinessTap!(origin),
            ),
          );

    return LayoutBuilder(
      builder: (context, constraints) {
        final scale = MediaQuery.textScalerOf(context).scale(14) / 14;
        final stacked = constraints.maxWidth < 330 || scale > 1.35;
        final cards = [
          if (personal != null) personal,
          if (business != null) business,
        ];
        if (stacked) {
          return Column(
            children: [
              for (var index = 0; index < cards.length; index++) ...[
                SizedBox(width: double.infinity, child: cards[index]),
                if (index < cards.length - 1) const SizedBox(height: 10),
              ],
            ],
          );
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (var index = 0; index < cards.length; index++) ...[
              Expanded(child: cards[index]),
              if (index < cards.length - 1) const SizedBox(width: 12),
            ],
          ],
        );
      },
    );
  }
}
