import 'terminal_types.dart';

/// Plugin-style registration for terminal-specific commands.
///
/// OCP: new commands register here without modifying _TermState._buildRegistry().
/// Each plugin receives the terminal context and registers its commands into
/// the _cmds map via a callback. The terminal owns the registry; plugins just
/// populate it.
///
/// Usage:
///   TerminalPlugin.ai.registerInto(_cmds, _ctx, _out, () => _engine);
typedef CmdRegistrar = void Function(String name, CmdFn fn);

abstract class TerminalPlugin {
  /// Registers this plugin's commands into the terminal's command map.
  /// [getEngine] is a lazy getter for the LLM engine (may be null).
  void registerInto(
    CmdRegistrar register,
    TerminalCtx ctx,
    void Function(String text, Ln type) out,
    Object? Function() getEngine,
  );
}
