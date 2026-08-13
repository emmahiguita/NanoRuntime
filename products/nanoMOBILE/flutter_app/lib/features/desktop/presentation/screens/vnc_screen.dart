import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:nanoai/core/providers/app_providers.dart';
import 'package:nanoai/core/services/package_service.dart';
import 'package:nanoai/core/services/rootfs_manager.dart';
import 'package:nanoai/core/theme/design_tokens.dart';
import 'package:nanoai/features/desktop/vnc_client.dart';

/// Visor VNC interactivo para el escritorio Linux.
///
/// Estabilidad de conexión:
/// 1. Handshake RFB 3.8 + decodificación zero-copy sin congelamientos de UI.
/// 2. Auto-arranque resiliente: Si VNC no está activo, lanza startDesktop().
/// 3. Reconexión automática con exponential backoff (1s → 2s → 4s → 8s → 16s → 30s).
///    Máximo 7 intentos. Tras agotarlos, muestra botón manual.
/// 4. Heartbeat del cliente VNC detecta caídas silenciosas del socket.
/// 5. Control flotante con teclado táctil integrado (envía keysyms a Xvnc para xterm).
/// 6. Gestos profesionales: touch directo en zona superior, touchpad inferior
///    (arrastre = mover cursor sin clic, tap = clic), pinch 2 dedos = zoom
///    anclado al foco, pan 2 dedos con zoom activo, barra de clics de mouse.
class VncScreen extends ConsumerStatefulWidget {
  final int port;
  const VncScreen({super.key, this.port = 5901});

  @override
  ConsumerState<VncScreen> createState() => _VncScreenState();
}

enum _ConnState { connecting, connected, reconnecting, failed }

enum _GestureMode { none, touch, touchpad, pinch }

class _VncScreenState extends ConsumerState<VncScreen> {
  final RootfsManager _rootfs = RootfsManager.instance;
  final PackageService _pkg = const PackageService();

  VncClient? _client;
  ui.Image? _frame;

  int get port => widget.port;
  bool _busy = false;
  bool _connected = false;
  bool _initialized = false;
  bool _showKeyboard = false;
  String _status = 'Comprobando servicio VNC';
  String _detail = '';

  // ── Panel lateral + overlay de ayuda ──
  bool _showPanel = false;
  bool _showHelp = false;
  bool _helpDismissed = false; // ya visto/cerrado en esta sesión
  bool _helpSeen = false; // flag persistente (SharedPreferences)

  // ── Reconexión automática ──
  _ConnState _connState = _ConnState.connecting;
  int _reconnectAttempts = 0;
  Timer? _reconnectTimer;
  static const _maxReconnectAttempts = 7;

  int _fbWidth = 0;
  int _fbHeight = 0;
  Offset? _lastPanFb; // última posición fb del drag (para soltar al final)

  // ── Zoom / pan profesional (pinch 2 dedos) ──
  // _zoom: escala adicional sobre el fit (1.0 = ajuste a pantalla, máx 4.0).
  // _panFb: desplazamiento del viewport en unidades de framebuffer.
  double _zoom = 1.0;
  Offset _panFb = Offset.zero;
  static const double _maxZoom = 4.0;

  // ── Touchpad inferior (cursor relativo profesional) ──
  // Fracción inferior de la pantalla que actúa como touchpad: arrastre
  // mueve el puntero SIN hacer clic; tap = clic izquierdo en el cursor.
  static const double _touchpadZoneFraction = 0.28;
  Offset _cursorFb = Offset.zero; // posición virtual del puntero (fb coords)

  // Estado del gesto en curso (un único recognizer onScale maneja 1 y 2 dedos).
  _GestureMode _gestureMode = _GestureMode.none;
  int _activeMask = 0; // máscara de botones RFB activa (1=izq, 4=der)
  Offset _dragTotal = Offset.zero; // para distinguir tap de arrastre
  double _zoomAtGestureStart = 1.0;
  Offset _panAtGestureStart = Offset.zero;
  Offset _pinchStartFocal = Offset.zero;

  final FocusNode _keyboardFocus = FocusNode();
  final TextEditingController _keyboardInput = TextEditingController();

  int _connectToken = 0; // in-flight token: cancela connects stale

  @override
  void initState() {
    super.initState();
    _detail = 'Conectando a 127.0.0.1:$port vía RFB 3.8.';
    // Cargar settings persistidos (tema, password VNC) — sin esto, en frío
    // el password volvía a '' y el visor no podía autenticarse.
    ref.read(settingsProvider.notifier).init();
    SharedPreferences.getInstance().then((prefs) {
      final seen = prefs.getBool(_helpSeenKey) ?? false;
      if (mounted) setState(() => _helpSeen = seen);
    });
    _connect();
  }

  static const _helpSeenKey = 'vnc_help_seen_v1';

  @override
  void dispose() {
    _reconnectTimer?.cancel();
    _client?.disconnect();
    _frame?.dispose();
    _keyboardFocus.dispose();
    _keyboardInput.dispose();
    super.dispose();
  }

  // ── Reconexión con exponential backoff ──

  void _scheduleReconnect() {
    if (!mounted) return;
    _reconnectTimer?.cancel();
    if (_reconnectAttempts >= _maxReconnectAttempts) {
      setState(() {
        _connState = _ConnState.failed;
        _busy = false;
        _connected = false;
        _status = 'Conexión perdida';
        _detail = 'Agotados $_maxReconnectAttempts intentos. '
            'Verifica que el escritorio esté iniciado y toca Reconectar.';
      });
      return;
    }
    _reconnectAttempts++;
    // Exponential backoff: 1s, 2s, 4s, 8s, 16s, 30s, 30s
    final seconds = math.min(math.pow(2, _reconnectAttempts - 1).toInt(), 30);
    if (mounted) {
      setState(() {
        _connState = _ConnState.reconnecting;
        _busy = true;
        _status = 'Reconectando en ${seconds}s';
        _detail = 'Intento $_reconnectAttempts/$_maxReconnectAttempts. '
            'Esperando ${seconds}s antes de reintentar...';
      });
    }
    _reconnectTimer = Timer(Duration(seconds: seconds), () {
      if (mounted) _connect();
    });
  }

