import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Envoltorio para detección de gestos táctiles de pellizco (Pinch to Zoom / Resize / Minimize).
/// Utiliza seguimiento de punteros crudos en Listener para capturar gestos de 2 dedos
/// sin que el motor Chromium de InAppWebView intercepte o bloquee el pellizco.
class BrowserPinchWrapper extends StatefulWidget {
  final Widget child;
  final VoidCallback onPinchIn;
  final VoidCallback onPinchOut;
  final ValueChanged<double>? onPinchScaleUpdate;

  const BrowserPinchWrapper({
    super.key,
    required this.child,
    required this.onPinchIn,
    required this.onPinchOut,
    this.onPinchScaleUpdate,
  });

  @override
  State<BrowserPinchWrapper> createState() => _BrowserPinchWrapperState();
}

class _BrowserPinchWrapperState extends State<BrowserPinchWrapper> {
  final Map<int, Offset> _pointers = {};
  double? _initialDistance;
  final ValueNotifier<double> _scaleNotifier = ValueNotifier<double>(1.0);
  bool _isPinching = false;

  @override
  void dispose() {
    _scaleNotifier.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      behavior: HitTestBehavior.translucent,
      onPointerDown: (event) {
        _pointers[event.pointer] = event.position;
        if (_pointers.length == 2) {
          final pts = _pointers.values.toList();
          _initialDistance = (pts[0] - pts[1]).distance;
          _isPinching = true;
          _scaleNotifier.value = 1.0;
        }
      },
      onPointerMove: (event) {
        if (_pointers.containsKey(event.pointer)) {
          _pointers[event.pointer] = event.position;
          if (_pointers.length == 2 &&
              _initialDistance != null &&
              _initialDistance! > 25) {
            final pts = _pointers.values.toList();
            final currentDist = (pts[0] - pts[1]).distance;
            final scale = (currentDist / _initialDistance!).clamp(0.65, 1.6);

            _scaleNotifier.value = scale;

            // Disparo anticipado si el gesto es determinante
            if (scale < 0.72) {
              _initialDistance = null;
              _triggerPinchIn();
            } else if (scale > 1.38) {
              _initialDistance = null;
              _triggerPinchOut();
            }
          }
        }
      },
      onPointerUp: (event) => _handlePointerRelease(event.pointer),
      onPointerCancel: (event) => _handlePointerRelease(event.pointer),
      child: ValueListenableBuilder<double>(
        valueListenable: _scaleNotifier,
        child: widget.child,
        builder: (context, scale, child) {
          return Transform.scale(
            scale: _isPinching ? scale.clamp(0.88, 1.12) : 1.0,
            alignment: Alignment.center,
            child: child,
          );
        },
      ),
    );
  }

  void _handlePointerRelease(int pointer) {
    _pointers.remove(pointer);
    if (_pointers.length < 2 && _isPinching) {
      final finalScale = _scaleNotifier.value;
      _isPinching = false;
      _scaleNotifier.value = 1.0;
      _initialDistance = null;

      if (finalScale < 0.82) {
        _triggerPinchIn();
      } else if (finalScale > 1.25) {
        _triggerPinchOut();
      }
    }
  }

  void _triggerPinchIn() {
    _pointers.clear();
    _isPinching = false;
    _scaleNotifier.value = 1.0;
    HapticFeedback.lightImpact();
    widget.onPinchIn();
  }

  void _triggerPinchOut() {
    _pointers.clear();
    _isPinching = false;
    _scaleNotifier.value = 1.0;
    HapticFeedback.lightImpact();
    widget.onPinchOut();
  }
}
