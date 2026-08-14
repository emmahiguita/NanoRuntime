import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/foundation.dart';

import 'vnc_des.dart';

/// Cliente RFB/VNC súper optimizado en Dart puro.
///
/// Protocolo implementado: RFB 3.8, Security Type None (1) y VNC Auth (2),
/// Raw encoding (0), CopyRect (1).
///
/// VNC Auth (type 2): el servidor manda un challenge de 16 bytes; el cliente
/// lo cifra con DES/ECB usando la clave derivada del password (bits invertidos
/// por byte, RFC 6143 §7.1.2) y devuelve los 16 bytes. [password] vacío =
/// solo tipo None (comportamiento previo).
///
/// Optimizaciones críticas de rendimiento:
/// 1. Buffer `Uint8List` continuo con puntero `_readPos` — cero asignaciones `sublist`
///    o desplazamientos O(N) `removeRange` sobre la lista de bytes en cada paquete.
/// 2. Lectura directa por offset en `_applyRawRect` evitando instanciación de arrays.
/// 3. Throttling de decodificación `_decodingFrame` para evitar colapsar la cola del
///    hilo rasterizador/GPU con múltiples llamadas concurrentes a `decodeImageFromPixels`.
///
/// Estabilidad de conexión:
/// 4. Heartbeat vía FramebufferUpdateRequest cada 30s — detecta caídas silenciosas
///    del socket TCP (WiFi inestable, suspensión del dispositivo, crash de Xvnc).
/// 5. Frame timeout de 60s: si no se reciben frames en 60s, se considera muerta.
class VncClient {
  final String host;
  final int port;

  /// Contraseña VNC (≤8 bytes efectivos, protocolo). Vacío = sin auth:
  /// el cliente solo acepta Security Type None. Con password, responde al
  /// challenge de VNC Auth (type 2) vía DES.
  final String password;

  Socket? _socket;
  StreamSubscription<Uint8List>? _sub;
  bool _running = false;
  bool _initialized = false;

  // Framebuffer
  int _fbWidth = 0;
  int _fbHeight = 0;
  late Uint8List _pixels; // RGBA
  String _desktopName = '';

  // Estado del parser RFB (declarados arriba: disconnect() los resetea).
  // 0=version, 1=security, 2=challenge (VNC Auth), 3=result, 4=init, 5=ready
  int _state =
      0; // 0=version, 1=security, 2=challenge, 3=result, 4=init, 5=ready
  int _msgType = 0;
  int _msgBytesNeeded = 0;
  int _colourEntriesLeft =
      0; // entradas de color por saltar (SetColourMapEntries)
  bool _decodingFrame = false;
  bool _framePending = false;
  bool _presentScheduled = false;

  // FSM incremental del FramebufferUpdate (P1 — parser TCP parcial):
  // el FBU de 3.5 MB llega en chunks TCP; el parser viejo re-leía el FBU
  // completo desde el msgType en cada chunk (re-aplicando rects Raw ya
  // aplicados y CopyRect con solape dos veces) y podía desincronizar el
  // stream si un chunk terminaba dentro del header de un rect (evidencia
  // device: "Encoding no soportado: 39173" / "Unknown msg type: 137").
  // Ahora el header del FBU se consume UNA vez y cada rect guarda su
  // estado hasta recibir su payload completo: cada byte del stream se
  // consume exactamente una vez.
  int _rectsTotal = 0;
  int _rectsProcessed = 0;
  bool _rectActive = false;
  int _rectX = 0, _rectY = 0, _rectW = 0, _rectH = 0, _rectEncoding = 0;
  int _rectDataNeeded = 0;

  // Backpressure (P0): máximo 1 FramebufferUpdateRequest en vuelo. Sin
  // esto, cualquier FBU vacío o desincronización puede regenerar el
  // ping-pong request↔FBU que saturaba el main isolate (ANR). El
  // heartbeat respeta esta bandera.
  bool _updatePending = false;

