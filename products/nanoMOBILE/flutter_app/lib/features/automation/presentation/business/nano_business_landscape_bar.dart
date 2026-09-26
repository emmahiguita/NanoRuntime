/// NANO-BUSINESS-LANDSCAPE-BAR — Barra superior compacta para orientación horizontal.
///
/// QUÉ HACE:
/// Proporciona una cabecera horizontal unificada y ultra-compacta para Modo Negocio,
/// integrando navegación, identidad, estado operativo y pestañas en una sola fila.
///
/// CÓMO FUNCIONA:
/// - Ocupa únicamente 48-52 píxeles de altura vertical.
/// - Ubica a la izquierda el botón atrás, icono y título con el badge interactivo de estado.
/// - Embebe a la derecha el [TabBar] con estilos visuales compactos para evitar overflow.
///
/// POR QUÉ:
/// En orientación horizontal (landscape), la pantalla del teléfono tiene solo 360-400px
/// de altura. Esta distribución profesional rescata más de 190px de espacio vertical,
/// garantizando que las listas, catálogos y formularios sean 100% usables y legibles.
library;

import 'package:flutter/material.dart';
import '../../../../core/widgets/feather_core_icon.dart';
import '../automation_visual_theme.dart';
import 'nano_business_status_badge.dart';

class NanoBusinessLandscapeBar extends StatelessWidget {
  final String businessName;
  final bool isActive;
  final ValueChanged<bool>? onToggleActive;
  final VoidCallback? onBack;

  const NanoBusinessLandscapeBar({
    super.key,
    required this.businessName,
    required this.isActive,
    this.onToggleActive,
    this.onBack,
  });

  @override
  Widget build(BuildContext context) {
    final visual = AutomationVisual.of(context);

    return Container(
      height: 50,
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      padding: const EdgeInsets.symmetric(horizontal: 4),
      decoration: BoxDecoration(
        color: visual.surface.withValues(alpha: 0.85),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: visual.outline.withValues(alpha: 0.20)),
      ),
      child: Row(
        children: [
          Semantics(
            label: 'Volver',
            button: true,
            child: IconButton(
              visualDensity: VisualDensity.compact,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
              onPressed: onBack ?? () => Navigator.of(context).maybePop(),
              icon: const Icon(Icons.arrow_back_rounded, size: 20),
            ),
          ),
          const SizedBox(width: 4),
          // 2. Icono representativo de negocio
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: visual.accent.withValues(alpha: 0.16),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Center(
              child: FeatherCoreIcon(
                type: FeatherCoreType.whatsappBusiness,
                size: 16,
              ),
            ),
          ),
          const SizedBox(width: 8),
          // 3. Título del negocio
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 130),
            child: Text(
              businessName.isNotEmpty ? businessName : 'Nano Negocio',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: visual.text,
                fontSize: 13,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          const SizedBox(width: 8),
          // 4. Selector interactivo de estado (Activo/Pausado) en formato compacto
          NanoBusinessStatusBadge(
            isActive: isActive,
            onChanged: onToggleActive,
            compact: true,
          ),
          const SizedBox(width: 12),
          const VerticalDivider(width: 1, indent: 10, endIndent: 10),
          const SizedBox(width: 8),
          // 5. Pestañas de navegación compactas
          Expanded(
            child: TabBar(
              isScrollable: true,
              tabAlignment: TabAlignment.start,
              indicatorColor: visual.accent,
              labelColor: visual.accent,
              unselectedLabelColor: visual.textMuted,
              labelStyle: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
              unselectedLabelStyle: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w500,
              ),
              dividerColor: Colors.transparent,
              padding: EdgeInsets.zero,
              labelPadding: const EdgeInsets.symmetric(horizontal: 10),
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
      ),
    );
  }
}
