// QUÉ: carcasa Liquid Glass compartida por navegación y escritura.
// CÓMO: delega transparencia, desenfoque y bordes al motor GlassSurface.
// POR QUÉ: conserva todos los estados del dock sin una placa blanca opaca.
library;

import 'package:flutter/material.dart';
import '../glass_surface.dart';

class NanoNavBarContainer extends StatelessWidget {
  const NanoNavBarContainer({
    super.key,
    required this.child,
    this.brightness,
    this.isFocused = false,
    this.isListening = false,
    this.isProcessing = false,
    this.compact = false,
    this.transparent = false,
    this.showHandle = true,
    this.radius = 26,
  });

  final Widget child;
  final Brightness? brightness;
  final bool isFocused;
  final bool isListening;
  final bool isProcessing;
  final bool compact;
  final bool transparent;
  final bool showHandle;
  final double radius;

  /// El dock utiliza el mismo motor de cristal que las ventanas y tarjetas.
  /// El estado activo solo refleja foco/voz/trabajo observados por su dueño.
  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final dark = (brightness ?? scheme.brightness) == Brightness.dark;
    final active = isFocused || isListening || isProcessing;
    return Semantics(
      container: true,
      label: 'Navegación y escritura de Nano',
      child: GlassSurface(
        radius: radius,
        interactive: false,
        blur: 20,
        opacity: transparent ? .74 : .90,
        intensity: dark ? .32 : .48,
        isActive: active,
        borderWidth: active ? 1.2 : .9,
        padding: EdgeInsets.symmetric(
          horizontal: compact ? 7 : 11,
          vertical: 3,
        ),
        child: Material(
          type: MaterialType.transparency,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (showHandle)
                Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Container(
                    width: 32,
                    height: 3,
                    decoration: BoxDecoration(
                      color: scheme.onSurfaceVariant.withValues(alpha: .6),
                      borderRadius: BorderRadius.circular(99),
                    ),
                  ),
                ),
              child,
            ],
          ),
        ),
      ),
    );
  }
}