  // Callbacks
  final ValueChanged<ui.Image?>? onFrame;
  final ValueChanged<String>? onStatus;
  final VoidCallback? onDisconnected;

  // ── Heartbeat / Keepalive ──
  Timer? _heartbeatTimer;
  Timer? _presentTimer;
  DateTime _lastFrameTime = DateTime.now();
  static const _heartbeatInterval = Duration(seconds: 30);
  static const _frameTimeout = Duration(seconds: 60);
  static const _presentInterval = Duration(milliseconds: 16);

  VncClient({
    required this.host,
    required this.port,
    this.password = '',
    this.onFrame,
    this.onStatus,
    this.onDisconnected,
  });

  bool get isRunning => _running;
  bool get isInitialized => _initialized;
  int get fbWidth => _fbWidth;
  int get fbHeight => _fbHeight;
  String get desktopName => _desktopName;

  Future<bool> connect() async {
    if (_running) return true;
    try {
      _status('Conectando a $host:$port...');
      _socket = await Socket.connect(
        host,
        port,
        timeout: const Duration(seconds: 8),
      );
      _socket?.setOption(SocketOption.tcpNoDelay, true);
      // TCP keepalive no existe en dart:io SocketOption. El heartbeat RFB
      // (FramebufferUpdateRequest cada 30s + frame timeout 60s) ya detecta
      // caídas silenciosas mejor que el keepalive de SO.
      _running = true;
      _sub = _socket!.listen(
        _onData,
        onError: _onError,
        onDone: _onDone,
        cancelOnError: false,
      );
      return true;
    } catch (e) {
      _status('Error conexión: $e');
      _running = false;
      _sub?.cancel();
      _sub = null;
      _socket?.destroy();
      _socket = null;
      return false;
    }
  }

  void disconnect() {
    _running = false;
    _initialized = false;
    _stopHeartbeat();
    _sub?.cancel();
    _sub = null;
    _socket?.destroy();
    _socket = null;
    _rawBuf = Uint8List(0);
    _readPos = 0;
    _end = 0;
    _state = 0;
    _legacy33 = false;
    _msgBytesNeeded = 0;
    _colourEntriesLeft = 0;
    _decodingFrame = false;
    _framePending = false;
    _presentScheduled = false;
    _rectsTotal = 0;
    _rectsProcessed = 0;
    _rectActive = false;
    _rectDataNeeded = 0;
    _updatePending = false;
    _presentTimer?.cancel();
    _presentTimer = null;
  }

  // ── Heartbeat / Keepalive ──

  void _startHeartbeat() {
    _stopHeartbeat();
    _lastFrameTime = DateTime.now();
    _heartbeatTimer = Timer.periodic(_heartbeatInterval, (_) {
      if (!_running || !_initialized) return;
      // Enviar FramebufferUpdateRequest incremental (no dispara re-render
      // completo, solo prueba que el socket sigue vivo). Respeta la
      // backpressure: si ya hay un request en vuelo, este tick se salta.
      _requestUpdate(0, 0, _fbWidth, _fbHeight, true);
      // Verificar frame timeout: si no hemos recibido frames en 60s,
      // la conexión está muerta (Xvnc crasheó, WiFi cayó, etc.)
      if (DateTime.now().difference(_lastFrameTime) > _frameTimeout) {
        _status(
          'Heartbeat timeout — sin frames en ${_frameTimeout.inSeconds}s',
        );
        disconnect();
        onDisconnected?.call();
      }
    });
  }

  void _stopHeartbeat() {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = null;
  }

  void _schedulePresent() {
    if (!_running || !_initialized || onFrame == null) return;
    if (_presentScheduled) return;
    _presentScheduled = true;
    _presentTimer ??= Timer(_presentInterval, () {
      _presentTimer = null;
      _presentScheduled = false;
      _emitFrame();
    });
  }

