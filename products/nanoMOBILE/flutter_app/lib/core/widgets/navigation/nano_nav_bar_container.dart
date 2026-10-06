// QUÉ: superficie única y neutra para navegación y escritura.
// CÓMO: Material usa la paleta de la aplicación sin filtros GPU ni halos.
// POR QUÉ: mejora contraste y evita repintados decorativos durante el teclado.
library;

import 'package:flutter/material.dart';

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
  final bool isFocused,
      isListening,
      isProcessing,
      compact,
      transparent,
      showHandle;
  final double radius;

  /// Conserva el contrato público; la entrada muestra por sí misma voz y detener.
  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Semantics(
      container: true,
      label: 'Navegación y escritura de Nano',
      child: Material(
        color: colors.surfaceContainer,
        elevation: 2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radius),
          side: BorderSide(color: colors.outlineVariant),
        ),
        clipBehavior: Clip.antiAlias,
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: compact ? 8 : 12,
            vertical: 4,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (showHandle)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Container(
                    width: 36,
                    height: 4,
                    decoration: BoxDecoration(
                      color: colors.onSurfaceVariant,
                      borderRadius: BorderRadius.circular(2),
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
