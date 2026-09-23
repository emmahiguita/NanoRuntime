// nano_overlay_runtime.dart — Recibe consultas del overlay nativo Android.
// QUÉ: MethodChannel 'dev.nanoai/overlay_runtime' recibe overlayQuery desde
//      NanoOverlayBridge (Kotlin) y lo despacha al NanoAiController activo.
// CÓMO: Resultado tipado {ok, text} — errores nunca devuelven ok=true.
//       Attach en initState, detach en dispose para evitar leaks.
// POR QUÉ: El overlay nativo vive en otro proceso; el puente es el único
//          canal seguro sin duplicar engines de Dart o de modelos.
import 'package:flutter/services.dart';
import 'nano_ai_controller.dart';
import 'nano_ai_models.dart';

/// Recibe overlayQuery del servicio nativo mientras el engine Flutter está vivo.
class NanoOverlayRuntime {
  NanoOverlayRuntime(this.controller);

  final NanoAiController controller;
  static const _channel = MethodChannel('dev.nanoai/overlay_runtime');

  void attach() => _channel.setMethodCallHandler(_dispatch);
  void detach() => _channel.setMethodCallHandler(null);

  Future<Map<String, Object>> _dispatch(MethodCall call) async {
    if (call.method != 'overlayQuery') {
      throw MissingPluginException(call.method);
    }
    final args = Map<String, dynamic>.from(call.arguments as Map);
    final prompt = (args['prompt'] as String? ?? '').trim();
    if (prompt.isEmpty) {
      return {'ok': false, 'text': 'La consulta está vacía.'};
    }
    final mode = switch (args['mode']) {
      'compare' => NanoMode.compare,
      'debate'  => NanoMode.debate,
      'action'  => NanoMode.action,
      'media'   => NanoMode.media,
      _         => NanoMode.quick,
    };
    controller.selectMode(mode);

    // Si viene contexto de pantalla activa (estilo Gemini), se inyecta al prompt.
    final screenCtx = args['screenContext'] as Map?;
    String effectivePrompt = prompt;
    if (screenCtx != null && screenCtx.isNotEmpty) {
      final pkg = screenCtx['package']?.toString() ?? '';
      final visibleText = screenCtx['text']?.toString() ?? '';
      final links = (screenCtx['links'] as List?)?.join(', ') ?? '';
      final b = StringBuffer('[Contexto de Pantalla en Android]\n');
      if (pkg.isNotEmpty) b.writeln('App activa: $pkg');
      if (links.isNotEmpty) b.writeln('Enlaces en pantalla: $links');
      if (visibleText.isNotEmpty) b.writeln('Texto visible:\n$visibleText');
      b.writeln('\nConsulta: $prompt');
      effectivePrompt = b.toString();
    }

    await controller.submit(effectivePrompt);
    final answers = controller.answers;
    final text = answers.isEmpty
        ? controller.status
        : [
            controller.status,
            ...answers.map((a) =>
                '${a.provider.name} · Ronda ${a.round}\n${a.error ?? a.text}'),
          ].join('\n\n');
    return {
      'ok': controller.activity == NanoActivity.success,
      'text': text,
    };
  }
}
