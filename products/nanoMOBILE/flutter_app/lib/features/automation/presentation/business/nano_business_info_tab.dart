/// NANO-BUSINESS-INFO-TAB — Pestaña "Negocio" del Agente Comercial.
///
/// QUÉ HACE:
/// Configura los datos operativos del negocio: ubicación, horarios,
/// cobertura de envíos y carga de plantillas por rubro comercial.
///
/// CÓMO FUNCIONA:
/// Integra con [LocationEditDialog], [HoursEditDialog], [DeliveryEditDialog]
/// y [BusinessPresetsSheet], persistiendo en [businessFactsNotifierProvider].
///
/// POR QUÉ:
/// Ofrece un centro comercial unificado en un archivo menor a 200 líneas.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'meta_templates_screen.dart';
import 'business_sales_messages_editor.dart';
import '../../engine/business/business_facts_providers.dart';
import '../../engine/business/business_profile.dart';
import '../automation_visual_theme.dart';
import '../widgets/dialogs/business_presets_sheet.dart';
import '../widgets/dialogs/business_profile_edit_dialog.dart';
import '../widgets/dialogs/business_name_edit_dialog.dart';
import '../widgets/dialogs/delivery_edit_dialog.dart';
import '../widgets/dialogs/hours_edit_dialog.dart';
import '../widgets/dialogs/location_edit_dialog.dart';
import '../widgets/settings_tile_components.dart';

class NanoBusinessInfoTab extends ConsumerWidget {
  const NanoBusinessInfoTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final visual = AutomationVisual.of(context);
    final facts = ref.watch(businessFactsNotifierProvider);
    final notifier = ref.read(businessFactsNotifierProvider.notifier);
    final isLandscape =
        MediaQuery.of(context).orientation == Orientation.landscape;

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
            'Nano Negocio usa únicamente estos datos reales para responder con precisión.',
            style: TextStyle(color: visual.textMuted, fontSize: 12),
          ),
        ),
        const SizedBox(height: 16),
        const AutomationSectionLabel('Sede y Operación'),
        SettingsCard(
          children: [
            SettingsRow(
              icon: Icons.storefront_outlined,
              title: 'Nombre del negocio',
              subtitle: facts.businessName.trim().isNotEmpty
                  ? facts.businessName.trim()
                  : 'Sin definir — se presentará como “nuestra tienda”',
              onTap: () async {
                final text = await showDialog<String>(
                  context: context,
                  useRootNavigator: true,
                  builder: (_) =>
                      BusinessNameEditDialog(initial: facts.businessName),
                );
                if (text != null) notifier.setBusinessName(text);
              },
            ),
            SettingsRow(
              icon: Icons.place_outlined,
              title: 'Ubicación o dirección',
              subtitle: facts.location.trim().isNotEmpty
                  ? facts.location.trim()
                  : 'Sin definir — Sede física o tienda virtual',
              onTap: () async {
                final text = await showDialog<String>(
                  context: context,
                  useRootNavigator: true,
                  builder: (_) => LocationEditDialog(initial: facts.location),
                );
                if (text != null) notifier.setLocation(text);
              },
            ),
            SettingsRow(
              icon: Icons.schedule_outlined,
              title: 'Horario de atención',
              subtitle: facts.hours.trim().isNotEmpty
                  ? facts.hours.trim()
                  : 'Sin definir — Franjas de atención al cliente',
              onTap: () async {
                final text = await showDialog<String>(
                  context: context,
                  useRootNavigator: true,
                  builder: (_) => HoursEditDialog(initial: facts.hours),
                );
                if (text != null) notifier.setHours(text);
              },
            ),
            SettingsRow(
              icon: Icons.local_shipping_outlined,
              title: 'Envíos y domicilios',
              subtitle: facts.delivery.trim().isNotEmpty
                  ? facts.delivery.trim()
                  : 'Sin definir — Cobertura y costos de entrega',
              onTap: () async {
                final text = await showDialog<String>(
                  context: context,
                  useRootNavigator: true,
                  builder: (_) => DeliveryEditDialog(initial: facts.delivery),
                );
                if (text != null) notifier.setDelivery(text);
              },
            ),
          ],
        ),
        const SizedBox(height: 16),
        const AutomationSectionLabel('Mensajes y Plantillas'),
        SettingsCard(
          children: [
            // Abre el editor de frases que el resolutor de ventas usa al responder.
            SettingsRow(
              icon: Icons.edit_note_outlined,
              title: 'Frases del agente de ventas',
              subtitle: 'Editar saludo, cierre, asesor y respuestas frecuentes',
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => const BusinessSalesMessagesEditor(),
                ),
              ),
            ),
            // Esta ruta administra el WABA remoto; no confunde presets locales con Meta.
            SettingsRow(
              icon: Icons.cloud_sync_outlined,
              title: 'Plantillas oficiales de Meta',
              subtitle:
                  'Consultar, crear y editar plantillas del WhatsApp Business API',
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => const MetaTemplatesScreen(),
                ),
              ),
            ),
            SettingsRow(
              icon: Icons.dashboard_customize_outlined,
              title: 'Cargar plantilla por rubro',
              subtitle: '10 perfiles originales versionados y editables',
              trailing: const ValueBadge(label: '10 PLANTILLAS'),
              onTap: () => BusinessPresetsSheet.show(context),
            ),
            if (facts.profile.isConfigured)
              SettingsRow(
                icon: Icons.schema_outlined,
                title: 'Editar plantilla activa',
                subtitle:
                    '${facts.profile.templateId} · revisión ${facts.profile.revision}',
                trailing: const ValueBadge(label: 'EDITABLE'),
                onTap: () async {
                  final updated = await showDialog<BusinessProfile>(
                    context: context,
                    useRootNavigator: true,
                    builder: (_) =>
                        BusinessProfileEditDialog(initial: facts.profile),
                  );
                  if (updated == null) return;
                  final saved = await notifier.setProfile(updated);
                  if (!context.mounted || saved) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('No fue posible guardar los cambios.'),
                    ),
                  );
                },
              ),
          ],
        ),
      ],
    );
  }
}
