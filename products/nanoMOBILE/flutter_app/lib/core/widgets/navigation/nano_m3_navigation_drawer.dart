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

    final border = Border(
      left: isRight
          ? BorderSide(
              color: isDark
                  ? Colors.white.withValues(alpha: 0.18)
                  : Colors.white.withValues(alpha: 0.70),
              width: 0.8,
            )
          : BorderSide.none,
      right: !isRight
          ? BorderSide(
              color: isDark
                  ? Colors.white.withValues(alpha: 0.18)
                  : Colors.white.withValues(alpha: 0.70),
              width: 0.8,
            )
          : BorderSide.none,
    );

    return Container(
      width: width,
      height: double.infinity,
      decoration: BoxDecoration(
        borderRadius: borderRadius,
        border: border,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.45 : 0.15),
            blurRadius: 30,
            offset: Offset(isRight ? -8 : 8, 0),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: borderRadius,
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 30, sigmaY: 30),
          child: Container(
            color: isDark ? const Color(0x95151A24) : const Color(0xB5F8FAFD),
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
