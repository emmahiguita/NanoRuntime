/// NANO-PERSONAL-HEADER — Encabezado representativo de Nano Personal.
///
/// QUÉ HACE:
/// Muestra la identidad del Agente Personal: icono de búho, título,
/// subtítulo explicativo, estado de actividad y canales conectados.
///
/// CÓMO FUNCIONA:
/// Diseñado con glassmorphism sutil, tipografía clara y badges de estado
/// que cumplen los principios de diseño Material Expressive y Nano.
///
/// POR QUÉ:
/// Ofrece orientación visual inmediata al usuario sobre en qué agente se
/// encuentra y qué canales están activos sin saturar la pantalla.
library;

import 'package:flutter/material.dart';
import '../../../../core/widgets/feather_core_icon.dart';
import '../automation_visual_theme.dart';

class NanoPersonalHeader extends StatelessWidget {
  final bool isActive;
  final List<String> activeChannels;

  const NanoPersonalHeader({
    super.key,
    this.isActive = true,
    this.activeChannels = const ['WhatsApp', 'Telegram'],
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
                    type: FeatherCoreType.personalAgent,
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
                      'Nano Personal',
                      style: TextStyle(
                        color: visual.text,
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.3,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Habla y responde como tú.',
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
                  color: visual.accent.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: visual.accent.withValues(alpha: 0.40),
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
                        color: visual.accent,
                      ),
                    ),
                    const SizedBox(width: 5),
                    Text(
                      isActive ? 'ACTIVO' : 'PAUSADO',
                      style: TextStyle(
                        color: visual.accent,
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
                'Canales:',
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
