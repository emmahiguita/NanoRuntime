part of 'single_browser_instance_widget.dart';

/// Gestiona únicamente controlador, orientación y recuperación del renderer.
mixin _BrowserInstanceLifecycle
    on ConsumerState<SingleBrowserInstanceWidget>, _BrowserInstancePromptState {
  Orientation? _lastOrientation;
  late BrowserWebViewLifecycleHandler _handler;
  late BrowserWebIdentityCoordinator _identity;
  int _webViewGeneration = 0;
  bool _recoveringRenderer = false;

  BrowserWebViewRegistry get _registry =>
      ref.read(browserWebViewRegistryProvider);

  /// Una pestaña oculta o minimizada no ejecuta trabajo salvo media activa.
  bool get _shouldPause => widget.isMinimized || !widget.isCurrentActive;

  bool _wasPaused(SingleBrowserInstanceWidget oldWidget) =>
      oldWidget.isMinimized || !oldWidget.isCurrentActive;

  /// Crea una sola coordinación de callbacks por instancia Flutter.
  @override
  void initState() {
    super.initState();
    final registry = _registry;
    final tabId = widget.tab.id;
    _identity = BrowserWebIdentityCoordinator(
      isAlive: () => mounted,
      userDesktopMode: () => widget.isDesktopMode,
    );
    _handler = BrowserWebViewLifecycleHandler(
      getContext: () => context,
      ref: ref,
      tab: widget.tab,
      identity: _identity,
      isDarkModeWeb: widget.isDarkModeWeb,
      currentZoom: widget.currentZoom,
      isAlive: () => mounted,
      onZoomChanged: _triggerZoomBadge,
      onPromptSaveCredential: _showCredentialPrompt,
      onRenderProcessLost: () => unawaited(_recoverRenderer(registry, tabId)),
      onControllerCreated: widget.onControllerCreated,
      onExternalPrompt: widget.onExternalPrompt,
    );
  }

  /// Notifica el nuevo viewport sin destruir la sesión ni el canvas nativo.
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final orientation = MediaQuery.orientationOf(context);
    if (_lastOrientation != null && _lastOrientation != orientation) {
      final controller = _registry.controllerFor(widget.tab.id);
      if (controller != null) {
        controller.evaluateJavascript(
          source: 'window.dispatchEvent(new Event("resize"));',
        );
        if (!_shouldPause) controller.resume();
      }
    }
    _lastOrientation = orientation;
  }

  /// Sincroniza cambios externos de pestaña con el WebView ya existente.
  @override
  void didUpdateWidget(covariant SingleBrowserInstanceWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    final controller = _registry.controllerFor(widget.tab.id);
    if (_wasPaused(oldWidget) != _shouldPause) {
      _shouldPause
          ? _registry.pauseTab(widget.tab.id)
          : _registry.resumeTab(widget.tab.id);
    }
    _handler
      ..tab = widget.tab
      ..isDarkModeWeb = widget.isDarkModeWeb
      ..currentZoom = widget.currentZoom;
    if (widget.tab.url != oldWidget.tab.url &&
        widget.tab.url != _handler.reportedUrl) {
      controller?.loadUrl(urlRequest: URLRequest(url: WebUri(widget.tab.url)));
    }
    if (widget.tab.zoomLevel != oldWidget.tab.zoomLevel) {
      controller?.evaluateJavascript(
        source: BrowserScripts.setZoomLevelScript(widget.tab.zoomLevel),
      );
    }
    if (widget.isDarkModeWeb != oldWidget.isDarkModeWeb) {
      controller?.evaluateJavascript(
        source: BrowserScripts.toggleDarkModeWebScript,
      );
    }
    final oldDesktop = BrowserSiteProfile.usesDesktop(
      url: oldWidget.tab.url,
      userDesktopMode: oldWidget.isDesktopMode,
    );
    final newDesktop = _identity.usesDesktop(widget.tab.url);
    if (oldDesktop != newDesktop && controller != null) {
      unawaited(_identity.applyPreference(controller, widget.tab.url));
    }
  }

  /// Reemplaza la vista nativa muerta; Android prohíbe reutilizar su renderer.
  Future<void> _recoverRenderer(
    BrowserWebViewRegistry registry,
    String tabId,
  ) async {
    if (_recoveringRenderer) return;
    _recoveringRenderer = true;
    await registry.removeTab(tabId);
    if (!mounted || widget.tab.id != tabId) return;
    setState(() {
      _webViewGeneration++;
      _recoveringRenderer = false;
    });
  }

  /// Publica avance real de carga para barra y botón detener.
  void _updateProgress(int progress) {
    if (!mounted) return;
    ref
        .read(browserTabProvider.notifier)
        .updateTabById(
          widget.tab.id,
          progress: progress / 100,
          isLoading: progress < 100,
        );
  }

  /// Conserva el título entregado por el documento activo.
  void _updateTitle(String? title) {
    if (!mounted || title?.isNotEmpty != true) return;
    ref
        .read(browserTabProvider.notifier)
        .updateTabById(widget.tab.id, title: title);
  }

  /// Reintenta sobre el controlador real o navega si todavía no existe.
  void _retryPage() {
    final controller = _registry.controllerFor(widget.tab.id);
    if (controller == null) {
      widget.onNavigate?.call(widget.tab.url);
      return;
    }
    ref
        .read(browserTabProvider.notifier)
        .updateTabById(
          widget.tab.id,
          clearError: true,
          isLoading: true,
          progress: 0.1,
        );
    controller.reload();
  }

  /// Recarga la pestaña activa sin crear una segunda sesión.
  void _reload() => _registry.controllerFor(widget.tab.id)?.reload();

  /// Retrocede solo cuando el historial nativo tiene un destino.
  Future<void> _goBack() async {
    final controller = _registry.controllerFor(widget.tab.id);
    if (controller != null && await controller.canGoBack()) {
      await controller.goBack();
    }
  }

  /// Avanza solo cuando el historial nativo tiene un destino.
  Future<void> _goForward() async {
    final controller = _registry.controllerFor(widget.tab.id);
    if (controller != null && await controller.canGoForward()) {
      await controller.goForward();
    }
  }
}
