// autonomy_mode_menu_anchor.dart — Menú interactivo de nivel de autonomía mediante MenuAnchor M3.
// QUÉ HACE:
// Despliega un menú contextual flotante anclado (MenuAnchor) para seleccionar el nivel de autonomía:
// 'Supervisado' (Borradores), 'Auto seguro' (Bajo riesgo), 'Autónomo' y 'Desactivado'.
//
// CÓMO FUNCIONA:
// Aloja MenuAnchor de Material 3 con MenuItemButton para cada nivel de autonomía,
// estilo Liquid Glass con desenfoque, iconos semánticos, checkmarks y actualización reactiva en SettingsProvider.
//
// POR QUÉ:
// Reemplaza las tarjetas rígidas y segmentadas por un menú M3 compacto y accesible según:
// https://pub.dev/documentation/material_ui/latest/material_ui/MenuAnchor-class.html
library;

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nanoai/core/providers/settings_provider.dart';
import 'package:nanoai/features/automation/domain/automation_policy.dart';
import 'package:nanoai/features/automation/personal_agent/domain/conversation_autonomy_mode.dart';
import 'autonomy_mode_menu_trigger.dart';

class AutonomyModeMenuAnchor extends ConsumerWidget {
  const AutonomyModeMenuAnchor({super.key});

  IconData _iconForMode(ConversationAutonomyMode mode) {
    switch (mode) {
      case ConversationAutonomyMode.suggestions:
        return CupertinoIcons.pencil_outline;
      case ConversationAutonomyMode.safeAuto:
        return CupertinoIcons.shield_fill;
      case ConversationAutonomyMode.autonomous:
        return CupertinoIcons.bolt_fill;
      case ConversationAutonomyMode.disabled:
        return CupertinoIcons.pause_circle;
    }
  }

  Color _colorForMode(ConversationAutonomyMode mode, ColorScheme scheme) {
    switch (mode) {
      case ConversationAutonomyMode.suggestions:
        return const Color(0xFFFFB26B);
      case ConversationAutonomyMode.safeAuto:
        return scheme.primary;
      case ConversationAutonomyMode.autonomous:
        return const Color(0xFF10B981);
      case ConversationAutonomyMode.disabled:
        return scheme.onSurfaceVariant;
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    final settingsNotifier = ref.read(settingsProvider.notifier);
    final waMode = ConversationAutonomyModeName.fromName(settings.waAutonomyMode);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    final activeColor = _colorForMode(waMode, scheme);

    return MenuAnchor(
      alignmentOffset: const Offset(0, 6),
      style: MenuStyle(
        backgroundColor: WidgetStatePropertyAll(
          isDark ? const Color(0xF20F172A) : const Color(0xF7FFFFFF),
        ),
        surfaceTintColor: const WidgetStatePropertyAll(Colors.transparent),
        elevation: const WidgetStatePropertyAll(12),
        shape: WidgetStatePropertyAll(
          RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: BorderSide(
              color: isDark
                  ? Colors.white.withValues(alpha: 0.16)
                  : Colors.black.withValues(alpha: 0.08),
              width: 1.0,
            ),
          ),
        ),
        padding: const WidgetStatePropertyAll(
          EdgeInsets.symmetric(vertical: 8, horizontal: 6),
        ),
      ),
      menuChildren: [
        for (final mode in ConversationAutonomyMode.values)
          MenuItemButton(
            leadingIcon: Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: _colorForMode(mode, scheme).withValues(alpha: 0.14),
                shape: BoxShape.circle,
              ),
              child: Icon(
                _iconForMode(mode),
                size: 16,
                color: _colorForMode(mode, scheme),
              ),
            ),
            trailingIcon: mode == waMode
                ? Icon(Icons.check_rounded, size: 20, color: scheme.primary)
                : null,
            onPressed: () {
              HapticFeedback.selectionClick();
              settingsNotifier.setWaAutonomyMode(mode.name);
              settingsNotifier.setAgentAutomationMode(
                mode == ConversationAutonomyMode.autonomous
                    ? AgentAutomationMode.autonomous
                    : AgentAutomationMode.assisted,
              );
            },
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    mode.label,
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 14,
                      fontWeight:
                          mode == waMode ? FontWeight.w600 : FontWeight.w500,
                      color: mode == waMode ? scheme.primary : scheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 2),
                  SizedBox(
                    width: 220,
                    child: Text(
                      mode.description,
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 11,
                        color: scheme.onSurfaceVariant,
                        height: 1.25,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
      builder: (context, controller, child) {
        return AutonomyModeMenuTrigger(
          controller: controller,
          mode: waMode,
          icon: _iconForMode(waMode),
          activeColor: activeColor,
        );
      },
    );
  }
}