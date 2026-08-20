import 'package:flutter/material.dart';

/// Posiciones espaciales permitidas para el dock de navegación en NanoAI.
enum NavPosition {
  left,
  right,
  top,
}

/// Zonas de acoplamiento magnético detectadas durante el arrastre físico.
enum DockDropZone {
  none,
  left,
  right,
  top,
}

/// Controlador de física, posición y estado del panel de navegación dockable.
class NanoDockController extends ChangeNotifier {
  NanoDockController({
    NavPosition initialPosition = NavPosition.left,
    bool initialMinimized = false,
  })  : _position = initialPosition,
        _isMinimized = initialMinimized;

  NavPosition _position;
  bool _isMinimized;
  bool _isDragging = false;
  Offset _dragOffset = Offset.zero;
  DockDropZone _activeDropZone = DockDropZone.none;

  NavPosition get position => _position;
  bool get isMinimized => _isMinimized;
  bool get isDragging => _isDragging;
  Offset get dragOffset => _dragOffset;
  DockDropZone get activeDropZone => _activeDropZone;

  bool get isHorizontal => _position == NavPosition.top;

  void setPosition(NavPosition newPosition) {
    if (_position == newPosition) return;
    _position = newPosition;
    notifyListeners();
  }

  void toggleMinimized() {
    _isMinimized = !_isMinimized;
    notifyListeners();
  }

  void setMinimized(bool value) {
    if (_isMinimized == value) return;
    _isMinimized = value;
    notifyListeners();
  }

  void onDragStart(DragStartDetails details) {
    _isDragging = true;
    _dragOffset = Offset.zero;
    _activeDropZone = _getDropZoneFromPosition(_position);
    notifyListeners();
  }

  void onDragUpdate(DragUpdateDetails details, Size screenSize) {
    _dragOffset += details.delta;

    final pointer = details.globalPosition;
    const magneticThreshold = 120.0;

    // Detectar zona magnética según cercanía a bordes y dirección de arrastre
    if (pointer.dy < magneticThreshold || _dragOffset.dy < -60) {
      _activeDropZone = DockDropZone.top;
    } else if (pointer.dx > screenSize.width - magneticThreshold || _dragOffset.dx > 80) {
      _activeDropZone = DockDropZone.right;
    } else if (pointer.dx < magneticThreshold || _dragOffset.dx < -80) {
      _activeDropZone = DockDropZone.left;
    } else {
      // Calcular cercanía euclidiana
      final distLeft = pointer.dx;
      final distRight = screenSize.width - pointer.dx;
      final distTop = pointer.dy;

      if (distTop < distLeft && distTop < distRight) {
        _activeDropZone = DockDropZone.top;
      } else if (distRight < distLeft) {
        _activeDropZone = DockDropZone.right;
      } else {
        _activeDropZone = DockDropZone.left;
      }
    }

    notifyListeners();
  }

  void onDragEnd(DragEndDetails details) {
    _isDragging = false;
    final lastDrag = _dragOffset;
    _dragOffset = Offset.zero;

    // 1. Detección de Swipe rápido por velocidad
    final velocityVec = details.velocity.pixelsPerSecond;
    if (velocityVec.dy < -250) {
      _position = NavPosition.top;
    } else if (velocityVec.dx > 250) {
      _position = NavPosition.right;
    } else if (velocityVec.dx < -250) {
      _position = NavPosition.left;
    } else if (lastDrag.dy < -50) {
      _position = NavPosition.top;
    } else if (lastDrag.dx > 60) {
      _position = NavPosition.right;
    } else if (lastDrag.dx < -60) {
      _position = NavPosition.left;
    } else {
      // 2. Aplicar la zona magnética calculada
      switch (_activeDropZone) {
        case DockDropZone.left:
          _position = NavPosition.left;
          break;
        case DockDropZone.right:
          _position = NavPosition.right;
          break;
        case DockDropZone.top:
          _position = NavPosition.top;
          break;
        case DockDropZone.none:
          break;
      }
    }

    _activeDropZone = DockDropZone.none;
    notifyListeners();
  }

  DockDropZone _getDropZoneFromPosition(NavPosition pos) {
    switch (pos) {
      case NavPosition.left:
        return DockDropZone.left;
      case NavPosition.right:
        return DockDropZone.right;
      case NavPosition.top:
        return DockDropZone.top;
    }
  }
}