  void _onClientDisconnected() {
    if (!mounted) return;
    _scheduleReconnect();
  }

  Future<void> _connect() async {
    if (_busy && _connState == _ConnState.connecting) return;
    final token = ++_connectToken;
    _reconnectTimer?.cancel();
    _client?.disconnect();

    if (!mounted || token != _connectToken) return;

    // Asegurar que el password VNC persistido ya se cargó (ruta launcher →
    // visor sin pasar por Ajustes; init() es idempotente y barato).
    await ref.read(settingsProvider.notifier).init();
    if (!mounted || token != _connectToken) return;

    final isReconnecting = _connState == _ConnState.reconnecting;
    setState(() {
      _busy = true;
      _connected = false;
      _initialized = false;
      _connState = _ConnState.connecting;
      if (!isReconnecting) {
        _frame = null;
      }
      _status = 'Conectando a Xvnc...';
      _detail = 'Negociando protocolo RFB 3.8 con 127.0.0.1:$port.';
    });

    // VNC-6: raza stale-client. El onDone/onError de un socket viejo puede
    // llegar DESPUÉS de crear un cliente nuevo (_connect() reemplaza _client).
    // Antes onDisconnected era una referencia directa a _onClientDisconnected
    // y un onDone stale disparaba _scheduleReconnect → _connect() → que
    // desconectaba el cliente NUEVO (bucle). El guard `identical(_client,
    // client)` descarta callbacks de clientes ya reemplazados.
    late final VncClient client;
    client = VncClient(
      host: '127.0.0.1',
      port: widget.port,
      // Password VNC persistido en Ajustes → Escritorio. Vacío = sin auth.
      password: ref.read(settingsProvider).vncPassword,
      onStatus: (String msg) {
        if (mounted) setState(() => _detail = msg);
      },
      onFrame: (ui.Image? img) {
        // Frame de un cliente stale no debe pintarse sobre el cliente nuevo.
        if (!identical(_client, client)) {
          img?.dispose();
          return;
        }
        // Si el widget ya se desmontó (UI salió a otra pantalla), el bitmap
        // (3.7 MB) se libera al instante — antes quedaba huérfano en memoria
        // nativa hasta el GC.
        if (!mounted || img == null) {
          img?.dispose();
          return;
        }
        final prev = _frame;
        setState(() {
          _frame = img;
          if (_fbWidth == 0) {
            // Primer frame: puntero virtual al centro del escritorio.
            _cursorFb = Offset(client.fbWidth / 2, client.fbHeight / 2);
          }
          _fbWidth = client.fbWidth;
          _fbHeight = client.fbHeight;
          _initialized = client.isInitialized;
        });
        // P2-7: el ui.Image anterior NUNCA se liberaba. Cada frame nuevo
        // (1280x720x4 ≈ 3.7 MB) acumulaba bitmap nativo → GC thrash →
        // ANR "Input dispatching timed out" al tocar tras ~2 min de uso
        // (evidencia device 2026-08-12, anr_17967/18164/18614).
        // Dispose diferido 1 frame: el raster puede aún estar pintando
        // la imagen vieja; liberarla ahí crashea el raster thread.
        if (prev != null) {
          WidgetsBinding.instance.addPostFrameCallback((_) => prev.dispose());
        }
      },
      onDisconnected: () {
        if (identical(_client, client)) _onClientDisconnected();
      },
    );
    _client = client;

    var ok = await _client!.connect();
    if (!mounted || token != _connectToken) return;

    // AUTO-ARRANQUE RESILIENTE: Si la conexión TCP falla (Xvnc no activo), lanzamos Xvnc desde la app
    if (!ok) {
      if (mounted) {
        setState(() {
          _status = 'Iniciando servidor VNC...';
          _detail = 'Arrancando Xvnc y Openbox en loopback...';
        });
      }
      try {
        final started = await _ensureDesktopStarted();
        if (!mounted || token != _connectToken) return;
        if (started && mounted) {
          await Future.delayed(const Duration(milliseconds: 800));
          ok = await _client!.connect();
          if (!mounted || token != _connectToken) return;
        }
      } catch (e) {
        debugPrint('[vnc_screen] Auto-start VNC error: $e');
      }
    }

    // Esperar handshake RFB completo (ServerInit)
    if (ok) {
      var waited = 0;
      while (mounted &&
          _client != null &&
          !_client!.isInitialized &&
          waited < 40) {
        await Future.delayed(const Duration(milliseconds: 100));
        waited++;
      }
    }

    if (!mounted || token != _connectToken) return;

    if (mounted) {
      final isConnected = ok && (_client?.isInitialized ?? false);
      setState(() {
        _busy = false;
        _connected = isConnected;
        _initialized = _client?.isInitialized ?? false;
        if (isConnected) {
          _reconnectAttempts = 0; // reset backoff on success
          _connState = _ConnState.connected;
          _status = 'Escritorio Linux Activo';
          _detail =
              '${_client!.fbWidth}x${_client!.fbHeight} — "${_client!.desktopName}"';
        } else if (ok) {
          _status = 'Handshake incompleto';
          _detail = 'Conectado pero ServerInit no recibido.';
          // VNC-2: el Timer de 2s reintentaba SIN incrementar
          // _reconnectAttempts → retry infinito sin tope de 7. El handshake
          // puede completar tarde, pero tras N intentos hay que rendirse y
          // mostrar el estado failed (no loopear para siempre).
          _reconnectAttempts++;
          if (_reconnectAttempts >= _maxReconnectAttempts) {
            _scheduleReconnect(); // detecta el tope y pinta failed
            return;
          }
          _reconnectTimer = Timer(const Duration(seconds: 2), () {
            if (mounted && _client != null && !_client!.isInitialized) {
              _connect();
            }
          });
        } else {
          _status = 'VNC no responde';
          _detail = 'No se pudo abrir el canal VNC en 127.0.0.1:$port.';
          _scheduleReconnect();
        }
      });
    }
  }

