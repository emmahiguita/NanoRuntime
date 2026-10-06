import 'package:flutter/material.dart';
import 'browser_address_field.dart';
import 'browser_icon_button.dart';

/// Barra principal: reutiliza edición y muestra progreso real del WebView.
/// Mantiene el contrato anterior para no alterar sus consumidores.
class BrowserWindowOmnibox extends StatelessWidget {
  final String url, title;
  final Color siteColor;
  final bool isLandscape, isLoading;
  final double progress;
  final ValueChanged<String> onSubmitted;
  final VoidCallback onReload;
  final VoidCallback? onStop;
  const BrowserWindowOmnibox({
    super.key,
    required this.url,
    required this.title,
    required this.siteColor,
    required this.isLandscape,
    required this.onSubmitted,
    required this.onReload,
    this.isLoading = false,
    this.progress = 1,
    this.onStop,
  });

  /// El color viene del tema; el avance no inventa porcentajes mínimos de carga.
  @override
  Widget build(BuildContext context) => Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      BrowserAddressField(
        url: url,
        title: title,
        onSubmitted: onSubmitted,
        trailing: BrowserIconButton(
          icon: isLoading ? Icons.close_rounded : Icons.refresh_rounded,
          label: isLoading ? 'Detener carga' : 'Recargar página',
          onPressed: isLoading ? onStop : onReload,
        ),
      ),
      if (isLoading)
        LinearProgressIndicator(
          minHeight: 2,
          value: progress.isFinite ? progress.clamp(0, 1).toDouble() : null,
        ),
    ],
  );
}
