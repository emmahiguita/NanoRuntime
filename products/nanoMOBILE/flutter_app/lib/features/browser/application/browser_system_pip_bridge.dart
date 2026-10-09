import 'package:flutter/services.dart';

/// Encapsula el canal Android del PiP y expone eventos tipados al dominio.
class BrowserSystemPipBridge {
  BrowserSystemPipBridge({
    required this.onModeChanged,
    required this.onUserLeaveHint,
  }) {
    _channel.setMethodCallHandler(_handleNativeCallback);
  }

  static const MethodChannel _channel = MethodChannel('com.nanoai/browser_pip');

  final ValueChanged<bool> onModeChanged;
  final VoidCallback onUserLeaveHint;

  /// Traduce mensajes nativos conocidos; ignora cualquier método no acordado.
  Future<void> _handleNativeCallback(MethodCall call) async {
    switch (call.method) {
      case 'pipModeChanged':
        onModeChanged(call.arguments == true);
      case 'onUserLeaveHint':
        onUserLeaveHint();
    }
  }

  /// Pide al Activity entrar en PiP y devuelve la confirmación real de Android.
  Future<bool> enter() async {
    try {
      return await _channel.invokeMethod<bool>('enterSystemPip') ?? false;
    } on PlatformException {
      return false;
    }
  }

  /// Retira el callback para que el canal no conserve un notifier destruido.
  void dispose() => _channel.setMethodCallHandler(null);
}