  Future<bool> _ensureDesktopStarted() async {
    if (mounted) {
      setState(() {
        _status = 'Preparando Linux...';
        _detail = 'Verificando rootfs antes de lanzar Xvnc.';
      });
    }

    var rootfsReady = await _rootfs.checkInstalled();
    if (!rootfsReady) {
      if (mounted) {
        setState(() {
          _status = 'Instalando rootfs Linux...';
          _detail = 'Descargando y extrayendo bootstrap Termux.';
        });
      }
      rootfsReady = await _rootfs.install();
    }
    if (!mounted) return false;
    if (!rootfsReady) {
      setState(() {
        _status = 'Rootfs no instalado';
        _detail =
            'No se pudo preparar Linux. Revisa red, almacenamiento y logcat.';
      });
      return false;
    }

    // VNC-7: antes se llamaba installGraphical() INCONDICIONAL en cada
    // reconexión (dpkg + extract + postinst sobre un rootfs ya instalado).
    // Ahora solo instala si el status reporta que falta algo — mismo gate
    // que desktop_launch_screen (statusBefore.installed/graphicalExtras).
    final statusBefore = await _pkg.getDesktopStatus();
    if (!mounted) return false;
    if (!statusBefore.installed || !statusBefore.graphicalExtras) {
      setState(() {
        _status = 'Preparando entorno gráfico...';
        _detail = 'Validando/instalando Xvnc, Openbox, xterm y XKB.';
      });
      final graphicalReady = await _pkg.installGraphical();
      if (!mounted) return false;
      if (!graphicalReady) {
        setState(() {
          _status = 'Entorno gráfico incompleto';
          _detail =
              'No se pudo instalar Xvnc/Openbox. Revisa logcat: exec_bin y vnc-service.';
        });
        return false;
      }
    }

    setState(() {
      _status = 'Iniciando servidor VNC...';
      _detail = 'Arrancando Xvnc y Openbox en 127.0.0.1:$port.';
    });
    final started = await _pkg.startDesktop(
      vncPassword: ref.read(settingsProvider).vncPassword,
    );
    if (!mounted) return false;
    if (!started) {
      setState(() {
        _status = 'Xvnc no arrancó';
        _detail = 'El servicio VNC devolvió error. Revisa logcat: vnc-service.';
      });
      return false;
    }
    return true;
  }

  /// Escala de ajuste (fit) actual: la menor entre ancho y alto para que el
  /// framebuffer completo sea visible sin recorte. null si aún no hay tamaño.
  double? _fitScale(Size widgetSize) {
    if (!_initialized || _fbWidth == 0 || _fbHeight == 0) return null;
    final scaleX = widgetSize.width / _fbWidth;
    final scaleY = widgetSize.height / _fbHeight;
    return scaleX < scaleY ? scaleX : scaleY;
  }

  /// Convierte coordenadas locales del widget a coordenadas del framebuffer
  /// X11 aplicando fit + zoom + pan actuales.
  Offset? _localToFb(Offset local, Size widgetSize) {
    final fit = _fitScale(widgetSize);
    if (fit == null) return null;

    final scale = fit * _zoom;
    final baseX = (widgetSize.width - _fbWidth * scale) / 2 + _panFb.dx * scale;
    final baseY = (widgetSize.height - _fbHeight * scale) / 2 + _panFb.dy * scale;

    final fbX = (local.dx - baseX) / scale;
    final fbY = (local.dy - baseY) / scale;

    if (fbX < 0 || fbY < 0 || fbX >= _fbWidth || fbY >= _fbHeight) {
      return null;
    }
    return Offset(fbX, fbY);
  }

  /// Limita el pan para que el viewport nunca salga del framebuffer.
  /// Con zoom <= 1 el contenido cabe entero: pan siempre cero (centrado).
  Offset _clampPan(Offset p) {
    if (_zoom <= 1.0) return Offset.zero;
    final maxX = (_fbWidth * _zoom - _fbWidth) / 2;
    final maxY = (_fbHeight * _zoom - _fbHeight) / 2;
    return Offset(
      p.dx.clamp(-maxX, maxX),
      p.dy.clamp(-maxY, maxY),
    );
  }

  /// Pan (en fb units) para que el punto [localFocal] siga apuntando al
  /// mismo píxel del framebuffer tras cambiar el zoom — zoom anclado al
  /// foco del pinch, como un visor de imágenes profesional.
  Offset _panForZoomAround(
    Offset localFocal,
    double oldZoom,
    Offset oldPan,
    double newZoom,
    Size ws,
  ) {
    final fit = _fitScale(ws);
    if (fit == null) return Offset.zero;
    final oldScale = fit * oldZoom;
    final baseX = (ws.width - _fbWidth * oldScale) / 2 + oldPan.dx * oldScale;
    final baseY = (ws.height - _fbHeight * oldScale) / 2 + oldPan.dy * oldScale;
    final fbX = (localFocal.dx - baseX) / oldScale;
    final fbY = (localFocal.dy - baseY) / oldScale;
    final newScale = fit * newZoom;
    final panX = (localFocal.dx - (ws.width - _fbWidth * newScale) / 2 - fbX * newScale) / newScale;
    final panY = (localFocal.dy - (ws.height - _fbHeight * newScale) / 2 - fbY * newScale) / newScale;
    return Offset(panX, panY);
  }

