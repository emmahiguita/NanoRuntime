import 'dart:async';
// Controlador del flotante: enruta consultas, acciones y descargas.
// Los tokens invalidan resultados sustituidos; una respuesta del motor no
// acredita por si sola que una accion externa haya cumplido su objetivo.
import 'package:flutter/foundation.dart';
import '../domain/chat_suggestion_engine.dart';
import 'nano_ai_models.dart';
import 'nano_turn_receipt.dart';
import 'nano_prepared_attachment.dart';
import 'nano_media_detector.dart';
import 'nano_media_downloader.dart';

part 'nano_ai_controller_submission.dart';
part 'nano_ai_query.dart';
part 'nano_ai_downloads.dart';
part 'nano_ai_panel_state.dart';

class NanoAiController extends ChangeNotifier {
  NanoAiController({
    required this.providers,
    required this.nativeApps,
    required this.actions,
    NanoMediaDetector? mediaDetector,
    NanoMediaDownloader? mediaDownloader,
    // QUÉ: Callback que el widget conecta al sheet de login.
    // POR QUÉ: SRP — el controller no importa Flutter UI ni BuildContext.
    //          Notifica al widget cuándo se requiere acción, con el providerId
    //          sugerido. El widget puede abrir el sheet, un dialog, etc.
    this.onLoginRequired,
  }) : _ownsMediaDownloader = mediaDownloader == null,
       _mediaDetector = mediaDetector ?? const NanoMediaDetector(),
       _mediaDownloader = mediaDownloader ?? NanoMediaDownloader();

  final List<NanoProvider> providers;
  final NanoNativeAiPort nativeApps;
  final NanoActionPort actions;
  final NanoMediaDetector _mediaDetector;
  final NanoMediaDownloader _mediaDownloader;
  final bool _ownsMediaDownloader;

  /// Callback opcional: invocado cuando la gateway necesita login del usuario.
  /// Recibe el [providerId] sugerido (el que falló). El widget debe mostrar UI.
  /// Devuelve Future<bool>: true = usuario confirmó login, false = canceló.
  final Future<bool> Function(String providerId)? onLoginRequired;

  /// Callback opcional: invocado cuando la gateway necesita login del usuario.
  /// Recibe el [providerId] sugerido (el que falló). El widget debe mostrar UI.
  /// Devuelve Future<bool>: true = usuario confirmó login, false = canceló.
  final Future<bool> Function(String providerId)? onLoginRequired;

  NanoActivity activity = NanoActivity.idle;
  NanoMode mode = NanoMode.quick;
  String panelTool = 'Chat';
  List<NanoAnswer> answers = const [];
  List<String> suggestions = const [];
  List<NanoMediaResource> detectedMedia = const [];
  String status = '';
  NanoPreparedAttachment? attachment;

  /// Preparar o retirar archivo actualiza la vista sin abrir ni enviar WhatsApp.
  void setAttachment(NanoPreparedAttachment? value) {
    attachment = value;
    _emit();
  }

  int _requestId = 0;
  bool _disposed = false;
  bool get isDisposed => _disposed;
  bool _turnActive = false;
  bool _preparingFile = false;
  NanoProvider? _activeProvider;

  /// El bloqueo dura hasta liberar el dueño, aunque se haya pedido detener.
  bool get isBusy =>
      _turnActive || _preparingFile || activity == NanoActivity.listening;
  String? _pendingPrompt;
  bool _pendingIsDictation = false;
  bool _requestExpand = false;
  bool isVisible = true;

  // Comparar/debatir quedan fuera del flujo: un mensaje conversacional genera una única respuesta.
  void selectMode(NanoMode value) {
    if (_turnActive) return;
    mode = switch (value) {
      NanoMode.action => NanoMode.action,
      NanoMode.media => NanoMode.media,
      _ => NanoMode.quick,
    };
    _emit();
  }

  /// El selector comparte admisión con el motor; no permite otro envío mientras
  /// el archivo se copia. El dueño debe terminar la preparación en finally.
  bool beginFilePreparation() {
    if (_disposed || isBusy || activity == NanoActivity.acting) return false;
    _preparingFile = true;
    _emit();
    return true;
  }

  void endFilePreparation() {
    _preparingFile = false;
    _emit();
  }

  /// Publica información de una operación propia sin fabricar éxito.
  void reportStatus(String text) {
    status = text;
    _emit();
  }

  void setActivity(NanoActivity act) {
    activity = act;
    _emit();
  }

  void setListening(bool value) {
    activity = value ? NanoActivity.listening : NanoActivity.idle;
    _emit();
  }

  Future<bool> askNativeApp(String pkg, String prompt) async {
    if (prompt.trim().isEmpty) return false;
    return nativeApps.sharePrompt(pkg, prompt.trim());
  }

  /// Cancela los recursos propios e invalida resultados pendientes del turno.
  /// Una descarga nativa ya entregada a Android puede continuar fuera de Dart.
  void cancel() {
    _mediaDownloader.cancelActive();
    _cancelQuery();
    final port = actions;
    if (port is NanoCancellableActionPort) port.cancelActiveAction();
    final wasAction = activity == NanoActivity.acting;
    ++_requestId;
    activity = NanoActivity.idle;
    status = wasAction
        ? 'Detención solicitada; revisa el resultado de cualquier acción iniciada.'
        : 'Consulta descartada';
    _emit();
  }

  /// Cancelación cooperativa del request propio; nunca apaga el motor compartido.
  void _cancelQuery() {
    final cancel = _activeProvider?.cancel;
    if (cancel != null) unawaited(cancel().catchError((Object _) {}));
  }

  bool _current(int id) => !_disposed && id == _requestId;
  void _emit() {
    if (!_disposed) notifyListeners();
  }

  @override
  /// Libera el descargador creado aquí; un descargador inyectado conserva dueño.
  void dispose() {
    _mediaDownloader.cancelActive();
    _cancelQuery();
    if (_ownsMediaDownloader) _mediaDownloader.dispose();
    final port = actions;
    if (port is NanoCancellableActionPort) port.cancelActiveAction();
    _disposed = true;
    ++_requestId;
    super.dispose();
  }
}
