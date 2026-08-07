import 'dart:async';
import 'dart:convert';
import 'package:flutter/services.dart';

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
  static const ch = MethodChannel('com.nanoai/pty');

  final int _id;
  final StreamController<Uint8List> _out = StreamController.broadcast();
  final StreamController<void> _done = StreamController.broadcast();
  Timer? _poll;
  bool _closed = false;
  int _lastAlive = 1;

  PtySession._(this._id);

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
  }) async {
    final id = await (ch.invokeMethod<num?>(
      'ptySpawn',
      {
        'argv': argv,
        'envp': env ?? const {},
        'ldPreload': ldPreload,
        'rows': rows,
        'cols': cols,
      },
    ));
    if (id == null || id == 0) {
      throw StateError('ptySpawn falló (argv=${argv.join(" ")})');
    }
    final s = PtySession._(id.toInt());
    s._startPolling();
    return s;
  }

  int get id => _id;
  Stream<Uint8List> get output => _out.stream;
  Stream<void> get done => _done.stream;
  bool get isClosed => _closed;

  void _startPolling() {
    const interval = Duration(milliseconds: 20);
    _poll = Timer.periodic(interval, (_) => _pollOnce());
  }

  Future<void> _pollOnce() async {
    if (_closed) return;
    // Lectura en batch hasta vaciar el buffer PTY (max 8 leidas por tic).
    for (var i = 0; i < 8; i++) {
      try {
        final data = await ch.invokeMethod<Uint8List?>(
          'ptyRead',
          {'id': _id, 'maxBytes': 4096},
        );
        if (data == null || data.isEmpty) break;
        _out.add(data);
      } catch (_) {
        break;
      }
    }
    // Detección de final: el proceso hijo terminó.
    if (_lastAlive == 1) {
      try {
        final alive = await ch.invokeMethod<int>('ptyIsAlive', {'id': _id});
        _lastAlive = alive ?? 1;
        if (alive == 0) {
          _closed = true;
          _poll?.cancel();
          _out.close();
          _done.add(null);
          _done.close();
        }
      } catch (_) {}
    }
  }

  /// Envía bytes (input del usuario) al PTY.
  Future<int> write(String text) => writeBytes(utf8.encode(text));

  Future<int> writeBytes(List<int> bytes) async {
    if (_closed) return 0;
    return await ch.invokeMethod<int>(
      'ptyWrite',
      {'id': _id, 'data': Uint8List.fromList(bytes)},
    ) ?? 0;
  }

  /// Cambia el tamaño de la ventana del PTY.
  Future<void> resize(int rows, int cols) async {
    if (_closed) return;
    await ch.invokeMethod('ptyResize', {
      'id': _id, 'rows': rows, 'cols': cols,
    });
  }

  /// Envía una señal (por defecto SIGINT) al proceso hijo.
  Future<void> signal([int sig = 2]) async {
    if (_closed) return;
    await ch.invokeMethod('ptyKill', {'id': _id, 'signal': sig});
  }

  /// Cierra la sesión PTY y libera el fd master.
  Future<void> close() async {
    if (_closed) return;
    _closed = true;
    _poll?.cancel();
    try { await ch.invokeMethod('ptyClose', {'id': _id}); } catch (_) {}
    if (!_out.isClosed) { _out.close(); }
  }
}