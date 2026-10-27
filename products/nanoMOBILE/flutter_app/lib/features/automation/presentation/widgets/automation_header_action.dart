// QUÉ: botón de cabecera con iconografía propia y estado explícito.
// CÓMO: conserva un blanco táctil de 48 px y deriva color/contraste del tema.
// POR QUÉ: un control de voz no debe parecer una videollamada ni un robot genérico.
import 'package:flutter/material.dart';
import '../../../../core/widgets/feather_core_icon.dart';
import '../../../../core/widgets/navigation/nano_glyph.dart';

class AutomationHeaderAction extends StatelessWidget {
  const AutomationHeaderAction({
    super.key,
    required this.label,
    required this.type,
    required this.onTap,
    this.active,
    this.muted = false,
  });
  final String label;
  final FeatherCoreType type;
  final VoidCallback? onTap;
  final bool? active;
  final bool muted;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final color = active == true ? scheme.primary : scheme.onSurfaceVariant;
    final duration =
        MediaQuery.disableAnimationsOf(context) ||
            MediaQuery.of(context).accessibleNavigation
        ? Duration.zero
        : const Duration(milliseconds: 180);
    return Semantics(
      button: true,
      label: label,
      enabled: onTap != null,
      toggled: active,
      excludeSemantics: true,
      child: IconButton(
        onPressed: onTap,
        tooltip: label,
        constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
        padding: const EdgeInsets.all(11),
        style: IconButton.styleFrom(
          backgroundColor: active == true
              ? scheme.primary.withValues(alpha: .09)
              : Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(15),
          ),
        ),
        // El cambio sigue el ajuste confirmado, no el simple intento de pulsación.
        icon: AnimatedOpacity(
          duration: duration,
          opacity: onTap == null ? .38 : 1,
          child: AnimatedScale(
            scale: active == true ? 1.06 : 1,
            duration: duration,
            curve: Curves.easeOutCubic,
            child: AnimatedSwitcher(
              duration: duration,
              switchInCurve: Curves.easeOutCubic,
              switchOutCurve: Curves.easeInCubic,
              child: SizedBox.square(
                key: ValueKey('${type.name}:$active:$muted'),
                dimension: 26,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    FeatherCoreIcon(
                      type: type,
                      size: 25,
                      framed: false,
                      accentColor: color,
                    ),
                    // La marca de silencio describe el ajuste real; no simula reproducción.
                    if (muted)
                      NanoGlyph(
                        type: NanoGlyphType.close,
                        size: 13,
                        color: color,
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
