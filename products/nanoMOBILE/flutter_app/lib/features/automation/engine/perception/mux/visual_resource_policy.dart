/// AUT-VIS-03 — VisualResourcePolicy: cuándo puede cargarse un modelo visual.
///
/// La inteligencia visual es OPCIONAL y debe degradar con elegancia bajo
/// presión de recursos del dispositivo. La política expone el estado del
/// modelo y autoriza (o niega) su carga; el escalado de percepción la
/// consulta ANTES de tocar el backend visual. Sin política o sin fuente de
/// RAM, el comportamiento conserva la carga bajo demanda actual.
///
/// INVARIANTE: VISUAL INTELLIGENCE MUST DEGRADE GRACEFULLY UNDER MOBILE
/// RESOURCE PRESSURE.
library;

/// Estados permitidos por el protocolo (sección AUT-VIS-03).
enum VisualModelState {
  /// Sin modelo cargado ni carga en curso.
  notLoaded,

  /// Carga en curso.
  loading,

  /// Cargado y utilizable.
  available,

  /// Carga denegada por recursos (RAM/térmica/batería).
  resourceDenied,

  /// El dispositivo no soporta el backend (sin aceleración, sin modelo).
  unavailable,
}

abstract interface class VisualResourcePolicy {
  VisualModelState state();

  /// ¿Puede intentarse la carga ahora? false → el escalado NO toca el
  /// backend visual y conserva la evidencia estructurada anterior.
  bool mayLoad();

  /// Refresca las señales de recursos (RAM/térmica) antes de decidir.
  Future<void> refresh();

  /// Registrar una carga en curso (estado → loading) y su desenlace.
  void markLoading();
  void markLoaded();
  void markFailed();
}

/// Política móvil conservadora: autoriza la carga salvo evidencia explícita
/// de presión de recursos. La fuente de RAM es inyectada; sin fuente, la
/// política degrada a permitir (comportamiento actual, sin romper nada).
final class MobileVisualResourcePolicy implements VisualResourcePolicy {
  MobileVisualResourcePolicy({
    required int minAvailableRamMb,
    Future<int?> Function()? availableRamMb,
    this.maxSimultaneousModels = 1,
  }) : _minAvailableRamMb = minAvailableRamMb,
       _availableRamMb = availableRamMb;

  final int _minAvailableRamMb;
  final Future<int?> Function()? _availableRamMb;
  final int maxSimultaneousModels;
  int _loadedModels = 0;
  VisualModelState _state = VisualModelState.notLoaded;

  @override
  VisualModelState state() => _state;

  @override
  bool mayLoad() {
    switch (_state) {
      case VisualModelState.available:
      case VisualModelState.loading:
        return false;
      case VisualModelState.unavailable:
        return false;
      case VisualModelState.notLoaded:
      case VisualModelState.resourceDenied:
        break;
    }
    if (_loadedModels >= maxSimultaneousModels) return false;
    final ram = _availableRamMb;
    if (ram == null) return true; // Sin fuente: permitir (degradación actual).
    return _lastKnownRamMb == null || _lastKnownRamMb! >= _minAvailableRamMb;
  }

  int? _lastKnownRamMb;

  /// Refresca la RAM disponible (llamado antes de decidir, con el valor
  /// más fresco posible). null = sin fuente.
  @override
  Future<void> refresh() async {
    _lastKnownRamMb = await _availableRamMb?.call();
  }

  @override
  void markLoading() {
    if (_state == VisualModelState.available) return;
    _state = VisualModelState.loading;
  }

  @override
  void markLoaded() {
    _loadedModels++;
    _state = VisualModelState.available;
  }

  @override
  void markFailed() {
    _state = _lastKnownRamMb != null && _lastKnownRamMb! < _minAvailableRamMb
        ? VisualModelState.resourceDenied
        : VisualModelState.notLoaded;
  }
}
