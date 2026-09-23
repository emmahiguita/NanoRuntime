/// NANO-BUSINESS-HEADER — Encabezado del Agente de Negocio Universal.
///
/// QUÉ HACE:
/// Muestra la identidad comercial: icono de negocio, título "Nano Negocio",
/// subtítulo explicativo, estado de actividad y canales de venta.
///
/// CÓMO FUNCIONA:
/// Diseñado con glassmorphism, badges reactivos y soporte multicanal
/// (WhatsApp Business, WhatsApp Personal, Telegram, Web).
///
/// POR QUÉ:
/// Desvincula la idea de que el negocio pertenece únicamente a WhatsApp,
/// posicionándolo como el cerebro comercial universal de la empresa.
library;

import 'package:flutter/material.dart';
import '../../../../core/widgets/feather_core_icon.dart';
import '../automation_visual_theme.dart';

class NanoBusinessHeader extends StatelessWidget {
  final String businessName;
  final bool isActive;
  final List<String> activeChannels;

  const NanoBusinessHeader({
    super.key,
    required this.businessName,
    this.isActive = true,
    this.activeChannels = const ['WhatsApp Business', 'Catálogo Activo'],
  });

  @override
  Widget build(BuildContext context) {
    final visual = AutomationVisual.of(context);

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 12),
      padding: const EdgeInsets.all(16),
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
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: visual.accent.withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Center(
                  child: FeatherCoreIcon(
                    type: FeatherCoreType.whatsappBusiness,
                    size: 26,
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      businessName.isNotEmpty ? businessName : 'Nano Negocio',
                      style: TextStyle(
                        color: visual.text,
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.3,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Atiende clientes y conoce tu negocio.',
                      style: TextStyle(
                        color: visual.textMuted,
                        fontSize: 12.5,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 9,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: isActive
                      ? visual.accent.withValues(alpha: 0.18)
                      : visual.textMuted.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isActive
                        ? visual.accent.withValues(alpha: 0.40)
                        : Colors.transparent,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 6,
                      height: 6,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: isActive ? visual.accent : visual.textMuted,
                      ),
                    ),
                    const SizedBox(width: 5),
                    Text(
                      isActive ? 'ACTIVO' : 'PAUSADO',
                      style: TextStyle(
                        color: isActive ? visual.accent : visual.textMuted,
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 6,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text(
                'Canales de venta:',
                style: TextStyle(
                  color: visual.textMuted,
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                ),
              ),
              for (final c in activeChannels)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 7,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: visual.surface.withValues(alpha: 0.70),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: visual.cardBorder.withValues(alpha: 0.18),
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
                          color: visual.accent,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        c,
                        style: TextStyle(
                          color: visual.text,
                          fontSize: 10.5,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
