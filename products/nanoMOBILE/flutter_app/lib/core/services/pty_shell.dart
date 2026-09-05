import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'nano_runtime_api.dart';
import 'terminal_audit_logger.dart';

/// Interfaz PTY para terminales interactivos (vim, htop, python, bash -i).
///
/// Envuelve el MethodChannel `com.nanoai/pty` que habla con libnanoshell.so
/// vía JNI (NanoshellBridge.kt). El C hace openpty + fork + dlopen del binario
/// en el hijo (bypass SELinux igual que nanoshell.c), pero con un pseudo-tty
/// real: isatty()==true, raw mode, control de jobs, resize y señales.
///
/// Uso:
/// ```dart
/// final ses = await PtySession.open(
///   argv: [bashPath, '-i'],
///   env: {'NANO_ROOTFS': '...'},
///   ldPreload: 'libnanoroot.so',
///   rows: 24, cols: 80,
/// );
/// ses.output.listen((bytes) => pintarTerminal(bytes));
/// ses.write('ls\n');
/// ses.resize(30, 100);
/// ses.close();
/// ```
class PtySession {
  static NanoRuntimeApi get _runtime => NanoRuntimeApi.instance;

  final int _id;
  final StreamController<Uint8List> _out = StreamController.broadcast();
  final StreamController<void> _done = StreamController.broadcast();
  Timer? _poll;
  bool _closed = false;
  bool _inFlight = false;
  int _lastAlive = 1;
  final TerminalAuditLogger? _logger;
  final String? _traceId;

  PtySession._(this._id, this._logger, this._traceId);

  /// Apertura de una sesión PTY ejecutando `argv[0]` como binario.
  ///
  /// [env] opcional: pares clave→valor. [ldPreload] opcional:
  /// "libnanoroot.so" para activar fakechroot en el hijo.
  /// [rows]/[cols] tamaño inicial (24x80 por defecto).
  static Future<PtySession> open({
    required List<String> argv,
    Map<String, String>? env,
    String? ldPreload,
    int rows = 24,
    int cols = 80,
    TerminalAuditLogger? logger,
    String? traceId,
  }) async {
    _validateSize(rows, cols);
    logger?.event(
      'pty.spawn.start',
      layer: 'pty',
      traceId: traceId,
      argv: argv,
      data: {'rows': rows, 'cols': cols, 'ldPreload': ldPreload ?? ''},
    );
    final sw = Stopwatch()..start();
    final id = await _runtime.ptySpawn(
      argv: argv,
      envp: env ?? const {},
      ldPreload: ldPreload,
      rows: rows,
      cols: cols,
    );
    if (id == null || id == 0) {
      throw StateError('ptySpawn falló (argv=${argv.join(" ")})');
    }
    final s = PtySession._(id.toInt(), logger, traceId);
    logger?.event(
      'pty.spawn.done',
      layer: 'pty',
      traceId: traceId,
      argv: argv,
      data: {'id': id, 'elapsedMs': sw.elapsedMilliseconds},
    );
    try {
      s._startPolling();
    } catch (_) {
      // _startPolling may fail (Timer.periodic in OOM edge case).
      // Close controllers to avoid leak, then rethrow.
      logger?.event(
        'pty.poll.start_error',
        layer: 'pty',
        traceId: traceId,
        argv: argv,
      );
      s._closeSync();
      rethrow;
    }
    return s;
  }

  static void _validateSize(int rows, int cols) {
    if (rows < 1 || rows > 200) {
      throw RangeError.range(rows, 1, 200, 'rows');
    }
    if (cols < 1 || cols > 400) {
      throw RangeError.range(cols, 1, 400, 'cols');
    }
  }

  int get id => _id;
  Stream<Uint8List> get output => _out.stream;
  Stream<void> get done => _done.stream;
  bool get isClosed => _closed;

  void _startPolling() {
    // 50ms → 20 polls/sec/session. Reducido de 20ms (50/sec) para bajar
    // overhead de MethodChannel. PTY interactivo con 50ms sigue siendo
    // responsivo (<1 frame a 60fps). Ver auditoría 2026-08-08.
    const interval = Duration(milliseconds: 50);
    _poll ??= Timer.periodic(interval, (_) => _pollOnce());
  }

  /// Pausa el polling — pestaña no visible (rate limiting).
  ///
  /// N pestañas abiertas = N × 20 MethodChannel calls/sec aunque el usuario
  /// solo vea una. Cancelar el timer de las ocultas reduce el overhead a
  /// 20/sec en la activa + 1 `ptyRead` residual por pestaña al re-activar.
  /// Idempotente.
  void pausePolling() {
    _poll?.cancel();
    _poll = null;
  }

  /// Reanuda el polling tras pausar (pestaña visible de nuevo).
  /// Idempotente — no crea timers duplicados.
  void resumePolling() {
    if (_closed || _poll != null) return;
    _startPolling();
  }