  /// Envía un evento de puntero (botón + coordenadas).
  void sendPointerEvent(int x, int y, int buttonMask) {
    if (!_initialized || _socket == null || !_running) return;
    final buf = ByteData(6);
    buf.setUint8(0, 5); // pointer event
    buf.setUint8(1, buttonMask);
    buf.setUint16(2, x);
    buf.setUint16(4, y);
    _socket!.add(buf.buffer.asUint8List());
  }

  /// Envía una tecla.
  void sendKeyEvent(int keysym, bool down) {
    if (!_initialized || _socket == null || !_running) return;
    final buf = ByteData(8);
    buf.setUint8(0, 4); // key event
    buf.setUint8(1, down ? 1 : 0);
    buf.setUint16(2, 0); // padding
    buf.setUint32(4, keysym);
    _socket!.add(buf.buffer.asUint8List());
  }

  void _status(String msg) {
    debugPrint('[vnc] $msg');
    onStatus?.call(msg);
  }

  // ── RFB Protocol Buffer & Handshake ──

  Uint8List _rawBuf = Uint8List(0);
  int _readPos = 0;
  int _end = 0; // fin de datos válidos dentro de _rawBuf (capacidad ≥ _end)

  // RFB 3.3 legacy: Xvnc con -SecurityTypes None ofrece "RFB 003.003" y usa
  // el handshake viejo: U32 con el security type (no la lista de 3.7+) y sin
  // SecurityResult tras None — ServerInit llega directo.
  bool _legacy33 = false;

  int get _availableBytes => _end - _readPos;

  void _onData(Uint8List data) {
    if (!_running) return;

    // Compactar el buffer si el puntero superó 64 KB.
    // Copia REAL (no sublistView): la vista comparte el TypedData subyacente,
    // así que el buffer grande (524 KB+) seguía vivo aunque solo quedaran
    // ~2 KB útiles (B6). Además el orden viejo restaba _end ANTES de usarlo
    // como índice absoluto de la vista — con _readPos=522329 y _end=523917
    // la sublistView recibía (522329, 1588) y lanzaba RangeError.
    if (_readPos > 65536) {
      final newLen = _end - _readPos;
      final compact = Uint8List(newLen);
      compact.setRange(0, newLen, _rawBuf, _readPos);
      _rawBuf = compact;
      _readPos = 0;
      _end = newLen;
    }

    // Crecimiento amortizado (doble de capacidad). El append anterior era
    // O(N²): copiaba todo el buffer acumulado en cada chunk TCP.
    final needed = _availableBytes + data.length;
    if (needed > _rawBuf.length - _readPos) {
      var cap = _rawBuf.isEmpty ? 64 * 1024 : _rawBuf.length;
      while (cap - _readPos < needed) {
        cap *= 2;
      }
      // BUG P0 (2026-08-12): se hacía _readPos = 0 SIN re-sincronizar _end.
      // _availableBytes es un getter (_end - _readPos); tras el reset devolvía
      // el _end viejo, y el setRange final escribía desplazado: hueco de ceros
      // + pérdida de bytes del chunk → el parser leía píxeles como msg-type
      // ("Unknown msg type: 24" / "Encoding 39173") y se desconectaba SIEMPRE
      // en el primer FBU de 3.7 MB. Capturar avail ANTES del reset y re-
      // sincronizar _end deja _availableBytes consistente.
      final avail = _availableBytes; // bytes realmente válidos, antes del reset
      final newBuf = Uint8List(cap);
      newBuf.setRange(0, avail, _rawBuf, _readPos);
      _rawBuf = newBuf;
      _readPos = 0;
      _end = avail; // re-sincronizado: sin hueco ni pérdida de bytes
    }
    _rawBuf.setRange(_readPos + _availableBytes, _readPos + needed, data);
    _end = _readPos + needed;

    _process();
  }

