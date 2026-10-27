// nano_overlay_runtime.dart — Recibe consultas del overlay nativo Android.
// QUÉ: MethodChannel 'dev.nanoai/overlay_runtime' recibe overlayQuery desde
//      NanoOverlayBridge (Kotlin) y lo despacha al NanoAiController activo.
// CÓMO: Resultado tipado {ok, text} — errores nunca devuelven ok=true.
//       Attach en initState, detach en dispose para evitar leaks.
// POR QUÉ: El overlay nativo vive en un Service; el puente reutiliza el
//          engine propietario sin duplicar runtimes de Dart o de modelos.
import 'package:flutter/services.dart';
import '../../../core/services/nano_runtime_api.dart';
import 'nano_ai_controller.dart';
import 'nano_assistant_voice.dart';
import 'nano_action_input.dart';
import 'nano_attachment_commands.dart';
import 'nano_prepared_attachment.dart';
import '../../automation/presentation/widgets/automation_attachment_picker.dart';
import '../../automation/presentation/widgets/automation_input_menu.dart';
import 'nano_ai_models.dart';
import '../../automation/ledger/automation_activity_store.dart';
part 'nano_overlay_files.dart';

/// Recibe overlayQuery del servicio nativo mientras el engine Flutter está vivo.
class NanoOverlayRuntime {
  NanoOverlayRuntime(this.controller, {this.voice});

  final NanoAiController controller;
  final NanoAssistantVoice Function()? voice;
  static const _channel = MethodChannel('dev.nanoai/overlay_runtime');

  void attach() => _channel.setMethodCallHandler(_dispatch);
  void detach() => _channel.setMethodCallHandler(null);

  Future<Map<String, Object>> _dispatch(MethodCall call) async {
    if (call.method != 'overlayQuery') {
      throw MissingPluginException(call.method);
    }
    final args = Map<String, dynamic>.from(call.arguments as Map);
    if (args['mode'] == 'cancel_action' ||
        (const ['action', 'whatsapp'].contains(args['mode']) &&
            NanoActionInput.isCancel(args['prompt']?.toString() ?? ''))) {
      controller.cancel();
      return {
        'ok': false,
        'state': 'cancel_requested',
        'text': controller.status,
      };
    }
    if (args['mode'] == 'pick_attachment') {
      return _pickFile(args['prompt']?.toString() ?? '');
    }
    // El canal compartido de voz devuelve aceptación real, no texto inventado.
    if (args['mode'] == 'speak' || args['mode'] == 'stop_speech') {
      final stop = args['mode'] == 'stop_speech';
      final text = (args['prompt'] as String? ?? '').trim();
      final shared = voice?.call();
      final bool ok;
      if (shared != null) {
        if (stop) {
          await shared.stopReading();
          ok = true;
        } else {
          ok = await shared.startReading(text);
        }
      } else {
        ok = stop
            ? await NanoRuntimeApi.instance.stopSpeech()
            : text.isNotEmpty && await NanoRuntimeApi.instance.speak(text);
      }
      return {
        'ok': ok,
        'state': stop ? 'speech_stop_requested' : 'speech_requested',
        'text': ok ? '' : 'No se pudo iniciar la lectura de voz.',
      };
    }
    if (args['mode'] == 'history') {
      final rows = await AutomationActivityStore.instance.read();
      final text = rows.isEmpty
          ? 'Todavía no hay acciones registradas.'
          : rows
                .take(12)
                .map((e) => '${e.route}\n${e.state} · ${e.detail}')
                .join('\n\n');
      return {'ok': true, 'text': text};
    }
    final prompt = (args['prompt'] as String? ?? '').trim();
    if (prompt.isEmpty) {
      return {'ok': false, 'text': 'La consulta está vacía.'};
    }
    final mode = switch (args['mode']) {
      'action' || 'whatsapp' => NanoMode.action,
      'media' => NanoMode.media,
      _ => NanoMode.quick,
    };

    // Si viene contexto de pantalla activa (resumen/inspección explícita),
    // se acota de forma segura para no saturar el presupuesto de tokens con logs.
    final screenCtx = args['screenContext'] as Map?;
    String effectivePrompt = prompt;
    if (mode == NanoMode.action) {
      try {
        if (!NanoActionInput.isConfirm(prompt)) {
          effectivePrompt = prepareNanoAttachment(
            prompt,
            controller.attachment,
          );
        }
        if (args['mode'] == 'whatsapp') {
          effectivePrompt = NanoActionInput.prepare(
            effectivePrompt,
            whatsApp: true,
          );
        }
      } on FormatException catch (error) {
        return {'ok': false, 'state': 'clarification', 'text': error.message};
      }
    }
    if (mode != NanoMode.action && screenCtx != null && screenCtx.isNotEmpty) {
      final pkg = screenCtx['package']?.toString() ?? '';
      var visibleText = screenCtx['text']?.toString() ?? '';
      // Acotar texto visual a 600 caracteres para evitar saturar el prompt con logs o volcados.
      if (visibleText.length > 600) {
        visibleText = '${visibleText.substring(0, 600)}…';
      }
      final links = (screenCtx['links'] as List?)?.take(5).join(', ') ?? '';
      final b = StringBuffer('[Contexto de Pantalla en Android]\n');
      if (pkg.isNotEmpty) b.writeln('App activa: $pkg');
      if (links.isNotEmpty) b.writeln('Enlaces: $links');
      if (visibleText.isNotEmpty) b.writeln('Texto visible:\n$visibleText');
      b.writeln('\nConsulta: $prompt');
      effectivePrompt = b.toString();
    }

    final receipt = await controller.submit(
      effectivePrompt,
      requestedMode: mode,
    );
    return receipt.toMap();
  }
}
