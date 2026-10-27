import 'package:flutter/material.dart';
import '../../../../core/theme/design_tokens.dart';

/// Fondo Material Expressive estático del panel de WhatsApp.
///
/// QUÉ: conserva el paisaje, el cristal y el fundido visual profesional.
/// CÓMO: compone una imagen cacheada y dos gradientes aislados del resto.
/// POR QUÉ: las nubes animadas mantenían GPU y UI ocupadas aun en reposo.
class MessagingAmbientBackdrop extends StatelessWidget {
  final bool isDark;

  const MessagingAmbientBackdrop({super.key, required this.isDark});

  @override
  Widget build(BuildContext context) {
    // En horizontal reducimos la altura para no cubrir contenido útil.
    final landscape =
        MediaQuery.orientationOf(context) == Orientation.landscape;
    final colors = NanoThemeExtension.maybeOf(context)?.colors;
    final fadeColor = isDark
        ? (colors?.background ?? const Color(0xFF09111F))
        : const Color(0xFFF8FAFC);

    return Positioned.fill(
      child: IgnorePointer(
        child: Align(
          alignment: Alignment.topCenter,
          // Aísla el fondo: cambiar mensajes no obliga a repintar la imagen.
          child: RepaintBoundary(
            child: SizedBox(
              width: double.infinity,
              height: landscape ? 238 : 340,
              child: ClipRect(
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    Image.asset(
                      'assets/automation/messaging_ice_header.png',
                      fit: BoxFit.cover,
                      alignment: Alignment.topCenter,
                      filterQuality: FilterQuality.medium,
                      color: isDark
                          ? const Color(0xFF0F172A).withValues(alpha: 0.48)
                          : Colors.white.withValues(alpha: 0.03),
                      colorBlendMode: isDark
                          ? BlendMode.multiply
                          : BlendMode.screen,
                    ),
                    // El fundido permite leer la lista sobre cualquier imagen.
                    DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          stops: const [0.0, 0.52, 0.80, 1.0],
                          colors: [
                            fadeColor.withValues(alpha: 0),
                            fadeColor.withValues(alpha: 0.04),
                            fadeColor.withValues(alpha: 0.58),
                            fadeColor,
                          ],
                        ),
                      ),
                    ),
                    // Brillo diagonal sutil sin animaciones ni temporizadores.
                    DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            Colors.white.withValues(
                              alpha: isDark ? 0.02 : 0.14,
                            ),
                            Colors.transparent,
                            const Color(
                              0xFFBFDBFE,
                            ).withValues(alpha: isDark ? 0.025 : 0.07),
                          ],
                        ),
                      ),
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