  void _process() {
    try {
      switch (_state) {
        case 0:
          _handleVersion();
          break;
        case 1:
          _handleSecurity();
          break;
        case 2:
          _handleChallenge();
          break;
        case 3:
          _handleSecurityResult();
          break;
        case 4:
          _handleServerInit();
          break;
        case 5:
          _handleMessages();
          break;
      }
    } catch (e) {
      _status('Error protocolo: $e');
      disconnect();
      onDisconnected?.call();
    }
  }

  void _handleVersion() {
    // Server sends "RFB 003.008\n" (12 bytes)
    if (_availableBytes < 12) return;
    final version = String.fromCharCodes(
      _rawBuf.sublist(_readPos, _readPos + 11),
    );
    _status('Server: $version');
    _legacy33 = version.endsWith('003.003');
    _readPos += 12;
    // Respond with same version
    _socket?.add(version.codeUnits);
    _socket?.add([0x0a]); // \n
    _state = 1;
    _process();
  }

  void _handleSecurity() {
    if (_legacy33) {
      // RFB 3.3: el server manda U32 con el security type directo (no la
      // lista count+types de 3.7+). None = 1. Tras None NO hay SecurityResult:
      // el server manda ServerInit inmediatamente.
      if (_availableBytes < 4) return;
      final b = ByteData.sublistView(_rawBuf, _readPos, _readPos + 4);
      final secType = b.getUint32(0);
      _readPos += 4;
      if (secType == 1) {
        _state = 4; // ServerInit directo (sin SecurityResult en 3.3)
        _process();
        return;
      }
      if (secType == 2) {
        // Xvnc 3.3 puede ofrecer VNC Auth: mismo challenge que 3.8.
        _state = 2; // esperar challenge de 16 bytes
        _process();
        return;
      }
      _status('Security type 3.3 no soportado: $secType');
      disconnect();
      return;
    }
    // Server sends number of security types (1 byte) + types
    if (_availableBytes < 1) return;
    final numTypes = _rawBuf[_readPos];
    if (_availableBytes < 1 + numTypes) return;
    final types = _rawBuf.sublist(_readPos + 1, _readPos + 1 + numTypes);
    _readPos += (1 + numTypes);

    if (types.contains(1)) {
      // Security Type None
      _socket?.add([1]);
      _state = 3;
    } else if (types.contains(2)) {
      // Security Type VNC Auth: el server responde con el challenge.
      if (password.isEmpty) {
        _status('El servidor requiere contraseña VNC (no configurada)');
        disconnect();
        onDisconnected?.call();
        return;
      }
      _socket?.add([2]);
      _state = 2; // esperar challenge de 16 bytes
    } else {
      _status('Tipos seguridad no soportados: $types');
      disconnect();
      return;
    }
    _process();
  }

  /// VNC Auth: espera el challenge de 16 bytes, lo cifra con DES/ECB
  /// (clave = password con bits invertidos) y envía la respuesta.
  void _handleChallenge() {
    if (_availableBytes < 16) return;
    final challenge = Uint8List.fromList(
      _rawBuf.sublist(_readPos, _readPos + 16),
    );
    _readPos += 16;
    final key = vncAuthKey(password);
    final response = vncAuthResponse(challenge, key);
    _socket?.add(response);
    _status('VNC Auth: challenge respondido (DES)');
    _state = 3;
    _process();
  }

  void _handleSecurityResult() {
    if (_availableBytes < 4) return;
    final b = ByteData.sublistView(_rawBuf, _readPos, _readPos + 4);
    final result = b.getUint32(0);
    _readPos += 4;
    if (result != 0) {
      // RFB 3.8: tras un fallo el server manda reasonLen(4) + reason(N).
      var reason = '';
      if (!_legacy33 && _availableBytes >= 4) {
        final rb = ByteData.sublistView(_rawBuf, _readPos, _readPos + 4);
        final len = rb.getUint32(0);
        if (len > 0 && _availableBytes >= 4 + len) {
          reason = String.fromCharCodes(
            _rawBuf.sublist(_readPos + 4, _readPos + 4 + len),
          );
          _readPos += (4 + len);
        }
      }
      _status(
        reason.isNotEmpty
            ? 'Autenticación rechazada: $reason'
            : 'Security result error: $result',
      );
      disconnect();
      onDisconnected?.call();
      return;
    }
    // Send ClientInit (shared flag = 1)
    _socket?.add([1]);
    _state = 4;
    _process();
  }

