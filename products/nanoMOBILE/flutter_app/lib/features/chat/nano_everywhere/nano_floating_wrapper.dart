import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'browser_ai_login_sheet.dart';
import 'nano_ai_controller.dart';
import 'nano_ai_models.dart';
import 'nano_android_native_ai_port.dart';
import 'nano_floating_assistant.dart';
import 'nano_floating_system.dart';
import 'nano_overlay_runtime.dart';
import 'nano_assistant_voice.dart';
import '../../automation/engine/voice/voice_runtime.dart';

/// Wrapper principal. Conectar a BrowserAiGateway y AgentToolDispatcher via nano_providers.dart.
class NanoFloatingWrapper extends StatefulWidget {
  const NanoFloatingWrapper({
    super.key,
    required this.child,
    required this.webProviders,
    required this.actions,
    required this.audioLevel,
    this.onVoice,
    this.voiceSession,
    this.enabled = true,
  });
  final Widget child;
  final List<NanoProvider> webProviders;
  final NanoActionPort actions;
  final ValueListenable<double> audioLevel;
  final VoidCallback? onVoice;
  final VoiceSessionManager? voiceSession;
  final bool enabled;

  static NanoAiController? activeController;
  static bool expand({String? prompt, NanoMode? mode}) {
    if (activeController == null) return false;
    if (mode != null) activeController!.selectMode(mode);
    activeController!.expand(prompt);
    return true;
  }

  static bool toggle() {
    if (activeController == null) return false;
    activeController!.toggle();
    return true;
  }

  static bool hide() {
    if (activeController == null) return false;
    activeController!.hide();
    return true;
  }

  @override
  State<NanoFloatingWrapper> createState() => _NanoFloatingWrapperState();
}

class _NanoFloatingWrapperState extends State<NanoFloatingWrapper>
    with WidgetsBindingObserver {
  late NanoAiController controller;
  late NanoOverlayRuntime overlay;
  late NanoAssistantVoice voice;

  // El overlay del sistema posee la interacción cuando está activo.
  void _nativeChanged() {
    if (mounted) setState(() {});
  }

  // QUÉ HACE: Crea la instancia única de NanoAiController conectando puertos y UI.
  // CÓMO FUNCIONA: Inyecta proveedores web, acciones del sistema y el handler de login.
  // POR QUÉ: Desacopla la lógica del controlador de la vista mediante Inversión de Dependencias (DIP).
  NanoAiController _makeController() => NanoAiController(
    providers: widget.webProviders,
    nativeApps: const NanoAndroidNativeAiPort(),
    actions: widget.actions,
    onLoginRequired: (providerId) async {
      if (!mounted) return false;
      return showBrowserAiLoginSheet(context, suggestedProviderId: providerId);
    },
  );

  @override
  void initState() {
    super.initState();
    NanoFloatingSystem.activeState.addListener(_nativeChanged);
    controller = _makeController();
    voice = NanoAssistantVoice(() => controller, session: widget.voiceSession);
    NanoFloatingWrapper.activeController = controller;
    overlay = NanoOverlayRuntime(controller, voice: () => voice)..attach();
    WidgetsBinding.instance.addObserver(this);
    // Revisar si hay un prompt pendiente del overlay nativo al arrancar.
    WidgetsBinding.instance.addPostFrameCallback((_) => _takeEntry());
  }

  @override
  void didUpdateWidget(covariant NanoFloatingWrapper oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.voiceSession != widget.voiceSession) {
      voice.dispose();
      voice = NanoAssistantVoice(
        () => controller,
        session: widget.voiceSession,
      );
    }
    // Recrear el controller solo si cambia la configuración de proveedores.
    if (oldWidget.webProviders != widget.webProviders ||
        oldWidget.actions != widget.actions) {
      voice.stop();
      overlay.detach();
      controller.dispose();
      controller = _makeController();
      NanoFloatingWrapper.activeController = controller;
      overlay = NanoOverlayRuntime(controller, voice: () => voice)..attach();
    }
  }

  // Recuperar prompt+mode del Intent del overlay nativo al volver a la app.
  Future<void> _takeEntry() async {
    try {
      await const NanoFloatingSystem().active;
      final entry = await const NanoFloatingSystem().takePendingEntry();
      if (!mounted || entry == null) return;
      controller.selectMode(switch (entry['mode']) {
        'action' => NanoMode.action,
        _ => NanoMode.quick,
      });
      controller.queuePrompt(entry['prompt']?.toString() ?? '');
    } on MissingPluginException {
      // Web / preview sin canal Android — ignorar silenciosamente.
    } on PlatformException {
      // El diagnóstico de integración nativa se reporta en logcat.
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Al volver a primer plano, revisar si el overlay dejó un prompt.
    if (state == AppLifecycleState.resumed) _takeEntry();
  }

  @override
  void dispose() {
    NanoFloatingSystem.activeState.removeListener(_nativeChanged);
    WidgetsBinding.instance.removeObserver(this);
    if (NanoFloatingWrapper.activeController == controller) {
      NanoFloatingWrapper.activeController = null;
    }
    voice.dispose();
    overlay.detach();
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.enabled) return widget.child;
    return Stack(
      children: [
        Positioned.fill(child: widget.child),
        // El Navigator ya aporta Overlay; el asistente gestiona un solo listener.
        if (!NanoFloatingSystem.activeState.value)
          Positioned.fill(
            child: Material(
              type: MaterialType.transparency,
              child: NanoFloatingAssistant(
                controller: controller,
                audioLevel: widget.audioLevel,
                onVoice: widget.onVoice ?? voice.toggle,
                onSpeak: voice.read,
                onStopVoice: voice.stop,
              ),
            ),
          ),
      ],
    );
  }
}
