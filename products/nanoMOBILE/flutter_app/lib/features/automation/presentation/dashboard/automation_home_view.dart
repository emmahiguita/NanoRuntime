/// AUTOMATION-HOME-VIEW — Vista orquestadora principal del módulo Automatización.
///
/// QUÉ HACE:
/// Presenta la experiencia limpia y jerárquica de 4 pilares:
/// 1. Universal AI Inbox (Centro de Mensajería).
/// 2. Nano Personal (Cerebro personal).
/// 3. Nano Negocio (Cerebro comercial universal).
/// 4. Automatización y Sistema (Control operativo y configuración técnica).
///
/// CÓMO FUNCIONA:
/// Integra los subcomponentes modulares de dashboard leyendo los providers
/// durables ([businessFactsNotifierProvider], [ruleRegistryProvider], [settingsProvider]).
///
/// POR QUÉ:
/// Reemplaza la antigua lista desordenada de 7-10 accesos técnicos por una
/// arquitectura orientada al usuario: Usar, Enseñar y Administrar.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/providers/settings_provider.dart';
import '../../../../core/widgets/feather_core_icon.dart';
import '../../application/automation_coordinator_provider.dart' show ruleRegistryProvider;
import '../../engine/business/business_facts_providers.dart';
import '../../engine/messaging/messaging_package.dart';
import '../automation_layout.dart';
import '../automation_visual_theme.dart';
import 'automation_agent_card.dart';
import 'automation_inbox_card.dart';
import 'automation_system_footer.dart';

class AutomationHomeView extends ConsumerWidget {
  final VoidCallback onMessagesTap;
  final VoidCallback onPersonalTap;
  final VoidCallback onBusinessTap;
  final VoidCallback onRulesTap;
  final VoidCallback onSystemTap;
  final VoidCallback onPickModeTap;

  const AutomationHomeView({
    super.key,
    required this.onMessagesTap,
    required this.onPersonalTap,
    required this.onBusinessTap,
    required this.onRulesTap,
    required this.onSystemTap,
    required this.onPickModeTap,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final visual = AutomationVisual.of(context);
    final settings = ref.watch(settingsProvider);
    final businessFacts = ref.watch(businessFactsNotifierProvider);
    final productsCount = businessFacts.products.length;

    final ruleRegistry = ref.watch(ruleRegistryProvider);
    final activeRulesCount = ruleRegistry.rules.where((r) => r.enabled).length;
    final isW4bActive = ruleRegistry.isWhatsAppRuleActive(
      MessagingPackage.whatsappBusiness,
    );

    return Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: AutomationLayout.contentMaxWidth(context)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 1. Cabecera principal
            _buildHeader(context, visual, settings.agentAutomationMode.label),
            const SizedBox(height: 18),

            // 2. Pilar USAR: Centro de Mensajería (Universal AI Inbox)
            AutomationInboxCard(onTap: onMessagesTap),
            const SizedBox(height: 16),

            // 3. Pilar ENSEÑAR: Tus Dos Agentes Principales (Cuadros organizados)
            const AutomationSectionLabel('Tus Agentes'),
            Row(
              children: [
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
                    onTap: onPersonalTap,
                  ),
                ),
                const SizedBox(width: 12),
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
                    metricLabel: productsCount > 0
                        ? '$productsCount prod.'
                        : 'Catálogo',
                    onTap: onBusinessTap,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),

            // 4. Pilar ADMINISTRAR: Automatización y Sistema
            const AutomationSectionLabel('Control y Sistema'),
            AutomationSystemFooter(
              automationModeLabel: settings.agentAutomationMode.label,
              activeRulesCount: activeRulesCount,
              onRulesTap: onRulesTap,
              onSystemTap: onSystemTap,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(
    BuildContext context,
    AutomationVisualPalette visual,
    String modeLabel,
  ) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Automatización',
              style: TextStyle(
                color: visual.text,
                fontSize: 22,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.5,
              ),
            ),
            const SizedBox(height: 3),
            Text(
              'Tus conversaciones y agentes en un solo lugar',
              style: TextStyle(color: visual.textMuted, fontSize: 12.5),
            ),
          ],
        ),
        InkWell(
          onTap: onPickModeTap,
          borderRadius: BorderRadius.circular(16),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: visual.accent.withValues(alpha: 0.16),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: visual.accent.withValues(alpha: 0.40)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.tune_rounded, size: 14, color: visual.accent),
                const SizedBox(width: 5),
                Text(
                  modeLabel,
                  style: TextStyle(
                    color: visual.accent,
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
