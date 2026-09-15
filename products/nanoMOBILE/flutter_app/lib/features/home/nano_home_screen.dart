import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:nanoai/core/theme/design_tokens.dart';
import 'package:nanoai/features/account/presentation/widgets/google_account_dashboard_card.dart';
import 'package:nanoai/features/browser/presentation/widgets/browser_window_widget.dart';

import 'buho_wallpaper.dart';
import 'nano_home_models.dart';

// =============================================================
// NANO HOME SCREEN — Dashboard Real con Cuenta Google & Telemetría
// =============================================================

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

  /// Estados EN VIVO reales (providers)
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
    final topInset = MediaQuery.viewPaddingOf(context).top;

    return Scaffold(
      resizeToAvoidBottomInset: false,
      backgroundColor: Colors.transparent,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Fondo cósmico del Búho
          const BuhoWallpaper(),

          // Dashboard frontal interactivo
          Align(
            alignment: Alignment.topCenter,
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              padding: EdgeInsets.fromLTRB(16, topInset + 18, 16, 110),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Card Oficial de la Cuenta de Google Conectada
                  const GoogleAccountDashboardCard(),

                  const SizedBox(height: 12),

                  // Ventana Visual Profesional del Navegador Web Real interactiva en Inicio
                  BrowserWindowWidget(
                    isEmbedded: true,
                    onFullscreen: () => context.push('/browser'),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

