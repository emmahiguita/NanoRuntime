part of 'whatsapp_web_screen.dart';

/// Selección cancelable: no muestra otro chat mientras comprueba cuenta y encabezado.
extension WhatsAppWebRequestedChat on _WhatsAppWebScreenState {
  Future<void> _openRequestedChat() async {
    final title = widget.chatTitle, controller = _webViewController;
    if (title == null ||
        controller == null ||
        _openingRequestedChat ||
        _requestedChatReady) {
      return;
    }
    _openingRequestedChat = true;
    try {
      await WhatsAppWebChatRequest.open(
        controller,
        title,
        widget.chatAlias ?? '',
        () => !mounted,
      );
      if (!mounted) return;
      await _adapter.syncNavigationState(WhatsAppNavState.conversation);
      if (mounted) {
        setState(() {
          _requestedChatReady = true;
          _requestedChatError = null;
        });
      }
    } catch (error) {
      if (mounted) {
        setState(
          () => _requestedChatError = error is StateError
              ? error.message.toString()
              : 'No se pudo abrir este chat de WhatsApp',
        );
      }
    } finally {
      _openingRequestedChat = false;
    }
  }

  /// Mantiene el WebView vivo bajo una cubierta neutra hasta verificar el destino.
  Widget _requestedChatSurface(Widget webView) {
    final verified = widget.chatTitle == null || _requestedChatReady;
    return Stack(
      fit: StackFit.expand,
      children: [
        IgnorePointer(
          ignoring: !verified,
          child: Opacity(opacity: verified ? 1 : 0, child: webView),
        ),
        if (!verified)
          Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (_requestedChatError == null)
                    const CircularProgressIndicator(),
                  const SizedBox(height: 12),
                  Text(
                    _requestedChatError ?? 'Abriendo el chat real de WhatsApp…',
                    textAlign: TextAlign.center,
                  ),
                  if (_requestedChatError != null)
                    TextButton(
                      onPressed: _openRequestedChat,
                      child: const Text('Reintentar'),
                    ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}
