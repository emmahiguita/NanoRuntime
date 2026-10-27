// browser_screen.dart — Pantalla completa del navegador web de Nano AI.
// QUÉ HACE: Presenta BrowserWindowWidget en modo fullscreen real, sin solapamientos con el dashboard.
// CÓMO FUNCIONA: Ocupa todo el Scaffold con fondo opaco; usa SafeArea para respetar insets nativos.
//   Al entrar: detach las WebViews del host embebido. Al salir: las devuelve al host embebido.
// POR QUÉ: backgroundColor transparente causaba que el navegador mostrara el dashboard debajo.
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../application/browser_surface_notifier.dart';
import '../../application/browser_tab_notifier.dart';
import '../../application/browser_webview_registry.dart';
import '../widgets/browser_window_widget.dart';

/// Pantalla completa del navegador móvil Nano AI — sin solapamientos, fondo propio.
class BrowserScreen extends ConsumerStatefulWidget {
  /// URL opcional a cargar al abrir (viene del query param ?url=).
  final String? initialUrl;

  const BrowserScreen({super.key, this.initialUrl});

  @override
  ConsumerState<BrowserScreen> createState() => _BrowserScreenState();
}

class _BrowserScreenState extends ConsumerState<BrowserScreen> {
  // Controla si las WebViews ya fueron desacopladas del host embebido.
  bool _surfaceReady = false;

  @override
  void initState() {
    super.initState();
    // Desacoplar el host embebido antes de montar las PlatformViews fullscreen.
    // Hacerlo en postFrameCallback para evitar conflictos con el primer build.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ref.read(browserSurfaceProvider.notifier).showFullscreen();
      setState(() => _surfaceReady = true);
    });
  }

  @override
  void dispose() {
    // Al salir, devolver las WebViews al host embebido del dashboard.
    ref.read(browserSurfaceProvider.notifier).showEmbedded();
    super.dispose();
  }

  /// Retrocede en la web; al llegar al inicio vuelve al módulo Automatización.
  Future<void> _handleBack() async {
    final activeTab = ref.read(browserTabProvider).activeTab;
    final ctrl = ref
        .read(browserWebViewRegistryProvider)
        .controllerFor(activeTab.id);
    if (ctrl != null && await ctrl.canGoBack()) {
      await ctrl.goBack();
      return;
    }
    _goToAutomation();
  }

  /// El botón visible y el gesto del sistema comparten un destino predecible.
  void _goToAutomation() {
    if (!mounted) return;
    context.go('/automation');
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final mq = MediaQuery.of(context);
    final isLandscape = mq.orientation == Orientation.landscape;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      // Ajusta los íconos del sistema al tema real, también en modo claro.
      value:
          (colors.brightness == Brightness.dark
                  ? SystemUiOverlayStyle.light
                  : SystemUiOverlayStyle.dark)
              .copyWith(
                statusBarColor: Colors.transparent,
                systemNavigationBarColor: colors.surface,
              ),
      child: PopScope(
        // Intercepta el botón back del sistema para retroceder en historial o salir limpiamente.
        canPop: false,
        onPopInvokedWithResult: (didPop, _) {
          if (!didPop) _handleBack();
        },
        child: Scaffold(
          // Fondo opaco oscuro: ELIMINA el solapamiento con el dashboard debajo.
          backgroundColor: colors.surface,
          // false: el navegador gestiona su propio layout con las WebViews.
          resizeToAvoidBottomInset: false,
          body: SafeArea(
            // En landscape dejamos los insets laterales para el notch.
            left: isLandscape,
            right: isLandscape,
            bottom:
                true, // Protege controles y página de la barra de gestos del sistema.
            child: _surfaceReady
                ? Padding(
                    // Solo el notch horizontal necesita separación exterior.
                    padding: EdgeInsets.symmetric(
                      horizontal: isLandscape ? 4 : 0,
                    ),
                    child: BrowserWindowWidget(
                      isEmbedded: false,
                      initialUrl: widget.initialUrl,
                      onClose: _goToAutomation,
                    ),
                  )
                : const _LoadingPlaceholder(),
          ),
        ),
      ),
    );
  }
}

/// Placeholder mientras las WebViews se desacoplan del host embebido.
// Se muestra <1 frame, pero evita un flash blanco o transparente.
class _LoadingPlaceholder extends StatelessWidget {
  const _LoadingPlaceholder();

  @override
  Widget build(BuildContext context) =>
      const Center(child: CircularProgressIndicator(strokeWidth: 2.0));
}
