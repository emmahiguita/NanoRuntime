part of 'nano_owl_alive.dart';

/// Conserva la cadencia de sprites anterior al rediseño. La política de
/// visibilidad suspende relojes sin sustituir la animación visible por un timer.
extension _NanoOwlAlivePolicy on _NanoOwlAliveState {
  /// Reproduce el reposo a 3200 ms, vuelo a 560 ms y sueño reversible a 2000 ms,
  /// tal como la implementación previa; no añade mezclas entre fotogramas.
  void _applyActivityPolicy() {
    if (!mounted) return;
    blinkTimer?.cancel();
    blinkTimer = null;
    blinkStep = -1;
    motion.stop();
    if (!animate) return;
    // Reiniciar la simulación aplica la duración nueva, no solo cambia el campo.
    motion.duration = Duration(
      milliseconds: isSleep
          ? 2000
          : isFly
          ? 560
          : 3200,
    );
    motion.repeat(reverse: isSleep);
    if (!isSleep && !isFly) _scheduleBlink();
  }

  /// Solo cuenta inactividad visible; interactuar despierta al mismo personaje.
  void _resetInactivityTimer() {
    sleepInactivityTimer?.cancel();
    if (!animate || isAutoSleeping || widget.activity != NanoActivity.idle) {
      return;
    }
    sleepInactivityTimer = Timer(const Duration(seconds: 22), () {
      if (!mounted || !animate || widget.activity != NanoActivity.idle) return;
      _enterSleep();
    });
  }
}
