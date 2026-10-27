import 'package:flutter/material.dart';

import '../../domain/browser_tab_model.dart';
import 'browser_credential_save_banner.dart';
import 'browser_error_view.dart';
import 'browser_zoom_badge_overlay.dart';

/// Dibuja estados sobre la página sin poseer ni recrear la WebView.
class BrowserWebViewOverlays extends StatelessWidget {
  const BrowserWebViewOverlays({
    super.key,
    required this.tab,
    required this.accentColor,
    required this.showSaveBanner,
    required this.pendingDomain,
    required this.pendingUser,
    required this.showZoomBadge,
    required this.currentScale,
    required this.onRetry,
    required this.onNavigate,
    required this.onSaveCredential,
    required this.onDismissCredential,
  });

  final BrowserTabModel tab;
  final Color accentColor;
  final bool showSaveBanner;
  final String? pendingDomain;
  final String? pendingUser;
  final bool showZoomBadge;
  final double currentScale;
  final VoidCallback onRetry;
  final ValueChanged<String>? onNavigate;
  final VoidCallback onSaveCredential;
  final VoidCallback onDismissCredential;

  /// Cada capa aparece solo cuando su estado real la requiere.
  @override
  Widget build(BuildContext context) => Stack(
    fit: StackFit.expand,
    children: [
      if (tab.isLoading && tab.progress < 1)
        Align(
          alignment: Alignment.topCenter,
          child: LinearProgressIndicator(
            value: tab.progress,
            minHeight: 2,
            backgroundColor: Colors.transparent,
            color: accentColor,
          ),
        ),
      if (tab.hasError)
        BrowserErrorView(
          url: tab.url,
          errorMessage: tab.errorMessage,
          errorCode: tab.errorCode,
          onRetry: onRetry,
          onNavigate: (url) => onNavigate?.call(url),
          onGoHome: () => onNavigate?.call('https://www.google.com'),
        ),
      if (showSaveBanner && pendingDomain != null)
        Positioned(
          top: 4,
          left: 8,
          right: 8,
          child: BrowserCredentialSaveBanner(
            domain: pendingDomain!,
            username: pendingUser ?? '',
            onSave: onSaveCredential,
            onDismiss: onDismissCredential,
          ),
        ),
      BrowserZoomBadgeOverlay(
        visible: showZoomBadge,
        scale: currentScale,
        accentColor: accentColor,
      ),
    ],
  );
}
