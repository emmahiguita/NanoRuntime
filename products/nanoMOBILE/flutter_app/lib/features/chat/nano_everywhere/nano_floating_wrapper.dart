import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../core/services/owl_surface_bridge.dart';
import '../../automation/whatsapp_workspace/owl_export_inbox.dart';
import '../../automation/whatsapp_workspace/owl_screen_evidence.dart';
import '../../automation/engine/voice/voice_runtime.dart';
import 'browser_ai_login_sheet.dart';
import 'nano_ai_controller.dart';
import 'nano_ai_models.dart';
import 'nano_android_native_ai_port.dart';
import 'nano_floating_assistant.dart';
import 'nano_floating_system.dart';
import 'nano_overlay_runtime.dart';
import 'nano_assistant_voice.dart';
part 'nano_floating_wrapper_entry.dart';
part 'nano_floating_wrapper_view.dart';

/// Una sesión y un borrador para las superficies interna y externa del búho.
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
  static final externalRevision = ValueNotifier<int>(0);
  static ({
    NanoAiController controller,
    TextEditingController input,
    ValueListenable<double> audio,
    NanoAssistantVoice voice,
  })?
  externalSession;

  /// Las entradas externas preparan el mismo controlador; no ejecutan texto.
  static bool expand({String? prompt, NanoMode? mode}) {
    final owner = activeController;
    if (owner == null) return false;
    if (mode != null) owner.selectMode(mode);
    owner.expand(prompt);
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
  final sharedInput = TextEditingController();
  int _entryRevision = 0;

  /// Actualiza consumidores tras reemplazar voz o proveedores; nunca conserva
  /// listeners en controladores liberados ni crea otro modelo para el overlay.
  void _publishExternal() {
    NanoFloatingWrapper.externalSession = (
      controller: controller,
      input: sharedInput,
      audio: widget.audioLevel,
      voice: voice,
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) NanoFloatingWrapper.externalRevision.value++;
    });
  }

  /// Inyecta puertos existentes. La observación no usa un frame Flutter
  /// después de pausar el engine: espera solo la retirada Android de la ventana.
  NanoAiController _makeController() => NanoAiController(
    providers: widget.webProviders,
    nativeApps: const NanoAndroidNativeAiPort(),
    actions: widget.actions,
    observeScreen: () async {
      try {
        await OwlSurfaceBridge.channel.invokeMethod<void>('collapse');
      } on MissingPluginException {
        /* La vista interna ya se ocultó. */
      }
      await Future<void>.delayed(const Duration(milliseconds: 80));
      return OwlScreenEvidence().read();
    },
    onLoginRequired: (id) async =>
        mounted &&
        await showBrowserAiLoginSheet(context, suggestedProviderId: id),
  );

  /// El engine conserva la sesión al salir de Nano. Importar recibe archivos
  /// explícitos del sistema; no genera respuestas ni acciones en WhatsApp.
  @override
  void initState() {
    super.initState();
    controller = _makeController();
    voice = NanoAssistantVoice(() => controller, session: widget.voiceSession);
    NanoFloatingWrapper.activeController = controller;
    _publishExternal();
    overlay = NanoOverlayRuntime(controller, voice: () => voice)..attach();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _takeEntry();
      unawaited(
        OwlExportInbox.drain()
            .then((text) {
              if (mounted && text.isNotEmpty) controller.reportStatus(text);
            })
            .catchError((Object error) {
              if (mounted) {
                controller.reportStatus('No se importó el historial: $error');
              }
            }),
      );
    });
  }

  /// Cambiar configuración libera únicamente los recursos de la sesión vieja.
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
    if (oldWidget.webProviders != widget.webProviders ||
        oldWidget.actions != widget.actions) {
      voice.stop();
      overlay.detach();
      controller.dispose();
      controller = _makeController();
      NanoFloatingWrapper.activeController = controller;
      overlay = NanoOverlayRuntime(controller, voice: () => voice)..attach();
    }
    _publishExternal();
  }

  /// Una salida no vuelve a abrir la interfaz por callbacks pendientes.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) {
      _entryRevision++;
      controller.hide();
    } else {
      _takeEntry();
    }
  }

  /// El editor y la voz tienen un solo dueño aun al desmontar ambas vistas.
  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    if (NanoFloatingWrapper.activeController == controller) {
      NanoFloatingWrapper.activeController = null;
      NanoFloatingWrapper.externalSession = null;
    }
    voice.dispose();
    overlay.detach();
    controller.dispose();
    sharedInput.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => buildView(context);
}