  void _handleServerInit() {
    // ServerInit: fbWidth(2) fbHeight(2) pixelFormat(16) nameLength(4) name(N)
    if (_availableBytes < 24) return;

    final bb = ByteData.sublistView(_rawBuf, _readPos, _readPos + 24);
    final w = bb.getUint16(0);
    final h = bb.getUint16(2);
    final depth = _rawBuf[_readPos + 5];
    final nameLen = bb.getUint32(20);

    if (_availableBytes < 24 + nameLen) return;

    _fbWidth = w;
    _fbHeight = h;
    _desktopName = String.fromCharCodes(
      _rawBuf.sublist(_readPos + 24, _readPos + 24 + nameLen),
    );
    _readPos += (24 + nameLen);

    _pixels = Uint8List(_fbWidth * _fbHeight * 4);
    _status(
      'Framebuffer: ${_fbWidth}x$_fbHeight, depth=$depth, "$_desktopName"',
    );
    _initialized = true;
    _state = 5;

    // ClientInit (shared flag = 1): en 3.8 lo manda _handleSecurityResult,
    // pero el flujo 3.3 no tiene SecurityResult — se manda aquí.
    if (_legacy33) _socket?.add([1]);

    _startHeartbeat();
    _sendSetPixelFormat();
    _sendSetEncodings();
    // Primer FBU NO incremental: garantiza el frame completo inicial
    // (con incremental=true algunos servidores no envían nada hasta el
    // primer cambio real).
    _requestUpdate(0, 0, _fbWidth, _fbHeight, false);
    _process();
  }

  void _handleMessages() {
    while (_availableBytes > 0 && _running) {
      // Continuar saltando entradas de color de un SetColourMapEntries previo.
      // Sin esto el stream se desincronizaba: se leía el siguiente byte de
      // color como si fuera un msg-type.
      if (_colourEntriesLeft > 0) {
        if (_availableBytes < 6) return;
        _readPos += 6;
        _colourEntriesLeft--;
        continue;
      }

      if (_msgBytesNeeded == 0) {
        _msgType = _rawBuf[_readPos];
        _readPos += 1;
        switch (_msgType) {
          case 0: // FramebufferUpdate
            _msgBytesNeeded = 3; // padding(1) + numRects(2)
            break;
          case 1: // SetColourMapEntries
            _msgBytesNeeded = 5; // padding(1) + firstColour(2) + numColours(2)
            break;
          case 2: // Bell
            _msgBytesNeeded = 0;
            break;
          case 3: // ServerCutText
            _msgBytesNeeded = 7; // padding(3) + length(4)
            break;
          default:
            // Ruido de protocolo: solo logcat, no mancha el UI. Además el UI
            // debe enterarse para auto-reconectar; antes disconnect() silen-
            // cioso dejaba la pantalla zombie (_connected=true, frame=null).
            debugPrint('[vnc] Unknown msg type: $_msgType');
            disconnect();
            onDisconnected?.call();
            return;
        }
      }

      if (_msgBytesNeeded > 0 && _availableBytes < _msgBytesNeeded) return;

      switch (_msgType) {
        case 0:
          _handleFramebufferUpdate();
          break;
        case 1:
          _handleSetColourMapEntries();
          break;
        case 2:
          _msgBytesNeeded = 0;
          break;
        case 3:
          _handleServerCutText();
          break;
        default:
          _readPos += _msgBytesNeeded;
          _msgBytesNeeded = 0;
      }
      // Handlers de mensajes largos (FramebufferUpdate raw, ServerCutText)
      // hacen return sin consumir cuando el chunk TCP trae datos parciales,
      // dejando _msgBytesNeeded != 0. Sin este break el while vuelve a
      // invocarlos con los mismos bytes y sin consumir nada: giro infinito
      // síncrono que congela el isolate de UI (el primer frame de 3.7 MB
      // llega siempre en chunks y lo disparaba siempre).
      if (_msgBytesNeeded != 0) break;
    }
  }

