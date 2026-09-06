import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:nanoai/features/automation/presentation/automation_visual_theme.dart';
import 'nano_destination.dart';
import 'nano_multi_use_nav_bar.dart';
import 'nano_search_dispatcher.dart';
import 'nano_universal_input.dart';

/// Marco de navegación principal de Nano AI.
///
/// Implementa la arquitectura SOLID de entrada universal: observa el provider
/// `nanoUniversalInputProvider` para que la pantalla activa configure de forma
/// limpia y desacoplada el placeholder, las acciones de envío, voz y adjuntos.
///
/// NAV-UI-AUDIT-01 — el SafeArea vive AQUÍ (fuente única): el shell y las
/// pantallas empujadas reciben los mismos insets de sistema en la barra.
class NanoFloatingNavigationFrame extends ConsumerStatefulWidget {
  const NanoFloatingNavigationFrame({
    super.key,
    required this.child,
    required this.selectedIndex,
    required this.onDestinationSelected,
    this.slotId,
    this.onSearch,
    this.onVoice,
    this.onAvatarTap,
    this.searchHint = 'Buscar, conversar o ejecutar en Nano AI...',
    this.fullBleed = false,
    this.transparentDock = false,
    this.protectTop = false,
  });

  final Widget child;
  final int selectedIndex;
  final ValueChanged<int> onDestinationSelected;

  /// Slot del provider de input del que se lee la config. null → se deriva
  /// del destino activo (`destination.name`); las pantallas empujadas pasan
  /// el suyo para no chocar con el slot del shell (NAV-UI-AUDIT-01: antes
  /// reglas y dashboard compartían 'automation' y el envío podía ejecutar
  /// la acción de la OTRA pantalla montada).
  final String? slotId;
  final ValueChanged<String>? onSearch;
  final VoidCallback? onVoice;
  final VoidCallback? onAvatarTap;
  final String searchHint;

  /// HOME-BLEED-01 — el child se pinta a pantalla COMPLETA (sin reservar
  /// franja inferior para la barra). Para pantallas-fondo (Inicio con su
  /// wallpaper): la imagen llega hasta el borde inferior y la barra flota
  /// encima. Solo cuando abajo no hay contenido interactivo que ocultar.
  final bool fullBleed;

  /// HOME-BLEED-01 — el dock deja de pintar su cáscara (gradiente + blur) y
  /// queda transparente: detrás de la barra se ve el MISMO fondo de la
  /// pantalla, sin corte ni color distinto.
  final bool transparentDock;

  /// TOP-INSET-FIX-01 — el frame aplica SafeArea superior como FUENTE ÚNICA
  /// (NAV-UI-AUDIT-01): el contenido jamás queda solapado con la barra de
  /// estado. Las pantallas hijas NO deben añadir su propio SafeArea top
  /// (duplicaría el inset). En fullBleed se desactiva (el fondo pinta hasta
  /// el borde; el contenido se protege solo, p. ej. la marca de Inicio).
  final bool protectTop;

  @override
  ConsumerState<NanoFloatingNavigationFrame> createState() =>
      _NanoFloatingNavigationFrameState();
}

