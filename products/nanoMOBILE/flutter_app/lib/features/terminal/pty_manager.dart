import 'dart:async';
import 'dart:io';
import 'package:flutter/widgets.dart';
import 'package:flutter/services.dart';
import '../../core/services/pty_shell.dart';
import '../../core/services/rootfs_manager.dart';
import '../../core/services/terminal_audit_logger.dart';
import 'ansi_terminal.dart';

/// Single-responsibility: owns the PTY session lifecycle.
/// Extracted from _TermState. Handles open, close, resize, signal,
/// and ANSI buffer management.
///
/// T1.4 — DEFERRED BY DESIGN (no MISSING, no IMPLEMENTED):
/// PtyManager/PtySession son la vía INTERACTIVA, ya aislada de la ejecución
/// no-interactiva (LinuxExecutionBackend → ShellExecutor). Viven en
/// features/terminal porque hoy el ÚNICO consumidor es el Terminal.
/// Extraer a core/services/LinuxInteractiveBackend SOLO cuando aparezca un
/// segundo consumidor no-Terminal (Automation interactivo, Voz shell/REPL,
/// chat con PTY bidireccional). Hasta entonces, extraer = abstracción muerta.
class PtyManager {
  PtySession? _session;
  AnsiTerminal? _ansi;
  StreamSubscription<Uint8List>? _outputSub;
  StreamSubscription<void>? _doneSub;

  // Injected dependencies (constructor-injected, not late-init)
  final RootfsManager? rootfs;
  final Map<String, String> Function({
    String? ldPreload,
    Map<String, String>? extra,
  })
  rootfsEnv;
  final void Function(String title)? onTitle;
  final TerminalAuditLogger? logger;

  /// Se invoca cuando la sesión termina o se cierra (done o close()).
  /// El dueño (NanoTerminal) lo usa para limpiar su propia referencia al
  /// AnsiTerminal compartido ANTES de que se haga dispose — sin esto, el
  /// build renderiza un ChangeNotifier ya disposed y crashea.
  final void Function()? onSessionEnd;

  PtyManager({
    this.rootfs,
    required this.rootfsEnv,
    this.onTitle,
    this.logger,
    this.onSessionEnd,
  });

  bool get isActive => _session != null && !_session!.isClosed;
  PtySession? get session => _session;
  AnsiTerminal? get ansi => _ansi;

  bool _opening = false;
  bool _disposed = false;
  Future<void>? _closeFuture;