  void _handleSetColourMapEntries() {
    // Truecolor no usa el colour map: solo consumimos el mensaje completo
    // para no desincronizar el stream. Cabecera: padding(1) + firstColour(2)
    // + numColours(2); luego N entradas de 6 bytes (r,g,b ×2).
    final bb = ByteData.sublistView(_rawBuf, _readPos, _readPos + 5);
    _colourEntriesLeft = bb.getUint16(3);
    _readPos += 5;
    _msgBytesNeeded = 0;
  }

  void _handleFramebufferUpdate() {
    // Cabecera del FBU: padding(1) + numRects(2). Se consume UNA sola vez
    // (_rectsTotal != 0 la marca consumida); los chunks siguientes entran
    // directo al rect en curso.
    if (_rectsTotal == 0) {
      if (_availableBytes < 3) {
        _msgBytesNeeded = 3;
        return;
      }
      final bb = ByteData.sublistView(_rawBuf, _readPos, _readPos + 3);
      _rectsTotal = bb.getUint16(1);
      _rectsProcessed = 0;
      _rectActive = false;
      _readPos += 3;
      _msgBytesNeeded = 0;
    }

    var offset = _readPos;

    while (_rectsProcessed < _rectsTotal && _running) {
      // Cabecera del rect: x(2) y(2) w(2) h(2) encoding(4) = 12 bytes.
      if (!_rectActive) {
        if (_end - offset < 12) {
          _readPos = offset;
          _msgBytesNeeded = 12;
          return;
        }
        final rectBb = ByteData.sublistView(_rawBuf, offset, offset + 12);
        _rectX = rectBb.getUint16(0);
        _rectY = rectBb.getUint16(2);
        _rectW = rectBb.getUint16(4);
        _rectH = rectBb.getUint16(6);
        _rectEncoding = rectBb.getInt32(8);
        offset += 12;
        _rectActive = true;
        switch (_rectEncoding) {
          case 0: // Raw
            _rectDataNeeded = _rectW * _rectH * 4;
            break;
          case 1: // CopyRect
            _rectDataNeeded = 4;
            break;
          default:
            // Ídem P0: ruido de protocolo → logcat; avisa al UI para
            // reconectar en vez de dejar la sesión zombie.
            debugPrint(
              '[vnc] Encoding no soportado: $_rectEncoding '
              '(rect ${_rectsProcessed + 1}/$_rectsTotal '
              '$_rectX,$_rectY ${_rectW}x$_rectH)',
            );
            disconnect();
            onDisconnected?.call();
            return;
        }
      }

      // Payload del rect: esperar a tenerlo completo sin consumir parcial.
      if (_end - offset < _rectDataNeeded) {
        _readPos = offset;
        _msgBytesNeeded = _rectDataNeeded;
        return;
      }

      if (_rectEncoding == 0) {
        _applyRawRect(_rectX, _rectY, _rectW, _rectH, _rawBuf, offset);
        offset += _rectDataNeeded;
      } else {
        final rectData = ByteData.sublistView(_rawBuf, offset, offset + 4);
        final srcX = rectData.getUint16(0);
        final srcY = rectData.getUint16(2);
        _applyCopyRect(_rectX, _rectY, _rectW, _rectH, srcX, srcY);
        offset += 4;
      }

      _rectsProcessed++;
      _rectActive = false;
    }

    _readPos = offset;
    _rectsTotal = 0;
    _msgBytesNeeded = 0;
    _updatePending = false; // FBU recibido completo: request respondido.

    _lastFrameTime = DateTime.now(); // heartbeat: reset frame timeout

    // P0 — ANR "Input dispatching timed out" (evidencia anr_20300, 15 ANRs
    // en device 2026-08-12): el servidor responde CADA FramebufferUpdateRequest
    // con un FBU (con 0 rects si no hay cambios), y este código respondía a
    // CADA FBU con otro request + _emitFrame del framebuffer COMPLETO
    // (copia 3.7 MB + decodeImageFromPixels). En loopback el ACK llega en
    // microsegundos: el main isolate quedaba atrapado en un ping-pong
    // FBU→emit→request→FBU→... y el evento de input del usuario nunca se
    // procesaba → am_kill a los 5s. El trace del ANR muestra el main en
    // write() desde [anon:dart-code] (el socket.add del request) y
    // RssHwm 525 MB (imágenes de 3.7 MB acumuladas).
    //
    // Regla nueva: FBU con 0 rects = ACK del server, NO genera request
    // nuevo ni emit. El siguiente update lo pide el heartbeat (30s) o el
    // próximo FBU con rects reales (que re-pide al final). Así el flujo
    // queda: cambios → FBU → emit → request → (silencio hasta el próximo
    // cambio o heartbeat), y el input siempre encuentra el event loop libre.
    if (_rectsProcessed == 0) return;

    _schedulePresent();
    // Incremental=true tras cada frame. Antes pedía NO incremental, y Xvnc
    // reenviaba el framebuffer COMPLETO (3.6 MB por frame) — causa directa
    // del lag en el visor.
    _requestUpdate(0, 0, _fbWidth, _fbHeight, true);
  }

