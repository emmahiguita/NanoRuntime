part of 'single_browser_instance_widget.dart';

/// Posee banners temporales; siempre cancela su temporizador al desmontarse.
mixin _BrowserInstancePromptState
    on ConsumerState<SingleBrowserInstanceWidget> {
  Timer? _zoomBadgeTimer;
  bool _showZoomBadge = false;
  bool _showSaveBanner = false;
  double _currentScale = 1;
  String? _pendingDomain;
  String? _pendingUser;
  String? _pendingPass;

  /// Muestra el zoom y reinicia un único temporizador de ocultación.
  void _triggerZoomBadge(double scale) {
    if (!mounted) return;
    _zoomBadgeTimer?.cancel();
    setState(() {
      _currentScale = scale;
      _showZoomBadge = true;
    });
    _zoomBadgeTimer = Timer(const Duration(milliseconds: 1200), () {
      if (mounted) setState(() => _showZoomBadge = false);
    });
  }

  /// Guarda solo la solicitud explícita recibida desde el formulario activo.
  void _showCredentialPrompt(String domain, String user, String password) {
    if (!mounted || password.isEmpty) return;
    setState(() {
      _pendingDomain = domain.isNotEmpty
          ? domain
          : (Uri.tryParse(widget.tab.url)?.host ?? '');
      _pendingUser = user;
      _pendingPass = password;
      _showSaveBanner = true;
    });
  }

  /// Confirma el guardado en el vault existente y limpia datos temporales.
  void _confirmSave() {
    final domain = _pendingDomain;
    final password = _pendingPass;
    if (domain != null && password != null) {
      ref.read(browserCredentialProvider.notifier).saveCredential(
        domain: domain,
        username: _pendingUser ?? '',
        password: password,
      );
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Contraseña guardada'),
          duration: Duration(seconds: 2),
        ),
      );
    }
    _clearCredentialPrompt();
  }

  /// Descarta el secreto pendiente sin modificar el vault.
  void _dismissCredential() => _clearCredentialPrompt();

  /// Limpia los datos temporales para que no sobrevivan al banner.
  void _clearCredentialPrompt() {
    if (!mounted) return;
    setState(() {
      _showSaveBanner = false;
      _pendingDomain = null;
      _pendingUser = null;
      _pendingPass = null;
    });
  }

  /// Libera el único recurso temporal propio de los overlays.
  @override
  void dispose() {
    _zoomBadgeTimer?.cancel();
    super.dispose();
  }
}