  // ── Gestos unificados (onScale: 1 dedo = touch/touchpad, 2 dedos = zoom+pan) ──

  void _onScaleStart(ScaleStartDetails d, Size widgetSize) {
    if (d.pointerCount >= 2) {
      // Pinch de 2 dedos: zoom anclado al foco inicial + pan por arrastre.
      _gestureMode = _GestureMode.pinch;
      _zoomAtGestureStart = _zoom;
      _panAtGestureStart = _panFb;
      _pinchStartFocal = d.localFocalPoint;
      return;
    }

    final inTouchpad =
        d.localFocalPoint.dy > widgetSize.height * (1 - _touchpadZoneFraction);
    _dragTotal = Offset.zero;
    _gestureMode = inTouchpad ? _GestureMode.touchpad : _GestureMode.touch;

    if (inTouchpad) return; // sin clic: el arrastre mueve el puntero

    final fb = _localToFb(d.localFocalPoint, widgetSize);
    if (fb != null) {
      _activeMask = 1;
      _cursorFb = fb;
      _lastPanFb = fb;
      _client?.sendPointerEvent(fb.dx.round(), fb.dy.round(), 1);
    }
  }

  void _onScaleUpdate(ScaleUpdateDetails d, Size widgetSize) {
    switch (_gestureMode) {
      case _GestureMode.pinch:
        final fit = _fitScale(widgetSize);
        if (fit == null) return;
        final newZoom = (_zoomAtGestureStart * d.scale).clamp(1.0, _maxZoom);
        var pan = _panAtGestureStart;
        if (newZoom > 1.0) {
          pan = _panForZoomAround(
            _pinchStartFocal,
            _zoomAtGestureStart,
            _panAtGestureStart,
            newZoom,
            widgetSize,
          );
          // Pan con el arrastre de los 2 dedos (en fb units).
          pan += d.focalPointDelta / (fit * newZoom);
        }
        setState(() {
          _zoom = newZoom;
          _panFb = _clampPan(pan);
        });
        break;

      case _GestureMode.touchpad:
        final fit = _fitScale(widgetSize);
        if (fit == null) return;
        final delta = d.focalPointDelta / (fit * _zoom);
        _dragTotal += d.focalPointDelta;
        _cursorFb = Offset(
          (_cursorFb.dx + delta.dx).clamp(0.0, _fbWidth - 1.0),
          (_cursorFb.dy + delta.dy).clamp(0.0, _fbHeight - 1.0),
        );
        // Mover el puntero del servidor sin botón presionado (hover real).
        _client?.sendPointerEvent(
          _cursorFb.dx.round(),
          _cursorFb.dy.round(),
          0,
        );
        break;

      case _GestureMode.touch:
        _dragTotal += d.focalPointDelta;
        final fb = _localToFb(d.localFocalPoint, widgetSize);
        if (fb != null && _activeMask != 0) {
          _cursorFb = fb;
          _lastPanFb = fb;
          _client?.sendPointerEvent(fb.dx.round(), fb.dy.round(), _activeMask);
        }
        break;

      case _GestureMode.none:
        break;
    }
  }

  void _onScaleEnd(ScaleEndDetails d, Size widgetSize) {
    switch (_gestureMode) {
      case _GestureMode.touch:
        // Soltar el botón izquierdo con la última posición conocida
        // (P2-8: sin release el servidor queda con drag fantasma).
        if (_activeMask != 0) {
          final fb = _lastPanFb;
          if (fb != null) {
            _client?.sendPointerEvent(fb.dx.round(), fb.dy.round(), 0);
          }
          _activeMask = 0;
        }
        break;

      case _GestureMode.touchpad:
        // Tap corto en el touchpad = clic izquierdo en la posición del cursor.
        if (_dragTotal.distance < 8) {
          _client?.sendPointerEvent(_cursorFb.dx.round(), _cursorFb.dy.round(), 1);
          _client?.sendPointerEvent(_cursorFb.dx.round(), _cursorFb.dy.round(), 0);
        }
        break;

      case _GestureMode.pinch:
      case _GestureMode.none:
        break;
    }
    _gestureMode = _GestureMode.none;
  }

  /// Clic derecho (máscara RFB 4) en la posición actual del puntero virtual.
  /// Útil para el menú de openbox (clic derecho en el escritorio).
  void _sendRightClick() {
    _client?.sendPointerEvent(_cursorFb.dx.round(), _cursorFb.dy.round(), 4);
    _client?.sendPointerEvent(_cursorFb.dx.round(), _cursorFb.dy.round(), 0);
  }

  /// Clic izquierdo explícito en el puntero virtual (botón de la barra).
  void _sendLeftClick() {
    _client?.sendPointerEvent(_cursorFb.dx.round(), _cursorFb.dy.round(), 1);
    _client?.sendPointerEvent(_cursorFb.dx.round(), _cursorFb.dy.round(), 0);
  }

  /// Scroll de rueda RFB en la posición del puntero virtual.
  /// Máscaras: 8 = rueda arriba, 16 = rueda abajo (RFB 3.8).
  void _sendWheel(bool up) {
    final x = _cursorFb.dx.round();
    final y = _cursorFb.dy.round();
    _client?.sendPointerEvent(x, y, up ? 8 : 16);
    _client?.sendPointerEvent(x, y, 0);
  }

