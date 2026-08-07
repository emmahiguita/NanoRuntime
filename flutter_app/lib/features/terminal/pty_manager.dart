import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import '../../core/services/pty_shell.dart';
import '../../core/services/shell_executor.dart';
import '../../core/services/rootfs_manager.dart';
import 'ansi_terminal.dart';

/// Single-responsibility: owns the PTY session lifecycle.
/// Extracted from _TermState. Handles open, close, resize, signal,
/// and ANSI buffer management.
class PtyManager {
  PtySession? _session;
  AnsiTerminal? _ansi;
  StreamSubscription<Uint8List>? _outputSub;
  StreamSubscription<void>? _doneSub;
  bool _alive = true;

  // Injected dependencies (constructor-injected, not late-init)
  final ShellExecutor? shell;
  final RootfsManager? rootfs;
  final Map<String, String> Function({String? ldPreload, Map<String, String>? extra}) rootfsEnv;
  final void Function(String title)? onTitle;

  PtyManager({
    this.shell,
    this.rootfs,
    required this.rootfsEnv,
    this.onTitle,
  });

  bool get isActive => _session != null && !_session!.isClosed;
  PtySession? get session => _session;
  AnsiTerminal? get ansi => _ansi;

  /// Open a PTY session with the given command. Fails gracefully if rootfs
  /// isn't available or the binary doesn't exist.
  Future<bool> open(List<String> argv, {Map<String, String>? env, String? ldPreload}) async {
    await close(); // ensure clean state

    if (rootfs == null || !rootfs!.isInstalled) return false;

    final defaultEnv = rootfsEnv(ldPreload: ldPreload);
    if (env != null) defaultEnv.addAll(env);

    try {
      final ses = await PtySession.open(
        argv: argv,
        env: defaultEnv,
        ldPreload: ldPreload,
        rows: 24,
        cols: 80,
      );
      _session = ses;
      _ansi?.dispose();
      _ansi = AnsiTerminal(rows: 24, cols: 80);

      var lastTitle = '';
      _ansi!.addListener(() {
        final t = _ansi!.title;
        if (t.isNotEmpty && t != lastTitle) {
          lastTitle = t;
          onTitle?.call(t);
        }
      });

      _outputSub = ses.output.listen((data) {
        _ansi?.feedBytes(data);
      });

      _doneSub = ses.done.listen((_) {
        _session = null;
        _ansi?.dispose();
        _ansi = null;
      });

      return true;
    } catch (_) {
      return false;
    }
  }

  /// Close the active PTY session. Idempotent.
  Future<void> close() async {
    if (_session == null) return;
    try {
      _outputSub?.cancel();
      _doneSub?.cancel();
      await _session!.close();
    } catch (_) {}
    _session = null;
    _ansi?.dispose();
    _ansi = null;
  }

  /// Write bytes to the PTY master fd.
  void write(List<int> bytes) {
    _session?.writeBytes(bytes);
  }

  /// Write a string to the PTY.
  void writeString(String s) {
    _session?.write(s);
  }

  /// Apply new dimensions (SIGWINCH).
  void resize(int w, int h, {double? cellW, double? cellH}) {
    if (!isActive) return;
    final cols = cellW != null ? (w / cellW).floor().clamp(20, 300) : 80;
    final rows = cellH != null ? (h / cellH).floor().clamp(5, 100) : 24;
    _ansi?.reset(rows: rows, cols: cols);
    _session?.resize(rows, cols);
  }

  /// Send a signal to the PTY child process.
  void signal(int sig) {
    _session?.signal(sig);
  }

  void dispose() {
    _alive = false;
    close();
  }
}
