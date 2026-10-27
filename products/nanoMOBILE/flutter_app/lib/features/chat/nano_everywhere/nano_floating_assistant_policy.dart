part of 'nano_floating_assistant.dart';

/// Owns snap and idle decisions; layout never creates a second snap animation.
extension _NanoFloatingAssistantPolicy on _NanoFloatingAssistantState {
  /// Dims only an actively rendered orb, with the existing four-second delay.
  void _startIdleTimer() {
    _idleTimer?.cancel();
    if (motionEnabled && !expanded && isVisible) {
      _idleTimer = Timer(const Duration(seconds: 4), () {
        if (mounted && !expanded && !_dragging) {
          setState(() => _opacity = 0.70);
        }
      });
    }
  }

  /// Restores interaction visibility and restarts the owned idle deadline.
  void _wakeUp() {
    _idleTimer?.cancel();
    if (_opacity != 1.0) {
      setState(() => _opacity = 1.0);
    }
    _startIdleTimer();
  }

  /// Uses one easeOutBack interpolator and valid bounds on very small windows.
  void _handlePanEnd(
    double screenWidth,
    double maxX,
    double maxY,
    double orbSize,
  ) {
    setState(() => _dragging = false);
    _wakeUp();

    final centerX = position.dx + orbSize / 2;
    final minX = maxX < 10 ? maxX : 10.0;
    final minY = maxY < 12 ? maxY : 12.0;
    final targetX = centerX < screenWidth / 2 ? minX : maxX;
    final targetY = position.dy.clamp(minY, maxY).toDouble();
    _snapDestination = Offset(targetX, targetY);
    if (!motionEnabled) {
      setState(_settleSnap);
      return;
    }

    _snapAnimation = Tween<Offset>(begin: position, end: _snapDestination)
        .animate(
          CurvedAnimation(parent: _snapController, curve: Curves.easeOutBack),
        );
    _snapController.forward(from: 0.0);
  }

  /// Finishes an interrupted snap without leaving a hidden controller running.
  void _settleSnap() {
    _snapController.stop();
    if (_snapAnimation != null && _snapDestination != null) {
      position = _snapDestination!;
    }
    _snapAnimation = null;
  }
}
