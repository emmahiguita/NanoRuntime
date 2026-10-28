part of 'nano_floating_wrapper.dart';

/// Consume entradas del sistema una vez y liga su presentación al foreground.
/// El canal no concede permiso para ejecutar: solo prepara el panel/borrador.
extension _NanoFloatingWrapperEntry on _NanoFloatingWrapperState {
  bool get _canPresentEntry => !const {
    AppLifecycleState.inactive,
    AppLifecycleState.paused,
    AppLifecycleState.hidden,
    AppLifecycleState.detached,
  }.contains(WidgetsBinding.instance.lifecycleState);

  /// Las esperas de Android pueden terminar después de salir de la app. En ese
  /// caso conserva el texto oculto y descarta la solicitud tardía de apertura.
  Future<void> _takeEntry() async {
    final revision = _entryRevision;
    if (!mounted || !_canPresentEntry) return;
    try {
      await const NanoFloatingSystem().active;
      if (!mounted || revision != _entryRevision || !_canPresentEntry) return;
      final entry = await const NanoFloatingSystem().takePendingEntry();
      if (!mounted || entry == null) return;
      final prompt = entry['prompt']?.toString() ?? '';
      if (revision != _entryRevision || !_canPresentEntry) {
        controller.queuePrompt(prompt, reveal: false);
        return;
      }
      controller.selectMode(switch (entry['mode']) {
        'action' => NanoMode.action,
        _ => NanoMode.quick,
      });
      if (entry['open'] == true) {
        controller.expand(prompt);
      } else {
        controller.queuePrompt(prompt);
      }
    } on MissingPluginException {
      // La vista aislada de Flutter no tiene el servicio Android.
    } on PlatformException catch (error) {
      debugPrint('[owl] pending entry unavailable: ${error.code}');
    }
  }
}