  void _applyRawRect(int x, int y, int w, int h, Uint8List src, int srcOffset) {
    var di = srcOffset;
    for (var row = 0; row < h; row++) {
      var dst = ((y + row) * _fbWidth + x) * 4;
      for (var col = 0; col < w; col++) {
        _pixels[dst] = src[di + 2]; // R
        _pixels[dst + 1] = src[di + 1]; // G
        _pixels[dst + 2] = src[di]; // B
        _pixels[dst + 3] = 255; // A
        dst += 4;
        di += 4;
      }
    }
  }

  void _applyCopyRect(int dstX, int dstY, int w, int h, int srcX, int srcY) {
    // CopyRect puede solaparse (scroll de ventana). La copia anterior
    // iteraba siempre hacia delante y corrompía los datos cuando src < dst
    // en la misma región — efecto memmove sin manejo de solape.
    final forward = (srcY > dstY) || (srcY == dstY && srcX > dstX);
    if (forward) {
      for (var row = 0; row < h; row++) {
        final srcIdx = ((srcY + row) * _fbWidth + srcX) * 4;
        final dstIdx = ((dstY + row) * _fbWidth + dstX) * 4;
        _pixels.setRange(dstIdx, dstIdx + w * 4, _pixels, srcIdx);
      }
    } else {
      // src < dst: iterar hacia atrás (filas y bytes) como memmove.
      for (var row = h - 1; row >= 0; row--) {
        final srcIdx = ((srcY + row) * _fbWidth + srcX) * 4;
        final dstIdx = ((dstY + row) * _fbWidth + dstX) * 4;
        for (var i = w * 4 - 1; i >= 0; i--) {
          _pixels[dstIdx + i] = _pixels[srcIdx + i];
        }
      }
    }
  }

  void _handleServerCutText() {
    if (_availableBytes < 7) return;
    final bb = ByteData.sublistView(_rawBuf, _readPos, _readPos + 7);
    final len = bb.getUint32(3);
    if (_availableBytes < 7 + len) return;
    _readPos += (7 + len);
    _msgBytesNeeded = 0;
  }

