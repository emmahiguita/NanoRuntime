/// NANO-BUSINESS-SCREEN — Pantalla unificada y estudio completo de Nano Negocio.
///
/// QUÉ HACE:
/// Integra en una sola experiencia comercial la gestión total de ventas:
/// catálogo de productos/servicios, medios de pago, logística/atención y canales.
///
/// CÓMO FUNCIONA:
/// - Detecta automáticamente la orientación del dispositivo (vertical vs horizontal).
/// - En modo vertical (portrait), despliega un encabezado completo con badges y pestañas amplias.
/// - En modo horizontal (landscape), activa [NanoBusinessLandscapeBar], compactando la cabecera
///   a 50px para maximizar el área de trabajo y eliminar cuellos de botella y desbordamientos.
/// - Permite activar o desactivar Nano Negocio directamente vía [RuleRegistry], persistiendo en SQLite.
///
/// POR QUÉ:
/// Cumple con los lineamientos de arquitectura limpia, SOLID, Material Expressive y código < 200 líneas.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/widgets/navigation/nano_navigation_panel.dart';
import '../../application/automation_coordinator_provider.dart'
    show ruleRegistryProvider;
import '../../engine/business/business_facts_providers.dart';
import '../../engine/messaging/messaging_package.dart';
import '../automation_visual_theme.dart';
import 'nano_business_catalog_tab.dart';
import 'nano_business_channels_tab.dart';
import 'nano_business_header.dart';
import 'nano_business_info_tab.dart';
import 'nano_business_landscape_bar.dart';
import 'nano_business_payments_tab.dart';
import 'nano_business_service_tab.dart';

class NanoBusinessScreen extends ConsumerWidget {
  final int initialTabIndex;

  const NanoBusinessScreen({super.key, this.initialTabIndex = 0});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final visual = AutomationVisual.of(context);
    final ruleRegistry = ref.watch(ruleRegistryProvider);
    final facts = ref.watch(businessFactsNotifierProvider);
    final isLandscape =
        MediaQuery.of(context).orientation == Orientation.landscape;

    final isW4bActive = ruleRegistry.isWhatsAppRuleActive(
      MessagingPackage.whatsappBusiness,
    );
    final businessName = facts.businessName.trim().isEmpty
        ? 'Nano Negocio'
        : facts.businessName.trim();

    // Canales y capacidades activas reales calculadas dinámicamente sin simulación
    final activeChannels = <String>[
      if (isW4bActive) 'WhatsApp Business',
      if (facts.products.isNotEmpty) '${facts.products.length} productos',
      if (facts.delivery.trim().isNotEmpty) 'Envíos',
      if (facts.payments.trim().isNotEmpty) 'Pagos',
    ];

    void toggleBusinessActive(bool active) {
      if (active) {
        ref
            .read(ruleRegistryProvider)
            .seedWhatsAppRule(MessagingPackage.whatsappBusiness);
      } else {
        ref
            .read(ruleRegistryProvider)
            .removeWhatsAppRule(MessagingPackage.whatsappBusiness);
      }
    }

    return DefaultTabController(
      length: 5,
      initialIndex: initialTabIndex,
      child: Scaffold(
        resizeToAvoidBottomInset: false,
        backgroundColor: Colors.transparent,
        body: NanoShellBarScope(
          slotId: 'nano_business',
          child: SafeArea(
            top: true,
            bottom: false,
            child: Column(
              children: [
                if (isLandscape) ...[
                  // 1. Barra ultra-compacta para modo horizontal: navegación, estado y pestañas integradas
                  NanoBusinessLandscapeBar(
                    businessName: businessName,
                    isActive: isW4bActive,
                    onToggleActive: toggleBusinessActive,
                  ),
                ] else ...[
                  // 2. Modo vertical estándar: encabezado espacioso y estético Material Expressive
                  const AutomationBackHeader(),
                  NanoBusinessHeader(
                    businessName: businessName,
                    isActive: isW4bActive,
                    activeChannels: activeChannels,
                    onToggleActive: toggleBusinessActive,
                  ),
                  Container(
                    margin: const EdgeInsets.symmetric(horizontal: 16),
                    decoration: BoxDecoration(
                      color: visual.surface.withValues(alpha: 0.60),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: visual.outline.withValues(alpha: 0.15),
                      ),
                    ),
                    child: TabBar(
                      isScrollable: true,
                      tabAlignment: TabAlignment.start,
                      indicatorColor: visual.accent,
                      labelColor: visual.accent,
                      unselectedLabelColor: visual.textMuted,
                      labelStyle: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                      unselectedLabelStyle: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                      dividerColor: Colors.transparent,
                      tabs: const [
                        Tab(text: 'Negocio'),
                        Tab(text: 'Productos'),
                        Tab(text: 'Pagos'),
                        Tab(text: 'Atención'),
                        Tab(text: 'Canales'),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 6),
                // Contenido de las pestañas
                const Expanded(
                  child: TabBarView(
                    children: [
                      NanoBusinessInfoTab(),
                      NanoBusinessCatalogTab(),
                      NanoBusinessPaymentsTab(),
                      NanoBusinessServiceTab(),
                      NanoBusinessChannelsTab(),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
