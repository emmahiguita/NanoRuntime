/// NANO-BUSINESS-CHANNELS-TAB — Pestaña "Canales" del Agente Comercial.
///
/// QUÉ HACE:
/// Permite activar o desactivar la atención comercial en WhatsApp Business,
/// WhatsApp Personal o Telegram de forma independiente.
///
/// CÓMO FUNCIONA:
/// Conecta con [ruleRegistryProvider] para encender o apagar las reglas
/// de atención de ventas de cada canal conectado.
///
/// POR QUÉ:
/// Desacopla el negocio del canal específico: puedes atender ventas en
/// WhatsApp Business o en tu WhatsApp regular usando el mismo catálogo.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/widgets/feather_core_icon.dart';
import '../../application/automation_coordinator_provider.dart'
    show ruleRegistryProvider;
import '../../engine/messaging/messaging_package.dart';
import '../automation_visual_theme.dart';
import '../widgets/settings_tile_components.dart';

class NanoBusinessChannelsTab extends ConsumerWidget {
  const NanoBusinessChannelsTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final visual = AutomationVisual.of(context);
    final ruleRegistry = ref.watch(ruleRegistryProvider);
    final isW4bActive =
        ruleRegistry.isWhatsAppRuleActive(MessagingPackage.whatsappBusiness);

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: visual.surface.withValues(alpha: 0.50),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: visual.outline.withValues(alpha: 0.18)),
          ),
          child: Text(
            'El Agente de Negocio es universal: tu catálogo, precios y políticas se utilizarán en todos los canales donde actives la atención comercial.',
            style: TextStyle(color: visual.textMuted, fontSize: 12),
          ),
        ),
        const SizedBox(height: 16),
        const AutomationSectionLabel('Canales de Atención Comercial'),
        SettingsCard(
          children: [
            SettingsRow(
              featherType: FeatherCoreType.whatsappBusiness,
              title: 'WhatsApp Business',
              subtitle: isW4bActive
                  ? 'Activo · Atiende ventas y catálogo'
                  : 'Inactivo · Toca para activar atención',
              trailing: Switch(
                value: isW4bActive,
                onChanged: (v) {
                  if (v) {
                    ref.read(ruleRegistryProvider).seedWhatsAppRule(
                          MessagingPackage.whatsappBusiness,
                        );
                  } else {
                    ref.read(ruleRegistryProvider).removeWhatsAppRule(
                          MessagingPackage.whatsappBusiness,
                        );
                  }
                },
              ),
              showChevron: false,
            ),
            const SettingsRow(
              featherType: FeatherCoreType.personalAgent,
              title: 'WhatsApp Personal (Consultas comerciales)',
              subtitle: 'Responde precios cuando un contacto pregunte por productos',
              trailing: ValueBadge(label: 'INTELIGENTE'),
            ),
            const SettingsRow(
              icon: Icons.send_rounded,
              title: 'Telegram Comercial',
              subtitle: 'Atención de catálogo en grupos y chats de Telegram',
              trailing: ValueBadge(label: 'DISPONIBLE'),
            ),
          ],
        ),
      ],
    );
  }
}
