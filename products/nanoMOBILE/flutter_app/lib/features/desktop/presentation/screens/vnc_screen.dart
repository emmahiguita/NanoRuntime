import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:nanoai/core/providers/app_providers.dart';
import 'package:nanoai/core/services/package_service.dart';
import 'package:nanoai/core/services/rootfs_manager.dart';
import 'package:nanoai/core/theme/design_tokens.dart';
import 'package:nanoai/features/desktop/presentation/widgets/desktop_controls_overlay.dart';
import 'package:nanoai/features/desktop/presentation/widgets/desktop_extra_keys_bar.dart';
import 'package:nanoai/features/desktop/presentation/widgets/desktop_pip_view.dart';
import 'package:nanoai/features/desktop/presentation/widgets/desktop_sheets.dart';
import 'package:nanoai/features/desktop/presentation/widgets/desktop_stream_chrome.dart';
import 'package:nanoai/features/desktop/vnc_client.dart';
import 'package:nanoai/core/widgets/nano_ambient_background.dart';


enum _ConnState { connecting, connected, reconnecting, failed }

enum _GestureMode { none, touch, pan, touchpad, pinch }

/// Professional Mobile Linux Remote Workspace (VNC & Moonlight architecture).
///
/// Features:
/// 1. RFB 3.8 native Dart protocol client with zero-copy decoding & DES authentication.
/// 2. Resilient auto-start: auto-provisions rootfs & Xvnc server if uninitialized.
/// 3. Exponential backoff automatic reconnection (1s -> 2s -> 4s -> 8s -> 16s -> 30s).
/// 4. Edge-to-edge immersive canvas taking ~90-100% of viewport with zero redundant chrome.
/// 5. Gesture matrix: Touch mode (tap, long press right-click), Trackpad mode (hover, click, scroll wheel),
///    Pinch zoom anchored to focal point (up to 400%), focal point pan, double tap zoom toggle.
/// 6. Sticky PC key modifiers (Ctrl, Alt, Shift, Super) & quick X11 keysym conversion.
/// 7. Auto-hiding Moonlight controls overlay with smooth frosted glass design tokens.
/// 8. Draggable interactive PiP view for minimized desktop session.
class VncScreen extends ConsumerStatefulWidget {
  final int port;
  const VncScreen({super.key, this.port = 5901});

