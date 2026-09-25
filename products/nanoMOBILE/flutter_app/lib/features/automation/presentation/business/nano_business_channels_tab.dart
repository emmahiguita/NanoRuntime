/// NANO-BUSINESS-CHANNELS-TAB — Pestaña "Canales" del Agente Comercial.
///
/// QUÉ HACE:
/// Configura WhatsApp Business y explica la asignación explícita por chat.
///
/// CÓMO FUNCIONA:
/// - Lee y modifica [ruleRegistryProvider] para encender o apagar las reglas de atención.
/// - En WhatsApp Personal, cada conversación se transfiere desde Mensajería;
///   las palabras del mensaje nunca cambian el agente por sí solas.
/// - Adapta sus márgenes de desplazamiento en orientación horizontal (landscape).
///
/// POR QUÉ:
/// Ofrece control granular real sobre dónde atiende el negocio, cumpliendo con SOLID
/// y manteniendo un código limpio inferior a 150 líneas.
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
    final isLandscape =
        MediaQuery.of(context).orientation == Orientation.landscape;

    final isW4bActive = ruleRegistry.isWhatsAppRuleActive(
      MessagingPackage.whatsappBusiness,
    );
    return ListView(
      padding: EdgeInsets.fromLTRB(16, 6, 16, isLandscape ? 24 : 90),
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: visual.surface.withValues(alpha: 0.50),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: visual.outline.withValues(alpha: 0.18)),
          ),
          child: Text(
            'El catálogo y las políticas se usan solo en conversaciones asignadas a Negocios. Personal y Negocios conservan memorias separadas.',
            style: TextStyle(color: visual.textMuted, fontSize: 12),
          ),
        ),
        const SizedBox(height: 14),
        const AutomationSectionLabel('Canales de Atención Comercial'),
        SettingsCard(
          children: [
            // 1. WhatsApp Business — Canal empresarial exclusivo
            SettingsRow(
              featherType: FeatherCoreType.whatsappBusiness,
              title: 'WhatsApp Business',
              subtitle: isW4bActive
                  ? 'Activo · Atiende ventas y catálogo completo'
                  : 'Inactivo · Toca para activar atención en W4B',
              trailing: Switch(
                value: isW4bActive,
                onChanged: (v) {
                  if (v) {
                    ref
                        .read(ruleRegistryProvider)
                        .seedWhatsAppRule(MessagingPackage.whatsappBusiness);
                  } else {
                    ref
                        .read(ruleRegistryProvider)
                        .removeWhatsAppRule(MessagingPackage.whatsappBusiness);
                  }
                },
              ),
              showChevron: false,
            ),
            // 2. WhatsApp Personal exige asignación explícita para no mezclar memorias.
            const SettingsRow(
              featherType: FeatherCoreType.personalAgent,
              title: 'WhatsApp Personal',
              subtitle:
                  'Asigna el chat a Negocios desde el Centro de Mensajería',
              trailing: ValueBadge(label: 'POR CHAT'),
              showChevron: false,
            ),
          ],
        ),
      ],
    );
  }
}
