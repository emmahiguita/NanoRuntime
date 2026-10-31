import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../automation/presentation/widgets/automation_history_panel.dart';
import 'nano_assistant_panel.dart';
import 'nano_floating_wrapper.dart';
import '../../automation/whatsapp_workspace/owl_export_inbox.dart';
import 'nano_ai_controller.dart';

/// Superficie del mismo panel/engine fuera de Nano. Conserva el árbol normal
/// montado pero sin dibujarlo, y aporta Navigator para menús y diálogos propios.
class NanoExternalSurface extends StatefulWidget {
  const NanoExternalSurface({super.key, required this.child});
  final Widget child;
  static const channel = MethodChannel('dev.nanoai/owl_surface');
  @override
  State<NanoExternalSurface> createState() => _NanoExternalSurfaceState();
}
class _NanoExternalSurfaceState extends State<NanoExternalSurface> {
  bool visible = false;
  final panelKey = GlobalKey();
  final navigatorKey = GlobalKey<NavigatorState>();
  double lastHeight = 0;
  NanoAiController? _listenedController;

  @override
  void initState() {
    super.initState();
    _attachControllerListener(NanoFloatingWrapper.externalSession?.controller);
    NanoExternalSurface.channel.setMethodCallHandler((call) async {
      if (call.method == 'back') {
        if (await navigatorKey.currentState?.maybePop() != true) {
          command('collapse');
        }
        return true;
      }
      if (call.method == 'importReady') {
        final message = await OwlExportInbox.drain();
        final controller = NanoFloatingWrapper.activeController;
        if (controller != null && !controller.isDisposed) {
          controller.reportStatus(message);
        }
        return true;
      }
      if (call.method != 'setVisible') {
        throw MissingPluginException(call.method);
      }
      if (!mounted) return false;
      final session = NanoFloatingWrapper.externalSession;
      if (call.arguments == true && session == null) {
        return false;
      }
      _attachControllerListener(session?.controller);
      if (call.arguments == true) {
        session?.controller.expand();
      } else {
        session?.controller.hide();
      }
      setState(() {
        visible = call.arguments == true;
        lastHeight = 0;
      });
      if (visible) {
        await WidgetsBinding.instance.endOfFrame;
        if (!mounted || !visible) return false;
        publishSize();
      }
      return true;
    });
  }

  void _attachControllerListener(NanoAiController? controller) {
    if (_listenedController == controller) return;
    _listenedController?.removeListener(_onControllerChanged);
    _listenedController = controller;
    _listenedController?.addListener(_onControllerChanged);
  }

  void _onControllerChanged() {
    final activity = _listenedController?.activity;
    if (activity != null) {
      NanoExternalSurface.channel.invokeMethod<void>('mood', {
        'state': activity.name,
      });
    }
  }

  /// Delega al único dueño Android; no ejecuta órdenes de WhatsApp al cerrar.
  Future<void> command(String action) async {
    FocusManager.instance.primaryFocus?.unfocus();
    await NanoExternalSurface.channel.invokeMethod<void>(action);
  }

  /// Comunica cambios de layout, no usa timer ni redibujado continuo.
  void publishSize() {
    if (!mounted || !visible) return;
    final box = panelKey.currentContext?.findRenderObject();
    if (box is! RenderBox || !box.hasSize) return;
    final height = box.size.height + 12;
    if ((height - lastHeight).abs() < 1) return;
    lastHeight = height;
    NanoExternalSurface.channel.invokeMethod<void>('resize', {
      'height': height,
    });
  }

  /// Se ejecuta dentro de la ruta externa: historial/adjuntos encuentran su
  /// Navigator en vez de intentar usar el navegador principal oculto.
  Widget panelRoute(BuildContext routeContext) => ValueListenableBuilder<int>(
    valueListenable: NanoFloatingWrapper.externalRevision,
    builder: (_, _, _) {
      final session = NanoFloatingWrapper.externalSession;
      if (session == null) return const SizedBox.shrink();
      _attachControllerListener(session.controller);
      return Stack(
        fit: StackFit.expand,
        children: [
          Positioned.fill(
            child: Semantics(
              label: 'Contraer panel flotante',
              button: true,
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => command('collapse'),
                child: const SizedBox.expand(),
              ),
            ),
          ),
          Align(
            alignment: Alignment.topCenter,
            child: Padding(
              padding: const EdgeInsets.all(6),
              child: NotificationListener<SizeChangedLayoutNotification>(
                onNotification: (_) {
                  WidgetsBinding.instance.addPostFrameCallback(
                    (_) => publishSize(),
                  );
                  return false;
                },
                child: SizeChangedLayoutNotifier(
                  child: SizedBox(
                    key: panelKey,
                    child: Material(
                      type: MaterialType.transparency,
                      child: AnimatedBuilder(
                        animation: session.controller,
                        builder: (context, _) => NanoAssistantPanel(
                          controller: session.controller,
                          input: session.input,
                          audioLevel: session.audio,
                          onVoice: session.voice.toggle,
                          onSpeak: session.voice.read,
                          onCollapse: () => command('collapse'),
                          onCollapseForAction: () => command('collapse'),
                          onDismiss: () => command('close'),
                          onOpenApp: () => command('openNano'),
                          onShowHistory: () =>
                              showAutomationHistory(routeContext),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      );
    },
  );

  @override
  void dispose() {
    _listenedController?.removeListener(_onControllerChanged);
    _listenedController = null;
    NanoExternalSurface.channel.setMethodCallHandler(null);
    super.dispose();
  }

  /// El Navigator conserva una sola ruta externa; el motor y los modelos son
  /// los mismos. Las animaciones del fondo se detienen mientras está oculto.
  @override
  Widget build(BuildContext context) => Stack(
    fit: StackFit.expand,
    children: [
      TickerMode(
        enabled: !visible,
        child: Offstage(offstage: visible, child: widget.child),
      ),
      if (visible)
        Navigator(
          key: navigatorKey,
          onGenerateRoute: (_) => PageRouteBuilder<void>(
            opaque: false,
            pageBuilder: (context, _, _) => panelRoute(context),
          ),
        ),
    ],
  );
}
