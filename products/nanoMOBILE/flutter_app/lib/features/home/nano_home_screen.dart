import 'package:flutter/material.dart';
import 'package:nanoai/core/theme/design_tokens.dart';

import 'buho_wallpaper.dart';
import 'nano_home_models.dart';

// =============================================================
// NANO HOME SCREEN — fondo publicitario del Búho + marca flotante
// =============================================================
//
// HOME-CLEAN-01 — la pantalla de inicio es SOLO el fondo (wallpaper del
// Búho, cover, juego vertical/horizontal según la pantalla) y la marca
// «N A N O  A I» flotando arriba. Fuera telemetría (RAM/CPU/…), fuera
// héroe: el acceso a secciones vive en la barra flotante del shell.
class NanoHomeScreen extends StatelessWidget {
  final NanoTelemetryData telemetry;
  final KaliStatus kaliStatus;
  final String? chatSubtitle;
  final String? terminalSubtitle;

  final VoidCallback onTerminalTap;
  final VoidCallback onChatTap;
  final VoidCallback onModelsTap;
  final VoidCallback? onDesktopTap;
  final VoidCallback? onAutomationTap;
  final VoidCallback onKaliTap;

  /// Estados EN VIVO reales (providers) — conservados por contrato del
  /// call site (dashboard_screen), sin uso visual en la versión limpia.
  final bool chatOn;
  final bool termOn;
  final bool modelOn;

  const NanoHomeScreen({
    super.key,
    required this.telemetry,
    required this.kaliStatus,
    this.chatSubtitle,
    this.terminalSubtitle,
    required this.onTerminalTap,
    required this.onChatTap,
    required this.onModelsTap,
    this.onDesktopTap,
    this.onAutomationTap,
    required this.onKaliTap,
    this.chatOn = false,
    this.termOn = false,
    this.modelOn = false,
  });

  @override
  Widget build(BuildContext context) {
    final colors = NanoThemeExtension.of(context).colors;
    final isDark = colors is NanoDarkColors;

    return Scaffold(
      // KEYBOARD-FIX-01 — al escribir en la barra (teclado visible), el
      // wallpaper NO debe encogerse: el frame ya mueve la barra sobre el
      // teclado. Sin esto, el Stack se comprime y «se solapa todo» + franja
      // oscura.
      resizeToAvoidBottomInset: false,
      backgroundColor: Colors.transparent,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Capa base: la imagen llena la pantalla (cover) y encaja como
          // parte de la app; el contenido vive encima, jamás solapado.
          const BuhoWallpaper(),
          Align(
            alignment: Alignment.topCenter,
            child: Padding(
              // HOME-CLEAN-01 — único margen: aire superior para la marca
              // flotante. TOP-INSET-FIX-01: el shell despoja MediaQuery.padding
              // (removeTop) — SafeArea aquí leería 0 y la marca quedaría
              // solapada con la barra de estado. viewPadding sobrevive a
              // removePadding: es el inset FÍSICO real de la status bar.
              padding: EdgeInsets.only(
                top: MediaQuery.viewPaddingOf(context).top + 28,
              ),
              child: Text(
                'N A N O   A I',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 3.2,
                  color: colors.textPrimary,
                  shadows: [
                    Shadow(
                      color: (isDark ? colors.accentCyan : colors.accentBlue)
                          .withValues(alpha: isDark ? 0.45 : 0.20),
                      blurRadius: 18,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