  /// Zoom por botón: factor multiplicativo anclado al centro del viewport.
  void _zoomBy(double factor) {
    final newZoom = (_zoom * factor).clamp(1.0, _maxZoom);
    if (newZoom == _zoom) return;
    setState(() {
      _panFb = _clampPan(_panFb * (newZoom / _zoom));
      _zoom = newZoom;
    });
  }

  void _resetZoom() {
    setState(() {
      _zoom = 1.0;
      _panFb = Offset.zero;
    });
  }

  /// Lanza una app gráfica del escritorio (allowlist nativa:
  /// aterm/pcmanfm/mousepad/feh). La ventana aparece en el framebuffer.
  Future<void> _launchApp(String app) async {
    final ok = await _pkg.launchApp(app);
    if (!ok && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('No se pudo lanzar $app — ¿escritorio activo?'),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  void _togglePanel() => setState(() => _showPanel = !_showPanel);

  void _openHelp() {
    setState(() {
      _showPanel = false;
      _showHelp = true;
    });
  }

  void _dismissHelp() {
    setState(() {
      _showHelp = false;
      _helpDismissed = true;
      _helpSeen = true;
    });
    SharedPreferences.getInstance()
        .then((prefs) => prefs.setBool(_helpSeenKey, true));
  }

  void _toggleKeyboard() {
    setState(() => _showKeyboard = !_showKeyboard);
    if (_showKeyboard) {
      _keyboardFocus.requestFocus();
    } else {
      _keyboardFocus.unfocus();
    }
  }

  /// Mapea un codeUnit UTF-16 a su keysym X11 (X11/keysymdef.h).
  /// El codeUnit crudo solo coincide con el keysym para ASCII imprimible
  /// (0x20-0x7E) y Latin-1 (0xA0-0xFF, donde el keysym es el codepoint).
  /// Controles y el resto del BMP necesitan tabla o el prefijo Unicode.
  int _x11Keysym(int codeUnit) {
    switch (codeUnit) {
      case 0x08: return 0xFF08; // XK_BackSpace
      case 0x09: return 0xFF09; // XK_Tab
      case 0x0A: // LF — mismo comportamiento que CR (Return)
      case 0x0D: return 0xFF0D; // XK_Return
      case 0x1B: return 0xFF1B; // XK_Escape
      case 0x7F: return 0xFFFF; // XK_Delete
    }
    if (codeUnit >= 0x20 && codeUnit <= 0x7E) return codeUnit; // ASCII
    if (codeUnit >= 0xA0 && codeUnit <= 0xFF) return codeUnit; // Latin-1
    return 0x01000000 + codeUnit; // Unicode keysym (XK_ prefix 0x01000000)
  }

  void _onKeyInput(String text) {
    if (text.isEmpty || _client == null) return;
    for (final char in text.codeUnits) {
      // Pares surrogados UTF-16 (emoji, etc.): sin keysym directo en X11.
      if (char >= 0xD800 && char <= 0xDFFF) continue;
      final keysym = _x11Keysym(char);
      _client?.sendKeyEvent(keysym, true);
      _client?.sendKeyEvent(keysym, false);
    }
    _keyboardInput.clear();
  }

  @override
  Widget build(BuildContext context) {
    final colors = NanoThemeExtension.of(context).colors;

    return Scaffold(
      backgroundColor: const Color(0xFF0A0D14),
      body: SafeArea(
        child: Stack(
          children: [
            // Framebuffer principal
            Positioned.fill(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final widgetSize = Size(
                    constraints.maxWidth,
                    constraints.maxHeight,
                  );
                  return _buildContent(colors, widgetSize);
                },
              ),
            ),

            // Control flotante superior
            Positioned(
              top: 12,
              left: 12,
              right: 12,
              child: _FloatingControlBar(
                status: _status,
                connected: _connected,
                busy: _busy,
                showKeyboard: _showKeyboard,
                panelOpen: _showPanel,
                onTogglePanel: _togglePanel,
                onBack: () => context.pop(),
                onRefresh: () {
                  _reconnectAttempts = 0;
                  _connect();
                },
                onToggleKeyboard: _toggleKeyboard,
              ),
            ),

            // Barra inferior de mouse: grupos Mouse (clics + rueda) y Vista
            // (zoom). Aparece conectado; sus botones capturan el tap antes
            // que el touchpad del framebuffer (está más arriba en el Stack).
            if (_connected && _frame != null)
              Positioned(
                bottom: 12,
                left: 12,
                right: 12,
                child: Center(
                  child: _MouseControlBar(
                    zoom: _zoom,
                    onLeftClick: _sendLeftClick,
                    onRightClick: _sendRightClick,
                    onWheelUp: () => _sendWheel(true),
                    onWheelDown: () => _sendWheel(false),
                    onZoomIn: () => _zoomBy(1.25),
                    onZoomOut: () => _zoomBy(1 / 1.25),
                    onResetZoom: _resetZoom,
                  ),
                ),
              ),

            // Fondo táctil del panel lateral (tap fuera = cerrar)
            if (_showPanel)
              Positioned.fill(
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: _togglePanel,
                  child: Container(color: Colors.black38),
                ),
              ),

            // Panel lateral plegable: apps rápidas + vista + ayuda
            Positioned(
              top: 76,
              bottom: 12,
              left: 0,
              child: AnimatedSlide(
                offset: _showPanel ? Offset.zero : const Offset(-1.08, 0),
                duration: const Duration(milliseconds: 220),
                curve: Curves.easeOutCubic,
                child: _ControlPanel(
                  zoom: _zoom,
                  maxZoom: _maxZoom,
                  desktopName: _client?.desktopName ?? '',
                  fbWidth: _fbWidth,
                  fbHeight: _fbHeight,
                  onClose: _togglePanel,
                  onLaunch: _launchApp,
                  onZoomIn: () => _zoomBy(1.25),
                  onZoomOut: () => _zoomBy(1 / 1.25),
                  onResetZoom: _resetZoom,
                  onOpenHelp: _openHelp,
                ),
              ),
            ),

            // Overlay de ayuda de gestos (primera vez o manual desde panel)
            if (_showHelp ||
                (_connected &&
                    _frame != null &&
                    !_helpSeen &&
                    !_helpDismissed))
              Positioned.fill(
                child: _HelpOverlay(onDismiss: _dismissHelp),
              ),

            // TextField oculto para capturar el teclado nativo del móvil
            Positioned(
              left: -9999,
              top: -9999,
              child: SizedBox(
                width: 1,
                height: 1,
                child: TextField(
                  controller: _keyboardInput,
                  focusNode: _keyboardFocus,
                  autofocus: false,
                  enableSuggestions: false,
                  autocorrect: false,
                  onChanged: _onKeyInput,
                  onSubmitted: (v) {
                    _client?.sendKeyEvent(0xFF0D, true);
                    _client?.sendKeyEvent(0xFF0D, false);
                    _keyboardInput.clear();
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContent(NanoColors colors, Size widgetSize) {
    // Animación de carga organizada en dos casos, MISMO diseño (spinner +
    // título + detalle): 1) conectando/reconectando (_busy) y 2) conectado
    // pero aguardando el primer frame — antes el spinner saltaba al UI de
    // "Reintentar" durante los milisegundos que tarda en decodificarse.
    final waitingFirstFrame = _initialized &&
        _connState == _ConnState.connected &&
        _frame == null;
    if ((_busy || waitingFirstFrame) && _frame == null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(color: Color(0xFF10B981)),
            const SizedBox(height: 16),
            Text(
              _status,
              style: const TextStyle(
                fontFamily: 'Inter',
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              _detail,
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 12,
                color: Colors.white.withValues(alpha: 0.7),
              ),
            ),
          ],
        ),
      );
    }

    if (!_connected || _frame == null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.05),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.desktop_access_disabled_rounded,
                  color: Colors.white.withValues(alpha: 0.4),
                  size: 48,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                _status,
                style: const TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                _detail,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 13,
                  color: Colors.white.withValues(alpha: 0.7),
                ),
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: () {
                  _reconnectAttempts = 0;
                  _connect();
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF10B981),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 12,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                icon: const Icon(Icons.refresh_rounded),
                label: const Text(
                  'Reintentar Conexión',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
        ),
      );
    }

    // Framebuffer VNC con zoom/pan profesional (fit → zoom → pan en fb units).
    // Un único recognizer onScale maneja 1 dedo (touch/touchpad) y 2 (pinch):
    // separar recognizers en Android compite por la arena de gestos y hace
    // que el pan de 2 dedos robe eventos al pinch.
    final fit = _fitScale(widgetSize);
    if (fit == null) return Container(color: Colors.black);

    final scale = fit * _zoom;
    final fbW = (_fbWidth * scale).roundToDouble();
    final fbH = (_fbHeight * scale).roundToDouble();
    final left = ((widgetSize.width - fbW) / 2 + _panFb.dx * scale).roundToDouble();
    final top = ((widgetSize.height - fbH) / 2 + _panFb.dy * scale).roundToDouble();

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onScaleStart: (d) => _onScaleStart(d, widgetSize),
      onScaleUpdate: (d) => _onScaleUpdate(d, widgetSize),
      onScaleEnd: (d) => _onScaleEnd(d, widgetSize),
      child: Container(
        decoration: const BoxDecoration(
          color: Color(0xFF0F172A),
        ),
        child: Stack(
          clipBehavior: Clip.hardEdge,
          children: [
            Positioned(
              left: left,
              top: top,
              width: fbW,
              height: fbH,
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(4),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.5),
                      blurRadius: 16,
                      spreadRadius: 2,
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: RawImage(
                    image: _frame,
                    fit: BoxFit.fill,
                    filterQuality: FilterQuality.medium,
                  ),
                ),
              ),
            ),
            // Guía visual sutil del touchpad inferior (no intercepta gestos).
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              height: (widgetSize.height * _touchpadZoneFraction).roundToDouble(),
              child: IgnorePointer(
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.transparent,
                        Colors.white.withValues(alpha: 0.045),
                      ],
                    ),
                  ),
                  child: Align(
                    alignment: Alignment.bottomCenter,
                    child: Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Text(
                        'Touchpad: arrastra para mover · tap = clic',
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 10,
                          color: Colors.white.withValues(alpha: 0.35),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Barra inferior con acciones de mouse organizadas en grupos:
/// [Clics | Rueda | Zoom]. Targets ≥44px para accesibilidad táctil.
class _MouseControlBar extends StatelessWidget {
  final VoidCallback onLeftClick;
  final VoidCallback onRightClick;
  final VoidCallback onWheelUp;
  final VoidCallback onWheelDown;
  final VoidCallback onZoomIn;
  final VoidCallback onZoomOut;
  final VoidCallback onResetZoom;
  final double zoom;

  const _MouseControlBar({
    required this.onLeftClick,
    required this.onRightClick,
    required this.onWheelUp,
    required this.onWheelDown,
    required this.onZoomIn,
    required this.onZoomOut,
    required this.onResetZoom,
    required this.zoom,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFF161B22).withValues(alpha: 0.88),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
        boxShadow: const [
          BoxShadow(
            color: Colors.black45,
            blurRadius: 10,
            offset: Offset(0, 4),
          ),
        ],
      ),
      // FittedBox scaleDown: con textScaler grande o pantallas angostas la
      // fila de 8 botones desbordaba y el último ("Zoom 100%") quedaba
      // cortado por el borde. scaleDown encoge la barra completa sin
      // recortar ningún control.
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Grupo Mouse: clics
            _barButton(Icons.mouse_rounded, 'Clic izquierdo', onLeftClick),
            _barButton(Icons.ads_click_rounded, 'Clic derecho', onRightClick),
            _separator(),
            // Grupo Rueda: scroll RFB
            _barButton(Icons.arrow_upward_rounded, 'Rueda arriba', onWheelUp),
            _barButton(Icons.arrow_downward_rounded, 'Rueda abajo', onWheelDown),
            _separator(),
            // Grupo Vista: zoom
            _barButton(Icons.zoom_out_rounded, 'Alejar', onZoomOut),
            _barButton(Icons.zoom_in_rounded, 'Acercar', onZoomIn),
            _barButton(
              Icons.zoom_out_map_rounded,
              'Zoom 100%',
              zoom > 1.0 ? onResetZoom : null,
            ),
          ],
        ),
      ),
    );
  }

  Widget _separator() => Container(
        width: 1,
        height: 26,
        margin: const EdgeInsets.symmetric(horizontal: 4),
        color: Colors.white.withValues(alpha: 0.14),
      );

  Widget _barButton(IconData icon, String tooltip, VoidCallback? onTap) {
    final enabled = onTap != null;
    return IconButton(
      onPressed: onTap,
      icon: Icon(
        icon,
        color: enabled ? Colors.white70 : Colors.white24,
        size: 20,
      ),
      tooltip: tooltip,
      constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
      padding: EdgeInsets.zero,
    );
  }
}

