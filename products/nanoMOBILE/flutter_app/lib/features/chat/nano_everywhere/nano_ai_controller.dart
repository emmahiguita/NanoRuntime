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

class NanoAiController extends ChangeNotifier {
  NanoAiController({
    required this.providers,
    required this.nativeApps,
    required this.actions,
  });

  final List<NanoProvider> providers;
  final NanoNativeAiPort nativeApps;
  final NanoActionPort actions;

  NanoActivity activity = NanoActivity.idle;
  NanoMode mode = NanoMode.quick;
  List<NanoAnswer> answers = const [];
  List<String> suggestions = const [];
  String status = '';

  int _requestId = 0;
  bool _disposed = false;
  Future<void> _lastQuery = Future<void>.value();
  String? _pendingPrompt;

  void queuePrompt(String prompt) {
    if (prompt.trim().isEmpty) return;
    _pendingPrompt = prompt;
    _emit();
  }

  String? takePendingPrompt() {
    final result = _pendingPrompt;
    _pendingPrompt = null;
    return result;
  }

  void selectMode(NanoMode value) { mode = value; _emit(); }
  void setListening(bool value) {
    activity = value ? NanoActivity.listening : NanoActivity.idle;
    _emit();
  }

  Future<void> submit(String input, {Iterable<String>? selectedIds}) async {
    final prompt = input.trim();
    if (prompt.isEmpty) return;
    if ({NanoActivity.thinking, NanoActivity.comparing,
      NanoActivity.debating, NanoActivity.acting}.contains(activity)) { return; }

    final token = ++_requestId;
    answers = const [];
    suggestions = const [];
    activity = switch (mode) {
      NanoMode.compare => NanoActivity.comparing,
      NanoMode.debate  => NanoActivity.debating,
      NanoMode.action  => NanoActivity.acting,
      _                => NanoActivity.thinking,
    };
    status = 'Consultando…';
    _emit();

    try {
      if (mode == NanoMode.action) {
        final result = await actions.executeAuthorizedGoal(prompt);
        if (!_current(token)) return;
        status = result;
        activity = NanoActivity.success;
        suggestions = ChatSuggestionEngine.derive(result);
        _emit();
        return;
      }

      // Evaluación conversacional local (saludos, identidad, ayuda sin LLM)
      final localRes = const NativeConversationalRouter().tryResolve(prompt);
      if (localRes != null && mode == NanoMode.quick) {
        final prov = providers.firstOrNull ?? const NanoProvider(
          id: 'nano_local', name: 'Nano', kind: NanoProviderKind.local,
        );
        answers = [NanoAnswer(provider: prov, requestId: token, round: 1, text: localRes.text)];
        suggestions = localRes.suggestions;
        activity = NanoActivity.success;
        status = 'Listo (Motor local)';
        _emit();
        return;
      }

      final selected = providers.where((p) =>
          p.supportsProgrammaticQuery &&
          (selectedIds == null || selectedIds.contains(p.id))).toList();
      if (selected.isEmpty) throw StateError('Sin proveedores disponibles.');

      final batch = mode == NanoMode.quick ? selected.take(1).toList() : selected;
      final first = await Future.wait(batch.map((p) => _serialAsk(p, prompt, token, 1)));
      if (!_current(token)) return;
      answers = first;
      status = '${first.where((a) => a.ok).length}/${batch.length} respuestas';
      _emit();

      if (first.every((a) => !a.ok)) throw StateError('Ningún proveedor respondió.');

      if (mode == NanoMode.debate && first.where((a) => a.ok).length > 1) {
        final context = first.where((a) => a.ok).map((a) => '${a.provider.name}: ${a.text}').join('\n\n');
        final challenge = 'Pregunta: $prompt\n\nAnaliza desacuerdos y errores verificables:\n\n$context';
        final next = await Future.wait(batch.map((p) => _serialAsk(p, challenge, token, 2)));
        if (!_current(token)) return;
        answers = [...first, ...next];
      }

      // Deriva opciones interactivas de respuesta para continuar el diálogo
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

  void cancel() {
    ++_requestId;
    activity = NanoActivity.idle;
    status = 'Consulta descartada';
    _emit();
  }

  Future<NanoAnswer> _serialAsk(NanoProvider p, String prompt, int id, int round) {
    final next = _lastQuery.then((_) => _ask(p, prompt, id, round));
    _lastQuery = next.then((_) {});
    return next;
  }

  Future<NanoAnswer> _ask(NanoProvider p, String prompt, int id, int round) async {
    try {
      final text = (await p.ask!(prompt)).trim();
      return NanoAnswer(
        provider: p, requestId: id, round: round,
        text: text, error: text.isEmpty ? 'Respuesta vacía' : null,
      );
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
