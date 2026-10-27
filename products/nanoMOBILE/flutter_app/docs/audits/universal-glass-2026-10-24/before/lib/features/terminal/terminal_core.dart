import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/services/llm_engine_client.dart';
import '../../core/services/rootfs_manager.dart';
import '../../core/services/proot_manager.dart';
import '../../core/services/kali_manager.dart';
import '../../core/services/docker_manager.dart';
import '../../core/services/proc_fs.dart';
import '../../core/services/pty_shell.dart';
import '../../core/linux/linux_distribution.dart';
import '../../core/services/hardware_info_service.dart';
import '../../core/services/terminal_dependencies.dart';
import 'i_bin_executor.dart';
import 'keyboard_mapper.dart';
import 'command_executor.dart';
import 'terminal_session_controller.dart';
import 'command_tagger.dart';
import 'noar_persistence.dart';

import 'noar_panel.dart';
import 'ansi_terminal.dart';
import 'command_dispatcher.dart';
import 'cron_scheduler.dart';
import 'pty_manager.dart';
import 'real_fs_shell.dart';
import 'terminal_types.dart';
import 'terminalservices.dart';
import 'plugins/system_plugin.dart';
import 'plugins/devops_plugin.dart';
import 'plugins/dashboard_plugin.dart';
import 'plugins/monitor_plugin.dart';
import 'plugins/network_plugin.dart';
import 'plugins/pkg_plugin.dart';
import 'plugins/process_plugin.dart';

import 'presentation/widgets/terminal_keys_row.dart';
import 'presentation/widgets/terminal_text_style.dart';

part 'terminal_operations.dart';
part 'terminal_state_base.dart';
part 'terminal_lifecycle.part.dart';
part 'terminal_shell_init.part.dart';
part 'terminal_registry.part.dart';
part 'terminal_diagnostics.part.dart';
part 'terminal_inference.part.dart';
part 'terminal_tuning.part.dart';
part 'terminal_parsing.part.dart';
part 'terminal_commands.part.dart';
part 'terminal_pty.part.dart';
part 'terminal_keyboard.part.dart';
part 'terminal_history.part.dart';
part 'terminal_console.part.dart';

class NanoTerminal extends StatefulWidget {
  final int sessionId;
  final String initialCwd;
  final LLMEngineClient? engine;
  final void Function(String title)? onTitle;

  /// true = pestaÃ±a visible en el IndexedStack. Dirige pause/resume del
  /// polling PTY: solo la pestaÃ±a activa consume 20 polls/seg (rate limit).
  final bool visible;
  final bool directInput;
  final TerminalDependencies? deps; // optional override for testing

  /// Comando que se ejecuta una sola vez cuando el shell estÃ¡ listo
  /// (ej: "kali shell" desde la card Kali del dashboard). Cuando existe,
  /// se suprime el bash PTY automÃ¡tico para que el stream del comando
  /// sea el dueÃ±o del terminal.
  final String? initialCommand;
  final FocusNode? focusNode;
  final TextEditingController? commandController;

  const NanoTerminal({
    super.key,
    this.sessionId = 0,
    this.initialCwd = '/home/nanoai',
    this.engine,
    this.onTitle,
    this.visible = true,
    this.directInput = false,
    this.deps,
    this.initialCommand,
    this.focusNode,
    this.commandController,
  });
  @override
  State<NanoTerminal> createState() => NanoTerminalState();
}

/// Estado público preservado: métodos heredados y recursos con un solo dueño.
class NanoTerminalState extends _TerminalStateBase
    with
        _TerminalLifecycle,
        _TerminalShellInit,
        _TerminalRegistry,
        _TerminalDiagnostics,
        _TerminalInference,
        _TerminalTuning,
        _TerminalParsing,
        _TerminalCommands,
        _TerminalPty,
        _TerminalKeyboard,
        _TerminalHistory,
        _TerminalConsole {}