/// Panel lateral plegable con organización profesional:
/// apps rápidas del escritorio, controles de vista y guía de gestos.
class _ControlPanel extends StatelessWidget {
  final double zoom;
  final double maxZoom;
  final String desktopName;
  final int fbWidth;
  final int fbHeight;
  final VoidCallback onClose;
  final void Function(String app) onLaunch;
  final VoidCallback onZoomIn;
  final VoidCallback onZoomOut;
  final VoidCallback onResetZoom;
  final VoidCallback onOpenHelp;

  const _ControlPanel({
    required this.zoom,
    required this.maxZoom,
    required this.desktopName,
    required this.fbWidth,
    required this.fbHeight,
    required this.onClose,
    required this.onLaunch,
    required this.onZoomIn,
    required this.onZoomOut,
    required this.onResetZoom,
    required this.onOpenHelp,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 300,
      decoration: BoxDecoration(
        color: const Color(0xFF12161F).withValues(alpha: 0.96),
        borderRadius: const BorderRadius.horizontal(right: Radius.circular(20)),
        border: Border(
          right: BorderSide(color: Colors.white.withValues(alpha: 0.12)),
        ),
        boxShadow: const [
          BoxShadow(color: Colors.black54, blurRadius: 18, offset: Offset(4, 0)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Encabezado
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 8, 8),
            child: Row(
              children: [
                const Icon(Icons.dashboard_rounded,
                    color: Color(0xFF10B981), size: 22),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    'Panel Linux',
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                ),
                IconButton(
                  onPressed: onClose,
                  icon: const Icon(Icons.close_rounded,
                      color: Colors.white70, size: 20),
                  tooltip: 'Cerrar panel',
                  constraints:
                      const BoxConstraints(minWidth: 40, minHeight: 40),
                  padding: EdgeInsets.zero,
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: Colors.white12),

          // Apps rápidas
          const _PanelSectionTitle('Apps rápidas'),
          _panelAppButton(
            icon: Icons.terminal_rounded,
            label: 'Terminal',
            sub: 'aterm · fuente grande',
            onTap: () => onLaunch('aterm'),
          ),
          _panelAppButton(
            icon: Icons.folder_rounded,
            label: 'Archivos',
            sub: 'pcmanfm',
            onTap: () => onLaunch('pcmanfm'),
          ),
          _panelAppButton(
            icon: Icons.edit_note_rounded,
            label: 'Editor',
            sub: 'mousepad',
            onTap: () => onLaunch('mousepad'),
          ),
          _panelAppButton(
            icon: Icons.image_rounded,
            label: 'Imágenes',
            sub: 'feh',
            onTap: () => onLaunch('feh'),
          ),
          const Divider(height: 1, color: Colors.white12),

          // Vista: zoom
          const _PanelSectionTitle('Vista'),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            child: Row(
              children: [
                _zoomBtn(Icons.zoom_out_rounded, 'Alejar', onZoomOut),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    '${(zoom * 100).round()}%',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                _zoomBtn(Icons.zoom_in_rounded, 'Acercar', onZoomIn),
                const SizedBox(width: 8),
                _zoomBtn(
                  Icons.zoom_out_map_rounded,
                  'Zoom 100%',
                  zoom > 1.0 ? onResetZoom : null,
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: Colors.white12),

          // Ayuda
          const _PanelSectionTitle('Ayuda'),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: OutlinedButton.icon(
              onPressed: onOpenHelp,
              icon: const Icon(Icons.gesture_rounded, size: 18),
              label: const Text('Guía de gestos'),
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.white70,
                side: BorderSide(color: Colors.white.withValues(alpha: 0.2)),
                minimumSize: const Size.fromHeight(44),
              ),
            ),
          ),

          const Spacer(),

          // Info de conexión
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  desktopName.isEmpty ? 'Escritorio' : desktopName,
                  style: const TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF10B981),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '$fbWidth×$fbHeight px · zoom máx ${(maxZoom * 100).round()}%',
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 11,
                    color: Colors.white.withValues(alpha: 0.5),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _panelAppButton({
    required IconData icon,
    required String label,
    required String sub,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: const Color(0xFF10B981).withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: const Color(0xFF10B981), size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: const TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                  Text(
                    sub,
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 11,
                      color: Colors.white.withValues(alpha: 0.5),
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.open_in_new_rounded,
                size: 15, color: Colors.white.withValues(alpha: 0.35)),
          ],
        ),
      ),
    );
  }

  Widget _zoomBtn(IconData icon, String tooltip, VoidCallback? onTap) {
    return IconButton(
      onPressed: onTap,
      icon: Icon(icon,
          color: onTap != null ? Colors.white70 : Colors.white24, size: 22),
      tooltip: tooltip,
      constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
      padding: EdgeInsets.zero,
      style: IconButton.styleFrom(
        backgroundColor: Colors.white.withValues(alpha: 0.06),
      ),
    );
  }
}

class _PanelSectionTitle extends StatelessWidget {
  final String text;
  const _PanelSectionTitle(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: Text(
        text.toUpperCase(),
        style: TextStyle(
          fontFamily: 'Inter',
          fontSize: 10,
          fontWeight: FontWeight.w700,
          letterSpacing: 1.2,
          color: Colors.white.withValues(alpha: 0.45),
        ),
      ),
    );
  }
}

