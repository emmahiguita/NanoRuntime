// automation_dashboard_actions.dart — Estructura visual de secciones de Automatización.
// QUÉ HACE: Renderiza Banner 16:9, lista de Agentes iOS y lista abierta de Herramientas.
// CÓMO FUNCIONA: Orquesta AutomationAgentTripleCards y AutomationToolsGroupedCard con espacios estandarizados.
// POR QUÉ: Satisface la composición iOS agrupada con tipografía refinada y alta densidad.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../automation_visual_theme.dart';
import '../dashboard/automation_inbox_card.dart';
import '../dashboard/automation_tools_grouped_card.dart';
import 'automation_agent_triple_cards.dart';

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
    this.modeLabel = 'Manual',
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
    final visual = AutomationVisual.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // 1. BANNER: Centro de Mensajería (16:9)
        if (onMessagesTap != null) ...[
          AutomationInboxCard(onTap: onMessagesTap!),
          const SizedBox(height: 18),
        ],

        // 2. SECCIÓN: Tus agentes (Lista agrupada iOS Liquid Glass)
        AutomationAgentTripleCards(
          onPersonalTap: onPersonalAgentTap != null
              ? () => onPersonalAgentTap!(context)
              : null,
          onBusinessTap: onBusinessTap != null
              ? () => onBusinessTap!(context)
              : null,
          onModelsTap: onModelsTap,
          onManageTap: onRulesTap ?? onSettingsTap,
          isW4bActive: isW4bActive,
        ),
        const SizedBox(height: 20),

        // 3. SECCIÓN: Herramientas (Lista abierta que aprovecha el espacio)
        _buildSectionHeader('Herramientas', visual),
        const SizedBox(height: 6),
        AutomationToolsGroupedCard(
          onMcpTap: onMcpTap,
          onAiWebTap: onAiWebTap,
          onChatTap: onChatTap,
          onWhatsAppWebTap: onWhatsAppWebTap,
          onBrowserTap: onBrowserTap,
          onTerminalTap: onTerminalTap,
          onSettingsTap: onSettingsTap,
        ),
      ],
    );
  }

  Widget _buildSectionHeader(String title, AutomationVisualPalette visual) {
    return Padding(
      padding: const EdgeInsets.only(left: 4),
      child: Text(
        title,
        style: TextStyle(
          fontFamily: 'Inter',
          fontSize: 13.5,
          fontWeight: FontWeight.w600,
          height: 1.3,
          color: visual.text,
        ),
      ),
    );
  }
}