  void _sendSetPixelFormat() {
    if (_socket == null || !_running) return;
    final buf = ByteData(20);
    buf.setUint8(0, 0); // msg type = SetPixelFormat
    buf.setUint8(4, 32); // bpp
    buf.setUint8(5, 24); // depth
    buf.setUint8(6, 0); // little-endian
    buf.setUint8(7, 1); // true color
    buf.setUint16(8, 255); // red max
    buf.setUint16(10, 255); // green max
    buf.setUint16(12, 255); // blue max
    buf.setUint8(14, 16); // red shift
    buf.setUint8(15, 8); // green shift
    buf.setUint8(16, 0); // blue shift
    _socket!.add(buf.buffer.asUint8List());
  }

  void _sendSetEncodings() {
    if (_socket == null || !_running) return;
    final buf = ByteData(4 + 2 * 4);
    buf.setUint8(0, 2); // msg type = SetEncodings
    buf.setUint16(2, 2); // 2 encodings
    buf.setInt32(4, 0, Endian.big); // Raw
    buf.setInt32(8, 1, Endian.big); // CopyRect
    _socket!.add(buf.buffer.asUint8List());
  }

  void _requestUpdate(int x, int y, int w, int h, bool incremental) {
    if (_socket == null || !_running) return;
    // Backpressure: nunca más de 1 request sin responder.
    if (_updatePending) return;
    _updatePending = true;
    final buf = ByteData(10);
    buf.setUint8(0, 3); // FramebufferUpdateRequest
    buf.setUint8(1, incremental ? 1 : 0);
    buf.setUint16(2, x);
    buf.setUint16(4, y);
    buf.setUint16(6, w);
    buf.setUint16(8, h);
    _socket!.add(buf.buffer.asUint8List());
  }

  Future<void> _emitFrame() async {
    if (!_initialized || _fbWidth == 0 || onFrame == null || !_running) return;
    if (_decodingFrame) {
      _framePending = true;
      return;
    }
    _decodingFrame = true;
    try {
      // Copia defensiva: decodeImageFromPixels es async y el hilo de red
      // puede mutar _pixels durante la decodificación (frames rasgados,
      // mitad frame viejo / mitad nuevo). Una copia por frame emitido es
      // despreciable frente al coste del decode.
      final snapshot = Uint8List.fromList(_pixels);
      final completer = Completer<ui.Image>();
      // VNC-5: si el decode cuelga y el timeout dispara, decodeImageFromPixels
      // puede IGUAL entregar la imagen después (callback tardío). Future.timeout
      // NO completa el completer subyacente, así que nadie espera ese callback
      // y el bitmap nativo (3.7 MB) quedaba huérfano en memoria. `timedOut`
      // hace que el callback tardío libere la imagen en vez de completar un
      // future ya abandonado.
      var timedOut = false;
      ui.decodeImageFromPixels(
        snapshot,
        _fbWidth,
        _fbHeight,
        ui.PixelFormat.rgba8888,
        (image) {
          if (timedOut) {
            image.dispose();
          } else {
            completer.complete(image);
          }
        },
        rowBytes: _fbWidth * 4,
        targetWidth: _fbWidth,
        targetHeight: _fbHeight,
        allowUpscaling: false,
      );
      final img = await completer.future.timeout(
        const Duration(seconds: 5),
        onTimeout: () {
          timedOut = true;
          throw TimeoutException('decodeImageFromPixels hung');
        },
      );
      if (_running) {
        onFrame?.call(img);
      } else {
        // Sesión ya muerta: liberar el bitmap nativo (3.7 MB) de inmediato —
        // antes quedaba huérfano en memoria.
        img.dispose();
      }
    } catch (e) {
      _status('Error decodificando frame: $e');
    } finally {
      _decodingFrame = false;
      if (_framePending && _running) {
        _framePending = false;
        _schedulePresent();
      }
    }
  }

  void _onError(dynamic error) {
    _status('Socket error: $error');
    disconnect();
    onDisconnected?.call();
  }

  void _onDone() {
    _status('Conexión cerrada por el servidor');
    disconnect();
    onDisconnected?.call();
  }
}
