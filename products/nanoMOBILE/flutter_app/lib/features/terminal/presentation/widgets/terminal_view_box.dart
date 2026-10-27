import 'package:flutter/material.dart';
import 'package:nanoai/core/services/llm_engine_client.dart';
import 'package:nanoai/features/terminal/terminal_core.dart';
import 'terminal_session_item.dart';

/// Contenedor estilizado para la pila de sesiones interactivas de terminal.
///
/// QUÉ HACE:
/// Aloja el [IndexedStack] con las instancias vivas de [NanoTerminal], aplicando
/// una superficie del tema y un borde de separación discreto.
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
  final bool directInput;
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
    this.directInput = false,
    required this.onTitleChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(8, 2, 8, 4),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
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
                directInput: directInput,
                focusNode: i == activeIndex ? commandFocusNode : null,
                commandController: i == activeIndex ? commandController : null,
                initialCommand: i == activeIndex ? initialCommand : null,
                onTitle: (title) => onTitleChanged(i, title),
              ),
          ],
        ),
      ),
    );
  }
}
