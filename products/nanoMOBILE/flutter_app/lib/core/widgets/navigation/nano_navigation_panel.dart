import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../theme/design_tokens.dart';
import 'nano_destination.dart';
import 'nano_multi_use_nav_bar.dart';
import 'nano_search_dispatcher.dart';
import 'nano_universal_input.dart';

typedef NavTabSpec = ({IconData icon, IconData sel, String label});

enum NanoNavigationDock { topLeft, topRight, bottomLeft, bottomRight }

/// Pestañas del shell, compartidas por el shell y por las pantallas
/// empujadas (automatización, reglas, dev...) que muestran la barra global.
/// Fuente única: si cambia una pestaña, cambia en todas las visuales.
const List<NavTabSpec> nanoShellTabs = [
  (
    icon: Icons.dashboard_outlined,
    sel: Icons.dashboard_rounded,
    label: 'Inicio',
  ),
  (icon: Icons.chat_outlined, sel: Icons.chat_rounded, label: 'Chat'),
  (
    icon: Icons.extension_outlined,
    sel: Icons.extension_rounded,
    label: 'Modelos',
  ),
  (
    icon: Icons.terminal_outlined,
    sel: Icons.terminal_rounded,
    label: 'Terminal',
  ),
  (
    icon: Icons.settings_outlined,
    sel: Icons.settings_rounded,
    label: 'Ajustes',
  ),
  // Acceso directo a Automatización (mismo icono que su tarjeta en Inicio).
  (
    icon: Icons.auto_awesome_outlined,
    sel: Icons.auto_awesome_rounded,
    label: 'Automatización',
  ),
];

@immutable
class NanoFloatingNavigationStyle {
  const NanoFloatingNavigationStyle({
    required this.accent,
    required this.onAccent,
    required this.accentSoft,
    required this.text,
    required this.textMuted,
    required this.surfaceStart,
    required this.surfaceEnd,
    required this.border,
    required this.shadow,
  });

  factory NanoFloatingNavigationStyle.fromTheme(BuildContext context) {
    final colors = NanoThemeExtension.of(context).colors;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return NanoFloatingNavigationStyle(
      accent: colors.primary,
      onAccent: colors.onAccent,
      accentSoft: colors.primary.withValues(alpha: isDark ? 0.18 : 0.12),
      text: colors.textPrimary,
      textMuted: colors.textSecondary,
      surfaceStart: isDark
          ? colors.glass100.withValues(alpha: 0.90)
          : Colors.white.withValues(alpha: 0.88),
      surfaceEnd: isDark
          ? colors.glassBlue.withValues(alpha: 0.72)
          : colors.glassSecondary.withValues(alpha: 0.68),
      border: isDark ? colors.borderAccentColor : colors.borderPrimaryColor,
      shadow: Colors.black.withValues(alpha: isDark ? 0.34 : 0.14),
    );
  }

  final Color accent;
  final Color onAccent;
  final Color accentSoft;
  final Color text;
  final Color textMuted;
  final Color surfaceStart;
  final Color surfaceEnd;
  final Color border;
  final Color shadow;
}

/// Marco de navegación principal de Nano AI.
///
/// Implementa la arquitectura SOLID de entrada universal: observa el provider
/// `nanoUniversalInputProvider` para que la pantalla activa configure de forma
/// limpia y desacoplada el placeholder, las acciones de envío, voz y adjuntos.
class NanoFloatingNavigationFrame extends ConsumerStatefulWidget {
  const NanoFloatingNavigationFrame({
    super.key,
    required this.child,
    required this.tabs,
    required this.selectedIndex,
    required this.onDestinationSelected,
    this.style,
    this.hidden = false,
    this.onSearch,
    this.onVoice,
    this.onAvatarTap,
    this.searchHint = 'Buscar, conversar o ejecutar en Nano AI...',
    this.initialDock = NanoNavigationDock.bottomRight,
  });

  final Widget child;
  final List<NavTabSpec> tabs;
  final int selectedIndex;
  final ValueChanged<int> onDestinationSelected;
  final NanoFloatingNavigationStyle? style;
  final bool hidden;
  final ValueChanged<String>? onSearch;
  final VoidCallback? onVoice;
  final VoidCallback? onAvatarTap;
  final String searchHint;
  final NanoNavigationDock initialDock;

