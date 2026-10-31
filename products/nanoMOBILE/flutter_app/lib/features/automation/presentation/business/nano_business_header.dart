/// NANO-BUSINESS-HEADER — Encabezado del Agente de Negocio Universal.
///
/// QUÉ HACE:
/// Muestra la identidad comercial de Nano Negocio: icono distintivo, nombre comercial,
/// descripción de capacidades, conmutador de estado operativo y canales activos.
///
/// CÓMO FUNCIONA:
/// - Diseñado con componentes iOS Glass y squircle oficial [NanoBusinessIcon].
/// - Integra [NanoBusinessStatusBadge] para permitir encender o pausar el negocio directamente.
/// - Renderiza de forma dinámica las etiquetas de los canales de venta conectados en tiempo real.
///
/// POR QUÉ:
/// Centraliza la identidad y el control del negocio sin simulación y en menos de 150 líneas,
/// respetando el principio de Responsabilidad Única (SRP) de Clean Architecture.
library;

import 'package:flutter/material.dart';
import '../../../../core/widgets/nano_business_icon.dart';
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
        border: Border.all(color: visual.outline.withValues(alpha: 0.20)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              // Icono comercial profesional iOS squircle (44dp)
              const NanoBusinessIcon(
                size: 44,
                isTile: true,
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
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Atención, catálogo y cobros automáticos',
                      style: TextStyle(
                        color: visual.textMuted,
                        fontSize: 12,
                        height: 1.2,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              // Estado operativo interactivo
              NanoBusinessStatusBadge(
                isActive: isActive,
                onChanged: onToggleActive,
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Canales comerciales activos
          Wrap(
            spacing: 6,
            runSpacing: 4,
            children: activeChannels.map((channel) {
              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: visual.outline.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 6,
                      height: 6,
                      decoration: BoxDecoration(
                        color: isActive ? visual.accent : visual.outline,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 5),
                    Text(
                      channel,
                      style: TextStyle(
                        color: visual.text,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}
