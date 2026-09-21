import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nanoai/features/browser/application/browser_pip_notifier.dart';
import 'package:nanoai/features/browser/presentation/widgets/browser_pip_surface.dart';
import 'package:nanoai/features/browser/presentation/widgets/browser_pip_webview.dart';

/// Superficie multimedia global Picture-in-Picture del Navegador Nano AI.
/// 
/// - ¿Qué hace?: Se posiciona en la capa superior de la aplicación para mantener
///   videos y audio visibles mientras se navega entre Chat, Terminal o Ajustes.
/// - ¿Cómo funciona?: Escucha rowserPipProvider, gestiona las coordenadas de
///   arrastre y redimensionamiento, y delega a BrowserPipSurface y BrowserPipWebView.
/// - ¿Por qué?: Aplica Clean Architecture (<200 líneas) y desacopla la orquestación
///   de ventanas de la estética visual del contenedor.
class BrowserPipOverlay extends ConsumerStatefulWidget {
  const BrowserPipOverlay({super.key});

  @override
  ConsumerState<BrowserPipOverlay> createState() => _BrowserPipOverlayState();
}

class _BrowserPipOverlayState extends ConsumerState<BrowserPipOverlay> {
  Offset? _dragOrigin;
  Size? _resizeOrigin;
  Offset? _dragStartGlobal;
  Offset? _resizeStartGlobal;

  @override
  Widget build(BuildContext context) {
    final pip = ref.watch(browserPipProvider);
    if (!pip.isActive) return const SizedBox.shrink();

    final notifier = ref.read(browserPipProvider.notifier);
    final screen = MediaQuery.sizeOf(context);

    // Modo PiP del sistema Android nativo
    if (pip.isSystemPip) {
      return Positioned.fill(
        child: ColoredBox(
          color: Colors.black,
          child: BrowserPipWebView(pip: pip, notifier: notifier),
        ),
      );
    }

    // Modo Maximizado dentro de Nano AI
    if (pip.isMaximized) {
      return Positioned.fill(
        child: Material(
          color: const Color(0xFF020711),
          child: SafeArea(
            child: BrowserPipSurface(
              pip: pip, notifier: notifier, maximized: true,
              onDragStart: null, onDragUpdate: null,
              onResizeStart: null, onResizeUpdate: null,
            ),
          ),
        ),
      );
    }

    // Modo Ventana Flotante Interactiva
    final size = Size(
      pip.size.width.clamp(240, screen.width - 16),
      pip.size.height.clamp(250, screen.height - 80),
    );
    final left = pip.position.dx.clamp(8, screen.width - size.width - 8).toDouble();
    final top = pip.position.dy.clamp(40, screen.height - size.height - 40).toDouble();

    return Positioned(
      left: left, top: top, width: size.width, height: size.height,
      child: BrowserPipSurface(
        pip: pip, notifier: notifier, maximized: false,
        onDragStart: (details) {
          _dragOrigin = pip.position;
          _dragStartGlobal = details.globalPosition;
        },
        onDragUpdate: (details) {
          final origin = _dragOrigin ?? pip.position;
          final start = _dragStartGlobal ?? details.globalPosition;
          notifier.updatePosition(origin + (details.globalPosition - start), screen);
        },
        onResizeStart: (details) {
          _resizeOrigin = pip.size;
          _resizeStartGlobal = details.globalPosition;
        },
        onResizeUpdate: (details) {
          final origin = _resizeOrigin ?? pip.size;
          final start = _resizeStartGlobal ?? details.globalPosition;
          final delta = details.globalPosition - start;
          notifier.resizePip(Size(origin.width + delta.dx, origin.height + delta.dy), screen);
        },
      ),
    );
  }
}
