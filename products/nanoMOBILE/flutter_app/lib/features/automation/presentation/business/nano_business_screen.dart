/// NANO-BUSINESS-SCREEN — Pantalla unificada y estudio completo de Nano Negocio.
///
/// QUÉ HACE:
/// Integra en una sola experiencia comercial universal toda la gestión de ventas:
/// Negocio, Catálogo de Productos, Métodos de Pago, Atención/Envíos y Canales.
///
/// CÓMO FUNCIONA:
/// Utiliza un DefaultTabController con 5 pestañas limpias que leen
/// [businessFactsNotifierProvider] y [ruleRegistryProvider].
///
/// POR QUÉ:
/// Reemplaza la antigua pantalla "WhatsApp Negocio" limitada a una app,
/// convirtiéndola en el cerebro comercial universal de Nano AI en menos de 200 líneas.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/widgets/navigation/nano_navigation_panel.dart';
import '../../application/automation_coordinator_provider.dart'
    show ruleRegistryProvider;
import '../../engine/messaging/messaging_package.dart';
import '../automation_visual_theme.dart';
import 'nano_business_catalog_tab.dart';
import 'nano_business_channels_tab.dart';
import 'nano_business_header.dart';
import 'nano_business_info_tab.dart';
import 'nano_business_payments_tab.dart';
import 'nano_business_service_tab.dart';

class NanoBusinessScreen extends ConsumerWidget {
  final int initialTabIndex;

  const NanoBusinessScreen({super.key, this.initialTabIndex = 0});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final visual = AutomationVisual.of(context);
    final isW4bActive = ref.watch(ruleRegistryProvider).isWhatsAppRuleActive(
      MessagingPackage.whatsappBusiness,
    );

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
                const AutomationBackHeader(),
                NanoBusinessHeader(
                  businessName: 'Nano Negocio',
                  isActive: isW4bActive,
                ),
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 16),
                  decoration: BoxDecoration(
                    color: visual.surface.withValues(alpha: 0.60),
                    borderRadius: BorderRadius.circular(12),
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
                const SizedBox(height: 8),
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
