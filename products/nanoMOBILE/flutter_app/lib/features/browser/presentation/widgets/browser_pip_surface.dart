import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:nanoai/core/theme/design_tokens.dart';
import 'package:nanoai/features/browser/application/browser_pip_notifier.dart';
import 'package:nanoai/features/browser/domain/browser_pip_model.dart';
import 'package:nanoai/features/browser/domain/browser_url_resolver.dart';
import 'package:nanoai/features/browser/presentation/widgets/browser_pip_webview.dart';

/// Marco visual Glassmorphism y cabecera de control para la superficie PiP.
/// 
/// - ¿Qué hace?: Renderiza el contenedor flotante con borde verde esmeralda,
///   sombra difusa, tirador de arrastre, controles táctiles inmunes a errores de Overlay
///   y el manejador de redimensionamiento táctil inferior.
/// - ¿Cómo funciona?: Envuelve el contenido en Material transparente y utiliza botones
///   basados en GestureDetector + Semantics en lugar de Tooltip, eliminando el fallo No Overlay.
/// - ¿Por qué?: Resuelve de forma definitiva los errores visuales del PiP y modulariza el código.
class BrowserPipSurface extends StatelessWidget {
  final BrowserPipState pip;
  final BrowserPipNotifier notifier;
  final bool maximized;
  final GestureDragStartCallback? onDragStart;
  final GestureDragUpdateCallback? onDragUpdate;
  final GestureDragStartCallback? onResizeStart;
  final GestureDragUpdateCallback? onResizeUpdate;

  const BrowserPipSurface({
    super.key,
    required this.pip,
    required this.notifier,
    required this.maximized,
    required this.onDragStart,
    required this.onDragUpdate,
    required this.onResizeStart,
    required this.onResizeUpdate,
  });

  @override
  Widget build(BuildContext context) {
    final colors = NanoThemeExtension.of(context).colors;
    final isDark = colors is NanoDarkColors;
    final radius = maximized ? 0.0 : 20.0;

    return Material(
      type: MaterialType.transparency,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(radius),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: isDark ? const Color(0xF5081422) : const Color(0xF8F8FAFC),
              borderRadius: BorderRadius.circular(radius),
              border: maximized ? null : Border.all(color: const Color(0xFF10B981).withValues(alpha: 0.7), width: 1.2),
              boxShadow: maximized ? null : [
                BoxShadow(color: Colors.black.withValues(alpha: 0.48), blurRadius: 32, offset: const Offset(0, 12)),
                BoxShadow(color: const Color(0xFF10B981).withValues(alpha: 0.18), blurRadius: 22, spreadRadius: -4),
              ],
            ),
            child: Stack(
              children: [
                Column(
                  children: [
                    _PipHeader(
                      pip: pip, notifier: notifier, isDark: isDark, maximized: maximized,
                      onDragStart: onDragStart, onDragUpdate: onDragUpdate,
                    ),
                    Expanded(child: BrowserPipWebView(pip: pip, notifier: notifier)),
                  ],
                ),
                if (!maximized)
                  Positioned(
                    right: 0, bottom: 0,
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onPanStart: onResizeStart, onPanUpdate: onResizeUpdate,
                      child: const SizedBox(
                        width: 30, height: 30,
                        child: Icon(Icons.drag_handle_rounded, size: 17, color: Colors.white54),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _PipHeader extends StatelessWidget {
  final BrowserPipState pip;
  final BrowserPipNotifier notifier;
  final bool isDark, maximized;
  final GestureDragStartCallback? onDragStart;
  final GestureDragUpdateCallback? onDragUpdate;

  const _PipHeader({
    required this.pip, required this.notifier, required this.isDark, required this.maximized,
    required this.onDragStart, required this.onDragUpdate,
  });

  @override
  Widget build(BuildContext context) {
    final host = BrowserUrlResolver.extractHost(pip.url ?? '');
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onPanStart: onDragStart, onPanUpdate: onDragUpdate,
      child: Container(
        height: 44,
        padding: const EdgeInsets.only(left: 12, right: 6),
        color: isDark ? const Color(0xEE071522) : const Color(0xF2E8EEF5),
        child: Row(
          children: [
            Container(
              width: 9, height: 9,
              decoration: const BoxDecoration(
                color: Color(0xFF34D399), shape: BoxShape.circle,
                boxShadow: [BoxShadow(color: Color(0x8834D399), blurRadius: 8)],
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    pip.title?.trim().isNotEmpty == true ? pip.title! : 'Reproductor visible',
                    maxLines: 1, overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: isDark ? Colors.white : Colors.black87),
                  ),
                  Text(host, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 9.5, color: Color(0xFF34D399))),
                ],
              ),
            ),
            if (pip.transferPending)
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 6),
                child: SizedBox.square(dimension: 14, child: CircularProgressIndicator(strokeWidth: 1.5, color: Color(0xFF34D399))),
              ),
            _PipActionBtn(label: pip.isPlaying ? 'Pausar' : 'Reproducir', icon: pip.isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded, accent: true, onTap: notifier.togglePlayPause),
            _PipActionBtn(
              label: 'Picture-in-Picture del sistema', icon: Icons.picture_in_picture_alt_rounded,
              onTap: () async {
                HapticFeedback.mediumImpact();
                final opened = await notifier.enterSystemPictureInPicture();
                if (!opened && context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Este dispositivo no admite PiP del sistema.')));
                }
              },
            ),
            _PipActionBtn(label: maximized ? 'Restaurar' : 'Maximizar', icon: maximized ? Icons.fullscreen_exit_rounded : Icons.fullscreen_rounded, onTap: notifier.toggleMaximized),
            _PipActionBtn(label: 'Cerrar', icon: Icons.close_rounded, onTap: notifier.deactivatePip),
          ],
        ),
      ),
    );
  }
}

/// Botón de acción táctil independiente de Overlay y Tooltip para prevenir fallos No Overlay.
class _PipActionBtn extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback onTap;
  final bool accent;

  const _PipActionBtn({required this.label, required this.icon, required this.onTap, this.accent = false});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: label,
      button: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () { HapticFeedback.selectionClick(); onTap(); },
        child: Container(
          width: 32, height: 32, alignment: Alignment.center,
          margin: const EdgeInsets.symmetric(horizontal: 2),
          decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.05), borderRadius: BorderRadius.circular(6)),
          child: Icon(icon, size: 18, color: accent ? const Color(0xFF34D399) : (Colors.white.withValues(alpha: 0.85))),
        ),
      ),
    );
  }
}
