import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nanoai/core/providers/settings_provider.dart';
import 'package:nanoai/features/automation/application/automation_coordinator_provider.dart'
    show ruleRegistryProvider;
import 'package:nanoai/features/automation/domain/automation_policy.dart';
import 'package:nanoai/features/automation/engine/messaging/messaging_package.dart';
import 'package:nanoai/features/automation/personal_agent/domain/conversation_autonomy_mode.dart';
import '../../automation_visual_theme.dart';
import '../settings_tile_components.dart';

/// QUÉ HACE:
/// Tarjeta de configuración del nivel de autonomía y supervisión de WhatsApp.
///
/// CÓMO FUNCIONA:
/// Permite al usuario alternar entre 'Supervisado' (Borradores), 'Auto Seguro'
/// (Respuestas automatizadas a bajo riesgo) y 'Autónomo' (Envío directo con IA).
///
/// POR QUÉ:
/// Garantiza control determinista sobre cuándo el bot envía mensajes reales
/// o solicita confirmación humana, previniendo alucinaciones en producción.
class PersonalAgentAutonomyCard extends ConsumerWidget {
  const PersonalAgentAutonomyCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    final settingsNotifier = ref.read(settingsProvider.notifier);
    final visual = AutomationVisual.of(context);
    final isWaActive = ref.watch(ruleRegistryProvider).isWhatsAppRuleActive(
      MessagingPackage.whatsapp,
    );
    final waMode = ConversationAutonomyModeName.fromName(settings.waAutonomyMode);
    final selectedMode = switch (waMode) {
      ConversationAutonomyMode.autonomous => ConversationAutonomyMode.autonomous,
      ConversationAutonomyMode.safeAuto => ConversationAutonomyMode.safeAuto,
      _ => ConversationAutonomyMode.suggestions,
    };

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
              v ? reg.seedWhatsAppRule(MessagingPackage.whatsapp)
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
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      'Cómo escribe Nano por ti',
                      style: TextStyle(
                        color: visual.text,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  _buildModeBadge(waMode, visual),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                _getModeDescription(waMode),
                style: TextStyle(
                  color: visual.isDark ? const Color(0xFFD6DEE8) : visual.textMuted,
                  fontSize: 12.5,
                  height: 1.45,
                ),
              ),
              const SizedBox(height: 12),
              _buildSelector(selectedMode, settingsNotifier, visual),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildModeBadge(ConversationAutonomyMode mode, AutomationVisualPalette visual) {
    final label = switch (mode) {
      ConversationAutonomyMode.suggestions => 'BORRADOR',
      ConversationAutonomyMode.safeAuto => 'AUTO SEGURO',
      ConversationAutonomyMode.autonomous => 'AUTÓNOMO',
      ConversationAutonomyMode.disabled => 'DESACTIVADO',
    };
    return Chip(
      label: Text(
        label,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          color: visual.isDark ? const Color(0xFFFFB26B) : visual.accent,
        ),
      ),
      backgroundColor: visual.accent.withValues(alpha: 0.20),
      side: BorderSide(color: visual.accent.withValues(alpha: 0.55)),
      padding: const EdgeInsets.symmetric(horizontal: 4),
      visualDensity: VisualDensity.compact,
    );
  }

  String _getModeDescription(ConversationAutonomyMode mode) {
    return switch (mode) {
      ConversationAutonomyMode.suggestions =>
        '✏️ Supervisado: Nano redacta en Mensajes para tu aprobación previa.',
      ConversationAutonomyMode.safeAuto =>
        '🛡️ Auto seguro: Responde automáticamente mensajes de bajo riesgo.',
      ConversationAutonomyMode.autonomous =>
        '⚡ Autónomo: Responde directo en WhatsApp con tu identidad y tono.',
      ConversationAutonomyMode.disabled =>
        '⏸️ En pausa: Escucha entrantes sin responder ni generar borradores.',
    };
  }

  Widget _buildSelector(
    ConversationAutonomyMode selected,
    SettingsNotifier notifier,
    AutomationVisualPalette visual,
  ) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: ConstrainedBox(
            constraints: BoxConstraints(minWidth: constraints.maxWidth),
            child: SegmentedButton<ConversationAutonomyMode>(
              showSelectedIcon: false,
              style: ButtonStyle(
                visualDensity: VisualDensity.compact,
                side: WidgetStateProperty.all(BorderSide(color: visual.cardBorder)),
              ),
              segments: const [
                ButtonSegment(
                  value: ConversationAutonomyMode.suggestions,
                  label: Text('Supervisado', maxLines: 1),
                ),
                ButtonSegment(
                  value: ConversationAutonomyMode.safeAuto,
                  label: Text('Auto seguro', maxLines: 1),
                ),
                ButtonSegment(
                  value: ConversationAutonomyMode.autonomous,
                  label: Text('Autónomo', maxLines: 1),
                ),
              ],
              selected: {selected},
              onSelectionChanged: (set) {
                final mode = set.first;
                notifier.setWaAutonomyMode(mode.name);
                notifier.setAgentAutomationMode(
                  mode == ConversationAutonomyMode.autonomous
                      ? AgentAutomationMode.autonomous
                      : AgentAutomationMode.assisted,
                );
              },
            ),
          ),
        );
      },
    );
  }
}
