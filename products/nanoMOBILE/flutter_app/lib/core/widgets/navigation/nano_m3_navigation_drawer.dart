// nano_m3_navigation_drawer.dart — Menú lateral estilo iOS Liquid Glass.
// QUÉ HACE: Despliega un Drawer lateral adherido al borde con lista limpia de navegación Liquid Glass.
// CÓMO FUNCIONA: Usa BackdropFilter (blur 30), grupo Inset con los 4 destinos y botón de retorno al dock.
// POR QUÉ: Presenta exclusivamente Inicio, Modelos, Terminal y Ajustes con estética limpia (< 140 líneas).
library;

import 'dart:math' as math;
import 'dart:ui';
import 'package:flutter/material.dart';
import 'nano_destination.dart';
import 'nano_m3_drawer_conversion_card.dart';
import 'nano_m3_drawer_destinations.dart';
import 'nano_m3_drawer_header.dart';

class NanoM3NavigationDrawer extends StatelessWidget {
  const NanoM3NavigationDrawer({
    super.key,
    required this.selected,
    required this.onDestinationSelected,
    required this.onCloseDrawer,
    required this.onConvertToBottomBar,
    required this.onOpenSearch,
    required this.onOpenChat,
    required this.onOpenBrowser,
    required this.onOpenWhatsApp,
    required this.onOpenMcp,
    this.onOpenAiWeb,
    required this.onOpenDesktop,
    required this.onOpenDatabase,
    required this.onOpenAccount,
    this.isRight = true,
  });

  final NanoDestination selected;
  final ValueChanged<NanoDestination> onDestinationSelected;
  final VoidCallback onCloseDrawer;
  final VoidCallback onConvertToBottomBar;
  final VoidCallback onOpenSearch;
  final VoidCallback onOpenChat;
  final VoidCallback onOpenBrowser;
  final VoidCallback onOpenWhatsApp;
  final VoidCallback onOpenMcp;
  final VoidCallback? onOpenAiWeb;
  final VoidCallback onOpenDesktop;
  final VoidCallback onOpenDatabase;
  final VoidCallback onOpenAccount;
  final bool isRight;

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final width = math.min(290.0, media.size.width * 0.78);

    final borderRadius = isRight
        ? const BorderRadius.horizontal(left: Radius.circular(26))
        : const BorderRadius.horizontal(right: Radius.circular(26));

    // QUÉ: Borde lateral sutil según el tema activo.
    // CÓMO: Aplica outlineVariant con baja opacidad en claro y blanco difuso en oscuro.
    // POR QUÉ: Integra el Drawer a la paleta sin líneas rígidas o desfasadas.
    final borderColor = isDark
        ? Colors.white.withValues(alpha: 0.16)
        : theme.colorScheme.outlineVariant.withValues(alpha: 0.35);

    final border = Border(
      left: isRight ? BorderSide(color: borderColor, width: 0.75) : BorderSide.none,
      right: !isRight ? BorderSide(color: borderColor, width: 0.75) : BorderSide.none,
    );

    // QUÉ: Color de fondo translúcido Liquid Glass.
    // CÓMO: Extrae surfaceContainerHigh y surface del tema activo con transparencia calculada.
    // POR QUÉ: Asegura que el Drawer refleje el tema seleccionado en Nano (claro, oscuro u OLED).
    final drawerBg = isDark
        ? theme.colorScheme.surface.withValues(alpha: 0.82)
        : theme.colorScheme.surfaceContainerHigh.withValues(alpha: 0.88);

    return Container(
      width: width,
      height: double.infinity,
      decoration: BoxDecoration(
        borderRadius: borderRadius,
        border: border,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.40 : 0.08),
            blurRadius: 28,
            offset: Offset(isRight ? -6 : 6, 0),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: borderRadius,
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 28, sigmaY: 28),
          child: Container(
            color: drawerBg,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // 1. Cabecera limpia iOS
                NanoM3DrawerHeader(onClose: onCloseDrawer),

                // 2. Lista de destinos limpia estilo iOS Liquid Glass
                Expanded(
                  child: ListView(
                    physics: const BouncingScrollPhysics(),
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    children: [
                      NanoM3DrawerDestinations(
                        selected: selected,
                        onSelect: onDestinationSelected,
                      ),
                      const SizedBox(height: 12),
                      NanoM3DrawerConversionCard(
                        onConvertToBottomBar: onConvertToBottomBar,
                      ),
                      SizedBox(height: media.padding.bottom + 16),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
