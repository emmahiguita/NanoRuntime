// device_tilt_service.dart
//
// QUÉ HACE:
// Servicio híbrido para estimación y suavizado de inclinación del dispositivo (X, Y).
// Provee datos normalizados tanto desde sensores físicos (acelerómetro/giroscopio)
// como desde interacción táctil (Touch / Pan Drag) para emuladores y pruebas de escritorio.
//
// CÓMO FUNCIONA:
// - Aplica un filtro de zona muerta (|tilt| < 0.03 -> 0.0) para suprimir microtemblores de la mano.
// - Aplica suavizado exponencial (lerp con factor 0.08) para lograr transiciones cinemáticas fluidas.
// - Limita el rango estrictamente a [-1.0, 1.0] con clamping bidireccional.
// - Notifica a los escuchas a través de un ValueNotifier<Offset> ligero.
//
// POR QUÉ:
// Desacopla la lógica de sensores y gestos del renderizado de shaders (SRP / Clean Architecture)
// y garantiza portabilidad en cualquier plataforma (móvil, emulador, desktop) en menos de 140 líneas.

library;

import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

class DeviceTiltService {
  static const double _deadZoneThreshold = 0.03;
  static const double _smoothingFactor = 0.08;
  static const double _maxTilt = 1.0;

  final ValueNotifier<Offset> _tiltNotifier = ValueNotifier<Offset>(Offset.zero);
  Timer? _sensorPollTimer;

  // Coordenadas objetivo (sin filtrar)
  double _targetX = 0.0;
  double _targetY = 0.0;

  // Coordenadas suavizadas actuales
  double _currentX = 0.0;
  double _currentY = 0.0;

  bool _isDisposed = false;
  bool _useTouchOverride = false;

  DeviceTiltService() {
    _initTicker();
  }

  /// Notificador observable del vector de inclinación suavizado (rango -1.0 a 1.0).
  ValueListenable<Offset> get tiltListenable => _tiltNotifier;

  /// Vector de inclinación actual suavizado.
  Offset get currentTilt => _tiltNotifier.value;

  /// Inicia el bucle de actualización a 60 FPS (~16ms) para procesar el lerp.
  void _initTicker() {
    _sensorPollTimer = Timer.periodic(const Duration(milliseconds: 16), (_) {
      if (_isDisposed) return;
      _updateSmoothing();
    });
  }

  /// Procesa un cuadro de suavizado exponencial hacia los valores objetivo.
  void _updateSmoothing() {
    // 1. Filtrado de Zona Muerta (evita microvibraciones)
    final effectiveTargetX = _targetX.abs() < _deadZoneThreshold ? 0.0 : _targetX;
    final effectiveTargetY = _targetY.abs() < _deadZoneThreshold ? 0.0 : _targetY;

    // 2. Interpolación Lineal (Lerp Exponencial)
    _currentX += (effectiveTargetX - _currentX) * _smoothingFactor;
    _currentY += (effectiveTargetY - _currentY) * _smoothingFactor;

    // 3. Clamping duro en los límites
    final clampedX = _currentX.clamp(-_maxTilt, _maxTilt);
    final clampedY = _currentY.clamp(-_maxTilt, _maxTilt);

    final newOffset = Offset(clampedX, clampedY);
    if ((_tiltNotifier.value - newOffset).distanceSquared > 0.00001) {
      _tiltNotifier.value = newOffset;
    }
  }

  /// Actualiza la inclinación objetivo desde sensores nativos (acelerómetro/giroscopio).
  void updateFromSensor({required double rawPitch, required double rawRoll}) {
    if (_useTouchOverride) return;
    // Normalizar la gravedad hacia el rango aproximado [-1.0, 1.0]
    _targetX = (rawRoll / 9.81).clamp(-_maxTilt, _maxTilt);
    _targetY = (rawPitch / 9.81).clamp(-_maxTilt, _maxTilt);
  }

  /// Actualiza la inclinación manualmente desde gestos táctiles (Drag / Pan) en la UI.
  /// Ideal para emuladores, desktop o cuando el usuario interactúa con el dedo.
  void updateFromTouchOffset({
    required Offset touchOffset,
    required Size containerSize,
  }) {
    if (containerSize.width <= 0 || containerSize.height <= 0) return;
    _useTouchOverride = true;

    // Normalizar la posición del toque relativa al centro [-1.0, 1.0]
    final normalizedX = ((touchOffset.dx / containerSize.width) * 2.0 - 1.0);
    final normalizedY = ((touchOffset.dy / containerSize.height) * 2.0 - 1.0);

    _targetX = normalizedX.clamp(-_maxTilt, _maxTilt);
    _targetY = normalizedY.clamp(-_maxTilt, _maxTilt);
  }

  /// Restaura el objetivo al centro al soltar el toque.
  void releaseTouch() {
    _targetX = 0.0;
    _targetY = 0.0;
    // Permitir que vuelva al sensor físico después de una breve pausa
    Future.delayed(const Duration(milliseconds: 300), () {
      if (!_isDisposed) _useTouchOverride = false;
    });
  }

  /// Libera recursos y temporizadores.
  void dispose() {
    _isDisposed = true;
    _sensorPollTimer?.cancel();
    _tiltNotifier.dispose();
  }
}
