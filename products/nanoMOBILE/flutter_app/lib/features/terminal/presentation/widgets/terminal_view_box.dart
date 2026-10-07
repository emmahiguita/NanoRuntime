import 'package:flutter/material.dart';
import 'package:nanoai/core/theme/design_tokens.dart';
import 'package:nanoai/core/services/llm_engine_client.dart';
import 'package:nanoai/features/terminal/terminal_core.dart';
import 'terminal_session_item.dart';

/// Contenedor estilizado para la pila de sesiones interactivas de terminal.
///
/// QUÉ HACE:
/// Aloja el [IndexedStack] con las instancias vivas de [NanoTerminal], aplicando
/// bordes sutiles, sombras Obsidian y aceleración por GPU.
///
/// CÓMO FUNCIONA:
/// Mantiene todas las pestañas montadas para preservar el historial ANSI del PTY,
/// pero solo notifica visibilidad a la pestaña actualmente seleccionada.
///
/// POR QUÉ:
/// Cumple con Single Responsibility Principle (SRP) y mantiene los archivos bajo 200 líneas.
class TerminalViewBox extends StatelessWidget {
  final List<TerminalSessionItem> sessions;
  final int activeIndex;
  final bool isSquareMode;
  final Color fgColor;
  final bool isDark;
  final LLMEngineClient engine;
  final FocusNode commandFocusNode;
  final TextEditingController commandController;
  final String? initialCommand;
  final void Function(int index, String title) onTitleChanged;

  const TerminalViewBox({
    super.key,
    required this.sessions,
    required this.activeIndex,
    required this.isSquareMode,
    required this.fgColor,
    required this.isDark,
    required this.engine,
    required this.commandFocusNode,
    required this.commandController,
    this.initialCommand,
    required this.onTitleChanged,
  });

  @override
  Widget build(BuildContext context) {
    final themeColors = NanoThemeExtension.of(context).colors;
    final activeColor = sessions.isNotEmpty
        ? (sessions[activeIndex].color ?? fgColor)
        : fgColor;

    return Container(
      margin: const EdgeInsets.fromLTRB(6, 2, 6, 4),
      decoration: BoxDecoration(
        color: isDark
            ? const Color(0xFF020611).withValues(alpha: 0.90)
            : themeColors.surface.withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isSquareMode ? activeColor : fgColor.withValues(alpha: 0.14),
          width: isSquareMode ? 1.4 : 1.0,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.45),
            blurRadius: 18,
            offset: const Offset(0, 5),
          ),
          if (isSquareMode)
            BoxShadow(
              color: activeColor.withValues(alpha: 0.18),
              blurRadius: 14,
              spreadRadius: 1,
            ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(11),
        child: IndexedStack(
          index: activeIndex,
          children: [
            for (final (i, s) in sessions.indexed)
              NanoTerminal(
                key: s.key,
                sessionId: s.id,
                initialCwd: s.cwd,
                engine: engine,
                visible: i == activeIndex,
                focusNode: i == activeIndex ? commandFocusNode : null,
                commandController:
                    i == activeIndex ? commandController : null,
                initialCommand: i == activeIndex ? initialCommand : null,
                onTitle: (title) => onTitleChanged(i, title),
              ),
          ],
        ),
      ),
    );
  }
}