  @override
  ConsumerState<NanoFloatingNavigationFrame> createState() =>
      _NanoFloatingNavigationFrameState();
}

class _NanoFloatingNavigationFrameState
    extends ConsumerState<NanoFloatingNavigationFrame> {
  /// Altura real de la barra (crece con el campo multilínea). Inicial 110:
  /// la altura típica en reposo evita el salto del primer frame.
  double _dockHeight = 110;
  final _barKey = GlobalKey();

  @override
  Widget build(BuildContext context) {
    final destination = NanoDestination.fromIndex(widget.selectedIndex);
    final brightness = Theme.of(context).brightness;
    // NAV-BAR-FIX-01 — config del destino ACTIVO por slot (no la global):
    // el último scope montado ya no pisa la barra al cambiar de pestaña.
    // El watch suscribe al provider para reconstruir cuando un slot cambia;
    // la config se lee del notifier (los slots no viven en el estado global).
    ref.watch(nanoUniversalInputProvider);
    final inputConfig = ref
        .read(nanoUniversalInputProvider.notifier)
        .slotFor(destination.name);

    return LayoutBuilder(
      builder: (context, constraints) {
        final screenWidth = constraints.maxWidth;
        final isCompact = screenWidth < 520;

        return Stack(
          fit: StackFit.expand,
          children: [
            // NAV-BAR-FIX-06 — flotante visual + reserva real: la barra
            // conserva su look de vidrio flotante pero el contenido ADAPTA
            // su altura (AnimatedPadding con la altura medida de la barra),
            // nunca queda un componente debajo del otro. Si la card crece
            // con el campo multilínea, el contenido se empuja suavemente.
            AnimatedPadding(
              duration: const Duration(milliseconds: 280),
              curve: Curves.easeOutCubic,
              padding: EdgeInsets.only(bottom: _dockHeight + 10),
              child: RepaintBoundary(child: widget.child),
            ),
            AnimatedPositioned(
              duration: const Duration(milliseconds: 280),
              curve: Curves.easeOutCubic,
              left: 0,
              right: 0,
              bottom: widget.hidden ? -(_dockHeight + 40) : 10,
              child: AnimatedOpacity(
                duration: const Duration(milliseconds: 220),
                opacity: widget.hidden ? 0.0 : 1.0,
                curve: Curves.easeInOut,
                child: NotificationListener<SizeChangedLayoutNotification>(
                  onNotification: (_) {
                    // La barra creció con el campo multilínea: reservar la
                    // nueva altura para que no tape el contenido.
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      final size = _barKey.currentContext?.size;
                      if (size == null || !mounted) return;
                      if ((size.height - _dockHeight).abs() > 1) {
                        setState(() => _dockHeight = size.height);
                      }
                    });
                    return false;
                  },
                  child: SizeChangedLayoutNotifier(
                    key: _barKey,
                    child: Center(
                      child: Padding(
                        // NAV-BAR-FIX-02 — ancho completo (antes capado a
                        // 620 centrado: la card no aprovechaba el espacio en
                        // tablet/landscape y dejaba bordes muertos).
                        padding: const EdgeInsets.symmetric(horizontal: 10),
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
                          // NAV-BAR-FIX-05 — sin voz definida la barra dicta
                          // directo al campo (default real). Antes el fallback
                          // navegaba a /automation: el mic mentía su función.
                          onVoice: widget.onVoice,
                          // NAV-BAR-FIX-02 — el orbe es el acceso al
                          // asistente: en el propio chat no aporta y le robaba
                          // ancho al campo protagonista.
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
class NanoShellBarScope extends StatelessWidget {
  const NanoShellBarScope({
    super.key,
    required this.child,
    this.selectedIndex,
  });

  final Widget child;
  final int? selectedIndex;

  @override
  Widget build(BuildContext context) {
    return NanoFloatingNavigationFrame(
      tabs: nanoShellTabs,
      selectedIndex:
          selectedIndex ?? NanoDestination.automation.index,
      onDestinationSelected: (index) {
        context.go(NanoDestination.fromIndex(index).route);
      },
      // NAV-BAR-FIX-04 — las visuales fuera del shell no saltan a otra
      // pantalla: si el destino activo no definió su onSubmit (p.ej.
      // Mensajes, slot vacío), el envío se queda aquí en vez de caer al
      // dispatcher global y navegar a Chat.
      onSearch: (_) {},
      child: child,
    );
  }
}
