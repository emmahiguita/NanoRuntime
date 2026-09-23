/// NANO-PERSONAL-CHANNELS-TAB — Pestaña "Supervisión y Canales" de Nano Personal.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/providers/settings_provider.dart';
import '../../../../core/widgets/feather_core_icon.dart';
import '../../application/automation_coordinator_provider.dart'
    show ruleRegistryProvider;
import '../../engine/messaging/messaging_package.dart';
import '../../personal_agent/domain/conversation_autonomy_mode.dart';
import '../automation_visual_theme.dart';
import '../widgets/settings_tile_components.dart';

class NanoPersonalChannelsTab extends ConsumerWidget {
  const NanoPersonalChannelsTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final visual = AutomationVisual.of(context);
    final ruleRegistry = ref.watch(ruleRegistryProvider);
    final isWppActive =
        ruleRegistry.isWhatsAppRuleActive(MessagingPackage.whatsapp);

    final settings = ref.watch(settingsProvider);
    final settingsNotifier = ref.read(settingsProvider.notifier);
    final autonomyMode =
        ConversationAutonomyModeName.fromName(settings.waAutonomyMode);

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
      children: [
        // 1. Modo de Supervisión
        const AutomationSectionLabel('Modo de Supervisión y Envío'),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: visual.surface.withValues(alpha: 0.50),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: visual.outline.withValues(alpha: 0.18)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Define cuánto control tiene Nano para responder por sí mismo.',
                style: TextStyle(color: visual.textMuted, fontSize: 11.5),
              ),
              const SizedBox(height: 10),
              SegmentedButton<ConversationAutonomyMode>(
                segments: const [
                  ButtonSegment(
                    value: ConversationAutonomyMode.suggestions,
                    label: Text('Borrador', style: TextStyle(fontSize: 11)),
                    icon: Icon(Icons.edit_note_rounded, size: 16),
                  ),
                  ButtonSegment(
                    value: ConversationAutonomyMode.safeAuto,
                    label: Text('Seguro', style: TextStyle(fontSize: 11)),
                    icon: Icon(Icons.shield_outlined, size: 16),
                  ),
                  ButtonSegment(
                    value: ConversationAutonomyMode.autonomous,
                    label: Text('Autónomo', style: TextStyle(fontSize: 11)),
                    icon: Icon(Icons.bolt_rounded, size: 16),
                  ),
                ],
                selected: {
                  autonomyMode == ConversationAutonomyMode.disabled
                      ? ConversationAutonomyMode.suggestions
                      : autonomyMode
                },
                onSelectionChanged: (set) {
                  settingsNotifier.setWaAutonomyMode(set.first.name);
                },
              ),
              const SizedBox(height: 8),
              Text(
                autonomyMode.description,
                style: TextStyle(
                  color: visual.accent,
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // 2. Canales de mensajería
        const AutomationSectionLabel('Canales de Mensajería'),
        SettingsCard(
          children: [
            SettingsRow(
              featherType: FeatherCoreType.personalAgent,
              title: 'WhatsApp Personal',
              subtitle: isWppActive
                  ? 'Activo · Atiende chats personales'
                  : 'Inactivo · Toca para activar atención',
              trailing: Switch(
                value: isWppActive,
                onChanged: (v) {
                  if (v) {
                    ref.read(ruleRegistryProvider).seedWhatsAppRule(
                          MessagingPackage.whatsapp,
                        );
                  } else {
                    ref.read(ruleRegistryProvider).removeWhatsAppRule(
                          MessagingPackage.whatsapp,
                        );
                  }
                },
              ),
              showChevron: false,
            ),
            const SettingsRow(
              icon: Icons.send_rounded,
              title: 'Telegram',
              subtitle: 'Listo para vincular bot o cuenta de Telegram',
              trailing: ValueBadge(label: 'DISPONIBLE'),
            ),
            const SettingsRow(
              icon: Icons.mail_outline_rounded,
              title: 'Gmail / Correo',
              subtitle: 'Lectura y redacción de respuestas a correos',
              trailing: ValueBadge(label: 'DISPONIBLE'),
            ),
          ],
        ),
      ],
    );
  }
}
