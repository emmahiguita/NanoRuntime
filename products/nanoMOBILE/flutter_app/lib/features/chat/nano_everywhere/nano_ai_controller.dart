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

class NanoAiController extends ChangeNotifier {
  NanoAiController({
    required this.providers,
    required this.nativeApps,
    required this.actions,
    NanoMediaDetector? mediaDetector, NanoMediaDownloader? mediaDownloader,
  })  : _mediaDetector = mediaDetector ?? const NanoMediaDetector(),
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

  void queuePrompt(String prompt) { if (prompt.trim().isNotEmpty) { _pendingPrompt = prompt; isVisible = true; _emit(); } }
  void expand([String? prompt]) { _requestExpand = true; isVisible = true; if (prompt != null && prompt.trim().isNotEmpty) _pendingPrompt = prompt.trim(); _emit(); }
  void hide() { isVisible = false; _requestExpand = false; _emit(); }
  void toggle() { isVisible ? hide() : expand(); }
  bool checkAndClearExpandRequest() { final r = _requestExpand; _requestExpand = false; return r; }
  String? takePendingPrompt() { final r = _pendingPrompt; _pendingPrompt = null; return r; }
  void selectMode(NanoMode value) { mode = value; _emit(); }
  void setActivity(NanoActivity act) { activity = act; _emit(); }
  void setListening(bool value) { activity = value ? NanoActivity.listening : NanoActivity.idle; _emit(); }

  Future<void> submit(String input, {Iterable<String>? selectedIds}) async {
    final prompt = input.trim();
    if (_disposed || prompt.isEmpty) return;
    if ({NanoActivity.thinking, NanoActivity.comparing,
      NanoActivity.debating, NanoActivity.acting}.contains(activity)) { return; }

    final token = ++_requestId;
    if (mode == NanoMode.quick && NanoMediaDetector.shouldAutoDetectMedia(prompt)) {
      mode = NanoMode.media;
    }
    answers = const [];
    suggestions = const [];
    detectedMedia = const [];
    activity = switch (mode) {
      NanoMode.compare => NanoActivity.comparing,
      NanoMode.debate  => NanoActivity.debating,
      NanoMode.action  => NanoActivity.acting,
      _                => NanoActivity.thinking,
    };
    status = mode == NanoMode.media ? 'Extrayendo video/audio del enlace…' : 'Consultando…';
    _emit();

    try {
      if (mode == NanoMode.media) {
        final items = await _mediaDetector.detect(prompt);
        if (!_current(token)) return;
        detectedMedia = items;
        activity = items.isNotEmpty ? NanoActivity.success : NanoActivity.error;
        status = items.isNotEmpty
            ? '${items.length} opciones listas para descargar (MP4 / MP3)'
            : 'No se encontraron archivos descargables en este enlace.';
        _emit();
        return;
      }

      if (mode == NanoMode.action) {
        final result = await actions.executeAuthorizedGoal(prompt);
        if (!_current(token)) return;
        status = result;
        activity = NanoActivity.success;
        suggestions = ChatSuggestionEngine.derive(result);
        _emit();
        return;
      }

      final localRes = const NativeConversationalRouter().tryResolve(prompt);
      if (localRes != null && mode == NanoMode.quick) {
        final prov = providers.firstOrNull ?? const NanoProvider(id: 'nano_local', name: 'Nano', kind: NanoProviderKind.local);
        answers = [NanoAnswer(provider: prov, requestId: token, round: 1, text: localRes.text)];
        suggestions = localRes.suggestions;
        activity = NanoActivity.success;
        status = 'Listo (Motor local)';
        _emit();
        return;
      }

      final selected = providers.where((p) =>
          p.supportsProgrammaticQuery && (selectedIds == null || selectedIds.contains(p.id))).toList();
      if (selected.isEmpty) throw StateError('Sin proveedores disponibles.');

      final batch = mode == NanoMode.quick ? selected.take(1).toList() : selected;
      final first = await Future.wait(batch.map((p) => _serialAsk(p, prompt, token, 1)));
      if (!_current(token)) return;
      answers = first;
      status = '${first.where((a) => a.ok).length}/${batch.length} respuestas';
      _emit();

      if (first.every((a) => !a.ok)) throw StateError('Ningún proveedor respondió.');

      if (mode == NanoMode.debate && first.where((a) => a.ok).length > 1) {
        final ctx = first.where((a) => a.ok).map((a) => '${a.provider.name}: ${a.text}').join('\n\n');
        final next = await Future.wait(batch.map((p) => _serialAsk(p, 'Pregunta: $prompt\n\nAnaliza desacuerdos:\n\n$ctx', token, 2)));
        if (!_current(token)) return;
        answers = [...first, ...next];
      }

      final allText = answers.map((a) => a.text).join(' ');
      suggestions = ChatSuggestionEngine.derive(allText);
      activity = NanoActivity.success;
      status = 'Listo';
    } catch (error) {
      if (!_current(token)) return;
      activity = NanoActivity.error;
      status = error.toString().replaceFirst('StateError: ', '');
    }
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
    activity = downloaded.isNotEmpty ? NanoActivity.success : NanoActivity.error;
    status = downloaded.isNotEmpty ? 'Guardados ${downloaded.length}/${items.length} en Download/NanoAI/' : 'Error al descargar.';
    _emit();
    return downloaded.length;
  }

  void cancel() {
    ++_requestId;
    activity = NanoActivity.idle;
    status = 'Consulta descartada';
    _emit();
  }

  Future<NanoAnswer> _serialAsk(NanoProvider p, String prompt, int id, int round) {
    // Descartar consultas en cola antes de invocar al proveedor, no solo su resultado.
    final next = _lastQuery.then<NanoAnswer>((_) => _current(id)
        ? _ask(p, prompt, id, round)
        : NanoAnswer(provider: p, requestId: id, round: round, error: 'Consulta descartada'));
    _lastQuery = next.then((_) {});
    return next;
  }

  Future<NanoAnswer> _ask(NanoProvider p, String prompt, int id, int round) async {
    try {
      final text = (await p.ask!(prompt)).trim();
      return NanoAnswer(provider: p, requestId: id, round: round, text: text, error: text.isEmpty ? 'Respuesta vacía' : null);
    } catch (error) {
      return NanoAnswer(provider: p, requestId: id, round: round, error: error.toString());
    }
  }

  bool _current(int id) => !_disposed && id == _requestId;
  void _emit() { if (!_disposed) notifyListeners(); }

  @override
  void dispose() {
    _disposed = true;
    ++_requestId;
    super.dispose();
  }
}
