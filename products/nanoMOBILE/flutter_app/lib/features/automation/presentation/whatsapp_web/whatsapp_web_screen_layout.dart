part of 'whatsapp_web_screen.dart';

/// Presentación visible: conserva controles y delega la propiedad de la sesión.
extension WhatsAppWebScreenLayout on _WhatsAppWebScreenState {
  Widget _buildLayout(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final useTabletLayout = _usesTablet(context);
    final keyboardInset = MediaQuery.viewInsetsOf(context).bottom;
    final safeBottomInset = MediaQuery.viewPaddingOf(context).bottom;
    final bottomObstruction = keyboardInset > 0
        ? keyboardInset
        : safeBottomInset;
    final reusingPersistentWebView = WhatsAppWebSessionOwnership.created;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _handlePop();
      },
      child: Scaffold(
        resizeToAvoidBottomInset: false,
        backgroundColor: isDark
            ? const Color(0xFF0F172A)
            : const Color(0xFFF8FAFC),
        appBar: WhatsAppWebAppBar(
          isDark: isDark,
          isConversationActive: _adapter.isConversationActive,
          isOriginalMode: _isOriginalMode,
          sessionStatus: _session.status,
          onBack: _handlePop,
          onToggleMode: () =>
              _toggleDisplayMode(useTabletLayout: useTabletLayout),
          onReload: () {
            // Una recarga invalida la selección; debe verificarse otra vez antes de mostrarla.
            setState(() {
              _requestedChatReady = false;
              _requestedChatError = null;
            });
            _webViewController?.reload();
          },
        ),
        body: Padding(
          padding: EdgeInsets.only(bottom: bottomObstruction),
          child: Column(
            children: [
              if (_progress < 1.0)
                LinearProgressIndicator(
                  value: _progress,
                  minHeight: 2.5,
                  backgroundColor: Colors.transparent,
                  valueColor: AlwaysStoppedAnimation<Color>(
                    isDark ? const Color(0xFF10B981) : const Color(0xFF059669),
                  ),
                ),
              Expanded(
                child: _requestedChatSurface(
                  WhatsAppWebViewContainer(
                    keepAlive: WhatsAppWebSessionOwnership.keepAlive,
                    hasCreatedPersistentWebView:
                        WhatsAppWebSessionOwnership.created,
                    onWebViewCreated: (controller) {
                      WhatsAppWebSessionOwnership.created = true;
                      _webViewController = controller;
                      _adapter.attachController(controller);
                      whatsAppWebBridgeController.attachController(controller);
                      WidgetsBinding.instance.addPostFrameCallback((_) {
                        if (mounted) {
                          if (reusingPersistentWebView) {
                            unawaited(
                              _restorePersistentView(
                                useTabletLayout: useTabletLayout,
                              ),
                            );
                          } else {
                            unawaited(
                              _synchronizeAttachedView(
                                useTabletLayout: useTabletLayout,
                              ),
                            );
                          }
                        }
                      });
                    },
                    onLoadStop: (controller, url) async {
                      final urlStr = url?.toString() ?? '';
                      if (WhatsAppWebAdapter.isAllowedUrl(urlStr)) {
                        await whatsAppWebBridgeController.onPageFinished(
                          urlStr,
                        );
                        await _synchronizeAttachedView(
                          useTabletLayout: useTabletLayout,
                        );
                      }
                    },
                    onProgressChanged: (progress) {
                      if (mounted) setState(() => _progress = progress / 100);
                    },
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
