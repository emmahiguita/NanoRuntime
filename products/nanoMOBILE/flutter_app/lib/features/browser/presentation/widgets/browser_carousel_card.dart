// QUÉ: Tarjeta de pestaña estilo iOS Safari para la vista en carrusel de Nano Browser.
// CÓMO: Incluye cabecera con favicon/título y botón cerrar [X], cuerpo con la vista web y tap para enfocar.
// POR QUÉ: Elimina cabeceras duplicadas y permite seleccionar o cerrar pestañas con fluidez (< 130 líneas).

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../domain/browser_tab_model.dart';

class BrowserCarouselCard extends StatelessWidget {
  final BrowserTabModel tab;
  final bool isCurrent;
  final VoidCallback onSelect;
  final VoidCallback onClose;
  final Widget child;

  const BrowserCarouselCard({
    super.key,
    required this.tab,
    required this.isCurrent,
    required this.onSelect,
    required this.onClose,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final headerBg = isDark
        ? theme.colorScheme.surfaceContainerHigh.withValues(alpha: 0.95)
        : const Color(0xFFF1F5F9);
    final borderColor = isCurrent
        ? (isDark ? const Color(0xFF38BDF8) : const Color(0xFF2563EB))
        : (isDark ? Colors.white.withValues(alpha: 0.12) : const Color(0xFFCBD5E1));

    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: borderColor, width: isCurrent ? 1.6 : 0.9),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.35 : 0.10),
            blurRadius: isCurrent ? 18 : 8,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(19),
        child: Column(
          children: [
            // Cabecera limpia de pestaña estilo iOS Safari
            Material(
              color: headerBg,
              child: InkWell(
                onTap: () {
                  HapticFeedback.lightImpact();
                  onSelect();
                },
                child: Container(
                  height: 38,
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  decoration: BoxDecoration(
                    border: Border(
                      bottom: BorderSide(
                        color: isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.06),
                        width: 0.8,
                      ),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        tab.url.startsWith('https://')
                            ? CupertinoIcons.lock_shield_fill
                            : CupertinoIcons.globe,
                        size: 14,
                        color: tab.url.startsWith('https://')
                            ? (isDark ? const Color(0xFF38BDF8) : const Color(0xFF0284C7))
                            : (isDark ? Colors.white54 : Colors.black45),
                      ),
                      const SizedBox(width: 7),
                      Expanded(
                        child: Text(
                          tab.title.isEmpty ? tab.displayHost : tab.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: isCurrent ? FontWeight.w600 : FontWeight.w500,
                            color: isDark ? Colors.white : const Color(0xFF1E293B),
                          ),
                        ),
                      ),
                      const SizedBox(width: 4),
                      Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: () {
                            HapticFeedback.lightImpact();
                            onClose();
                          },
                          borderRadius: BorderRadius.circular(12),
                          child: Container(
                            padding: const EdgeInsets.all(5),
                            decoration: BoxDecoration(
                              color: isDark
                                  ? Colors.white.withValues(alpha: 0.12)
                                  : Colors.black.withValues(alpha: 0.07),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              CupertinoIcons.xmark,
                              size: 11,
                              color: isDark ? Colors.white70 : Colors.black54,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            // Contenido web interactivo / tap para enfocar pestaña
            Expanded(
              child: Stack(
                fit: StackFit.expand,
                children: [
                  child,
                  GestureDetector(
                    behavior: HitTestBehavior.translucent,
                    onTap: () {
                      HapticFeedback.lightImpact();
                      onSelect();
                    },
                    child: const ColoredBox(color: Colors.transparent),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