  /// Open a PTY session with the given command. Fails gracefully if rootfs
  /// isn't available or the binary doesn't exist.
  Future<bool> open(
    List<String> argv, {
    Map<String, String>? env,
    String? ldPreload,
    String? traceId,
  }) async {
    if (_opening || _disposed) {
      logger?.event(
        'pty.manager.open.rejected',
        layer: 'pty-manager',
        traceId: traceId,
        argv: argv,
        data: {'opening': _opening, 'disposed': _disposed},
      );
      return false;
    }
    logger?.event(
      'pty.manager.open.start',
      layer: 'pty-manager',
      traceId: traceId,
      argv: argv,
    );
    _opening = true;
    try {
      await close(); // ensure clean state

      if (rootfs == null || !rootfs!.isInstalled) {
        logger?.event(
          'pty.manager.open.no_rootfs',
          layer: 'pty-manager',
          traceId: traceId,
          argv: argv,
        );
        return false;
      }
      final resolvedArgv = _resolveExecutableArgv(argv);
      if (resolvedArgv == null) {
        logger?.event(
          'pty.manager.open.resolve_failed',
          layer: 'pty-manager',
          traceId: traceId,
          argv: argv,
        );
        return false;
      }
      logger?.event(
        'pty.manager.open.resolved',
        layer: 'pty-manager',
        traceId: traceId,
        argv: resolvedArgv,
      );

      final defaultEnv = rootfsEnv(ldPreload: ldPreload);
      if (env != null) defaultEnv.addAll(env);

      final ses = await PtySession.open(
        argv: resolvedArgv,
        env: defaultEnv,
        ldPreload: ldPreload,
        rows: 24,
        cols: 80,
        logger: logger,
        traceId: traceId,
      );
      _session = ses;
      // Old _ansi should be null here (close() calls _notifyEndAndDisposeAnsi).
      // Guard for edge cases where close() partially failed.
      final oldAnsi = _ansi;
      _ansi = AnsiTerminal(rows: 24, cols: 80);
      // DA/DSR (queries de vim/tmux) → respuesta directa al PTY.
      _ansi!.onResponse = (data) => _session?.write(data);
      // OSC 52 clipboard → portapapeles Android (best-effort).
      _ansi!.onClipboard = (text) {
        try {
          Clipboard.setData(ClipboardData(text: text));
        } catch (_) {}
      };
      // ?1004 focus events → \x1b[I (gana) / \x1b[O (pierde).
      _ansi!.onFocusChange = ({required bool focused}) {
        _session?.write(focused ? '\x1b[I' : '\x1b[O');
      };
      if (oldAnsi != null) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          try {
            oldAnsi.dispose();
          } catch (_) {}
        });
      }

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
        if (_disposed || _session != ses) return; // disposed o reemplazada
        _session = null;
        _notifyEndAndDisposeAnsi();
      });

      logger?.event(
        'pty.manager.open.ok',
        layer: 'pty-manager',
        traceId: traceId,
        argv: resolvedArgv,
      );
      return true;
    } catch (e, st) {
      logger?.event(
        'pty.manager.open.error',
        layer: 'pty-manager',
        traceId: traceId,
        argv: argv,
        error: e,
        stackTrace: st,
      );
      return false;
    } finally {
      _opening = false;
    }
  }

  List<String>? _resolveExecutableArgv(List<String> argv) {
    if (argv.isEmpty) return null;
    final executable = argv.first;
    if (executable.startsWith('/')) {
      return File(executable).existsSync() ? argv : null;
    }

    final usr = rootfs?.usrDir;
    if (usr == null || usr.isEmpty) return null;
    final candidates = [
      '$usr/bin/$executable',
      '$usr/bin/applets/$executable',
      '$usr/sbin/$executable',
      '$usr/libexec/$executable',
      '$usr/../bin/$executable',
    ];
    for (final candidate in candidates) {
      if (File(candidate).existsSync()) {
        return [candidate, ...argv.skip(1)];
      }
    }
    return null;
  }

  /// Limpia el estado interno tras el fin/cierre de la sesión.
  ///
  /// El orden importa: primero se avisa al dueño (onSessionEnd → setState →
  /// desmonta AnsiTerminalView) y el dispose del AnsiTerminal se difiere a
  /// post-frame. AnsiTerminalView.dispose() hace removeListener() sobre el
  /// terminal; removeListener en un ChangeNotifier ya disposed lanza
  /// "used after being disposed". Diferir el dispose garantiza que la vista
  /// se desmonta (y remueve su listener) antes de que el terminal muera.
  void _notifyEndAndDisposeAnsi() {
    final term = _ansi;
    _ansi = null;
    logger?.event('pty.manager.session.end', layer: 'pty-manager');
    onSessionEnd?.call();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      term?.dispose();
    });
  }

  /// Close the active PTY session. Idempotent.
  Future<void> close() async {
    final pendingClose = _closeFuture;
    if (pendingClose != null) {
      await pendingClose;
      return;
    }

    final s = _session;
    if (s == null) {
      logger?.event('pty.manager.close.noop', layer: 'pty-manager');
      return;
    }
    final closeFuture = _closeActiveSession(s);
    _closeFuture = closeFuture;
    try {
      await closeFuture;
    } finally {
      if (identical(_closeFuture, closeFuture)) {
        _closeFuture = null;
      }
    }
  }

  Future<void> _closeActiveSession(PtySession s) async {
    logger?.event(
      'pty.manager.close.start',
      layer: 'pty-manager',
      data: {'sessionId': s.id},
    );
    _session = null;
    try {
      _outputSub?.cancel();
      _outputSub = null;
      _doneSub?.cancel();
      _doneSub = null;
      await s.close();
    } catch (e, st) {
      logger?.event(
        'pty.manager.close.error',
        layer: 'pty-manager',
        error: e,
        stackTrace: st,
        data: {'sessionId': s.id},
      );
    }
    _notifyEndAndDisposeAnsi();
  }

  /// Write bytes to the PTY master fd.
  void write(List<int> bytes) {
    _session?.writeBytes(bytes);
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

  /// Pausa el polling de la sesión PTY (pestaña oculta). Rate limiting:
  /// N tabs abiertas = N×20 MethodChannel calls/sec; las ocultas no deben
  /// consumir overhead.
  void pausePolling() => _session?.pausePolling();

  /// Reanuda el polling PTY (pestaña visible de nuevo). Ignorada si la
  /// sesión ya cerró o pausar nunca llegó a aplicarse.
  void resumePolling() => _session?.resumePolling();

  void dispose() {
    if (_disposed) return;
    _disposed = true;
    unawaited(close());
  }
}
