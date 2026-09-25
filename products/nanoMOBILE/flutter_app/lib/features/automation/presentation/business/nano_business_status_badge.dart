/// NANO-BUSINESS-STATUS-BADGE — Control interactivo de estado de Nano Negocio.
///
/// QUÉ HACE:
/// Renderiza el conmutador de estado operativo (ACTIVO / PAUSADO) del Modo Negocio
/// con componentes Material Expressive (M3), combinando un indicador visual y switch.
///
/// CÓMO FUNCIONA:
/// - Muestra una cápsula interactiva (pill) con icono dinámico (check / pausa) y color de acento.
/// - Incorpora un [Switch] Material 3 compacto con iconos de estado en el thumb.
/// - Al tocar la cápsula o alternar el switch, ejecuta [onChanged] sin simulación.
///
/// POR QUÉ:
/// Cumple con la arquitectura limpia y SOLID (Principio de Responsabilidad Única):
/// aísla la lógica visual y táctil del estado del negocio en < 120 líneas reutilizables.
library;

import 'package:flutter/material.dart';
import '../automation_visual_theme.dart';

class NanoBusinessStatusBadge extends StatelessWidget {
  final bool isActive;
  final ValueChanged<bool>? onChanged;
  final bool compact;

  const NanoBusinessStatusBadge({
    super.key,
    required this.isActive,
    this.onChanged,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    final visual = AutomationVisual.of(context);
    final activeColor = visual.accent;
    final inactiveColor = visual.textMuted;
    final currentColor = isActive ? activeColor : inactiveColor;

    return Semantics(
      label: isActive
          ? 'Modo Negocio activo. Toca para pausar.'
          : 'Modo Negocio pausado. Toca para activar.',
      button: true,
      child: InkWell(
        onTap: onChanged != null ? () => onChanged!(!isActive) : null,
        borderRadius: BorderRadius.circular(999),
        child: Container(
          padding: EdgeInsets.symmetric(
            horizontal: compact ? 6 : 8,
            vertical: compact ? 2 : 4,
          ),
          decoration: BoxDecoration(
            color: currentColor.withValues(alpha: isActive ? 0.16 : 0.10),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(
              color: currentColor.withValues(alpha: isActive ? 0.35 : 0.18),
              width: 1.0,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Indicador luminoso circular con micro-icono Material Expressive
              Container(
                width: compact ? 14 : 16,
                height: compact ? 14 : 16,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: currentColor,
                ),
                child: Icon(
                  isActive ? Icons.check_rounded : Icons.pause_rounded,
                  size: compact ? 9 : 11,
                  color: Colors.black,
                ),
              ),
              const SizedBox(width: 5),
              // Etiqueta tipográfica de alta legibilidad
              Text(
                isActive ? 'ACTIVO' : 'PAUSADO',
                style: TextStyle(
                  color: currentColor,
                  fontSize: compact ? 9.5 : 10.5,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.4,
                ),
              ),
              if (!compact && onChanged != null) ...[
                const SizedBox(width: 4),
                // Micro switch M3 Expressive para cambio inmediato
                Transform.scale(
                  scale: 0.65,
                  child: Switch(
                    value: isActive,
                    onChanged: onChanged,
                    activeThumbColor: Colors.black,
                    activeTrackColor: activeColor,
                    inactiveThumbColor: visual.textMuted,
                    inactiveTrackColor: visual.surface.withValues(alpha: 0.4),
                    thumbIcon: WidgetStateProperty.resolveWith<Icon?>((states) {
                      if (states.contains(WidgetState.selected)) {
                        return const Icon(Icons.check, size: 12, color: Colors.black);
                      }
                      return const Icon(Icons.close, size: 12, color: Colors.white70);
                    }),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
