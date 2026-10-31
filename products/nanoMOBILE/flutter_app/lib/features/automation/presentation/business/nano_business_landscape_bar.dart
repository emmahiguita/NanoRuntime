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
import '../../../../core/widgets/nano_business_icon.dart';
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
          // 2. Icono representativo de negocio iOS squircle
          const NanoBusinessIcon(
            size: 28,
            isTile: true,
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
                letterSpacing: -0.2,
              ),
            ),
          ),
          const SizedBox(width: 8),
          // 4. Badge interactivo de estado operativo
          NanoBusinessStatusBadge(
            isActive: isActive,
            onChanged: onToggleActive,
            compact: true,
          ),
          const Spacer(),
          // 5. Contenedor flexible para que el TabBar se integre en la barra
          Flexible(
            flex: 2,
            child: TabBar(
              isScrollable: true,
              tabAlignment: TabAlignment.start,
              indicatorColor: visual.accent,
              indicatorWeight: 3,
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
              tabs: const [
                Tab(
                  icon: Icon(Icons.chat_bubble_outline, size: 16),
                  text: 'Canales',
                ),
                Tab(
                  icon: Icon(Icons.inventory_2_outlined, size: 16),
                  text: 'Catálogo',
                ),
                Tab(
                  icon: Icon(Icons.receipt_long_outlined, size: 16),
                  text: 'Pagos',
                ),
                Tab(
                  icon: Icon(Icons.smart_toy_outlined, size: 16),
                  text: 'Servicio',
                ),
                Tab(
                  icon: Icon(Icons.tune_rounded, size: 16),
                  text: 'Ajustes',
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