/// Overlay semitransparente con la guía de gestos. Aparece automático la
/// primera vez que el escritorio queda conectado y visible.
class _HelpOverlay extends StatelessWidget {
  final VoidCallback onDismiss;

  const _HelpOverlay({required this.onDismiss});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.black.withValues(alpha: 0.62),
      child: Center(
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 28),
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: const Color(0xFF161B22),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.white.withValues(alpha: 0.14)),
            boxShadow: const [
              BoxShadow(color: Colors.black54, blurRadius: 24),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(
                children: [
                  Icon(Icons.gesture_rounded, color: Color(0xFF10B981), size: 22),
                  SizedBox(width: 8),
                  Text(
                    'Gestos del escritorio',
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              _helpRow(Icons.touch_app_rounded, 'Zona superior:',
                  'tap = clic · arrastrar = mover'),
              _helpRow(Icons.linear_scale_rounded, 'Zona inferior (touchpad):',
                  'arrastra = cursor sin clic · tap = clic'),
              _helpRow(Icons.pinch_rounded, 'Pellizco 2 dedos:',
                  'zoom hasta 400%'),
              _helpRow(Icons.swipe_rounded, '2 dedos con zoom:',
                  'desplazar la vista (pan)'),
              _helpRow(Icons.mouse_rounded, 'Barra inferior:',
                  'clics, rueda de scroll y zoom'),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: onDismiss,
                  icon: const Icon(Icons.check_rounded, size: 18),
                  label: const Text('Entendido'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF10B981),
                    foregroundColor: Colors.white,
                    minimumSize: const Size.fromHeight(48),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _helpRow(IconData icon, String title, String desc) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          Icon(icon, size: 18, color: Colors.white.withValues(alpha: 0.7)),
          const SizedBox(width: 10),
          Expanded(
            child: RichText(
              text: TextSpan(
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 13,
                  height: 1.35,
                  color: Colors.white.withValues(alpha: 0.55),
                ),
                children: [
                  TextSpan(
                    text: '$title ',
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                  TextSpan(text: desc),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _FloatingControlBar extends StatelessWidget {
  final String status;
  final bool connected;
  final bool busy;
  final bool showKeyboard;
  final bool panelOpen;
  final VoidCallback onBack;
  final VoidCallback onRefresh;
  final VoidCallback onToggleKeyboard;
  final VoidCallback onTogglePanel;

  const _FloatingControlBar({
    required this.status,
    required this.connected,
    required this.busy,
    required this.showKeyboard,
    required this.panelOpen,
    required this.onBack,
    required this.onRefresh,
    required this.onToggleKeyboard,
    required this.onTogglePanel,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFF161B22).withValues(alpha: 0.85),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
        boxShadow: const [
          BoxShadow(
            color: Colors.black45,
            blurRadius: 10,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          IconButton(
            onPressed: onTogglePanel,
            icon: Icon(
              Icons.dashboard_rounded,
              color: panelOpen ? const Color(0xFF10B981) : Colors.white70,
              size: 20,
            ),
            tooltip: 'Panel de control',
            constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
            padding: EdgeInsets.zero,
          ),
          IconButton(
            onPressed: onBack,
            icon: const Icon(
              Icons.arrow_back_rounded,
              color: Colors.white,
              size: 20,
            ),
            tooltip: 'Volver',
            constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
            padding: EdgeInsets.zero,
          ),
          const SizedBox(width: 8),
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: connected
                  ? const Color(0xFF10B981)
                  : busy
                      ? const Color(0xFF3B82F6)
                      : Colors.amber,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              status,
              style: const TextStyle(
                fontFamily: 'Inter',
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          IconButton(
            onPressed: onToggleKeyboard,
            icon: Icon(
              Icons.keyboard_rounded,
              color: showKeyboard ? const Color(0xFF10B981) : Colors.white70,
              size: 20,
            ),
            tooltip: 'Teclado táctil',
            constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
            padding: EdgeInsets.zero,
          ),
          IconButton(
            onPressed: busy ? null : onRefresh,
            icon: busy
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Icon(
                    Icons.refresh_rounded,
                    color: Colors.white70,
                    size: 20,
                  ),
            tooltip: 'Reconectar',
            constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
            padding: EdgeInsets.zero,
          ),
        ],
      ),
    );
  }
}
