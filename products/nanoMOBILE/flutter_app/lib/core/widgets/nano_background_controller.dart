import 'dart:ui';
import 'package:flutter/foundation.dart';

/// Perfiles de calidad del shader adaptativo.
enum NanoBackgroundQuality {
  low,
  balanced,
  high,
  ultra,
}

/// Controlador físico de interacción, inercia y estado de telemetría para NanoLivingBackground.
class NanoBackgroundController extends ChangeNotifier {
  NanoBackgroundController({
    NanoBackgroundQuality quality = NanoBackgroundQuality.high,
  }) : _quality = quality;

  Offset _pointerPosition = const Offset(200, 300);
  Offset _pointerVelocity = Offset.zero;
  Offset _lastPointerPosition = const Offset(200, 300);
  double _pointerEnergy = 0.0;
  double _systemEnergy = 0.0;
  NanoBackgroundQuality _quality;

  Offset get pointerPosition => _pointerPosition;
  Offset get pointerVelocity => _pointerVelocity;
  double get pointerEnergy => _pointerEnergy;
  double get systemEnergy => _systemEnergy;
  NanoBackgroundQuality get quality => _quality;

  double get qualityLevel => switch (_quality) {
    NanoBackgroundQuality.low => 0.0,
    NanoBackgroundQuality.balanced => 1.0,
    NanoBackgroundQuality.high => 2.0,
    NanoBackgroundQuality.ultra => 3.0,
  };

  void setQuality(NanoBackgroundQuality q) {
    if (_quality != q) {
      _quality = q;
      notifyListeners();
    }
  }

  void setSystemEnergy(double energy) {
    final clamped = energy.clamp(0.0, 1.0);
    if ((_systemEnergy - clamped).abs() > 0.01) {
      _systemEnergy = clamped;
      notifyListeners();
    }
  }

  void onPointerDown(Offset pos) {
    _lastPointerPosition = _pointerPosition;
    _pointerPosition = pos;
    _pointerVelocity = Offset.zero;
    _pointerEnergy = 1.0;
    notifyListeners();
  }

  void onPointerMove(Offset pos) {
    final delta = pos - _pointerPosition;
    _pointerVelocity = delta * 0.15;
    _lastPointerPosition = _pointerPosition;
    _pointerPosition = pos;
    _pointerEnergy = (_pointerEnergy + 0.35).clamp(0.0, 1.0);
    notifyListeners();
  }

  void onPointerUp() {
    _pointerEnergy = (_pointerEnergy * 0.8).clamp(0.0, 1.0);
    notifyListeners();
  }

  void tickDecay() {
    bool changed = false;
    if (_pointerEnergy > 0.001) {
      _pointerEnergy *= 0.95;
      changed = true;
    } else if (_pointerEnergy != 0.0) {
      _pointerEnergy = 0.0;
      changed = true;
    }

    if (_pointerVelocity.distanceSquared > 0.001) {
      _pointerVelocity *= 0.90;
      changed = true;
    } else if (_pointerVelocity != Offset.zero) {
      _pointerVelocity = Offset.zero;
      changed = true;
    }

    if (changed) {
      notifyListeners();
    }
  }
}
