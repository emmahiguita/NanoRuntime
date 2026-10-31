// autonomy_mode_menu_trigger.dart — Botón activador del menú de nivel de autonomía.
// QUÉ HACE:
// Presenta la cápsula Liquid Glass táctil que actúa como ancla visual para MenuAnchor,
// mostrando el modo activo, icono representativo y chevron animado de apertura.
//
// CÓMO FUNCIONA:
// Al pulsar, emite feedback háptico ligero y abre o cierra el MenuController de Material 3.
//
// POR QUÉ:
// Separa la interfaz del botón activador respecto a la definición del menú contextual,
// garantizando que autonomy_mode_menu_anchor.dart permanezca por debajo de 150 líneas.
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:nanoai/features/automation/personal_agent/domain/conversation_autonomy_mode.dart';

class AutonomyModeMenuTrigger extends StatelessWidget {
  const AutonomyModeMenuTrigger({
    super.key,
    required this.controller,
    required this.mode,
    required this.icon,
    required this.activeColor,
  });

  final MenuController controller;
  final ConversationAutonomyMode mode;
  final IconData icon;
  final Color activeColor;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    return Material(
      color: isDark
          ? Colors.white.withValues(alpha: 0.07)
          : scheme.surfaceContainerHighest.withValues(alpha: 0.40),
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () {
          HapticFeedback.lightImpact();
          if (controller.isOpen) {
            controller.close();
          } else {
            controller.open();
          }
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isDark
                  ? Colors.white.withValues(alpha: 0.12)
                  : scheme.outlineVariant.withValues(alpha: 0.5),
              width: 1.0,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 30,
                height: 30,
                decoration: BoxDecoration(
                  color: activeColor.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  icon,
                  size: 16,
                  color: activeColor,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Nivel de Autonomía: ${mode.label}',
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: scheme.onSurface,
                      ),
                    ),
                    Text(
                      mode.description,
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 11,
                        color: scheme.onSurfaceVariant,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              Icon(
                controller.isOpen
                    ? Icons.keyboard_arrow_up_rounded
                    : Icons.keyboard_arrow_down_rounded,
                size: 20,
                color: scheme.onSurfaceVariant,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
