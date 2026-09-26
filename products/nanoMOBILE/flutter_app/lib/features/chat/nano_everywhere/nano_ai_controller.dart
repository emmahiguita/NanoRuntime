// nano_ai_controller.dart — Cerebro del asistente flotante.
// QUÉ: ChangeNotifier que gestiona el ciclo consulta→respuesta→sugerencias.
// CÓMO: 1° Evalúa rutas conversacionales locales ultrarrápidas (0ms) sin LLM.
//       2° Consulta providers remotos serializados con invalidación por token.
//       3° Deriva opciones interactivas para responder mediante ChatSuggestionEngine.
// POR QUÉ: Comprende desde un simple "hola" hasta párrafos extensos sin respuestas
//          robóticas o estáticas, proveyendo opciones de respuesta interactivas.
import 'package:flutter/foundation.dart';
import '../../../../core/services/native_conversational_router.dart';
import '../domain/chat_suggestion_engine.dart';
import 'nano_ai_models.dart';
import 'nano_media_detector.dart';
import 'nano_media_downloader.dart';

part 'nano_ai_controller_submission.dart';

class NanoAiController extends ChangeNotifier {
  NanoAiController({
    required this.providers,
    required this.nativeApps,
    required this.actions,
    NanoMediaDetector? mediaDetector,
    NanoMediaDownloader? mediaDownloader,
  }) : _mediaDetector = mediaDetector ?? const NanoMediaDetector(),
       _mediaDownloader = mediaDownloader ?? NanoMediaDownloader();

  final List<NanoProvider> providers;
  final NanoNativeAiPort nativeApps;
  final NanoActionPort actions;
  final NanoMediaDetector _mediaDetector;
  final NanoMediaDownloader _mediaDownloader;

  NanoActivity activity = NanoActivity.idle;
  NanoMode mode = NanoMode.quick;
  List<NanoAnswer> answers = const [];
  List<String> suggestions = const [];
  List<NanoMediaResource> detectedMedia = const [];
  String status = '';
  int _requestId = 0;
  bool _disposed = false;
  Future<void> _lastQuery = Future<void>.value();
  String? _pendingPrompt;
  bool _requestExpand = false;
  bool isVisible = false;

  void queuePrompt(String prompt) {
    if (prompt.trim().isNotEmpty) {
      _pendingPrompt = prompt;
      isVisible = true;
      _emit();
    }
  }

  void expand([String? prompt]) {
    _requestExpand = true;
    isVisible = true;
    if (prompt != null && prompt.trim().isNotEmpty) {
      _pendingPrompt = prompt.trim();
    }
    _emit();
  }

  void hide() {
    isVisible = false;
    _requestExpand = false;
    _emit();
  }

  void toggle() {
    isVisible ? hide() : expand();
  }

  bool checkAndClearExpandRequest() {
    final r = _requestExpand;
    _requestExpand = false;
    return r;
  }

  String? takePendingPrompt() {
    final r = _pendingPrompt;
    _pendingPrompt = null;
    return r;
  }

  // Comparar/debatir quedan fuera del flujo: un mensaje conversacional genera una única respuesta.
  void selectMode(NanoMode value) {
    mode = switch (value) {
      NanoMode.action => NanoMode.action,
      NanoMode.media => NanoMode.media,
      _ => NanoMode.quick,
    };
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

  Future<int> downloadMedia(List<NanoMediaResource> items) async {
    if (items.isEmpty) return 0;
    activity = NanoActivity.acting;
    status = 'Descargando ${items.length} archivos…';
    _emit();
    final downloaded = await _mediaDownloader.downloadBatch(items);
    activity = downloaded.isNotEmpty
        ? NanoActivity.success
        : NanoActivity.error;
    status = downloaded.isNotEmpty
        ? 'Guardados ${downloaded.length}/${items.length} en Download/NanoAI/'
        : 'Error al descargar.';
    _emit();
    return downloaded.length;
  }

  void cancel() {
    ++_requestId;
    activity = NanoActivity.idle;
    status = 'Consulta descartada';
    _emit();
  }

  bool _current(int id) => !_disposed && id == _requestId;
  void _emit() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    ++_requestId;
    super.dispose();
  }
}
