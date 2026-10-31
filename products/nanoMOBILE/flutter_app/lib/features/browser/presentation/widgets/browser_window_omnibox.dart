// QUÉ: Barra principal Omnibox: conmutación de URL, seguridad y progreso en tiempo real.
// CÓMO: Combina el campo NanoAddressBar con el botón de recarga e indicador de progreso fino.
// POR QUÉ: Presenta el estado de navegación de forma nítida, segura y profesional (< 90 líneas).

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'nano_address_bar.dart';

class BrowserWindowOmnibox extends StatelessWidget {
  final String url, title;
  final Color siteColor;
  final bool isLandscape, isLoading;
  final double progress;
  final ValueChanged<String> onSubmitted;
  final VoidCallback onReload;
  final VoidCallback? onStop;
  final ValueChanged<bool>? onEditingChanged;

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
    this.onEditingChanged,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        NanoAddressBar(
          url: url,
          title: title,
          onSubmitted: onSubmitted,
          onEditingChanged: onEditingChanged,
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
                padding: const EdgeInsets.all(8),
                child: Icon(
                  isLoading ? CupertinoIcons.xmark : CupertinoIcons.arrow_clockwise,
                  size: 15,
                  color: isDark ? const Color(0xFF38BDF8) : const Color(0xFF007AFF),
                ),
              ),
            ),
          ),
        ),
        if (isLoading)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(1.5),
              child: LinearProgressIndicator(
                minHeight: 2.5,
                backgroundColor: Colors.transparent,
                valueColor: AlwaysStoppedAnimation<Color>(
                  isDark ? const Color(0xFF38BDF8) : const Color(0xFF007AFF),
                ),
                value: progress.isFinite ? progress.clamp(0, 1).toDouble() : null,
              ),
            ),
          ),
      ],
    );
  }
}
