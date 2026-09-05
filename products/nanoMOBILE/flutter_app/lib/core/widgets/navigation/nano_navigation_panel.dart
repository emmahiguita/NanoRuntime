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

  @override
  ConsumerState<NanoFloatingNavigationFrame> createState() =>
      _NanoFloatingNavigationFrameState();
}

class _NanoFloatingNavigationFrameState
    extends ConsumerState<NanoFloatingNavigationFrame> {
  /// Altura real de la barra (crece con el campo multilínea). Inicial 110:
  /// la altura típica en reposo evita el salto del primer frame.
  double _dockHeight = _kInitialDockHeight;
  final _barKey = GlobalKey();

  static const double _kInitialDockHeight = 110;
  /// NAV-LANDSCAPE-01 — gap aumentado en landscape: la barra puede ser más
  /// alta (campo multilinea) y el aire entre contenido y barra evita solape.
  static const double _kDockGapPortrait = 12;
  static const double _kDockGapLandscape = 16;

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
  Widget build(BuildContext context) {
    final destination = NanoDestination.fromIndex(widget.selectedIndex);
    final brightness = Theme.of(context).brightness;
    ref.watch(nanoUniversalInputProvider);
    final inputConfig = ref
        .read(nanoUniversalInputProvider.notifier)
        .slotFor(widget.slotId ?? destination.name);
    // OVERLAP-FIX-01 — los insets del sistema (home indicator, navbar Android)
    // se suman al padding del CONTENIDO igual que a la barra flotante para que
    // nunca quede nada debajo de la barra en ningún dispositivo.
    final systemBottomInset = MediaQuery.paddingOf(context).bottom;

    return LayoutBuilder(
      builder: (context, constraints) {
        final isLandscape = constraints.maxWidth > constraints.maxHeight;
        final isCompact =
            constraints.maxWidth < 520 || constraints.maxHeight < 520;
        final dockGap = isLandscape ? _kDockGapLandscape : _kDockGapPortrait;
        // OVERLAP-FIX-01 — padding total = altura real de la barra +
        // gap de aire + insets del sistema. Cero saltos, cero solapamientos.
        final totalBottomPad = _dockHeight + dockGap + systemBottomInset;

        return Stack(
          fit: StackFit.expand,
          children: [
            // Contenido desplazado exactamente el espacio que ocupa la barra
            // (incluyendo insets del sistema). AnimatedPadding anima suavemente
            // cuando el campo crece (multilínea) o cambia orientación.
            AnimatedPadding(
              duration: const Duration(milliseconds: 260),
              curve: Curves.easeOutCubic,
              padding: EdgeInsets.only(bottom: totalBottomPad),
              child: RepaintBoundary(child: widget.child),
            ),
            AnimatedPositioned(
              duration: const Duration(milliseconds: 260),
              curve: Curves.easeOutCubic,
              left: 0,
              right: 0,
              bottom: dockGap,
              // NAV-UI-AUDIT-01 — SafeArea solo para la barra flotante.
              // El contenido ya compensó los insets manualmente (totalBottomPad).
              child: SafeArea(
                top: false,
                child: NotificationListener<SizeChangedLayoutNotification>(
                  onNotification: (_) {
                    _measureBar();
                    return false;
                  },
                  child: SizeChangedLayoutNotifier(
                    key: _barKey,
                    child: Center(
                      child: Padding(
                        padding: EdgeInsets.symmetric(
                          horizontal: isCompact ? 10 : 16,
                        ),
                        child: RepaintBoundary(
                          child: NanoMultiUseNavBar(
                            selected: destination,
                            compact: isCompact,
                            brightness: brightness,
                            inputConfig: inputConfig,
                            searchHint: widget.searchHint,
                            onDestinationSelected: (d) {
                              widget.onDestinationSelected(d.index);
                            },
                            onSearch: widget.onSearch ??
                                (query) {
                                  NanoSearchDispatcher.dispatch(
                                    context,
                                    query,
                                  );
                                },
                            onVoice: widget.onVoice,
                            onAvatarTap: widget.selectedIndex ==
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
        Positioned.fill(
          child: background ?? const AutomationBackdrop(),
        ),
        NanoFloatingNavigationFrame(
          slotId: slotId,
          selectedIndex: selectedIndex ?? NanoDestination.automation.index,
          onDestinationSelected: (index) {
            context.go(NanoDestination.fromIndex(index).route);
          },
          // NAV-BAR-FIX-04 — las visuales fuera del shell no saltan a otra
          // pantalla: si el destino activo no definió su onSubmit (p.ej.
          // Mensajes, slot vacío), el envío se queda aquí en vez de caer al
          // dispatcher global y navegar a Chat.
          onSearch: (_) {},
          child: child,
        ),
      ],
    );
  }
}
