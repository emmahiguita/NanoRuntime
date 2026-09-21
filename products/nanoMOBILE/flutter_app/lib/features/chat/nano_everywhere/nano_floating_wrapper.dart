// nano_floating_wrapper.dart — Integra el búho flotante en la app existente.
// QUÉ: StatefulWidget que envuelve la app con NanoFloatingAssistant y gestiona
//      el ciclo de vida del NanoAiController + el handoff del overlay nativo.
// CÓMO: WidgetsBindingObserver escucha lifecycle para recuperar el prompt
//       cuando la app vuelve de background (usuario escribió en el overlay).
// POR QUÉ: Separa el setup del controller de la UI (SOLID-S).
//          REEMPLAZAR los callbacks placeholder con BrowserAiGateway y
//          AgentToolDispatcher reales una vez conectados.
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'nano_ai_controller.dart';
import 'nano_ai_models.dart';
import 'nano_android_native_ai_port.dart';
import 'nano_floating_assistant.dart';
import 'nano_floating_system.dart';

/// Envuelve [child] con el búho flotante de Nano.
///
/// ```dart
/// // En main.dart, wrappear el MaterialApp.router o la pantalla raíz:
/// NanoFloatingWrapper(
///   child: MaterialApp.router(...),
///   webProviders: [...],   // NanoProviders con ask = BrowserAiGateway.ask
///   actions: myActionPort, // AgentToolDispatcher como NanoActionPort
///   audioLevel: micLevel,  // ValueNotifier<double> del micrófono
/// )
/// ```
class NanoFloatingWrapper extends StatefulWidget {
  const NanoFloatingWrapper({
    super.key,
    required this.child,
    required this.webProviders,
    required this.actions,
    required this.audioLevel,
    this.onVoice,
  });

  final Widget child;

  /// Lista de NanoProvider con ask≠null para consultas directas.
  final List<NanoProvider> webProviders;

  /// Puerto al AgentToolDispatcher existente para el modo Acción.
  final NanoActionPort actions;

  /// Nivel RMS del micrófono 0..1 — conectar al SpeechChannelHandler existente.
  final ValueListenable<double> audioLevel;

  /// Callback de voz — invocar SpeechChannelHandler.startListening().
  final VoidCallback? onVoice;

  @override
  State<NanoFloatingWrapper> createState() => _NanoFloatingWrapperState();
}

class _NanoFloatingWrapperState extends State<NanoFloatingWrapper>
    with WidgetsBindingObserver {
  late NanoAiController _controller;

  NanoAiController _build() => NanoAiController(
        providers: widget.webProviders,
        nativeApps: const NanoAndroidNativeAiPort(),
        actions: widget.actions,
      );

  @override
  void initState() {
    super.initState();
    _controller = _build();
    WidgetsBinding.instance.addObserver(this);
    // Recuperar prompt si la app ya tenía uno pendiente al arrancar.
    WidgetsBinding.instance.addPostFrameCallback((_) => _takePending());
  }

  @override
  void didUpdateWidget(covariant NanoFloatingWrapper old) {
    super.didUpdateWidget(old);
    // Reconstruye el controller si cambian providers o actions.
    if (old.webProviders != widget.webProviders ||
        old.actions != widget.actions) {
      final prev = _controller;
      _controller = _build();
      prev.dispose();
    }
  }

  /// Recupera el prompt que el usuario escribió en el overlay nativo.
  Future<void> _takePending() async {
    try {
      final prompt = await const NanoFloatingSystem().takePendingPrompt();
      if (mounted && prompt != null) _controller.queuePrompt(prompt);
    } catch (_) {
      // Canal no disponible (iOS, web, build sin Kotlin) — ignorar.
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Al volver de otra app, el usuario puede haber escrito en el overlay.
    if (state == AppLifecycleState.resumed) _takePending();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(children: [
      // Contenido principal de la app.
      Positioned.fill(child: widget.child),
      // Búho flotante sobre el contenido.
      Positioned.fill(
        child: ListenableBuilder(
          listenable: _controller,
          builder: (_, __) => NanoFloatingAssistant(
            controller: _controller,
            audioLevel: widget.audioLevel,
            onVoice: widget.onVoice,
          ),
        ),
      ),
    ]);
  }
}
