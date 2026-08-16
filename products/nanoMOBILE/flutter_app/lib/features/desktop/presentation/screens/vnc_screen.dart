import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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

  // â”€â”€ Overlay de ayuda (apps rápidas ahora en el FAB) â”€â”€
  bool _showHelp = false;
  bool _helpDismissed = false; // ya visto/cerrado en esta sesión
  bool _helpSeen = false; // flag persistente (SharedPreferences)
  bool _fabOpen = false; // estado del FAB radial
  bool _isMobileMode = true; // modo mobile (true) o desktop (false)

  // â”€â”€ Reconexión automática â”€â”€
  _ConnState _connState = _ConnState.connecting;
  int _reconnectAttempts = 0;
  Timer? _reconnectTimer;
  static const _maxReconnectAttempts = 7;

  int _fbWidth = 0;
  int _fbHeight = 0;
  Offset? _lastPanFb; // última posición fb del drag (para soltar al final)

  // â”€â”€ Zoom / pan profesional (pinch 2 dedos) â”€â”€
  // _zoom: escala adicional sobre el fit (1.0 = ajuste a pantalla, máx 4.0).
  // _panFb: desplazamiento del viewport en unidades de framebuffer.
  double _zoom = 1.0;
  Offset _panFb = Offset.zero;
  static const double _maxZoom = 4.0;

  // â”€â”€ Touchpad inferior (cursor relativo profesional) â”€â”€
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

  // U-2: long-press (550ms sin mover) = clic derecho en el punto tocado.
  Timer? _longPressTimer;
  bool _longPressFired = false;

  // U-2: scroll de 2 dedos (wheel RFB). Sticky: el gesto decide una vez —
  // desplazamiento vertical dominante = scroll; |scale-1| >= 0.05 = pinch.
  bool _pinchScroll = false;
  bool _pinchZoomed = false;
  double _scrollAccum = 0;

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
      final mobileMode = ref.read(settingsProvider).desktopMobileMode;
      final seen = prefs.getBool(_helpSeenKey) ?? false;
      if (mounted) {
        setState(() {
          _helpSeen = seen;
          // D-FIX: desktopMobileMode se cargaba SOLO en _barExpanded — el
          // modo persistido nunca se aplicaba a _isMobileMode (quedaba true
          // por defecto: barra inferior siempre oculta aunque el usuario
          // guardara modo PC). Ahora el modo manda: en PC la fila de teclas
          // rápidas arranca expandida (es el "teclado" del escritorio).
          _isMobileMode = mobileMode;
          _barExpanded = !mobileMode;
        });
      }
    });
    _connect();
  }

  static const _helpSeenKey = 'vnc_help_seen_v1';

  @override
  void dispose() {
    _reconnectTimer?.cancel();
    _longPressTimer?.cancel();
    _client?.disconnect();
    _frame?.dispose();
    _keyboardFocus.dispose();
    _keyboardInput.dispose();
    super.dispose();
  }

  // â”€â”€ Reconexión con exponential backoff â”€â”€

  void _scheduleReconnect() {
    if (!mounted) return;
    _reconnectTimer?.cancel();
    if (_reconnectAttempts >= _maxReconnectAttempts) {
      setState(() {
        _connState = _ConnState.failed;
        _busy = false;
        _connected = false;
        _status = 'Conexión perdida';
        _detail =
            'Agotados $_maxReconnectAttempts intentos. '
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
        _status = 'Reconectando...';
        _detail = 'Intento $_reconnectAttempts/$_maxReconnectAttempts';
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
        // (1280x720x4 â‰ˆ 3.7 MB) acumulaba bitmap nativo → GC thrash →
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
    // D-1: el framebuffer nace con el aspect del viewport del device
    // (cap 1920 en el backend) — sin franjas en portrait ni distorsión.
    // U-9: sizeOf devuelve dp LÓGICOS (360x800 @3.0); el backend espera
    // píxeles FÍSICOS. Sin el factor el Xvnc nacía en 360x800 — resolución
    // enana: el HUD y las apps wrappeaban a ~20 columnas y el texto se
    // veía roto. Multiplicar por devicePixelRatio restaura 864x1920.
    final viewport = MediaQuery.sizeOf(context);
    final dpr = MediaQuery.devicePixelRatioOf(context);
    final started = await _pkg.startDesktop(
      vncPassword: ref.read(settingsProvider).vncPassword,
      width: (viewport.width * dpr).round(),
      height: (viewport.height * dpr).round(),
    );
    if (!mounted) return false;
    if (!started) {
      setState(() {
        _status = 'Xvnc no arrancó';
        _detail =
            'El servicio VNC devolvió error. Revisa logcat: vnc-service.';
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
    final baseY =
        (widgetSize.height - _fbHeight * scale) / 2 + _panFb.dy * scale;

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
    return Offset(p.dx.clamp(-maxX, maxX), p.dy.clamp(-maxY, maxY));
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
    final panX =
        (localFocal.dx -
            (ws.width - _fbWidth * newScale) / 2 -
            fbX * newScale) /
        newScale;
    final panY =
        (localFocal.dy -
            (ws.height - _fbHeight * newScale) / 2 -
            fbY * newScale) /
        newScale;
    return Offset(panX, panY);
  }

  // â”€â”€ Gestos unificados (onScale: 1 dedo = touch/touchpad, 2 dedos = zoom+pan) â”€â”€

  void _onScaleStart(ScaleStartDetails d, Size widgetSize) {
    if (d.pointerCount >= 2) {
      // Pinch de 2 dedos: zoom anclado al foco inicial + pan por arrastre.
      // U-2: si el desplazamiento vertical domina, es scroll de rueda.
      _gestureMode = _GestureMode.pinch;
      _zoomAtGestureStart = _zoom;
      _panAtGestureStart = _panFb;
      _pinchStartFocal = d.localFocalPoint;
      _pinchScroll = false;
      _pinchZoomed = false;
      _scrollAccum = 0;
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
      // U-2: long-press = clic derecho (menú de openbox en el escritorio).
      _longPressFired = false;
      _longPressTimer?.cancel();
      _longPressTimer = Timer(const Duration(milliseconds: 550), () {
        if (_gestureMode != _GestureMode.touch) return;
        if (_dragTotal.distance >= 8) return;
        _longPressFired = true;
        final p = _lastPanFb;
        if (p != null && _client != null) {
          // Soltar el izquierdo antes del derecho (sin drag fantasma P2-8).
          _client?.sendPointerEvent(p.dx.round(), p.dy.round(), 0);
          _activeMask = 0;
          _client?.sendPointerEvent(p.dx.round(), p.dy.round(), 4);
          _client?.sendPointerEvent(p.dx.round(), p.dy.round(), 0);
          HapticFeedback.mediumImpact();
        }
      });
    }
  }

  void _onScaleUpdate(ScaleUpdateDetails d, Size widgetSize) {
    switch (_gestureMode) {
      case _GestureMode.pinch:
        final fit = _fitScale(widgetSize);
        if (fit == null) return;
        // U-2: decidir intención UNA vez (sticky) — scroll vs pinch real.
        if (!_pinchScroll && !_pinchZoomed) {
          if ((d.scale - 1.0).abs() >= 0.05) {
            _pinchZoomed = true;
          } else {
            final dy = d.localFocalPoint.dy - _pinchStartFocal.dy;
            if (dy.abs() > 24) _pinchScroll = true;
          }
        }
        if (_pinchScroll) {
          // Scroll de rueda: cada ~40px verticales = un paso RFB (8/16).
          _scrollAccum += d.focalPointDelta.dy;
          const notch = 40.0;
          final fb = _localToFb(d.localFocalPoint, widgetSize);
          while (_scrollAccum <= -notch) {
            _scrollAccum += notch;
            if (fb != null && _client != null) {
              _client?.sendPointerEvent(fb.dx.round(), fb.dy.round(), 8);
              _client?.sendPointerEvent(fb.dx.round(), fb.dy.round(), 0);
            }
          }
          while (_scrollAccum >= notch) {
            _scrollAccum -= notch;
            if (fb != null && _client != null) {
              _client?.sendPointerEvent(fb.dx.round(), fb.dy.round(), 16);
              _client?.sendPointerEvent(fb.dx.round(), fb.dy.round(), 0);
            }
          }
          return;
        }
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
        // U-2: movimiento real cancela el long-press pendiente.
        if (_dragTotal.distance >= 8) {
          _longPressTimer?.cancel();
          _longPressFired = false;
        }
        final fb = _localToFb(d.localFocalPoint, widgetSize);
        if (fb != null && _activeMask != 0 && !_longPressFired) {
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
        _longPressTimer?.cancel();
        if (_longPressFired) {
          // El clic derecho ya se envió completo en el timer; nada que soltar.
          _longPressFired = false;
          _activeMask = 0;
          break;
        }
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
          _client?.sendPointerEvent(
            _cursorFb.dx.round(),
            _cursorFb.dy.round(),
            1,
          );
          _client?.sendPointerEvent(
            _cursorFb.dx.round(),
            _cursorFb.dy.round(),
            0,
          );
        }
        break;

      case _GestureMode.pinch:
        _pinchScroll = false;
        _pinchZoomed = false;
        break;

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

  // â”€â”€ Teclas rápidas X11 (U-3) â”€â”€
  // El IME móvil no tiene Esc/Tab/Ctrl/Alt/flechas — sin esto, cerrar
  // diálogos o hacer Ctrl+C en la terminal es imposible sin teclado físico.

  // X11 keysyms: Esc=0xFF1B, Tab=0xFF09, Return=0xFF0D, Ctrl_L=0xFFE3,
  // Alt_L=0xFFE9, Left=0xFF51, Up=0xFF52, Right=0xFF53, Down=0xFF54.
  bool _ctrlSticky = false;
  bool _altSticky = false;

  // U-6: fila de teclas plegable — colapsada por defecto para no tapar
  // el framebuffer; se expande con el botón de teclado de la barra.
  bool _barExpanded = false;

  void _sendQuickKey(int keysym) {
    _client?.sendKeyEvent(keysym, true);
    _client?.sendKeyEvent(keysym, false);
  }

  void _toggleCtrl() {
    setState(() => _ctrlSticky = !_ctrlSticky);
    _client?.sendKeyEvent(0xFFE3, _ctrlSticky);
    HapticFeedback.selectionClick();
  }

  void _toggleAlt() {
    setState(() => _altSticky = !_altSticky);
    _client?.sendKeyEvent(0xFFE9, _altSticky);
    HapticFeedback.selectionClick();
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
  /// lxterminal/pcmanfm/mousepad/xpdf/file-roller/feh). La ventana aparece
  /// en el framebuffer.
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

  void _openHelp() {
    setState(() {
      _showHelp = true;
    });
  }

  /// FAB: bottom sheet con las apps rápidas del escritorio. Reemplaza al
  /// panel lateral — las apps viven en un acceso puntual que no estorba
  /// la vista del framebuffer.
  void _openAppsSheet() {
    final colors = NanoThemeExtension.of(context).colors;
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => Container(
        decoration: BoxDecoration(
          color: colors.surface,
          borderRadius: const BorderRadius.vertical(
            top: Radius.circular(22),
          ),
          border: Border(top: BorderSide(color: colors.outlineVariant)),
        ),
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
        child: SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 10),
                  decoration: BoxDecoration(
                    color: colors.outline,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              Text(
                'Apps del escritorio',
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: colors.onSurface,
                ),
              ),
              const SizedBox(height: 10),
              _appTile(
                icon: Icons.terminal_rounded,
                label: 'Terminal',
                sub: 'lxterminal',
                onTap: () {
                  Navigator.of(sheetContext).pop();
                  _launchApp('lxterminal');
                },
              ),
              _appTile(
                icon: Icons.folder_rounded,
                label: 'Archivos',
                sub: 'pcmanfm',
                onTap: () {
                  Navigator.of(sheetContext).pop();
                  _launchApp('pcmanfm');
                },
              ),
              _appTile(
                icon: Icons.edit_note_rounded,
                label: 'Editor',
                sub: 'mousepad',
                onTap: () {
                  Navigator.of(sheetContext).pop();
                  _launchApp('mousepad');
                },
              ),
              _appTile(
                icon: Icons.image_rounded,
                label: 'Imágenes',
                sub: 'feh',
                onTap: () {
                  Navigator.of(sheetContext).pop();
                  _launchApp('feh');
                },
              ),
              Divider(height: 20, color: colors.outlineVariant),
              _appTile(
                icon: Icons.gesture_rounded,
                label: 'Guía de gestos',
                sub: 'zoom, pan, clics',
                onTap: () {
                  Navigator.of(sheetContext).pop();
                  _openHelp();
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _appTile({
    required IconData icon,
    required String label,
    required String sub,
    required VoidCallback onTap,
  }) {
    final colors = NanoThemeExtension.of(context).colors;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 9),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: colors.accent.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(11),
              ),
              child: Icon(icon, color: colors.accent, size: 21),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: colors.onSurface,
                    ),
                  ),
                  Text(
                    sub,
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 11,
                      color: colors.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.chevron_right_rounded,
              size: 20,
              color: colors.onSurfaceVariant,
            ),
          ],
        ),
      ),
    );
  }

  void _dismissHelp() {
    setState(() {
      _showHelp = false;
      _helpDismissed = true;
      _helpSeen = true;
    });
    SharedPreferences.getInstance().then(
      (prefs) => prefs.setBool(_helpSeenKey, true),
    );
  }

  void _toggleKeyboard() {
    setState(() => _showKeyboard = !_showKeyboard);
    if (_showKeyboard) {
      _keyboardFocus.requestFocus();
    } else {
      _keyboardFocus.unfocus();
      // Al ocultar, descartar el texto pendiente del buffer sin reenviarlo.
      _clearKeyboardBuffer();
    }
  }

  /// Vacía el buffer del TextField oculto sin disparar _onKeyInput (el flag
  /// evita que el clear se interprete como borrado y envíe backspaces).
  void _clearKeyboardBuffer() {
    _keyboardClearing = true;
    _keyboardInput.clear();
    _lastKeyboardText = '';
    _keyboardClearing = false;
  }

  /// Enter del IME: Return en el escritorio y buffer limpio. El teclado
  /// sigue abierto (textInputAction.send) para poder seguir escribiendo.
  void _onKeyboardSubmit(String _) {
    _client?.sendKeyEvent(0xFF0D, true);
    _client?.sendKeyEvent(0xFF0D, false);
    _clearKeyboardBuffer();
  }

  /// Mapea un codeUnit UTF-16 a su keysym X11 (X11/keysymdef.h).
  /// El codeUnit crudo solo coincide con el keysym para ASCII imprimible
  /// (0x20-0x7E) y Latin-1 (0xA0-0xFF, donde el keysym es el codepoint).
  /// Controles y el resto del BMP necesitan tabla o el prefijo Unicode.
  int _x11Keysym(int codeUnit) {
    switch (codeUnit) {
      case 0x08:
        return 0xFF08; // XK_BackSpace
      case 0x09:
        return 0xFF09; // XK_Tab
      case 0x0A: // LF — mismo comportamiento que CR (Return)
      case 0x0D:
        return 0xFF0D; // XK_Return
      case 0x1B:
        return 0xFF1B; // XK_Escape
      case 0x7F:
        return 0xFFFF; // XK_Delete
    }
    if (codeUnit >= 0x20 && codeUnit <= 0x7E) return codeUnit; // ASCII
    if (codeUnit >= 0xA0 && codeUnit <= 0xFF) return codeUnit; // Latin-1
    return 0x01000000 + codeUnit; // Unicode keysym (XK_ prefix 0x01000000)
  }

  // U-8: el IME entrega en onChanged el texto COMPLETO del campo, no el
  // carácter tecleado. Enviar el texto entero en cada pulsación repetía
  // letras (teclear "abc" mandaba a→ab→abc al escritorio) y hacer clear()
  // a mitad de composición rompía el IME: el teclado "no escribía".
  // Fix: diff contra el texto previo — backspaces por lo borrado y solo
  // los caracteres NUEVOS al escritorio. El buffer se limpia al ocultar el
  // teclado o al llegar al tope, no en cada tecla.
  String _lastKeyboardText = '';
  bool _keyboardClearing = false;

  void _onKeyInput(String text) {
    if (_keyboardClearing || _client == null) return;
    final prevUnits = _lastKeyboardText.codeUnits;
    final newUnits = text.codeUnits;
    // Prefijo común: todo lo anterior ya fue enviado.
    int common = 0;
    while (common < prevUnits.length &&
        common < newUnits.length &&
        prevUnits[common] == newUnits[common]) {
      common++;
    }
    // Lo que desapareció del prefijo = borrados en el escritorio.
    for (var d = common; d < prevUnits.length; d++) {
      _client!.sendKeyEvent(0xFF08, true);
      _client!.sendKeyEvent(0xFF08, false);
    }
    // Lo nuevo = solo estos caracteres se envían.
    for (var i = common; i < newUnits.length; i++) {
      final char = newUnits[i];
      // Pares surrogados UTF-16 (emoji, etc.): sin keysym directo en X11.
      if (char >= 0xD800 && char <= 0xDFFF) continue;
      final keysym = _x11Keysym(char);
      _client!.sendKeyEvent(keysym, true);
      _client!.sendKeyEvent(keysym, false);
    }
    _lastKeyboardText = text;
    // Tope: buffer largo cansa al IME y no aporta — limpiar sin reenviar.
    if (text.length > 120) _clearKeyboardBuffer();
  }

  @override
  Widget build(BuildContext context) {
    final colors = NanoThemeExtension.of(context).colors;

    return Scaffold(
      backgroundColor: colors.background,
      // FAB radial circular minimalista para apps del escritorio.
      floatingActionButton: _RadialFab(
        isOpen: _fabOpen,
        onToggle: () => setState(() => _fabOpen = !_fabOpen),
        onOpenApps: _openAppsSheet,
        onToggleKeyboard: _toggleKeyboard,
        showKeyboard: _showKeyboard,
      ),
      body: SafeArea(
        child: Stack(
          children: [
            // U-7: layout en franjas. Los controles persistentes (barra
            // superior y barra de mouse) ocupan franjas PROPIAS del Column —
            // ya no flotan sobre la pantalla proyectada. El framebuffer se
            // reparte el espacio restante con Expanded y se ve completo:
            // ningún control tapa ni "interviene" la imagen del escritorio.
            Column(
              children: [
                // Franja superior: estado + conexión + teclado + modo toggle.
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
                  child: _FloatingControlBar(
                    status: _status,
                    connected: _connected,
                    busy: _busy,
                    showKeyboard: _showKeyboard,
                    isMobileMode: _isMobileMode,
                    onBack: () => context.pop(),
                    onRefresh: () {
                      _reconnectAttempts = 0;
                      _connect();
                    },
                    onToggleKeyboard: _toggleKeyboard,
                    onToggleMode: () {
                      // D-FIX: el toggle no persistía — al salir de la
                      // pantalla el modo elegido se perdía. Ahora guarda en
                      // settings y sincroniza la fila de teclas: en PC
                      // expandida (es el teclado del escritorio), en móvil
                      // colapsada (la barra ni se muestra).
                      final next = !_isMobileMode;
                      ref
                          .read(settingsProvider.notifier)
                          .setDesktopMobileMode(next);
                      setState(() {
                        _isMobileMode = next;
                        _barExpanded = !next;
                      });
                    },
                  ),
                ),

                // Pantalla proyectada — área exclusiva del framebuffer.
                Expanded(
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

                // Franja inferior: mouse/rueda/zoom/teclas rápidas. Solo
                // conectado (sin frame no hay dónde clicar). Al expandir la
                // fila de teclas, la franja crece y el framebuffer cede
                // espacio — nunca se superponen.
                // En modo mobile, ocultar para maximizar espacio de visor.
                if (_connected && _frame != null && !_isMobileMode)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(12, 6, 12, 10),
                    child: Center(
                      child: _MouseControlBar(
                        colors: colors,
                        zoom: _zoom,
                        expanded: _barExpanded,
                        onToggleExpanded: () =>
                            setState(() => _barExpanded = !_barExpanded),
                        onLeftClick: _sendLeftClick,
                        onRightClick: _sendRightClick,
                        onWheelUp: () => _sendWheel(true),
                        onWheelDown: () => _sendWheel(false),
                        onZoomIn: () => _zoomBy(1.25),
                        onZoomOut: () => _zoomBy(1 / 1.25),
                        onResetZoom: _resetZoom,
                        onQuickKey: _sendQuickKey,
                        ctrlActive: _ctrlSticky,
                        altActive: _altSticky,
                        onToggleCtrl: _toggleCtrl,
                        onToggleAlt: _toggleAlt,
                      ),
                    ),
                  ),
              ],
            ),

            // Overlay de ayuda de gestos (primera vez o manual desde el FAB)
            if (_showHelp ||
                (_connected && _frame != null && !_helpSeen && !_helpDismissed))
              Positioned.fill(child: _HelpOverlay(onDismiss: _dismissHelp)),

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
                  // send: la tecla Enter del IME envía Return y el teclado
                  // sigue abierto (done lo cerraría y cortaría el acceso).
                  textInputAction: TextInputAction.send,
                  onChanged: _onKeyInput,
                  onSubmitted: _onKeyboardSubmit,
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
    final waitingFirstFrame =
        _initialized && _connState == _ConnState.connected && _frame == null;
    if ((_busy || waitingFirstFrame) && _frame == null) {
      // Estado "sin señal" del área del framebuffer: se mantiene oscuro
      // (video chrome) aunque la app esté en modo claro.
      return Container(
        color: const Color(0xFF0A0D14),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(color: colors.accent),
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
        ),
      );
    }

    if (!_connected || _frame == null) {
      // Estado de error del área del framebuffer: se mantiene oscuro
      // (video chrome); el botón usa tokens para legibilidad en ambos modos.
      return Container(
        color: const Color(0xFF0A0D14),
        child: Center(
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
                    // D-FIX: verde 0xFF10B981 era inconsistente con la paleta
                    // Nano — commit 50c384d unificó 'Reintentar' a cyan; hoy
                    // colors.accent (0xFF42D9FF oscuro / 0xFF0EA5E9 claro).
                    backgroundColor: colors.accent,
                    foregroundColor: colors.onAccent,
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
    final left = ((widgetSize.width - fbW) / 2 + _panFb.dx * scale)
        .roundToDouble();
    final top = ((widgetSize.height - fbH) / 2 + _panFb.dy * scale)
        .roundToDouble();

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onScaleStart: (d) => _onScaleStart(d, widgetSize),
      onScaleUpdate: (d) => _onScaleUpdate(d, widgetSize),
      onScaleEnd: (d) => _onScaleEnd(d, widgetSize),
      child: Container(
        decoration: const BoxDecoration(color: Color(0xFF0F172A)),
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
              height: (widgetSize.height * _touchpadZoneFraction)
                  .roundToDouble(),
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
                      // U-6: con la fila de teclas expandida la toolbar tapa
                      // este texto; se oculta para no quedar a medias.
                      child: _barExpanded
                          ? const SizedBox.shrink()
                          : Text(
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
/// [Clics | Rueda | Zoom]. Targets â‰¥44px para accesibilidad táctil.
class _MouseControlBar extends StatelessWidget {
  final VoidCallback onLeftClick;
  final VoidCallback onRightClick;
  final VoidCallback onWheelUp;
  final VoidCallback onWheelDown;
  final VoidCallback onZoomIn;
  final VoidCallback onZoomOut;
  final VoidCallback onResetZoom;
  final void Function(int keysym) onQuickKey;
  final bool ctrlActive;
  final bool altActive;
  final VoidCallback onToggleCtrl;
  final VoidCallback onToggleAlt;
  final double zoom;
  final bool expanded;
  final VoidCallback onToggleExpanded;
  final NanoColors colors;

  const _MouseControlBar({
    required this.colors,
    required this.onLeftClick,
    required this.onRightClick,
    required this.onWheelUp,
    required this.onWheelDown,
    required this.onZoomIn,
    required this.onZoomOut,
    required this.onResetZoom,
    required this.onQuickKey,
    required this.ctrlActive,
    required this.altActive,
    required this.onToggleCtrl,
    required this.onToggleAlt,
    required this.zoom,
    required this.expanded,
    required this.onToggleExpanded,
  });

  @override
  Widget build(BuildContext context) {
    // U-6: ancho fijo al 94% de la pantalla (máx 1200).
    // D-FIX overflow: 8 botones fijos de 40dp + separadores + padding =
    // 338dp vs 338.4dp disponibles en 360dp de pantalla — margen 0.4dp que
    // desbordaba con cualquier redondeo. Botones ahora Expanded (min 32dp):
    // se reparten el ancho real y NO desbordan en ninguna resolución.
    final barWidth = math.min(MediaQuery.sizeOf(context).width * 0.94, 1200.0);

    return Container(
      width: barWidth,
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
      decoration: BoxDecoration(
        color: colors.surface.withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colors.outlineVariant),
        boxShadow: const [
          BoxShadow(
            color: Colors.black45,
            blurRadius: 10,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Fila 1: mouse/rueda/zoom + toggle de teclado. Siempre visible.
          // Cada botón Expanded: reparto equitativo del ancho — sin Spacer
          // ni anchos fijos que desbordaban (D-FIX).
          Row(
            children: [
              Expanded(
                child: _barButton(
                  Icons.mouse_rounded,
                  'Clic izquierdo',
                  onLeftClick,
                ),
              ),
              Expanded(
                child: _barButton(
                  Icons.ads_click_rounded,
                  'Clic derecho',
                  onRightClick,
                ),
              ),
              _separator(),
              Expanded(
                child: _barButton(
                  Icons.arrow_upward_rounded,
                  'Rueda arriba',
                  onWheelUp,
                ),
              ),
              Expanded(
                child: _barButton(
                  Icons.arrow_downward_rounded,
                  'Rueda abajo',
                  onWheelDown,
                ),
              ),
              _separator(),
              Expanded(
                child: _barButton(Icons.zoom_out_rounded, 'Alejar', onZoomOut),
              ),
              Expanded(
                child: _barButton(Icons.zoom_in_rounded, 'Acercar', onZoomIn),
              ),
              Expanded(
                child: _barButton(
                  Icons.zoom_out_map_rounded,
                  'Zoom 100%',
                  zoom > 1.0 ? onResetZoom : null,
                ),
              ),
              Expanded(
                child: _barButton(
                  Icons.expand_less_rounded,
                  expanded ? 'Colapsar' : 'Expandir',
                  onToggleExpanded,
                  highlighted: expanded,
                ),
              ),
            ],
          ),
          // Fila 2: teclas rápidas X11 — el IME móvil no trae Esc/Tab/Ctrl/
          // Alt/flechas; sin ellas no hay Ctrl+C ni diálogo cerrable.
          // Plegable (U-6): colapsada no tapa el framebuffer.
          if (expanded) ...[
            const SizedBox(height: 6),
            Row(
              children: [
                _keyChip('Esc', () => onQuickKey(0xFF1B)),
                _keyChip('Tab', () => onQuickKey(0xFF09)),
                _keyChip('Ctrl', onToggleCtrl, active: ctrlActive),
                _keyChip('Alt', onToggleAlt, active: altActive),
                _keyChip('↵', () => onQuickKey(0xFF0D)),
                _keyChip('←', () => onQuickKey(0xFF51)),
                _keyChip('↑', () => onQuickKey(0xFF52)),
                _keyChip('↓', () => onQuickKey(0xFF54)),
                _keyChip('→', () => onQuickKey(0xFF53)),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _separator() => Container(
    width: 1,
    height: 28,
    margin: const EdgeInsets.symmetric(horizontal: 1),
    color: colors.outlineVariant,
  );

  Widget _barButton(
    IconData icon,
    String tooltip,
    VoidCallback? onTap, {
    bool highlighted = false,
  }) {
    final enabled = onTap != null;
    return IconButton(
      onPressed: onTap,
      icon: Icon(
        icon,
        color: highlighted
            ? colors.accent
            : enabled
            ? colors.onSurfaceVariant
            : colors.onSurface.withValues(alpha: 0.24),
        size: 22,
      ),
      tooltip: tooltip,
      // D-FIX: minWidth 40dp fijo desbordaba la fila en 360dp (8×40 +
      // separadores = 326 vs 326.4 disponibles). El Expanded del Row reparte
      // el ancho; minWidth 32 es solo el piso (350dp/9 slots ≈ 39dp reales).
      // Alto 44 conserva el piso táctil práctico.
      constraints: const BoxConstraints(minWidth: 32, minHeight: 44),
      padding: EdgeInsets.zero,
      style: IconButton.styleFrom(
        minimumSize: const Size(32, 44),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        padding: EdgeInsets.zero,
      ),
    );
  }

  // Chip de tecla expandido uniformemente: ancho real de ~100px en 1080 de
  // pantalla, altura táctil 44. Nada de texto de 12px apretado.
  Widget _keyChip(String label, VoidCallback onTap, {bool active = false}) {
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 3),
        child: Material(
          color: active
              ? colors.accent.withValues(alpha: 0.25)
              : colors.onSurface.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(10),
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(10),
            child: Container(
              alignment: Alignment.center,
              constraints: const BoxConstraints(minHeight: 44),
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: active ? colors.accent : colors.onSurface,
                ),
              ),
            ),
          ),
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
    final colors = NanoThemeExtension.of(context).colors;
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
            boxShadow: const [BoxShadow(color: Colors.black54, blurRadius: 24)],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.gesture_rounded,
                    color: colors.accent,
                    size: 22,
                  ),
                  const SizedBox(width: 8),
                  const Text(
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
              _helpRow(
                Icons.touch_app_rounded,
                'Zona superior:',
                'tap = clic · arrastrar = mover',
              ),
              _helpRow(
                Icons.linear_scale_rounded,
                'Zona inferior (touchpad):',
                'arrastra = cursor sin clic · tap = clic',
              ),
              _helpRow(
                Icons.pinch_rounded,
                'Pellizco 2 dedos:',
                'zoom hasta 400%',
              ),
              _helpRow(
                Icons.swipe_rounded,
                '2 dedos con zoom:',
                'desplazar la vista (pan)',
              ),
              _helpRow(
                Icons.mouse_rounded,
                'Barra inferior:',
                'clics, rueda de scroll y zoom',
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: onDismiss,
                  icon: const Icon(Icons.check_rounded, size: 18),
                  label: const Text('Entendido'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: colors.accent,
                    foregroundColor: colors.onAccent,
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
  final bool isMobileMode;
  final VoidCallback onBack;
  final VoidCallback onRefresh;
  final VoidCallback onToggleKeyboard;
  final VoidCallback onToggleMode;

  const _FloatingControlBar({
    required this.status,
    required this.connected,
    required this.busy,
    required this.showKeyboard,
    required this.isMobileMode,
    required this.onBack,
    required this.onRefresh,
    required this.onToggleKeyboard,
    required this.onToggleMode,
  });

  @override
  Widget build(BuildContext context) {
    final colors = NanoThemeExtension.of(context).colors;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: colors.surface.withValues(alpha: 0.85),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colors.outlineVariant),
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
            onPressed: onBack,
            icon: Icon(
              Icons.arrow_back_rounded,
              color: colors.onSurface,
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
                  ? colors.success
                  : busy
                  ? colors.info
                  : colors.warning,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 8),
          Flexible(
            fit: FlexFit.loose,
            child: Text(
              status,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: colors.onSurface,
              ),
            ),
          ),
          IconButton(
            onPressed: onToggleKeyboard,
            icon: Icon(
              Icons.keyboard_rounded,
              color: showKeyboard ? colors.accent : colors.onSurfaceVariant,
              size: 20,
            ),
            tooltip: 'Teclado táctil',
            constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
            padding: EdgeInsets.zero,
          ),
          const SizedBox(width: 4),
          Container(
            width: 1,
            height: 20,
            color: colors.outlineVariant,
          ),
          const SizedBox(width: 4),
          // D-FIX: el modo era un icono ambiguo sin texto. Ahora es un chip
          // con etiqueta del modo ACTUAL — el tap alterna. Resaltado azul
          // paleta Nano cuando está en PC (desktop), tenue en Táctil.
          Material(
            color: isMobileMode
                ? Colors.transparent
                : colors.accent.withValues(alpha: 0.16),
            borderRadius: BorderRadius.circular(10),
            child: InkWell(
              onTap: onToggleMode,
              borderRadius: BorderRadius.circular(10),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 7),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      isMobileMode
                          ? Icons.phone_android_rounded
                          : Icons.desktop_windows_rounded,
                      size: 16,
                      color: isMobileMode
                          ? colors.onSurfaceVariant
                          : colors.accent,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      isMobileMode ? 'Táctil' : 'PC',
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: isMobileMode
                            ? colors.onSurfaceVariant
                            : colors.accent,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          IconButton(
            onPressed: busy ? null : onRefresh,
            icon: busy
                ? SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: colors.onSurface,
                    ),
                  )
                : Icon(
                    Icons.refresh_rounded,
                    color: colors.onSurfaceVariant,
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

/// FAB radial circular minimalista para acceso rápido a apps del escritorio.
/// Se expande en círculo con iconos minimalistas, aprovechando el espacio
/// de forma eficiente sin sabana lateral.
class _RadialFab extends StatefulWidget {
  final bool isOpen;
  final VoidCallback onToggle;
  final VoidCallback onOpenApps;
  final VoidCallback onToggleKeyboard;
  final bool showKeyboard;

  const _RadialFab({
    required this.isOpen,
    required this.onToggle,
    required this.onOpenApps,
    required this.onToggleKeyboard,
    required this.showKeyboard,
  });

  @override
  State<_RadialFab> createState() => _RadialFabState();
}

class _RadialFabState extends State<_RadialFab>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 250),
      vsync: this,
    );
    _scaleAnimation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeInOut,
    );
    if (widget.isOpen) {
      _controller.value = 1.0;
    }
  }

  @override
  void didUpdateWidget(_RadialFab oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isOpen != oldWidget.isOpen) {
      if (widget.isOpen) {
        _controller.forward();
      } else {
        _controller.reverse();
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = NanoThemeExtension.of(context).colors;
    return SizedBox(
      width: 56,
      height: 56,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Ítems radiales (aparecen cuando isOpen = true)
          if (widget.isOpen) ...[
            _RadialFabItem(
              angle: -45,
              distance: 70,
              icon: Icons.terminal_rounded,
              label: 'Terminal',
              onTap: () {
                widget.onToggle();
                widget.onOpenApps();
              },
              animation: _scaleAnimation,
            ),
            _RadialFabItem(
              angle: 0,
              distance: 80,
              icon: Icons.folder_rounded,
              label: 'Archivos',
              onTap: () {
                widget.onToggle();
                widget.onOpenApps();
              },
              animation: _scaleAnimation,
            ),
            _RadialFabItem(
              angle: 45,
              distance: 70,
              icon: Icons.edit_rounded,
              label: 'Editor',
              onTap: () {
                widget.onToggle();
                widget.onOpenApps();
              },
              animation: _scaleAnimation,
            ),
            _RadialFabItem(
              angle: 90,
              distance: 50,
              icon: Icons.image_rounded,
              label: 'Imágenes',
              onTap: () {
                widget.onToggle();
                widget.onOpenApps();
              },
              animation: _scaleAnimation,
            ),
          ],
          // Botón principal
          ScaleTransition(
            scale: _scaleAnimation,
            child: FloatingActionButton(
              heroTag: 'radial_fab',
              onPressed: widget.onToggle,
              // D-FIX: FAB verde 0xFF10B981 fuera de paleta — azul Nano
              // 0xFF42D9FF igual que Reintentar/teclado/modo.
              backgroundColor: colors.accent,
              foregroundColor: colors.onAccent,
              elevation: 6,
              child: AnimatedIcon(
                icon: AnimatedIcons.menu_close,
                progress: _scaleAnimation,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Ítem individual del FAB radial
class _RadialFabItem extends StatelessWidget {
  final double angle;
  final double distance;
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Animation<double> animation;

  const _RadialFabItem({
    required this.angle,
    required this.distance,
    required this.icon,
    required this.label,
    required this.onTap,
    required this.animation,
  });

  @override
  Widget build(BuildContext context) {
    final colors = NanoThemeExtension.of(context).colors;
    final radians = angle * math.pi / 180;
    final x = math.cos(radians) * distance;
    final y = math.sin(radians) * distance;

    return AnimatedBuilder(
      animation: animation,
      builder: (context, child) {
        final scale = animation.value;
        final opacity = animation.value;
        final offsetX = x * scale;
        final offsetY = y * scale;

        return Transform.translate(
          offset: Offset(offsetX, offsetY),
          child: Opacity(
            opacity: opacity,
            child: ScaleTransition(
              scale: animation,
              child: child,
            ),
          ),
        );
      },
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: colors.surface.withValues(alpha: 0.9),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: colors.outlineVariant),
            boxShadow: const [
              BoxShadow(
                color: Colors.black45,
                blurRadius: 8,
                offset: Offset(0, 2),
              ),
            ],
          ),
          child: Icon(
            icon,
            color: colors.onSurface,
            size: 24,
          ),
        ),
      ),
    );
  }
}
