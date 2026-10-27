part of 'nano_owl_3d_turntable.dart';

/// Gesture physics are separate from controller ownership and scene drawing.
extension _NanoOwl3dTurntableGestures on _NanoOwl3dTurntableState {
  /// Starts direct rotation and cancels only the superseded autonomous movement.
  void _onPanStart(DragStartDetails details) {
    _inertiaController.stop();
    _returnController.stop();
    _isDragging = true;
    HapticFeedback.selectionClick();
  }

  /// Keeps the existing direct-drag response when motion is permitted.
  void _onPanUpdate(DragUpdateDetails details) {
    if (!motionEnabled) return;
    setState(() {
      _yaw = (_yaw + details.delta.dx * 0.016).clamp(
        -1.08,
        1.08,
      ); // Giro elástico 3D acotado
      _pitch = (_pitch - details.delta.dy * 0.012).clamp(
        -0.35,
        0.35,
      ); // Pitch acotado
      _angularVelocity = details.delta.dx * 0.014;
    });
  }

  /// Releases into the original friction simulation or existing return curve.
  void _onPanEnd(DragEndDetails details) {
    _isDragging = false;
    if (!motionEnabled) return;
    final velocityX = details.velocity.pixelsPerSecond.dx;
    if (velocityX.abs() > 100) {
      _angularVelocity = (velocityX * 0.00014).clamp(-0.14, 0.14);
      _inertiaController.animateWith(
        FrictionSimulation(0.15, 0.0, _angularVelocity * 100),
      );
    } else {
      _springBackToCenter();
    }
  }

  /// Returns the dragged pose using the original easeOutBack and 460 ms duration.
  void _springBackToCenter() {
    if (!motionEnabled) return;
    if (_yaw.abs() < 0.01 && _pitch.abs() < 0.01) return;
    _returnYaw = _yaw;
    _returnPitch = _pitch;
    _returnController.forward(from: 0);
  }

  /// Un controlador propietario por State: no crea listeners temporales que
  /// puedan sobrevivir a un gesto sustituido o al cierre de la pantalla.
  void _restoreCenter() {
    final t = Curves.easeOutBack.transform(_returnController.value);
    setState(() {
      _yaw = _returnYaw * (1 - t);
      _pitch = _returnPitch * (1 - t);
    });
  }
}
