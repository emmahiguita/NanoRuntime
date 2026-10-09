import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'browser_address_field.dart';

/// Barra principal Omnibox: conmutación de URL y progreso en tiempo real del WebView.
///
/// - QUÉ HACE: Combina el campo de dirección con el botón de recarga e indicador de progreso.
/// - CÓMO FUNCIONA: Despacha estados de carga visual con barra de progreso superior/inferior fina.
/// - POR QUÉ: Presenta el estado de navegación de forma nítida y limpia (<200 líneas).
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

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        BrowserAddressField(
          url: url,
          title: title,
          onSubmitted: onSubmitted,
          trailing: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(16),
              onTap: () {
                HapticFeedback.lightImpact();
                if (isLoading) {
                  onStop?.call();
                } else {
                  onReload();
                }
              },
              child: Padding(
                padding: const EdgeInsets.all(7),
                child: Icon(
                  isLoading ? CupertinoIcons.xmark : CupertinoIcons.arrow_clockwise,
                  size: 14,
                  color: isDark ? const Color(0xFF38BDF8) : const Color(0xFF2563EB),
                ),
              ),
            ),
          ),
        ),
        if (isLoading)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 1.5),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(1),
              child: LinearProgressIndicator(
                minHeight: 2,
                backgroundColor: Colors.transparent,
                valueColor: AlwaysStoppedAnimation<Color>(
                  isDark ? const Color(0xFF38BDF8) : const Color(0xFF2563EB),
                ),
                value: progress.isFinite ? progress.clamp(0, 1).toDouble() : null,
              ),
            ),
          ),
      ],
    );
  }
}
