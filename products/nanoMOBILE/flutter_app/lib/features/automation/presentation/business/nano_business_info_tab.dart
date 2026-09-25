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
import '../../engine/business/business_facts_providers.dart';
import '../automation_visual_theme.dart';
import '../widgets/dialogs/business_presets_sheet.dart';
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
        const AutomationSectionLabel('Plantillas Comerciales'),
        SettingsCard(
          children: [
            SettingsRow(
              icon: Icons.dashboard_customize_outlined,
              title: 'Cargar plantilla por rubro',
              subtitle:
                  'Comercio, restaurante, servicios, salud, academia u otro',
              trailing: const ValueBadge(label: 'PLANTILLAS'),
              onTap: () => BusinessPresetsSheet.show(context),
            ),
          ],
        ),
      ],
    );
  }
}
