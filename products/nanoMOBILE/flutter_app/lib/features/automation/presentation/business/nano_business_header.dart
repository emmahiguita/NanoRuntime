/// NANO-BUSINESS-HEADER — Encabezado del Agente de Negocio Universal.
///
/// QUÉ HACE:
/// Muestra la identidad comercial de Nano Negocio: icono distintivo, nombre comercial,
/// descripción de capacidades, conmutador de estado operativo y canales activos.
///
/// CÓMO FUNCIONA:
/// - Diseñado con componentes Material Expressive: bordes orgánicos y tintes de superficie.
/// - Integra [NanoBusinessStatusBadge] para permitir encender o pausar el negocio directamente.
/// - Renderiza de forma dinámica las etiquetas de los canales de venta conectados en tiempo real.
///
/// POR QUÉ:
/// Centraliza la identidad y el control del negocio sin simulación y en menos de 150 líneas,
/// respetando el principio de Responsabilidad Única (SRP) de Clean Architecture.
library;

import 'package:flutter/material.dart';
import '../../../../core/widgets/feather_core_icon.dart';
import '../automation_visual_theme.dart';
import 'nano_business_status_badge.dart';

class NanoBusinessHeader extends StatelessWidget {
  final String businessName;
  final bool isActive;
  final List<String> activeChannels;
  final ValueChanged<bool>? onToggleActive;

  const NanoBusinessHeader({
    super.key,
    required this.businessName,
    this.isActive = true,
    this.activeChannels = const ['WhatsApp Business'],
    this.onToggleActive,
  });

  @override
  Widget build(BuildContext context) {
    final visual = AutomationVisual.of(context);

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 4, 16, 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: visual.surface.withValues(alpha: 0.70),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: visual.outline.withValues(alpha: 0.20),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              // Icono comercial con contenedor tonal Material Expressive
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: visual.accent.withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Center(
                  child: FeatherCoreIcon(
                    type: FeatherCoreType.whatsappBusiness,
                    size: 24,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              // Identidad y lema
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      businessName.isNotEmpty ? businessName : 'Nano Negocio',
                      style: TextStyle(
                        color: visual.text,
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.3,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Atiende clientes, catálogo y ventas con IA.',
                      style: TextStyle(
                        color: visual.textMuted,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              // Selector de estado interactivo Material Expressive
              NanoBusinessStatusBadge(
                isActive: isActive,
                onChanged: onToggleActive,
              ),
            ],
          ),
          const SizedBox(height: 10),
          // Resumen dinámico y real de canales de atención
          Wrap(
            spacing: 6,
            runSpacing: 4,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text(
                'Canales activos:',
                style: TextStyle(
                  color: visual.textMuted,
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                ),
              ),
              if (activeChannels.isEmpty)
                _buildChannelChip(
                  label: 'Sin canales activos',
                  visual: visual,
                  isMuted: true,
                )
              else
                for (final c in activeChannels)
                  _buildChannelChip(
                    label: c,
                    visual: visual,
                    isMuted: false,
                  ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildChannelChip({
    required String label,
    required AutomationVisualPalette visual,
    required bool isMuted,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 7,
        vertical: 2,
      ),
      decoration: BoxDecoration(
        color: visual.surface.withValues(alpha: 0.70),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isMuted
              ? visual.outline.withValues(alpha: 0.15)
              : visual.cardBorder.withValues(alpha: 0.22),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 5,
            height: 5,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isMuted ? visual.textMuted : visual.accent,
            ),
          ),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              color: isMuted ? visual.textMuted : visual.text,
              fontSize: 10.5,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