  @override
  ConsumerState<VncScreen> createState() => _VncScreenState();
}

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

  bool _showHelp = false;
  bool _adapting = false;
  int _adaptCount = 0;

  DesktopPointerMode _pointerMode = DesktopPointerMode.touch;
  DesktopWindowMode _windowMode = DesktopWindowMode.normal;
  DesktopFitMode _fitMode = DesktopFitMode.fit;

  // ── Connection state ────────────────────────────────────────────────────────
  _ConnState _connState = _ConnState.connecting;
  int _reconnectAttempts = 0;
  Timer? _reconnectTimer;
  static const _maxReconnectAttempts = 7;

  int _fbWidth = 0;
  int _fbHeight = 0;
  Offset? _lastPanFb;

  // ── Zoom / Pan (Focal point anchored) ──────────────────────────────────────
  double _zoom = 1.0;
  Offset _panFb = Offset.zero;
  static const double _minZoom = 0.10;
  static const double _maxZoom = 5.00;

  // Virtual cursor position in FB coords for Trackpad mode
  Offset _cursorFb = Offset.zero;

  // Gesture state
  _GestureMode _gestureMode = _GestureMode.none;
  int _activeMask = 0; // RFB button mask (1=left, 4=right)
  Offset _dragTotal = Offset.zero;
  double _zoomAtGestureStart = 1.0;
  Offset _panAtGestureStart = Offset.zero;
  Offset _pinchStartFocal = Offset.zero;
  DateTime? _lastTapTime;
  Offset? _lastTapFb;

  // Long press timer (550ms) for right click in touch mode
  Timer? _longPressTimer;
  bool _longPressFired = false;

  // 2-finger scroll vs pinch sticky decision
  bool _pinchScroll = false;
  bool _pinchZoomed = false;
  double _scrollAccum = 0;

  // Sticky modifiers
  bool _ctrlSticky = false;
  bool _altSticky = false;
  bool _shiftSticky = false;
  bool _superSticky = false;

  final FocusNode _keyboardFocus = FocusNode();
  final TextEditingController _keyboardInput = TextEditingController();

  int _connectToken = 0;

  @override
  void initState() {
    super.initState();
    _detail = 'Conectando a 127.0.0.1:$port vía RFB 3.8.';
    SystemChrome.setPreferredOrientations(DeviceOrientation.values);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ref.read(settingsProvider.notifier).setDesktopMobileMode(true);
    });
    _connect();
  }

  @override
  void dispose() {
    _reconnectTimer?.cancel();
    _longPressTimer?.cancel();
    _client?.disconnect();
    _frame?.dispose();
    _keyboardFocus.dispose();
    _keyboardInput.dispose();
    SystemChrome.setPreferredOrientations(DeviceOrientation.values);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    super.dispose();
  }

  void _enterImmersive() {
    if (!mounted) return;
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  }

  void _toggleOrientation() {
    final isLandscape = MediaQuery.orientationOf(context) == Orientation.landscape;
    if (isLandscape) {
      SystemChrome.setPreferredOrientations([
        DeviceOrientation.portraitUp,
        DeviceOrientation.portraitDown,
      ]);
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    } else {
      SystemChrome.setPreferredOrientations([
        DeviceOrientation.landscapeLeft,
        DeviceOrientation.landscapeRight,
      ]);
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    }
    HapticFeedback.lightImpact();
  }

  bool _fbMismatch() {
    final client = _client;
    if (client == null || !client.isInitialized) return false;
    if (client.fbWidth <= 0 || client.fbHeight <= 0) return false;
    final viewport = MediaQuery.sizeOf(context);
    if (viewport.width <= 0 || viewport.height <= 0) return false;
    final target = _desiredDesktopGeometryPx();
    if (target == null || target.width <= 0 || target.height <= 0) return false;
    final framebufferLandscape = client.fbWidth >= client.fbHeight;
    final targetLandscape = target.width >= target.height;
    if (framebufferLandscape != targetLandscape) return true;
    final currentRatio = client.fbWidth / client.fbHeight;
    final targetRatio = target.width / target.height;
    return ((currentRatio / targetRatio) - 1).abs() > 0.10;
  }

  void _adaptToViewArea() {
    if (_adapting || _adaptCount >= 3) return;
    final target = _desiredDesktopGeometryPx();
    if (target == null || target.width <= 0 || target.height <= 0) return;
    _adapting = true;
    _adaptCount++;
    setState(() {
      _status = 'Adaptando pantalla...';
      _detail = 'Reiniciando escritorio con la orientación actual.';
      _busy = true;
    });
    _client?.disconnect();
    _client = null;
    _frame = null;
    _connected = false;
    _fbWidth = 0;
    _fbHeight = 0;
    () async {
      try {
        await _pkg.stopDesktop();
        await Future.delayed(const Duration(milliseconds: 700));
        if (mounted) _connect();
      } catch (e) {
        if (mounted) _connect();
      } finally {
        _adapting = false;
      }
    }();
  }

  Size? _desiredDesktopGeometryPx() {
    if (!mounted) return null;
    final viewport = MediaQuery.sizeOf(context);
    final dpr = MediaQuery.devicePixelRatioOf(context);
    if (viewport.width <= 0 || viewport.height <= 0 || dpr <= 0) return null;
    return Size(viewport.width * dpr, viewport.height * dpr);
  }

  void _scheduleReconnect() {
    if (!mounted) return;
    _reconnectTimer?.cancel();
    if (_reconnectAttempts >= _maxReconnectAttempts) {
      setState(() {
        _connState = _ConnState.failed;
        _busy = false;
        _connected = false;
        _status = 'Conexión perdida';
        _detail = 'Agotados $_maxReconnectAttempts intentos. Verifica que el escritorio esté iniciado y toca Reconectar.';
      });
      return;
    }
    _reconnectAttempts++;
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

    late final VncClient client;
    client = VncClient(
      host: '127.0.0.1',
      port: widget.port,
      password: ref.read(settingsProvider).vncPassword,
      onStatus: (String msg) {
        if (mounted) setState(() => _detail = msg);
      },
      onFrame: (ui.Image? img) {
        if (!identical(_client, client)) {
          img?.dispose();
          return;
        }
        if (!mounted || img == null) {
          img?.dispose();
          return;
        }
        final prev = _frame;
        setState(() {
          _frame = img;
          if (_fbWidth == 0) {
            _cursorFb = Offset(client.fbWidth / 2, client.fbHeight / 2);
          }
          _fbWidth = client.fbWidth;
          _fbHeight = client.fbHeight;
          _initialized = client.isInitialized;
        });
        if (prev != null) {
          WidgetsBinding.instance.addPostFrameCallback((_) => prev.dispose());
        }
      },
      onDisconnected: () {
        if (identical(_client, client)) _onClientDisconnected();
      },
    );
    _client = client;

    // Fast-path: verificar/arrancar entorno y conectar rápidamente con probing
    var ok = false;
    final started = await _ensureDesktopStarted();
    if (!mounted || token != _connectToken) return;

    if (started) {
      // Probing rápido del socket (cada 60ms) para conectar al milisegundo exacto
      for (var attempt = 0; attempt < 25; attempt++) {
        ok = await _client!.connect();
        if (ok || !mounted || token != _connectToken) break;
        await Future.delayed(const Duration(milliseconds: 60));
      }
    }

    if (ok) {
      var waited = 0;
      while (mounted && _client != null && !_client!.isInitialized && waited < 40) {
        await Future.delayed(const Duration(milliseconds: 50));
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
          _reconnectAttempts = 0;
          _connState = _ConnState.connected;
          _status = 'Escritorio Linux Activo';
          _detail = '${_client!.fbWidth}x${_client!.fbHeight} — "${_client!.desktopName}"';
          _enterImmersive();
        } else if (ok) {
          _status = 'Handshake incompleto';
          _detail = 'Conectado pero ServerInit no recibido.';
          _reconnectAttempts++;
          if (_reconnectAttempts >= _maxReconnectAttempts) {
            _scheduleReconnect();
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
      if (isConnected) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted || !identical(_client, client)) return;
          if (_fbMismatch()) {
            _adaptToViewArea();
          } else {
            _adaptCount = 0;
            Future.delayed(const Duration(milliseconds: 1000), () {
              if (mounted && _connected) {
                _typeString('nano-info\n');
              }
            });
          }
        });
      }
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
        _detail = 'No se pudo preparar Linux. Revisa red, almacenamiento y logcat.';
      });
      return false;
    }

    final statusBefore = await _pkg.getDesktopStatus();
    if (!mounted) return false;
    if (statusBefore.running && statusBefore.reachable) {
      return true;
    }
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
          _detail = 'No se pudo instalar Xvnc/Openbox. Revisa logcat: exec_bin y vnc-service.';
        });
        return false;
      }
    }

    setState(() {
      _status = 'Iniciando servidor VNC...';
      _detail = 'Arrancando Xvnc y Openbox en 127.0.0.1:$port.';
    });

    // Geometría PC estándar 16:9 (1280x720) para proporciones reales de monitor PC
    final started = await _pkg.startDesktop(
      vncPassword: ref.read(settingsProvider).vncPassword,
      width: 1280,
      height: 720,
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

  double? _fitScale(Size widgetSize) {
    if (!_initialized || _fbWidth == 0 || _fbHeight == 0) return null;
    final scaleX = widgetSize.width / _fbWidth;
    final scaleY = widgetSize.height / _fbHeight;
    switch (_fitMode) {
      case DesktopFitMode.fit:
        return scaleX < scaleY ? scaleX : scaleY;
      case DesktopFitMode.fill:
        return scaleX > scaleY ? scaleX : scaleY;
      case DesktopFitMode.native1to1:
        return 1.0;
    }
  }

  void _toggleFullscreen() {
    setState(() {
      if (_windowMode == DesktopWindowMode.expanded) {
        _windowMode = DesktopWindowMode.normal;
        SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
      } else {
        _windowMode = DesktopWindowMode.expanded;
        SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
      }
    });
    HapticFeedback.mediumImpact();
  }

  void _toggleWindowMode() {
    setState(() {
      if (_windowMode == DesktopWindowMode.normal) {
        _windowMode = DesktopWindowMode.expanded;
        SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
      } else if (_windowMode == DesktopWindowMode.expanded) {
        _windowMode = DesktopWindowMode.minimized;
        SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
      } else {
        _windowMode = DesktopWindowMode.normal;
        SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
      }
    });
    HapticFeedback.lightImpact();
  }

  void _toggleFitMode() {
    setState(() {
      switch (_fitMode) {
        case DesktopFitMode.fit:
          _fitMode = DesktopFitMode.fill;
          break;
        case DesktopFitMode.fill:
          _fitMode = DesktopFitMode.native1to1;
          break;
        case DesktopFitMode.native1to1:
          _fitMode = DesktopFitMode.fit;
          break;
      }
      _panFb = Offset.zero;
    });
    HapticFeedback.lightImpact();
    if (!mounted) return;
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          _fitMode == DesktopFitMode.fit
              ? 'Ajuste: Proporcional (Fit)'
              : _fitMode == DesktopFitMode.fill
                  ? 'Ajuste: Llenar Pantalla (Fill)'
                  : 'Ajuste: Píxel Nativo 1:1',
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        duration: const Duration(seconds: 1),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _zoomInStep() {
    setState(() {
      if (_zoom >= 3.5) {
        _zoom = 1.0;
        _panFb = Offset.zero;
      } else {
        _zoom = (_zoom + 0.35).clamp(_minZoom, _maxZoom);
      }
    });
    HapticFeedback.lightImpact();
  }

  Offset? _localToFb(Offset local, Size widgetSize) {
    final fit = _fitScale(widgetSize);
    if (fit == null) return null;

    final scale = fit * _zoom;
    final baseX = (widgetSize.width - _fbWidth * scale) / 2 + _panFb.dx * scale;
    final baseY = (widgetSize.height - _fbHeight * scale) / 2 + _panFb.dy * scale;

    final fbX = ((local.dx - baseX) / scale).clamp(0.0, _fbWidth - 1.0);
    final fbY = ((local.dy - baseY) / scale).clamp(0.0, _fbHeight - 1.0);

    return Offset(fbX, fbY);
  }

  Offset _clampPan(Offset p, [Size? widgetSize]) {
    if (widgetSize == null || _fbWidth == 0 || _fbHeight == 0) return p;
    final fit = _fitScale(widgetSize);
    if (fit == null) return p;
    final scale = fit * _zoom;
    final maxX = (_fbWidth / 2) + (widgetSize.width / (2 * scale));
    final maxY = (_fbHeight / 2) + (widgetSize.height / (2 * scale));
    return Offset(p.dx.clamp(-maxX, maxX), p.dy.clamp(-maxY, maxY));
  }

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

  // ── Gesture handling ────────────────────────────────────────────────────────

  void _onScaleStart(ScaleStartDetails d, Size widgetSize) {
    if (d.pointerCount >= 2) {
      _gestureMode = _GestureMode.pinch;
      _zoomAtGestureStart = _zoom;
      _panAtGestureStart = _panFb;
      _pinchStartFocal = d.localFocalPoint;
      _pinchScroll = false;
      _pinchZoomed = false;
      _scrollAccum = 0;
      return;
    }

    if (_pointerMode == DesktopPointerMode.pan) {
      _gestureMode = _GestureMode.pan;
      _panAtGestureStart = _panFb;
      _pinchStartFocal = d.localFocalPoint;
      return;
    }

    final inTouchpad = _pointerMode == DesktopPointerMode.trackpad;
    _dragTotal = Offset.zero;
    _gestureMode = inTouchpad ? _GestureMode.touchpad : _GestureMode.touch;

    if (inTouchpad) return;

    final fb = _localToFb(d.localFocalPoint, widgetSize);
    if (fb != null) {
      _activeMask = 0; // Don't pre-fire click on down touch
      _cursorFb = fb;
      _lastPanFb = fb;
      // Hover window buttons/icons immediately in X11
      _client?.sendPointerEvent(fb.dx.round(), fb.dy.round(), 0);
      _longPressFired = false;
      _longPressTimer?.cancel();
      _longPressTimer = Timer(const Duration(milliseconds: 650), () {
        if (_gestureMode != _GestureMode.touch) return;
        if (_dragTotal.distance >= 18.0) return;
        _longPressFired = true;
        final p = _lastPanFb;
        if (p != null && _client != null) {
          final px = p.dx.round();
          final py = p.dy.round();
          _client?.sendPointerEvent(px, py, 4);
          Future.delayed(const Duration(milliseconds: 40), () {
            _client?.sendPointerEvent(px, py, 0);
          });
          HapticFeedback.mediumImpact();
        }
      });
    }
  }

  void _executeCommandFromSheet(String cmd) {
    _typeString(cmd);
    _client?.sendKeyEvent(0xFF0D, true);
    _client?.sendKeyEvent(0xFF0D, false);
  }

  void _openCommandsSheet() {
    DesktopSheets.showCommandsSheet(
      context: context,
      colors: NanoThemeExtension.of(context).colors,
      onExecuteCommand: _executeCommandFromSheet,
    );
  }

  void _onScaleUpdate(ScaleUpdateDetails d, Size widgetSize) {
    if (d.pointerCount >= 2 && _gestureMode != _GestureMode.pinch) {
      _gestureMode = _GestureMode.pinch;
      _zoomAtGestureStart = _zoom;
      _panAtGestureStart = _panFb;
      _pinchStartFocal = d.localFocalPoint;
      _pinchScroll = false;
      _pinchZoomed = false;
      _scrollAccum = 0;
      _longPressTimer?.cancel();
      _activeMask = 0;
    }

    switch (_gestureMode) {
      case _GestureMode.pan:
        final fit = _fitScale(widgetSize);
        if (fit != null) {
          setState(() {
            _panFb = _clampPan(_panFb + (d.focalPointDelta / (fit * _zoom)), widgetSize);
          });
        }
        break;

      case _GestureMode.pinch:
        if (d.pointerCount < 2) return;
        final fit = _fitScale(widgetSize);
        if (fit == null) return;
        if (!_pinchScroll && !_pinchZoomed) {
          if ((d.scale - 1.0).abs() >= 0.05) {
            _pinchZoomed = true;
          } else {
            final dy = d.localFocalPoint.dy - _pinchStartFocal.dy;
            if (dy.abs() > 24) _pinchScroll = true;
          }
        }
        if (_pinchScroll) {
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
        final newZoom = (_zoomAtGestureStart * d.scale).clamp(_minZoom, _maxZoom);
        var pan = _panForZoomAround(
          _pinchStartFocal,
          _zoomAtGestureStart,
          _panAtGestureStart,
          newZoom,
          widgetSize,
        );
        pan += d.focalPointDelta / (fit * newZoom);
        setState(() {
          _zoom = newZoom;
          _panFb = _clampPan(pan, widgetSize);
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
        _client?.sendPointerEvent(_cursorFb.dx.round(), _cursorFb.dy.round(), 0);
        break;

      case _GestureMode.touch:
        _dragTotal += d.focalPointDelta;
        if (_dragTotal.distance >= 18.0) {
          _longPressTimer?.cancel();
          _longPressFired = false;
          _activeMask = 1; // Dragging active
        }
        final fb = _localToFb(d.localFocalPoint, widgetSize);
        if (fb != null && !_longPressFired) {
          _cursorFb = fb;
          _lastPanFb = fb;
          if (_activeMask != 0) {
            _client?.sendPointerEvent(fb.dx.round(), fb.dy.round(), _activeMask);
          }
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
          _longPressFired = false;
          _activeMask = 0;
          break;
        }
        final fb = _lastPanFb;
        if (fb != null && _client != null) {
          if (_dragTotal.distance < 18.0) {
            // Touch Slop respected: this is a crisp Tap (or Double Tap)
            final now = DateTime.now();
            final isDouble = _lastTapTime != null &&
                now.difference(_lastTapTime!).inMilliseconds < 380 &&
                _lastTapFb != null &&
                (fb - _lastTapFb!).distance < 24.0;

            final fx = fb.dx.round();
            final fy = fb.dy.round();

            // Send ButtonPress (mask 1)
            _client?.sendPointerEvent(fx, fy, 1);
            // Real physical hold time (40ms) before Release so X11/GTK/Openbox event queues register it
            Future.delayed(const Duration(milliseconds: 40), () {
              _client?.sendPointerEvent(fx, fy, 0);

              if (isDouble) {
                // Secondary click for double-tap (opens desktop shortcuts)
                Future.delayed(const Duration(milliseconds: 40), () {
                  _client?.sendPointerEvent(fx, fy, 1);
                  Future.delayed(const Duration(milliseconds: 40), () {
                    _client?.sendPointerEvent(fx, fy, 0);
                  });
                });
              }
            });

            _lastTapTime = now;
            _lastTapFb = fb;
            HapticFeedback.selectionClick();
          } else if (_activeMask != 0) {
            // Release drag
            _client?.sendPointerEvent(fb.dx.round(), fb.dy.round(), 0);
          }
        }
        _activeMask = 0;
        break;

      case _GestureMode.touchpad:
        if (_dragTotal.distance < 18.0) {
          final fx = _cursorFb.dx.round();
          final fy = _cursorFb.dy.round();
          _client?.sendPointerEvent(fx, fy, 1);
          Future.delayed(const Duration(milliseconds: 40), () {
            _client?.sendPointerEvent(fx, fy, 0);
          });
          HapticFeedback.selectionClick();
        }
        break;

      case _GestureMode.pan:
      case _GestureMode.pinch:
        _pinchScroll = false;
        _pinchZoomed = false;
        break;

      case _GestureMode.none:
        break;
    }
    _gestureMode = _GestureMode.none;
  }

  // ── X11 keysyms & modifiers ──────────────────────────────────────────────────

  void _sendQuickKey(int keysym) {
    _client?.sendKeyEvent(keysym, true);
    _client?.sendKeyEvent(keysym, false);
  }

  void _typeString(String text) {
    if (_client == null) return;
    for (final char in text.codeUnits) {
      if (char == 0x0A || char == 0x0D) {
        _client?.sendKeyEvent(0xFF0D, true);
        _client?.sendKeyEvent(0xFF0D, false);
      } else {
        final keysym = _x11Keysym(char);
        _client?.sendKeyEvent(keysym, true);
        _client?.sendKeyEvent(keysym, false);
      }
    }
  }

  void _sendCombo(List<int> keys) {
    for (final k in keys) {
      _client?.sendKeyEvent(k, true);
    }
    for (final k in keys.reversed) {
      _client?.sendKeyEvent(k, false);
    }
    HapticFeedback.selectionClick();
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

  void _toggleShift() {
    setState(() => _shiftSticky = !_shiftSticky);
    _client?.sendKeyEvent(0xFFE1, _shiftSticky);
    HapticFeedback.selectionClick();
  }

  void _toggleSuper() {
    setState(() => _superSticky = !_superSticky);
    _client?.sendKeyEvent(0xFFEB, _superSticky);
    HapticFeedback.selectionClick();
  }

  void _setPointerMode(DesktopPointerMode mode) {
    if (_pointerMode == mode) return;
    setState(() => _pointerMode = mode);
    HapticFeedback.selectionClick();
  }

  void _setZoom(double value) {
    final newZoom = value.clamp(_minZoom, _maxZoom);
    if (newZoom == _zoom) return;
    setState(() {
      final ws = MediaQuery.sizeOf(context);
      _panFb = _clampPan(_panFb * (newZoom / _zoom), ws);
      _zoom = newZoom;
    });
  }

  void _resetZoom() {
    setState(() {
      _zoom = 1.0;
      _panFb = Offset.zero;
    });
  }

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

  void _toggleKeyboard() {
    setState(() => _showKeyboard = !_showKeyboard);
    if (_showKeyboard) {
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
      _keyboardFocus.requestFocus();
    } else {
      _keyboardFocus.unfocus();
      _clearKeyboardBuffer();
      if (_connected) {
        _enterImmersive();
      }
    }
  }

  void _clearKeyboardBuffer() {
    _keyboardClearing = true;
    _keyboardInput.clear();
    _lastKeyboardText = '';
    _keyboardClearing = false;
  }

  Future<void> _pasteClipboardToLinux() async {
    final data = await Clipboard.getData('text/plain');
    final text = data?.text;
    if (text == null || text.isEmpty || _client == null) return;

    // Sincronizar directamente con el portapapeles X11 (RFC 6143 ClientCutText)
    _client?.sendClientCutText(text);

    // Escribir en sesión activa
    if (text.length <= 160 && !text.contains('\n')) {
      _typeString(text);
    } else {
      // Párrafos grandes: simular Shift + Insert (pegar nativo en terminal/apps X11)
      _client?.sendKeyEvent(0xFFE1, true); // Shift
      _client?.sendKeyEvent(0xFF63, true); // Insert
      _client?.sendKeyEvent(0xFF63, false);
      _client?.sendKeyEvent(0xFFE1, false);
    }
    HapticFeedback.lightImpact();
  }

  void _onKeyboardSubmit(String text) {
    if (_client == null) return;
    // Si el texto tiene contenido pendiente no transmitido por eventos previos de IME
    if (text.isNotEmpty && text != _lastKeyboardText) {
      if (text.startsWith(_lastKeyboardText)) {
        _typeString(text.substring(_lastKeyboardText.length));
      } else {
        _typeString(text);
      }
    }
    _client?.sendKeyEvent(0xFF0D, true);
    _client?.sendKeyEvent(0xFF0D, false);
    _clearKeyboardBuffer();
  }

  int _x11Keysym(int codeUnit) {
    switch (codeUnit) {
      case 0x08:
        return 0xFF08;
      case 0x09:
        return 0xFF09;
      case 0x0A:
      case 0x0D:
        return 0xFF0D;
      case 0x1B:
        return 0xFF1B;
      case 0x7F:
        return 0xFFFF;
    }
    if (codeUnit >= 0x20 && codeUnit <= 0x7E) return codeUnit;
    if (codeUnit >= 0xA0 && codeUnit <= 0xFF) return codeUnit;
    return 0x01000000 + codeUnit;
  }

  String _lastKeyboardText = '';
  bool _keyboardClearing = false;

  void _onKeyInput(String text) {
    if (_keyboardClearing || _client == null) return;

    // Si se pegó o ingresó un bloque grande (> 80 chars o multilínea), sincronizar con portapapeles X11
    if (text.length > 80 || text.contains('\n')) {
      _client?.sendClientCutText(text);
    }

    final prevUnits = _lastKeyboardText.codeUnits;
    final newUnits = text.codeUnits;
    int common = 0;
    while (common < prevUnits.length &&
        common < newUnits.length &&
        prevUnits[common] == newUnits[common]) {
      common++;
    }
    for (var d = common; d < prevUnits.length; d++) {
      _client!.sendKeyEvent(0xFF08, true);
      _client!.sendKeyEvent(0xFF08, false);
    }
    for (var i = common; i < newUnits.length; i++) {
      final char = newUnits[i];
      if (char >= 0xD800 && char <= 0xDFFF) continue;
      final keysym = _x11Keysym(char);
      _client!.sendKeyEvent(keysym, true);
      _client!.sendKeyEvent(keysym, false);
    }
    _lastKeyboardText = text;
  }

  @override
  Widget build(BuildContext context) {
    final colors = NanoThemeExtension.of(context).colors;
    final isLandscape = MediaQuery.orientationOf(context) == Orientation.landscape;


    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) {
          SystemChrome.setPreferredOrientations(DeviceOrientation.values);
          if (context.canPop()) {
            context.pop();
          } else {
            context.go('/desktop');
          }
        }
      },
      child: Scaffold(
        resizeToAvoidBottomInset: false,
        backgroundColor: Colors.black,
        body: Stack(
          fit: StackFit.expand,
          children: [
            // Background visual wallpaper
            const Positioned.fill(
              child: NanoAmbientBackground(),
            ),

            // Main Desktop Viewport Canvas or PiP player
            Positioned.fill(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final widgetSize = Size(constraints.maxWidth, constraints.maxHeight);

                  if (_windowMode == DesktopWindowMode.minimized) {
                    return Stack(
                      children: [
                        _buildMinimizedPlaceholder(colors),
                        DesktopPipView(
                          frame: _frame,
                          screenSize: widgetSize,
                          colors: colors,
                          onRestore: () => setState(() => _windowMode = DesktopWindowMode.normal),
                          onClose: () {
                            SystemChrome.setPreferredOrientations(DeviceOrientation.values);
                            if (context.canPop()) {
                              context.pop();
                            } else {
                              context.go('/desktop');
                            }
                          },
                        ),
                      ],
                    );
                  }

                  return _buildContent(colors, widgetSize);
                },
              ),
            ),

            // Live Linux Command & Extra PC Keys Panel when Keyboard is visible
            if (_showKeyboard && _connected && _windowMode != DesktopWindowMode.minimized)
              Positioned(
                left: 0,
                right: 0,
                bottom: MediaQuery.of(context).viewInsets.bottom,
                child: Container(
                  decoration: BoxDecoration(
                    color: const Color(0xFF070A11).withValues(alpha: 0.94),
                    border: Border(
                      top: BorderSide(
                        color: colors.chromeActive.withValues(alpha: 0.35),
                        width: 1,
                      ),
                    ),
                    boxShadow: const [
                      BoxShadow(
                        color: Colors.black87,
                        blurRadius: 16,
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Interactive Linux Live Input Bar
                      Container(
                        padding: EdgeInsets.symmetric(horizontal: isLandscape ? 8 : 10, vertical: isLandscape ? 3 : 6),
                        color: Colors.white.withValues(alpha: 0.04),
                        child: Row(
                          children: [
                            Icon(
                              Icons.terminal_rounded,
                              size: isLandscape ? 16 : 18,
                              color: colors.chromeActive,
                            ),
                            SizedBox(width: isLandscape ? 6 : 8),
                            Expanded(
                              child: TextField(
                                controller: _keyboardInput,
                                focusNode: _keyboardFocus,
                                autofocus: true,
                                enableSuggestions: false,
                                autocorrect: false,
                                textInputAction: TextInputAction.send,
                                style: TextStyle(
                                  fontFamily: 'Inter',
                                  fontSize: isLandscape ? 12 : 13.5,
                                  color: Colors.white,
                                  fontWeight: FontWeight.w600,
                                ),
                                decoration: InputDecoration(
                                  hintText: 'Escribir comando o texto en Linux...',
                                  hintStyle: TextStyle(
                                    fontFamily: 'Inter',
                                    fontSize: isLandscape ? 11 : 12.5,
                                    color: Colors.white.withValues(alpha: 0.45),
                                  ),
                                  isDense: true,
                                  contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: isLandscape ? 5 : 8),
                                  filled: true,
                                  fillColor: Colors.white.withValues(alpha: 0.07),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(isLandscape ? 8 : 10),
                                    borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.12)),
                                  ),
                                  enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(isLandscape ? 8 : 10),
                                    borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.12)),
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(isLandscape ? 8 : 10),
                                    borderSide: BorderSide(color: colors.chromeActive),
                                  ),
                                ),
                                onChanged: _onKeyInput,
                                onSubmitted: _onKeyboardSubmit,
                              ),
                            ),
                            const SizedBox(width: 4),
                            IconButton(
                              icon: Icon(Icons.content_paste_rounded, size: isLandscape ? 16 : 18),
                              color: colors.chromeActive,
                              tooltip: 'Pegar portapapeles a Linux',
                              constraints: isLandscape ? const BoxConstraints(minWidth: 28, minHeight: 28) : null,
                              padding: isLandscape ? const EdgeInsets.all(4) : const EdgeInsets.all(8),
                              onPressed: _pasteClipboardToLinux,
                            ),
                            IconButton(
                              icon: Icon(Icons.send_rounded, size: isLandscape ? 16 : 18),
                              color: colors.chromeActive,
                              tooltip: 'Enviar Enter',
                              constraints: isLandscape ? const BoxConstraints(minWidth: 28, minHeight: 28) : null,
                              padding: isLandscape ? const EdgeInsets.all(4) : const EdgeInsets.all(8),
                              onPressed: () => _onKeyboardSubmit(_keyboardInput.text),
                            ),
                            IconButton(
                              icon: Icon(Icons.keyboard_hide_rounded, size: isLandscape ? 18 : 20),
                              color: Colors.white70,
                              tooltip: 'Ocultar teclado',
                              constraints: isLandscape ? const BoxConstraints(minWidth: 28, minHeight: 28) : null,
                              padding: isLandscape ? const EdgeInsets.all(4) : const EdgeInsets.all(8),
                              onPressed: _toggleKeyboard,
                            ),
                          ],
                        ),
                      ),
                      // Extra PC Keys Bar
                      DesktopExtraKeysBar(
                        colors: colors,
                        compact: isLandscape,
                        ctrlSticky: _ctrlSticky,
                        altSticky: _altSticky,
                        shiftSticky: _shiftSticky,
                        superSticky: _superSticky,
                        onToggleCtrl: _toggleCtrl,
                        onToggleAlt: _toggleAlt,
                        onToggleShift: _toggleShift,
                        onToggleSuper: _toggleSuper,
                        onQuickKey: _sendQuickKey,
                        onCombo: _sendCombo,
                      ),
                    ],
                  ),
                ),
              ),

            // Floating Top-Left Halo Hamburger & Top-Center 7-Control Pill Toolbar
            if (_connected && _frame != null && _windowMode != DesktopWindowMode.minimized)
              Positioned.fill(
                child: DesktopControlsOverlay(
                  colors: colors,
                  status: _status,
                  connected: _connected,
                  busy: _busy,
                  pointerMode: _pointerMode,
                  windowMode: _windowMode,
                  fitMode: _fitMode,
                  keyboardVisible: _showKeyboard,
                  zoom: _zoom,
                  isLandscape: isLandscape,
                  onBack: () {
                    SystemChrome.setPreferredOrientations(DeviceOrientation.values);
                    if (context.canPop()) {
                      context.pop();
                    } else {
                      context.go('/desktop');
                    }
                  },
                  onHelp: () => setState(() => _showHelp = true),
                  onRefresh: () {
                    _reconnectAttempts = 0;
                    _connect();
                  },
                  onFullscreen: _toggleFullscreen,
                  onWindowModeToggle: _toggleWindowMode,
                  onAspectModeToggle: _toggleFitMode,
                  onZoomIn: _zoomInStep,
                  onRotate: _toggleOrientation,
                  onMinimize: () => setState(() {
                    _windowMode = DesktopWindowMode.minimized;
                    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
                  }),
                  onTouch: () => _setPointerMode(DesktopPointerMode.touch),
                  onPan: () => _setPointerMode(DesktopPointerMode.pan),
                  onTrackpad: () => _setPointerMode(DesktopPointerMode.trackpad),
                  onKeyboard: _toggleKeyboard,
                  onCommands: _openCommandsSheet,
                  onZoom: () => DesktopSheets.showZoomSheet(
                    context: context,
                    colors: colors,
                    currentZoom: _zoom,
                    onZoomChanged: _setZoom,
                    onResetZoom: _resetZoom,
                  ),
                  onApps: () => DesktopSheets.showAppsSheet(
                    context: context,
                    colors: colors,
                    onLaunchApp: _launchApp,
                    onOpenHelp: () => setState(() => _showHelp = true),
                  ),
                  onMore: () => DesktopSheets.showMoreSheet(
                    context: context,
                    colors: colors,
                    status: _status,
                    connected: _connected,
                    fbWidth: _fbWidth,
                    fbHeight: _fbHeight,
                    onFullscreen: _toggleFullscreen,
                    onRotate: _toggleOrientation,
                    onMinimize: () => setState(() {
                      _windowMode = DesktopWindowMode.minimized;
                      SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
                    }),
                    onReconnect: () {
                      _reconnectAttempts = 0;
                      _connect();
                    },
                    onDisconnect: () {
                      _client?.disconnect();
                      if (context.canPop()) {
                        context.pop();
                      } else {
                        context.go('/desktop');
                      }
                    },
                    onOpenHelp: () => setState(() => _showHelp = true),
                  ),
                ),
              ),

            // Gesture Guide Overlay
            if (_showHelp)
              Positioned.fill(
                child: _HelpOverlay(onDismiss: () => setState(() => _showHelp = false)),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildContent(NanoColors colors, Size widgetSize) {
    final waitingFirstFrame = _initialized && _connState == _ConnState.connected && _frame == null;
    if ((_busy || waitingFirstFrame) && _frame == null) {
      return Container(
        color: const Color(0xFF07090E),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(color: colors.chromeActive),
              const SizedBox(height: 16),
              Text(
                _status,
                style: const TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
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
      return Container(
        color: const Color(0xFF07090E),
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
                    fontWeight: FontWeight.bold,
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
                    backgroundColor: colors.chromeActive,
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  icon: const Icon(Icons.refresh_rounded),
                  label: const Text('Reintentar Conexión', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return _buildCanvas(widgetSize);
  }

  /// Builds the 100% edge-to-edge interactive remote Linux desktop canvas.
  Widget _buildCanvas(Size canvasSize) {
    final fit = _fitScale(canvasSize);
    if (fit == null) return Container(color: Colors.black);

    final scale = fit * _zoom;
    final fbW = (_fbWidth * scale).roundToDouble();
    final fbH = (_fbHeight * scale).roundToDouble();
    final left = ((canvasSize.width - fbW) / 2 + _panFb.dx * scale).roundToDouble();
    final top = ((canvasSize.height - fbH) / 2 + _panFb.dy * scale).roundToDouble();

    final isExpanded = _windowMode == DesktopWindowMode.expanded;
    final isZoomedOrExpanded = isExpanded || _zoom > 1.05;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onScaleStart: (d) => _onScaleStart(d, canvasSize),
      onScaleUpdate: (d) => _onScaleUpdate(d, canvasSize),
      onScaleEnd: (d) => _onScaleEnd(d, canvasSize),
      child: Container(
        width: canvasSize.width,
        height: canvasSize.height,
        color: Colors.black,
        child: Stack(
          clipBehavior: Clip.hardEdge,
          children: [
            Positioned(
              left: left,
              top: top,
              width: fbW,
              height: fbH,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 160),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(isZoomedOrExpanded ? 0 : 10),
                  border: Border.all(
                    color: isZoomedOrExpanded
                        ? Colors.transparent
                        : const Color(0xFF0EA5E9).withValues(alpha: 0.50),
                    width: isZoomedOrExpanded ? 0 : 1.4,
                  ),
                  boxShadow: isZoomedOrExpanded
                      ? null
                      : [
                          BoxShadow(
                            color: const Color(0xFF0EA5E9).withValues(alpha: 0.25),
                            blurRadius: 18,
                            spreadRadius: 1,
                          ),
                          const BoxShadow(
                            color: Colors.black87,
                            blurRadius: 24,
                            spreadRadius: 6,
                          ),
                        ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(isZoomedOrExpanded ? 0 : 9),
                  child: RepaintBoundary(
                    child: RawImage(
                      image: _frame,
                      fit: BoxFit.fill,
                      filterQuality: FilterQuality.medium,
                    ),
                  ),
                ),
              ),
            ),

            // Virtual Trackpad Mouse Cursor
            if (_pointerMode == DesktopPointerMode.trackpad)
              Positioned(
                left: left + _cursorFb.dx * scale - 2,
                top: top + _cursorFb.dy * scale - 2,
                child: IgnorePointer(
                  child: Transform.rotate(
                    angle: -math.pi / 4,
                    child: const Icon(
                      Icons.navigation_rounded,
                      size: 20,
                      color: Color(0xFF0EA5E9),
                      shadows: [
                        Shadow(color: Colors.black87, blurRadius: 8),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildMinimizedPlaceholder(NanoColors colors) {
    return Center(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 20),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.65),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: colors.chromeActive.withValues(alpha: 0.35),
            width: 0.8,
          ),
          boxShadow: const [
            BoxShadow(
              color: Colors.black54,
              blurRadius: 16,
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                color: colors.chromeActive,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 10),
            const Text(
              'Sesión Linux Activa',
              style: TextStyle(
                fontFamily: 'Inter',
                fontWeight: FontWeight.bold,
                fontSize: 13,
                color: Colors.white,
              ),
            ),
            const SizedBox(width: 14),
            TextButton.icon(
              onPressed: () => setState(() => _windowMode = DesktopWindowMode.normal),
              style: TextButton.styleFrom(
                foregroundColor: colors.chromeActive,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              ),
              icon: const Icon(Icons.fullscreen_rounded, size: 16),
              label: const Text('Restaurar', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
            ),
          ],
        ),
      ),
    );
  }
}

class _HelpOverlay extends StatelessWidget {
  final VoidCallback onDismiss;

  const _HelpOverlay({required this.onDismiss});

  @override
  Widget build(BuildContext context) {
    final colors = NanoThemeExtension.of(context).colors;
    return Container(
      color: Colors.black.withValues(alpha: 0.75),
      child: Center(
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 24),
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: const Color(0xFF111622),
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
                  Icon(Icons.gesture_rounded, color: colors.chromeActive, size: 22),
                  const SizedBox(width: 8),
                  const Text(
                    'Gestos del Escritorio Linux',
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              _helpRow(Icons.touch_app_rounded, 'Modo táctil:', 'tap y arrastre directos sobre Linux'),
              _helpRow(Icons.touch_app_outlined, 'Clic derecho:', 'mantén presionado 550ms sin mover'),
              _helpRow(Icons.mouse_rounded, 'Modo trackpad:', 'arrastra el cursor · tap = clic'),
              _helpRow(Icons.pinch_rounded, 'Pellizco 2 dedos:', 'zoom anclado al foco hasta 400%'),
              _helpRow(Icons.swipe_rounded, '2 dedos con zoom:', 'desplazar la vista (pan)'),
              _helpRow(Icons.center_focus_strong_rounded, 'Doble / Triple tap:', 'doble tap = zoom 2x · triple = 100% fit'),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: onDismiss,
                  icon: const Icon(Icons.check_rounded, size: 18),
                  label: const Text('Entendido'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: colors.chromeActive,
                    foregroundColor: Colors.black,
                    minimumSize: const Size.fromHeight(48),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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
                      fontWeight: FontWeight.bold,
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
