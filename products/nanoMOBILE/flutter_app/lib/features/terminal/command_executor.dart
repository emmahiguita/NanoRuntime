import 'dart:async';
import 'dart:convert';
import 'package:flutter/widgets.dart';
import 'i_bin_executor.dart';
import 'real_fs_shell.dart';
import '../../core/services/rootfs_manager.dart';
import '../../core/services/terminal_audit_logger.dart';
import '../../core/services/pty_shell.dart';
import 'command_dispatcher.dart';
import 'terminal_types.dart';

/// Dependency bundle passed to [CommandExecutor] so the 265-line _execAsync
/// can live outside _TermState. Every dependency is explicit here — no implicit
/// coupling to the widget state (DIP applied).
///
/// Mutable fields (historyIndex, bashCwd) are owned by _TermState and borrowed
/// by CommandExecutor for the duration of execute().
class CmdExecCtx {
  // ── Output ──
  final void Function(String, Ln) out;
  final void Function(Duration, void Function()) after;

  // ── PTY (actualizado antes de cada execute()) ──
  PtySession? pty;
  bool ptyActive;
  final Future<void> Function() closePty;

  // ── Prompt & history ──
  String ps1;
  final List<String> history;
  int historyIndex;
  final TextEditingController input;

  // ── Noar library ──
  final void Function(String, String) saveToNoar;
  final String Function(String) tagFor;

  // ── Dispatch ──
  final CommandDispatcher? dispatcher;
  final bool Function(String) hasShellOps;

  // ── Shell ──
  final IBinExecutor? shell;
  String bashCwd;
  final RootfsManager? rootfs;

  /// Filesystem shell REAL del host (desktop Linux/macOS). null en Android
  /// (ahí manda NanoRuntime/toybox). Inyectado para tests con fake.
  final RealFsShell? realFs;

  /// true si la plataforma es Android. Inyectado para tests (fakes).
  final bool isAndroid;
  final Map<String, String> Function({
    String? ldPreload,
    Map<String, String>? extra,
  })
  rootfsEnv;
  final void Function(ShellResult) shellOut;

  // ── Real commands (rootfs toybox como fuente de verdad) ──
  final Set<String> realCmds;

  // ── Tokenizer ──
  final List<String> Function(String) tokenize;

  // ── Registry ──
  final TerminalCtx ctx;
  final Map<String, CmdFn> cmds;

  // ── Audit ──
  final TerminalAuditLogger? audit;

  // ── Lifecycle ──
  bool alive;

  CmdExecCtx({
    required this.out,
    required this.after,
    required this.pty,
    required this.ptyActive,
    required this.closePty,
    required this.ps1,
    required this.history,
    required this.historyIndex,
    required this.input,
    required this.saveToNoar,
    required this.tagFor,
    required this.dispatcher,
    required this.hasShellOps,
    required this.shell,
    required this.bashCwd,
    required this.rootfs,
    this.realFs,
    this.isAndroid = false,
    required this.rootfsEnv,
    required this.shellOut,
    required this.realCmds,
    required this.tokenize,
    required this.ctx,
    required this.cmds,
    required this.audit,
    required this.alive,
  });
}