  /// Polling serializado: flag _inFlight evita que dos invocaciones async
  /// del timer se solapen y escriban en stream controllers ya cerrados.
  Future<void> _pollOnce() async {
    if (_closed || _inFlight) return;
    _inFlight = true;
    try {
      // Lectura en batch hasta vaciar el buffer PTY (max 8 leídas por tic).
      for (var i = 0; i < 8; i++) {
        if (_closed) break;
        try {
          final data = await _runtime.ptyRead(_id);
          if (_closed) break;
          if (data == null || data.isEmpty) break;
          if (!_out.isClosed) _out.add(data);
          _logger?.event(
            'pty.read.bytes',
            layer: 'pty',
            traceId: _traceId,
            byteCount: data.length,
            data: {'sessionId': _id},
          );
        } catch (e, st) {
          _logger?.event(
            'pty.read.error',
            layer: 'pty',
            traceId: _traceId,
            error: e,
            stackTrace: st,
            data: {'sessionId': _id},
          );
          break;
        }
      }
      // Detección de final: el proceso hijo terminó.
      if (_closed) return;
      if (_lastAlive == 1) {
        try {
          final alive = await _runtime.ptyIsAlive(_id);
          if (_closed) return;
          _lastAlive = alive;
          if (alive == 0) {
            _logger?.event(
              'pty.done',
              layer: 'pty',
              traceId: _traceId,
              data: {'sessionId': _id},
            );
            _closed = true;
            _poll?.cancel();
            // TER-24: fin natural de sesión (exit/Ctrl-D) debe liberar el
            // slot nativo del registry (máx 8) y el master fd — antes solo
            // se cerraban los controllers Dart y cada sesión terminada
            // filtraba un slot; tras ~7 exits todo pty nuevo fallaba.
            try {
              await _runtime.ptyClose(_id);
            } catch (e, st) {
              _logger?.event(
                'pty.close.error',
                layer: 'pty',
                traceId: _traceId,
                error: e,
                stackTrace: st,
                data: {'sessionId': _id},
              );
            }
            if (!_out.isClosed) _out.close();
            if (!_done.isClosed) {
              _done.add(null);
              _done.close();
            }
          }
        } catch (e, st) {
          _logger?.event(
            'pty.alive.error',
            layer: 'pty',
            traceId: _traceId,
            error: e,
            stackTrace: st,
            data: {'sessionId': _id},
          );
        }
      }
    } finally {
      _inFlight = false;
    }
  }

  /// Envía bytes (input del usuario) al PTY.
  Future<int> write(String text) => writeBytes(utf8.encode(text));

  Future<int> writeBytes(List<int> bytes) async {
    if (_closed) return 0;
    _logger?.event(
      'pty.write.start',
      layer: 'pty',
      traceId: _traceId,
      byteCount: bytes.length,
      data: {'sessionId': _id},
    );
    final written = await _runtime.ptyWrite(_id, Uint8List.fromList(bytes));
    _logger?.event(
      'pty.write.ok',
      layer: 'pty',
      traceId: _traceId,
      byteCount: written,
      data: {'sessionId': _id},
    );
    return written;
  }

  /// Cambia el tamaño de la ventana del PTY.
  Future<void> resize(int rows, int cols) async {
    if (_closed) return;
    _validateSize(rows, cols);
    await _runtime.ptyResize(_id, rows, cols);
    _logger?.event(
      'pty.resize.ok',
      layer: 'pty',
      traceId: _traceId,
      data: {'sessionId': _id, 'rows': rows, 'cols': cols},
    );
  }

  /// Envía una señal (por defecto SIGINT) al proceso hijo.
  Future<void> signal([int sig = 2]) async {
    if (_closed) return;
    await _runtime.ptyKill(_id, signal: sig);
    _logger?.event(
      'pty.signal.ok',
      layer: 'pty',
      traceId: _traceId,
      data: {'sessionId': _id, 'signal': sig},
    );
  }

  /// Synchronous cleanup of Dart-side controllers. Used when _startPolling()
  /// fails — the native PTY session was already created (we have the id) but
  /// polling never started. No async MethodChannel call needed.
  void _closeSync() {
    if (_closed) return;
    _closed = true;
    _poll?.cancel();
    if (!_out.isClosed) _out.close();
    if (!_done.isClosed) {
      _done.add(null);
      _done.close();
    }
  }

  /// Cierra la sesión PTY y libera el fd master.
  Future<void> close() async {
    if (_closed) return;
    _closed = true;
    _poll?.cancel();
    try {
      await _runtime.ptyClose(_id);
      _logger?.event(
        'pty.close.ok',
        layer: 'pty',
        traceId: _traceId,
        data: {'sessionId': _id},
      );
    } catch (e, st) {
      _logger?.event(
        'pty.close.error',
        layer: 'pty',
        traceId: _traceId,
        error: e,
        stackTrace: st,
        data: {'sessionId': _id},
      );
    }
    if (!_out.isClosed) {
      _out.close();
    }
    // Signal completion and clean up _done stream — must match _pollOnce behavior.
    // Without this, manual close() leaks the broadcast controller and its listeners.
    if (!_done.isClosed) {
      _done.add(null);
      _done.close();
    }
  }
}