class _NanoFloatingNavigationFrameState
    extends ConsumerState<NanoFloatingNavigationFrame> {
  /// Altura real de la barra (crece con el campo multilínea). Inicial 132:
  /// coincide con la altura calculada en reposo (~132.8px), eliminando
  /// el salto visual (twitch de 23px) que ocurría en el primer frame.
  static const double _kInitialDockHeight = 132.0;
  double _dockHeight = _kInitialDockHeight;
  final _barKey = GlobalKey();

  static const double _kDockGapPortrait = 16.0;
  static const double _kDockGapLandscape = 12.0;

  /// Mide la altura real de la barra con PostFrameCallback + notificaciones.
  void _measureBar() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final size = _barKey.currentContext?.size;
      if (size == null) return;
      // Umbral 0.5px: detecta cambios sub-pixel en multilínea sin rebuild innecesario.
      if ((size.height - _dockHeight).abs() > 0.5) {
        setState(() => _dockHeight = size.height);
      }
    });
  }

  @override
  void didUpdateWidget(covariant NanoFloatingNavigationFrame oldWidget) {
    super.didUpdateWidget(oldWidget);
    // WA-REG-01 — al cambiar de pestaña, el build de este frame corre ANTES
    // de que el scope destino reaplique su config (didChangeDependencies →
    // postFrame → setConfig); si los datos son iguales no hay notificación y
    // la barra conserva la config leída antes de la reaplicación. Un rebuild
    // extra tras el frame cierra el hueco: el slot ya está fresco.
    if (oldWidget.selectedIndex != widget.selectedIndex) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) setState(() {});
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final destination = NanoDestination.fromIndex(widget.selectedIndex);
    final brightness = Theme.of(context).brightness;
    // NAV-REBUILD-FIX: usar ref.watch una sola vez y derivar el slot directamente.
    // Antes: ref.watch() para rebuild + ref.read() para leer = 2 accesos
    // separados y rebuilds en cada keypress. Ahora un solo acceso.
    final notifier = ref.read(nanoUniversalInputProvider.notifier);
    ref.watch(
      nanoUniversalInputProvider,
    ); // observar para notificaciones de cambio
    final inputConfig = notifier.slotFor(widget.slotId ?? destination.name);

    final systemBottomInset = MediaQuery.paddingOf(context).bottom;
    final keyboardInset = MediaQuery.viewInsetsOf(context).bottom;

    return LayoutBuilder(
      builder: (context, constraints) {
        final isDeviceLandscape =
            MediaQuery.orientationOf(context) == Orientation.landscape;
        final isLandscape = isDeviceLandscape && constraints.maxWidth > 520;
        final isCompact =
            constraints.maxWidth < 520 ||
            (isDeviceLandscape && constraints.maxHeight < 520);
        final baseGap = isLandscape ? _kDockGapLandscape : _kDockGapPortrait;

        // Flotación real: si el teclado está abierto, flota sobre el teclado.
        // Si está cerrado, flota con espacio holgado sobre la barra de gestos o
        // botones del sistema (nunca pegada ni solapando los bordes).
        final floatingBottom = keyboardInset > 0
            ? (keyboardInset + 10.0)
            : (systemBottomInset > 0
                  ? (systemBottomInset + baseGap)
                  : (baseGap + 8.0));

        // Margen horizontal generoso para que sea una auténtica cápsula/isla flotante
        // y nunca toque los bordes laterales del dispositivo.
        final horizontalMargin = isLandscape ? 32.0 : (isCompact ? 16.0 : 20.0);

        // Padding inferior del contenido para que nada quede oculto tras la barra flotante.
        final totalBottomPad = _dockHeight + floatingBottom + 12.0;

        return Stack(
          fit: StackFit.expand,
          children: [
            // Contenido desplazado exactamente el espacio que ocupa la barra
            // (incluyendo insets del sistema y teclado). AnimatedPadding anima suavemente
            // cuando el campo crece (multilínea), cambia orientación o sube el teclado.
            // HOME-BLEED-01: en fullBleed el child pinta a pantalla completa
            // (sin padding) — el fondo llega al borde y la barra flota encima.
            // TOP-INSET-FIX-01: SafeArea top como fuente única de insets.
            SafeArea(
              top: widget.protectTop && !widget.fullBleed,
              bottom: false,
              left: false,
              right: false,
              child: AnimatedPadding(
                duration: const Duration(milliseconds: 260),
                curve: Curves.easeOutCubic,
                padding: EdgeInsets.only(
                  bottom: widget.fullBleed ? 0 : totalBottomPad,
                ),
                child: RepaintBoundary(child: widget.child),
              ),
            ),
            AnimatedPositioned(
              duration: const Duration(milliseconds: 260),
              curve: Curves.easeOutCubic,
              left: 0,
              right: 0,
              bottom: floatingBottom,
              child: NotificationListener<SizeChangedLayoutNotification>(
                onNotification: (_) {
                  _measureBar();
                  return false;
                },
                child: SizeChangedLayoutNotifier(
                  key: _barKey,
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 520),
                      child: Padding(
                        padding: EdgeInsets.symmetric(
                          horizontal: horizontalMargin,
                        ),
                        child: RepaintBoundary(
                          child: NanoMultiUseNavBar(
                            selected: destination,
                            compact: isCompact,
                            brightness: brightness,
                            transparent: widget.transparentDock,
                            inputConfig: inputConfig,
                            searchHint: widget.searchHint,
                            onDestinationSelected: (d) {
                              widget.onDestinationSelected(d.index);
                            },
                            onSearch:
                                widget.onSearch ??
                                (query) {
                                  NanoSearchDispatcher.dispatch(context, query);
                                },
                            onVoice: widget.onVoice,
                            onAvatarTap:
                                widget.selectedIndex ==
                                    NanoDestination.chat.index
                                ? null
                                : (widget.onAvatarTap ??
                                      () {
                                        context.go('/chat');
                                      }),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

/// Envuelve pantallas empujadas (fuera del shell, p.ej. /automation y sus
/// pantallas internas) con la barra global: escritura universal + dock de
/// pestañas que salta a cualquier sección con `go`. DRY: un solo punto donde
/// las visuales fuera del shell reciben la barra.
///
/// Monta el fondo continuo a pantalla completa (`AutomationBackdrop`) detrás
/// del frame para que la barra flotante y su efecto glass desenfoquen el fondo
/// líquido continuo y jamás queden cortes negros por el padding inferior.
class NanoShellBarScope extends StatelessWidget {
  const NanoShellBarScope({
    super.key,
    required this.child,
    this.selectedIndex,
    this.slotId,
    this.background,
  });

  final Widget child;
  final int? selectedIndex;

  /// Slot propio de la pantalla (NAV-UI-AUDIT-01). Sin él, el frame leería
  /// el slot del destino activo ('automation') y el envío de esta pantalla
  /// ejecutaría la acción del dashboard montado debajo.
  final String? slotId;
  final Widget? background;

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        Positioned.fill(child: background ?? const AutomationBackdrop()),
        NanoFloatingNavigationFrame(
          slotId: slotId,
          selectedIndex: selectedIndex ?? NanoDestination.automation.index,
          // HOME-BLEED-01 — la cáscara de la barra sale en TODA la app:
          // detrás del dock se ve el mismo fondo de la pantalla.
          transparentDock: true,
          // TOP-INSET-FIX-01 — fuente única del inset superior en las
          // pantallas empujadas (las hijas no añaden SafeArea top propio).
          protectTop: true,
          onDestinationSelected: (index) {
            context.go(NanoDestination.fromIndex(index).route);
          },
          // Si no se provee un onSearch específico, hereda el comportamiento
          // por defecto de NanoFloatingNavigationFrame (NanoSearchDispatcher.dispatch).
          child: child,
        ),
      ],
    );
  }
}
