import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nanoai/core/providers/settings_provider.dart';
import 'package:nanoai/core/services/nano_runtime_api.dart';
import 'package:nanoai/core/services/runtime_engine.dart';
import 'package:nanoai/core/widgets/nano_glass_window.dart';
import 'package:nanoai/features/automation/application/automation_coordinator_provider.dart'
    show ruleRegistryProvider;
import 'package:nanoai/features/automation/engine/messaging/messaging_package.dart';
import 'package:nanoai/features/automation/engine/model/automation_model.dart';
import 'package:nanoai/features/automation/personal_agent/domain/conversation_autonomy_mode.dart';
import '../automation_visual_theme.dart';
import 'automation_settings_pickers.dart';
import 'settings_tile_components.dart';

part 'whatsapp_background_automation_card.part.dart';
part 'whatsapp_background_automation_rows.part.dart';

/// WA-BUSINESS-01 — Selector de aplicaciones de WhatsApp.
/// Crea/elimina la regla universal de WhatsApp y WhatsApp Business
/// por petición explícita del usuario (opt-in, WA-CONSENT-01).
class WhatsAppAppsCard extends ConsumerWidget {
  const WhatsAppAppsCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final registry = ref.watch(ruleRegistryProvider);

    bool isActive(String pkg) => registry.isWhatsAppRuleActive(pkg);

    void toggle(String pkg, bool value) {
      if (value) {
        registry.seedWhatsAppRule(pkg);
      } else {
        registry.removeWhatsAppRule(pkg);
      }
    }

    final isWaActive = isActive(MessagingPackage.whatsapp);
    final isW4bActive = isActive(MessagingPackage.whatsappBusiness);

    return SettingsCard(
      children: [
        SettingsRow(
          icon: Icons.chat_outlined,
          title: 'WhatsApp Personal',
          subtitle: isWaActive
              ? 'Activo — Nano procesa y responde mensajes'
              : 'Inactivo — no procesa mensajes',
          trailing: Switch(
            value: isWaActive,
            onChanged: (v) => toggle(MessagingPackage.whatsapp, v),
          ),
          showChevron: false,
        ),
        SettingsRow(
          icon: Icons.storefront_outlined,
          title: 'WhatsApp Business',
          subtitle: isW4bActive
              ? 'Activo — responde mensajes de clientes comerciales'
              : 'Inactivo — toca para activar',
          trailing: Switch(
            value: isW4bActive,
            onChanged: (v) => toggle(MessagingPackage.whatsappBusiness, v),
          ),
          showChevron: false,
        ),
      ],
    );
  }
}

/// AUTO-03 — modo de autonomía del pipeline de WhatsApp. El MISMO motor de
/// decisión (ConversationDecisionEngine) aplica el modo como tope ANTES de su
/// fórmula: no hay segundo motor ni reglas nuevas.
/// AUTONOMY FAIL-SAFE (PROD-02): `waAutonomyMode == null` = el dueño aún no
/// elige. La card lo dice honesto (sin pretender que hay selección) y el
/// pipeline opera en safeAuto hasta que el dueño elija en este picker.
class AutonomyModeCard extends ConsumerWidget {
  const AutonomyModeCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final raw = ref.watch(settingsProvider).waAutonomyMode;
    final mode = ConversationAutonomyModeName.fromName(raw);
    return SettingsCard(
      children: [
        SettingsRow(
          icon: Icons.auto_awesome_outlined,
          title: 'Autonomía de respuestas',
          subtitle: raw == null
              ? 'No has elegido aún — Nano solo responde lo seguro.'
              : mode.description,
          trailing: ValueBadge(label: mode.label.toUpperCase()),
          onTap: () => _pickAutonomyMode(context, ref),
        ),
      ],
    );
  }

  static Future<void> _pickAutonomyMode(
    BuildContext context,
    WidgetRef ref,
  ) async {
    final rawSelected = ref.read(settingsProvider).waAutonomyMode;
    final selected = rawSelected == null
        ? null
        : ConversationAutonomyModeName.fromName(rawSelected);
    final value = await showNanoGlassWindow<ConversationAutonomyMode>(
      context: context,
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Autonomía de respuestas',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 8),
              for (final mode in ConversationAutonomyMode.values)
                ListTile(
                  leading: Icon(
                    mode == selected
                        ? Icons.radio_button_checked_rounded
                        : Icons.radio_button_unchecked_rounded,
                    color: mode == selected
                        ? AutomationVisual.of(context).accent
                        : AutomationVisual.of(context).textMuted,
                  ),
                  title: Text(mode.label),
                  subtitle: Text(mode.description),
                  onTap: () => Navigator.of(context).pop(mode),
                ),
            ],
          ),
        ),
      ),
    );
    if (value != null) {
      ref.read(settingsProvider.notifier).setWaAutonomyMode(value.name);
    }
  }
}