/// Executes a single raw command line through the complete pipeline:
/// PTY → history → dispatcher → !shell → shell ops → real commands → registry.
///
/// Extracted from _TermState._execAsync (265 lines) for SRP.
/// Stateless except for [CmdExecCtx] which holds mutable borrows.
class CommandExecutor {
  static Future<void> execute(String raw, CmdExecCtx x) async {
    final traceId = x.audit?.nextTraceId('cmd');
    final started = Stopwatch()..start();
    x.audit?.event(
      'command.input',
      layer: 'terminal',
      traceId: traceId,
      command: raw,
      data: {'ptyActive': x.ptyActive},
    );

    // ── Modo PTY: Enter como CR directo al terminal ──
    if (x.ptyActive) {
      final cmd = raw.trim();
      if (cmd == 'exit' || cmd == 'logout' || cmd == '^D') {
        x.audit?.event(
          'command.pty.exit',
          layer: 'terminal',
          traceId: traceId,
          command: cmd,
        );
        await x.closePty();
        return;
      }
      if (cmd.isNotEmpty) {
        x.audit?.event(
          'command.pty.write_line',
          layer: 'terminal',
          traceId: traceId,
          command: cmd,
          byteCount: cmd.length + 1,
        );
        // _onKey ya transmitió cada tecla (UTF-8 via keyToPtyBytes) al PTY
        // conforme se tecleó. Aquí solo se envía CR (Enter). Reenviar el
        // comando completo duplicaría cada carácter (regresión real).
        x.pty!.writeBytes([0x0d]);
      }
      return;
    }

    x.out(x.ps1 + raw, Ln.prompt);
    final cmd = raw.trim();
    if (cmd.isEmpty) return;
    x.history.add(cmd);
    x.historyIndex = -1;
    x.input.clear();
    x.saveToNoar(cmd, x.tagFor(cmd));

    if (cmd == 'exit' || cmd == 'logout') {
      x.audit?.event(
        'command.exit',
        layer: 'terminal',
        traceId: traceId,
        command: cmd,
      );
      x.out('— Sesion finalizada ($cmd) —', Ln.system);
      return;
    }

    // ── CommandDispatcher: comandos Linux comunes ──
    if (x.dispatcher != null && !x.hasShellOps(cmd)) {
      final parts = cmd.split(RegExp(r'\s+'));
      if (parts.isNotEmpty &&
          x.dispatcher!.dispatch(
            parts[0],
            parts.length > 1 ? parts.sublist(1) : <String>[],
            traceId: traceId,
          )) {
        x.audit?.event(
          'command.completed',
          layer: 'terminal',
          traceId: traceId,
          command: cmd,
          duration: started.elapsed,
          data: {'path': 'dispatcher'},
        );
        return;
      }
    }

    // ── Prefijo ! → ash -c via Nanoshell FFI ──
    if (cmd.startsWith('!')) {
      final shellCmd = cmd.substring(1).trim();
      if (shellCmd.isEmpty) return;
      if (shellCmd.startsWith('cd ') || shellCmd == 'cd') {
        final target = shellCmd.length > 3 ? shellCmd.substring(3).trim() : '/';
        if (target == '..') {
          x.bashCwd = x.bashCwd == '/'
              ? '/'
              : x.bashCwd.substring(0, x.bashCwd.lastIndexOf('/'));
          if (x.bashCwd.isEmpty) x.bashCwd = '/';
        } else if (target.startsWith('/')) {
          x.bashCwd = target;
        } else if (target.isNotEmpty) {
          x.bashCwd = x.bashCwd == '/' ? '/$target' : '${x.bashCwd}/$target';
        }
        x.out('[ash] cd → ${x.bashCwd}', Ln.system);
      }
      if (x.shell != null && x.shell!.initialized) {
        x.out('[ash] $shellCmd', Ln.system);
        final extraEnv = x.rootfs?.isInstalled == true
            ? <String, String>{
                'LD_PRELOAD': 'libnanoroot.so',
                'NANO_ROOTFS': x.shell!.usrDir!,
                'LD_LIBRARY_PATH': '${x.shell!.usrDir}/lib',
                'HOME': '${x.shell!.baseDir!}/home',
                'PATH':
                    '${x.shell!.usrDir}/bin:${x.shell!.usrDir}/bin/applets:/system/bin:/system/xbin',
                'TERMUX': 'true',
                'LANG': 'en_US.UTF-8',
              }
            : null;
        final r = await x.shell!.toybox([
          'ash',
          '-c',
          shellCmd,
        ], extraEnv: extraEnv);
        x.audit?.event(
          'command.shell.result',
          layer: 'shell',
          traceId: traceId,
          command: shellCmd,
          exitCode: r.exitCode,
          duration: started.elapsed,
          data: {'path': 'bang'},
        );
        x.shellOut(r);
      } else {
        x.out('! : shell no disponible (binarios no extraídos)', Ln.stderr);
      }
      return;
    }

    // ── Detección pipes/redirección → ash -c ──
    if (x.hasShellOps(cmd)) {
      // Desktop: sh real del host (pipes/redirección/&& reales).
      if (!x.isAndroid && x.realFs?.hasRealShell == true) {
        await x.realFs!.runShell(cmd, out: x.out);
        return;
      }
      if (x.shell != null && x.shell!.initialized) {
        x.out('[ash] $cmd', Ln.system);
        final extraEnv = x.rootfs?.isInstalled == true
            ? x.rootfsEnv(ldPreload: 'libnanoroot.so')
            : null;
        final r = await x.shell!.toybox(['ash', '-c', cmd], extraEnv: extraEnv);
        x.audit?.event(
          'command.shell.result',
          layer: 'shell',
          traceId: traceId,
          command: cmd,
          exitCode: r.exitCode,
          duration: started.elapsed,
          data: {'path': 'shell_ops'},
        );
        x.shellOut(r);
        return;
      }
      x.out('sh: no disponible (sin rootfs ni shell del host)', Ln.stderr);
      return;
    }

    var parts = x.tokenize(cmd);
    if (parts.isNotEmpty && x.ctx.aliases.containsKey(parts[0])) {
      parts = x.tokenize(x.ctx.aliases[parts[0]]!);
    }
    if (parts.isEmpty) return;
    final name = parts[0], args = parts.sublist(1);

    // ── bash / toybox explícitos ──
    if (name == 'bash' && x.shell != null && x.shell!.initialized) {
      final shellCmd = args.isNotEmpty ? args.join(' ') : '-i';
      x.out('[ash] $shellCmd', Ln.system);
      final r = await x.shell!.toybox(['ash', '-c', shellCmd]);
      x.audit?.event(
        'command.shell.result',
        layer: 'shell',
        traceId: traceId,
        command: shellCmd,
        exitCode: r.exitCode,
        duration: started.elapsed,
        data: {'path': 'bash_cmd'},
      );
      x.shellOut(r);
      return;
    }
    if (name == 'toybox' && x.shell != null && x.shell!.initialized) {
      final result = await x.shell!.toybox(args);
      x.audit?.event(
        'command.shell.result',
        layer: 'shell',
        traceId: traceId,
        command: 'toybox',
        argv: args,
        exitCode: result.exitCode,
        duration: started.elapsed,
        data: {'path': 'toybox'},
      );
      x.shellOut(result);
      return;
    }

    // ── Comandos whitelist → toybox real del rootfs ──
    // A-27: antes un 127 "not found" del rootfs caía en silencio al HOST
    // (dart:io) — el usuario creía que el comando corría en Linux y
    // corría en Android. El rootfs es la fuente de verdad: su stderr se
    // muestra tal cual, sin fallback engañoso.
    if (x.realCmds.contains(name)) {
      if (x.shell != null && x.shell!.initialized) {
        final r = await x.shell!.toybox([name, ...args]);
        x.audit?.event(
          'command.shell.result',
          layer: 'shell',
          traceId: traceId,
          command: name,
          argv: [name, ...args],
          exitCode: r.exitCode,
          duration: started.elapsed,
          data: {'path': 'real_cmd_shell'},
        );
        x.shellOut(r);
        return;
      }
      if (!x.isAndroid &&
          (x.realFs?.supports(name) == true ||
              x.realFs?.hasRealShell == true)) {
        // Desktop: binario real del host con fallback dart:io.
        await x.realFs!.run(name, args, out: x.out);
        if (name == 'cd') x.bashCwd = x.realFs!.cwd;
        return;
      }
      if (!x.isAndroid) {
        x.out('$name: no disponible (sin binarios en este host)', Ln.stderr);
        return;
      }
      x.out('$name: shell engine not initialized.', Ln.stderr);
      return;
    }

    // ── Fallback dart:io (desktop, comandos fuera de realCommands) ──
    if (!x.isAndroid && x.realFs?.supports(name) == true) {
      await x.realFs!.run(name, args, out: x.out);
      if (name == 'cd') x.bashCwd = x.realFs!.cwd;
      return;
    }

    // ── source: ejecuta un script línea a línea ──
    if (name == 'source') {
      if (args.isEmpty) {
        x.out('source: falta archivo', Ln.stderr);
        return;
      }
      if (x.shell != null && x.shell!.initialized) {
        final r = await x.shell!.toybox(['ash', '-c', 'source ${args[0]}']);
        x.shellOut(r);
      } else {
        x.out('source: shell engine not initialized.', Ln.stderr);
      }
      return;
    }

    // ── Registry dispatch (plugins + inline commands) ──
    final handler = x.cmds[name];
    if (handler != null) {
      try {
        handler(args, x.ctx, x.out, x.after);
        x.audit?.event(
          'command.completed',
          layer: 'terminal',
          traceId: traceId,
          command: name,
          duration: started.elapsed,
          data: {'path': 'registry'},
        );
      } catch (e, st) {
        x.audit?.event(
          'command.error',
          layer: 'terminal',
          traceId: traceId,
          command: name,
          duration: started.elapsed,
          error: e,
          stackTrace: st,
          data: {'path': 'registry'},
        );
        rethrow;
      }
    } else {
      x.audit?.event(
        'command.not_found',
        layer: 'terminal',
        traceId: traceId,
        command: name,
        duration: started.elapsed,
      );
      x.out('$name: comando no encontrado. "help" para ver todos.', Ln.stderr);
    }
  }
}
