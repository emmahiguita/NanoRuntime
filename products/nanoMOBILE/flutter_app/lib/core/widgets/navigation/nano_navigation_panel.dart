import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:nanoai/core/theme/nano_motion.dart';
import 'package:nanoai/features/automation/presentation/automation_visual_theme.dart';
import 'nano_destination.dart';
import 'nano_glyph.dart';
import 'nano_multi_use_nav_bar.dart';
import 'nano_nav_mini_pill.dart';
import 'nano_nav_tokens.dart';
import 'nano_search_dispatcher.dart';
import 'nano_universal_input.dart';

/// Modos de visualización adaptativa del dock de navegación de Nano AI.
enum NanoNavDockMode {
  /// Estado 1: Barra cósmica flotante inferior completa (búsqueda + 6 destinos).
  bottom,

  /// Estado 2: Barra contraída en la esquina inferior derecha con activador cósmico.
  rightCollapsed,

  /// Estado 3: Barra contraída en la esquina inferior izquierda con activador cósmico.
  leftCollapsed,

  /// Estado 4: Barra contraída en la esquina superior derecha.
  topRight,

  /// Estado 5: Barra contraída en la esquina superior izquierda.
  topLeft,

  /// Estado 6: Panel lateral derecho (drawer glass) con los 6 destinos y buscador.
  rightDrawer;

  /// Alias semánticos para posicionamiento en esquinas
  static const NanoNavDockMode bottomRight = rightCollapsed;
  static const NanoNavDockMode bottomLeft = leftCollapsed;
}

/// Marco de navegación principal de Nano AI.
///
/// Implementa la arquitectura SOLID de entrada universal: observa el provider
/// `nanoUniversalInputProvider` para que la pantalla activa configure de forma
/// limpia y desacoplada el placeholder, las acciones de envío, voz y adjuntos.
///
/// Soporta estados de snap adaptativos (Bottom Dock, Corner Dock y Right Drawer)
/// sin duplicar rutas ni controladores de navegación.
const double kNanoBarScrollReserve = 200.0;
const double kNanoBarScrollReserveLandscape = 76.0;

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
    this.searchHint = 'Buscar, conversar o ejecutar en Nano AI...',
    this.fullBleed = false,
    this.floatOverContent = false,
    this.transparentDock = false,
    this.protectTop = false,
    this.initialDockMode = NanoNavDockMode.bottom,
    this.allowSideDock = true,
  });

  final Widget child;
  final int selectedIndex;
  final ValueChanged<int> onDestinationSelected;
  final NanoNavDockMode initialDockMode;

  /// Si es true (por defecto), permite posicionar la barra en las esquinas
  /// de la pantalla tanto en orientación vertical como horizontal.
  final bool allowSideDock;

  /// Slot del provider de input del que se lee la config. null → se deriva
  /// del destino activo (`destination.name`); las pantallas empujadas pasan
  /// el suyo para no chocar con el slot del shell (NAV-UI-AUDIT-01: antes
  /// reglas y dashboard compartían 'automation' y el envío podía ejecutar
  /// la acción de la OTRA pantalla montada).
  final String? slotId;
  final ValueChanged<String>? onSearch;
  final VoidCallback? onVoice;
  final String searchHint;

  /// HOME-BLEED-01 — el child se pinta a pantalla COMPLETA (sin reservar
  /// franja inferior para la barra). Para pantallas-fondo (Inicio con su
  /// wallpaper): la imagen llega hasta el borde inferior y la barra flota
  /// encima. Solo cuando abajo no hay contenido interactivo que ocultar.
  final bool fullBleed;

  /// NAV-FLOAT-01 — el child pinta a pantalla completa y la barra flota
  /// encima SIN reservar franja inferior en el layout (el fondo no se
  /// recorta). Las pantallas hijas reservan su propio espacio en el scroll
  /// ([kNanoBarScrollReserve]). A diferencia de fullBleed, el SafeArea top
  /// se conserva: esto es para pantallas con contenido, no fondos.
  final bool floatOverContent;

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

class _NanoFloatingNavigationFrameState extends ConsumerState<NanoFloatingNavigationFrame> {
  /// Altura real de la barra (crece con el campo multilínea). Inicial 132:
  /// coincide con la altura calculada en reposo (~132.8px), eliminando
  /// el salto visual (twitch de 23px) que ocurría en el primer frame.
  static const double _kInitialDockHeight = 132.0;
  double _dockHeight = _kInitialDockHeight;
  final _barKey = GlobalKey();

  static const double _kDockGapPortrait = 16.0;
  static const double _kDockGapLandscape = 12.0;

  late NanoNavDockMode _dockMode = widget.allowSideDock
      ? widget.initialDockMode
      : NanoNavDockMode.bottom;
  Offset _dragOffset = Offset.zero;
  bool _isDragging = false;
  double? _sideDockY;
  bool _isDrawerSearchExpanded = false;
  final TextEditingController _drawerSearchController = TextEditingController();
  final FocusNode _drawerSearchFocusNode = FocusNode();

  Timer? _autoShrinkTimer;
  bool _isBarMinimized = false;
  bool _hasAutoShrunkInLandscape = false;

  void _scheduleAutoShrink({int milliseconds = 3200}) {
    _autoShrinkTimer?.cancel();
    _autoShrinkTimer = Timer(Duration(milliseconds: milliseconds), () {
      if (!mounted) return;
      final keyboard = MediaQuery.viewInsetsOf(context).bottom;
      if (keyboard > 0 || _isDragging || _isBarMinimized || _isDrawerSearchExpanded) return;
      setState(() {
        _isBarMinimized = true;
      });
    });
  }

  void _cancelAutoShrink() {
    _autoShrinkTimer?.cancel();
    _autoShrinkTimer = null;
  }

  @override
  void initState() {
    super.initState();
    _drawerSearchController.addListener(_onSearchChanged);
  }

  void _onSearchChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _autoShrinkTimer?.cancel();
    _drawerSearchController.removeListener(_onSearchChanged);
    _drawerSearchController.dispose();
    _drawerSearchFocusNode.dispose();
    super.dispose();
  }

  /// Mide la altura real de la barra con PostFrameCallback + notificaciones.
  void _measureBar() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final size = _barKey.currentContext?.size;
      if (size == null) return;
      // Umbral 2.0px: evita disparar rebuilds espurios por fluctuaciones sub-pixel
      // en la tipografia o redondeo de layout durante transiciones de pantalla.
      if ((size.height - _dockHeight).abs() > 2.0) {
        setState(() => _dockHeight = size.height);
      }
    });
  }

  @override
  void didUpdateWidget(covariant NanoFloatingNavigationFrame oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!widget.allowSideDock && _dockMode != NanoNavDockMode.bottom) {
      setState(() {
        _dockMode = NanoNavDockMode.bottom;
        _isDrawerSearchExpanded = false;
        _dragOffset = Offset.zero;
        _isDragging = false;
        _sideDockY = null;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final destination = NanoDestination.fromIndex(widget.selectedIndex);
    final brightness = Theme.of(context).brightness;
    final isDark = brightness == Brightness.dark;

    // PERFORMANCE-03: Lectura selectiva del slot.
    // Que hace: escucha UNICAMENTE cambios en la configuracion del slot visible.
    // Como funciona: ref.watch selectivo evita que cambios en otros scopes
    // reconstruyan todo el widget.child de la pantalla activa.
    // Por que: previene el jank y doble render al entrar a pantallas con NanoInputScope.
    final targetSlot = widget.slotId ?? destination.name;
    final inputConfig = ref.watch(
      nanoUniversalInputProvider.select(
        (_) => ref.read(nanoUniversalInputProvider.notifier).slotFor(targetSlot),
      ),
    );

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

        // Un campo activo (chat, control humano, búsqueda) debe seguir visible
        // en horizontal. Minimizarlo automáticamente dejaba solo una píldora
        // y hacía parecer que no se podía escribir ni enviar.
        if (isLandscape &&
            !inputConfig.keepDockVisible &&
            !_hasAutoShrunkInLandscape &&
            !_isBarMinimized) {
          _hasAutoShrunkInLandscape = true;
          _scheduleAutoShrink(milliseconds: 2500);
        } else if (!isLandscape && _hasAutoShrunkInLandscape) {
          _hasAutoShrunkInLandscape = false;
        }

        final canDockToSide = widget.allowSideDock;
        final isLeftDock =
            canDockToSide &&
            (_dockMode == NanoNavDockMode.leftCollapsed ||
                _dockMode == NanoNavDockMode.topLeft);
        final isRightDock =
            canDockToSide &&
            (_dockMode == NanoNavDockMode.rightCollapsed ||
                _dockMode == NanoNavDockMode.topRight);
        final isTopCorner =
            canDockToSide &&
            (_dockMode == NanoNavDockMode.topLeft || _dockMode == NanoNavDockMode.topRight);
        final isCollapsed = isLeftDock || isRightDock;
        final isBottomDock = !isCollapsed;
        final hideBar = !isBottomDock || _isBarMinimized;

        final mediaQuery = MediaQuery.of(context);
        final topSafe = mediaQuery.padding.top;
        final bottomSafe = mediaQuery.padding.bottom;
        final availableHeight = constraints.maxHeight - topSafe - bottomSafe;
        final isShortScreen = availableHeight < 410;
        final dockItemSize = isShortScreen ? 31.0 : 36.0;
        final dockIconSize = isShortScreen ? 16.0 : 19.0;
        final dockSpacing = isShortScreen ? 3.0 : 5.0;
        final dockPaddingVert = isShortScreen ? 6.0 : 10.0;
        final estimatedDockHeight =
            (dockPaddingVert * 2) + (7 * (dockItemSize + 4.0)) + (7 * dockSpacing) + 18.0;

        // Flotación real: si el teclado está abierto, flota sobre el teclado.
        final floatingBottom = keyboardInset > 0
            ? (keyboardInset + 10.0)
            : (systemBottomInset > 0 ? (systemBottomInset + baseGap) : (baseGap + 8.0));

        final minDockTop = topSafe + 8.0;
        final maxDockTop = (constraints.maxHeight - estimatedDockHeight - bottomSafe - 8.0)
            .clamp(minDockTop, double.infinity);
        final defaultDockTop = isTopCorner
            ? minDockTop
            : (constraints.maxHeight - estimatedDockHeight - floatingBottom).clamp(
                minDockTop,
                maxDockTop,
              );
        final effectiveDockTop = (_sideDockY ?? defaultDockTop).clamp(
          minDockTop,
          maxDockTop,
        );

        final horizontalMargin = isLandscape ? 16.0 : (isCompact ? 16.0 : 20.0);

        // Padding inferior del contenido: 0 en modos contraídos o minimizados para liberar pantalla
        final totalBottomPad = (isBottomDock && !_isBarMinimized)
            ? (isLandscape
                  ? (_dockHeight + (systemBottomInset > 0 ? systemBottomInset : 4.0)).clamp(
                      28.0,
                      44.0,
                    )
                  : (_dockHeight + floatingBottom + 12.0))
            : 0.0;

        return Stack(
          fit: StackFit.expand,
          children: [
            // Contenido desplazado exactamente el espacio que ocupa la barra cuando está abajo
            SafeArea(
              top: widget.protectTop && !widget.fullBleed,
              bottom: false,
              left: false,
              right: false,
              child: AnimatedPadding(
                duration: NanoMotionDurations.quick,
                curve: Curves.easeOutCubic,
                padding: EdgeInsets.only(
                  bottom: widget.fullBleed
                      ? 0
                      : (isCollapsed || _isDrawerSearchExpanded || _isBarMinimized)
                      ? 0
                      : widget.floatOverContent
                      ? keyboardInset
                      : totalBottomPad,
                ),
                child: NotificationListener<ScrollNotification>(
                  onNotification: (notification) {
                    if (notification is UserScrollNotification &&
                        !inputConfig.keepDockVisible) {
                      if (notification.direction == ScrollDirection.reverse &&
                          !_isBarMinimized) {
                        setState(() => _isBarMinimized = true);
                        _cancelAutoShrink();
                      } else if (notification.direction == ScrollDirection.forward &&
                          _isBarMinimized) {
                        setState(() => _isBarMinimized = false);
                      }
                    }
                    return false;
                  },
                  child: RepaintBoundary(child: widget.child),
                ),
              ),
            ),

            // Estado 1: Barra inferior cósmica interactiva con física de arrastre
            AnimatedPositioned(
              duration: _isDragging ? Duration.zero : NanoMotionDurations.quick,
              curve: Curves.easeOutCubic,
              left: 0,
              right: 0,
              bottom: hideBar
                  ? -(_dockHeight + 110.0)
                  : (floatingBottom - _dragOffset.dy.clamp(0.0, 120.0)),
              child: AnimatedOpacity(
                duration: NanoMotionDurations.press,
                opacity: hideBar
                    ? 0.0
                    : (1.0 - (_dragOffset.distance / 160.0).clamp(0.0, 0.8)),
                child: IgnorePointer(
                  ignoring: hideBar,
                  child: NotificationListener<SizeChangedLayoutNotification>(
                    onNotification: (_) {
                      _measureBar();
                      return false;
                    },
                    child: SizeChangedLayoutNotifier(
                      key: _barKey,
                      child: Center(
                        child: ConstrainedBox(
                          constraints: BoxConstraints(maxWidth: isLandscape ? 760 : 520),
                          child: Padding(
                            padding: EdgeInsets.symmetric(horizontal: horizontalMargin),
                            child: Transform.translate(
                              offset: Offset(_dragOffset.dx.clamp(-80.0, 80.0), 0),
                              child: Transform.scale(
                                scale: (1.0 - (_dragOffset.distance / 600.0)).clamp(
                                  0.92,
                                  1.0,
                                ),
                                child: canDockToSide
                                    ? GestureDetector(
                                        onPanStart: (_) {
                                          setState(() => _isDragging = true);
                                        },
                                        onPanUpdate: (details) {
                                          setState(() {
                                            _dragOffset += details.delta;
                                          });
                                        },
                                        onPanEnd: (details) {
                                          final velocity = details.velocity.pixelsPerSecond;
                                          final shouldCollapseLeft =
                                              _dragOffset.dx < -50 || velocity.dx < -300;
                                          final shouldCollapseRight =
                                              _dragOffset.dx > 50 || velocity.dx > 300;
                                          final shouldCollapseDown =
                                              _dragOffset.dy > 35 || velocity.dy > 300;
                                          final shouldCollapseUp =
                                              _dragOffset.dy < -50 || velocity.dy < -300;
                                          setState(() {
                                            _isDragging = false;
                                            if (shouldCollapseUp) {
                                              HapticFeedback.mediumImpact();
                                              _dockMode = _dragOffset.dx < 0
                                                  ? NanoNavDockMode.topLeft
                                                  : NanoNavDockMode.topRight;
                                              _sideDockY = minDockTop;
                                            } else if (shouldCollapseLeft) {
                                              HapticFeedback.mediumImpact();
                                              _dockMode = NanoNavDockMode.leftCollapsed;
                                              _sideDockY = maxDockTop;
                                            } else if (shouldCollapseRight) {
                                              HapticFeedback.mediumImpact();
                                              _dockMode = NanoNavDockMode.rightCollapsed;
                                              _sideDockY = maxDockTop;
                                            } else if (shouldCollapseDown) {
                                              HapticFeedback.mediumImpact();
                                              _isBarMinimized = true;
                                            }
                                            _dragOffset = Offset.zero;
                                          });
                                        },
                                        child: RepaintBoundary(
                                          child: NanoMultiUseNavBar(
                                            selected: destination,
                                            compact: isCompact,
                                            brightness: brightness,
                                            transparent: widget.transparentDock,
                                            inputConfig: inputConfig,
                                            searchHint: widget.searchHint,
                                            onCollapse: () {
                                              HapticFeedback.lightImpact();
                                              setState(() {
                                                _isBarMinimized = true;
                                              });
                                            },
                                            onDestinationSelected: (d) {
                                              widget.onDestinationSelected(d.index);
                                            },
                                            onSearch:
                                                widget.onSearch ??
                                                (query) {
                                                  NanoSearchDispatcher.dispatch(
                                                    context,
                                                    query,
                                                    ref: ref,
                                                  );
                                                },
                                            onVoice: widget.onVoice,
                                          ),
                                        ),
                                      )
                                    : RepaintBoundary(
                                        child: NanoMultiUseNavBar(
                                          selected: destination,
                                          compact: isCompact,
                                          brightness: brightness,
                                          transparent: widget.transparentDock,
                                          inputConfig: inputConfig,
                                          searchHint: widget.searchHint,
                                          onCollapse: () {
                                            HapticFeedback.lightImpact();
                                            setState(() {
                                              _isBarMinimized = true;
                                            });
                                          },
                                          onDestinationSelected: (d) {
                                            widget.onDestinationSelected(d.index);
                                          },
                                          onSearch:
                                              widget.onSearch ??
                                              (query) {
                                                NanoSearchDispatcher.dispatch(
                                                  context,
                                                  query,
                                                  ref: ref,
                                                );
                                              },
                                          onVoice: widget.onVoice,
                                        ),
                                      ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),

            // Estado Mini: Cápsula flotante ultra-compacta al pie de pantalla
            AnimatedPositioned(
              duration: const Duration(milliseconds: 240),
              curve: Curves.easeOutCubic,
              bottom: _isBarMinimized && !isCollapsed
                  ? (systemBottomInset > 0 ? systemBottomInset + 2.0 : 6.0)
                  : -60.0,
              left: 0,
              right: 0,
              child: AnimatedOpacity(
                duration: const Duration(milliseconds: 180),
                opacity: _isBarMinimized && !isCollapsed ? 1.0 : 0.0,
                child: IgnorePointer(
                  ignoring: !_isBarMinimized || isCollapsed,
                  child: Center(
                    child: NanoNavMiniPill(
                      selected: destination,
                      isLandscape: isLandscape,
                      brightness: brightness,
                      onExpand: () {
                        HapticFeedback.mediumImpact();
                        setState(() {
                          _isBarMinimized = false;
                        });
                        _scheduleAutoShrink(milliseconds: 4500);
                      },
                    ),
                  ),
                ),
              ),
            ),

            // Estado 2: Vertical Cyber-Glass Dock (Deslizamiento Libre Premium)
            AnimatedPositioned(
              duration: _isDragging ? Duration.zero : const Duration(milliseconds: 260),
              curve: Curves.easeOutCubic,
              left: isLeftDock ? 0 : (isRightDock ? null : -80),
              right: isRightDock ? 0 : (isLeftDock ? null : -80),
              top: effectiveDockTop,
              child: AnimatedOpacity(
                duration: const Duration(milliseconds: 180),
                opacity: isCollapsed ? 1.0 : 0.0,
                child: IgnorePointer(
                  ignoring: !isCollapsed,
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onVerticalDragStart: (_) {
                      setState(() {
                        _isDragging = true;
                        _sideDockY = effectiveDockTop;
                      });
                    },
                    onVerticalDragUpdate: (details) {
                      setState(() {
                        _sideDockY = ((_sideDockY ?? effectiveDockTop) + details.delta.dy)
                            .clamp(minDockTop, maxDockTop);
                      });
                    },
                    onVerticalDragEnd: (details) {
                      final velocityY = details.velocity.pixelsPerSecond.dy;
                      HapticFeedback.selectionClick();
                      setState(() {
                        _isDragging = false;
                        final inertia = velocityY * 0.12;
                        _sideDockY = ((_sideDockY ?? effectiveDockTop) + inertia).clamp(
                          minDockTop,
                          maxDockTop,
                        );
                      });
                    },
                    onHorizontalDragUpdate: (details) {
                      final delta = details.primaryDelta ?? 0;
                      if ((isRightDock && delta < -14) || (isLeftDock && delta > 14)) {
                        HapticFeedback.mediumImpact();
                        setState(() {
                          _dockMode = NanoNavDockMode.bottom;
                          _isDrawerSearchExpanded = false;
                          _isDragging = false;
                        });
                      }
                    },
                    child: Container(
                      width: 54,
                      padding: EdgeInsets.symmetric(vertical: dockPaddingVert),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.horizontal(
                          left: isLeftDock ? Radius.zero : const Radius.circular(27),
                          right: isLeftDock ? const Radius.circular(27) : Radius.zero,
                        ),
                        gradient: const LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [Color(0xF207131D), Color(0xFA02070C)],
                        ),
                        border: Border.all(
                          color: const Color(0xFF10B981).withValues(alpha: 0.38),
                          width: 1.1,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.75),
                            blurRadius: 28,
                            spreadRadius: 2,
                            offset: Offset(isLeftDock ? 5 : -5, 6),
                          ),
                          BoxShadow(
                            color: const Color(0xFF10B981).withValues(alpha: 0.16),
                            blurRadius: 20,
                            spreadRadius: -2,
                          ),
                        ],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.horizontal(
                          left: isLeftDock ? Radius.zero : const Radius.circular(27),
                          right: isLeftDock ? const Radius.circular(27) : Radius.zero,
                        ),
                        child: BackdropFilter(
                          filter: ImageFilter.blur(sigmaX: 30, sigmaY: 30),
                          child: Stack(
                            children: [
                              // Reflejo especular superior Glass Bevel
                              Positioned(
                                top: 0,
                                left: 8,
                                right: 8,
                                height: 1.2,
                                child: DecoratedBox(
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      colors: [
                                        Colors.transparent,
                                        Colors.white.withValues(alpha: 0.55),
                                        Colors.transparent,
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                              ConstrainedBox(
                                constraints: BoxConstraints(
                                  maxHeight:
                                      (constraints.maxHeight - topSafe - bottomSafe - 16.0)
                                          .clamp(100.0, double.infinity),
                                ),
                                child: SingleChildScrollView(
                                  physics: const ClampingScrollPhysics(),
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      // 1. Icono de Búsqueda (🔍 con aura verde)
                                      _buildCyberDockItem(
                                        context,
                                        icon: Icons.search_rounded,
                                        isActive: _isDrawerSearchExpanded,
                                        tooltip: 'Buscar o ejecutar',
                                        isLeftDock: isLeftDock,
                                        itemSize: dockItemSize,
                                        iconSize: dockIconSize,
                                        onTap: () {
                                          HapticFeedback.lightImpact();
                                          setState(() {
                                            _isDrawerSearchExpanded =
                                                !_isDrawerSearchExpanded;
                                          });
                                          if (_isDrawerSearchExpanded) {
                                            WidgetsBinding.instance.addPostFrameCallback((
                                              _,
                                            ) {
                                              if (mounted) {
                                                _drawerSearchFocusNode.requestFocus();
                                              }
                                            });
                                          }
                                        },
                                      ),
                                      SizedBox(height: dockSpacing),

                                      // 2. Destinos de navegación (Inicio, Chat, Modelos, Terminal, Ajustes, Auto)
                                      for (final d in NanoDestination.values) ...[
                                        _buildCyberDockDestination(
                                          context,
                                          destination: d,
                                          isActive:
                                              destination == d && !_isDrawerSearchExpanded,
                                          isLeftDock: isLeftDock,
                                          itemSize: dockItemSize,
                                          iconSize: dockIconSize,
                                          onTap: () {
                                            HapticFeedback.selectionClick();
                                            setState(() {
                                              _isDrawerSearchExpanded = false;
                                            });
                                            widget.onDestinationSelected(d.index);
                                          },
                                        ),
                                        SizedBox(height: dockSpacing),
                                      ],

                                      // Grip inferior capacitivo para restaurar al dock inferior
                                      GestureDetector(
                                        behavior: HitTestBehavior.opaque,
                                        onTap: () {
                                          HapticFeedback.mediumImpact();
                                          setState(() {
                                            _dockMode = NanoNavDockMode.bottom;
                                            _isDrawerSearchExpanded = false;
                                          });
                                        },
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(vertical: 4),
                                          child: Center(
                                            child: Container(
                                              margin: const EdgeInsets.only(
                                                top: 4,
                                                bottom: 4,
                                              ),
                                              width: 22,
                                              height: 3.5,
                                              decoration: BoxDecoration(
                                                borderRadius: BorderRadius.circular(2),
                                                color: const Color(
                                                  0xFF10B981,
                                                ).withValues(alpha: 0.45),
                                                boxShadow: [
                                                  BoxShadow(
                                                    color: const Color(
                                                      0xFF10B981,
                                                    ).withValues(alpha: 0.35),
                                                    blurRadius: 6,
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),

            // Scrim interactivo de desenfoque al abrir búsqueda desde el dock lateral
            if (_isDrawerSearchExpanded && isCollapsed)
              Positioned.fill(
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () {
                    _drawerSearchController.clear();
                    setState(() {
                      _isDrawerSearchExpanded = false;
                    });
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    color: Colors.black.withValues(alpha: 0.42),
                  ),
                ),
              ),

            // Cápsula de Búsqueda Expansible Horizontal (Top Floating Command Bar)
            if (canDockToSide && _isDrawerSearchExpanded)
              Positioned(
                top: topSafe + 10.0,
                left: isLeftDock ? 64 : 16,
                right: isLeftDock ? 16 : 64,
                child: TweenAnimationBuilder<double>(
                  tween: Tween<double>(begin: 0.0, end: 1.0),
                  duration: const Duration(milliseconds: 240),
                  curve: Curves.easeOutCubic,
                  builder: (context, anim, child) {
                    return Opacity(
                      opacity: anim,
                      child: Transform.translate(
                        offset: Offset(0, -18.0 * (1.0 - anim)),
                        child: child,
                      ),
                    );
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(24),
                      gradient: const LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [Color(0xF2071622), Color(0xF802080E)],
                      ),
                      border: Border.all(
                        color: const Color(0xFF10B981).withValues(alpha: 0.75),
                        width: 1.3,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF10B981).withValues(alpha: 0.28),
                          blurRadius: 22,
                          spreadRadius: -1,
                        ),
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.70),
                          blurRadius: 26,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(24),
                      child: BackdropFilter(
                        filter: ImageFilter.blur(sigmaX: 30, sigmaY: 30),
                        child: Stack(
                          children: [
                            Positioned(
                              top: 0,
                              left: 16,
                              right: 16,
                              height: 1.2,
                              child: DecoratedBox(
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: [
                                      Colors.transparent,
                                      Colors.white.withValues(alpha: 0.40),
                                      Colors.transparent,
                                    ],
                                  ),
                                ),
                              ),
                            ),
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                const Icon(
                                  Icons.search_rounded,
                                  size: 20,
                                  color: Color(0xFF10B981),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: TextField(
                                    controller: _drawerSearchController,
                                    focusNode: _drawerSearchFocusNode,
                                    autofocus: true,
                                    minLines: 1,
                                    maxLines: 5,
                                    keyboardType: TextInputType.multiline,
                                    textInputAction: TextInputAction.send,
                                    cursorColor: const Color(0xFF10B981),
                                    cursorWidth: 2.0,
                                    cursorRadius: const Radius.circular(2),
                                    style: const TextStyle(
                                      fontFamily: 'Inter',
                                      fontSize: 14,
                                      color: Colors.white,
                                      fontWeight: FontWeight.w500,
                                      letterSpacing: 0.1,
                                    ),
                                    decoration: InputDecoration(
                                      isDense: true,
                                      border: InputBorder.none,
                                      enabledBorder: InputBorder.none,
                                      focusedBorder: InputBorder.none,
                                      disabledBorder: InputBorder.none,
                                      errorBorder: InputBorder.none,
                                      filled: false,
                                      fillColor: Colors.transparent,
                                      hintText:
                                          inputConfig.hint ??
                                          'Buscar, conversar o ejecutar...',
                                      hintStyle: TextStyle(
                                        fontFamily: 'Inter',
                                        fontSize: 13,
                                        color: Colors.white.withValues(alpha: 0.55),
                                      ),
                                      contentPadding: const EdgeInsets.symmetric(
                                        vertical: 8,
                                        horizontal: 2,
                                      ),
                                    ),
                                    onSubmitted: (query) {
                                      final trimmed = query.trim();
                                      if (trimmed.isNotEmpty) {
                                        HapticFeedback.mediumImpact();
                                        if (inputConfig.onSubmit != null) {
                                          inputConfig.onSubmit!(trimmed);
                                        } else if (widget.onSearch != null) {
                                          widget.onSearch!(trimmed);
                                        } else {
                                          NanoSearchDispatcher.dispatch(
                                            context,
                                            trimmed,
                                            ref: ref,
                                          );
                                        }
                                        _drawerSearchController.clear();
                                        _drawerSearchFocusNode.unfocus();
                                        setState(() {
                                          _isDrawerSearchExpanded = false;
                                        });
                                      }
                                    },
                                  ),
                                ),
                                if (_drawerSearchController.text.trim().isNotEmpty) ...[
                                  Semantics(
                                    label: 'Limpiar texto',
                                    button: true,
                                    child: IconButton(
                                      icon: Container(
                                        width: 20,
                                        height: 20,
                                        alignment: Alignment.center,
                                        decoration: BoxDecoration(
                                          shape: BoxShape.circle,
                                          color: Colors.white.withValues(alpha: 0.18),
                                        ),
                                        child: const Icon(
                                          Icons.close_rounded,
                                          size: 13,
                                          color: Colors.white,
                                        ),
                                      ),
                                      padding: EdgeInsets.zero,
                                      constraints: const BoxConstraints.tightFor(
                                        width: 28,
                                        height: 28,
                                      ),
                                      onPressed: () {
                                        _drawerSearchController.clear();
                                      },
                                    ),
                                  ),
                                  const SizedBox(width: 4),
                                  Material(
                                    color: Colors.transparent,
                                    shape: const CircleBorder(),
                                    child: InkWell(
                                      customBorder: const CircleBorder(),
                                      onTap: () {
                                        final trimmed = _drawerSearchController.text.trim();
                                        if (trimmed.isNotEmpty) {
                                          HapticFeedback.mediumImpact();
                                          if (inputConfig.onSubmit != null) {
                                            inputConfig.onSubmit!(trimmed);
                                          } else if (widget.onSearch != null) {
                                            widget.onSearch!(trimmed);
                                          } else {
                                            NanoSearchDispatcher.dispatch(
                                              context,
                                              trimmed,
                                              ref: ref,
                                            );
                                          }
                                          _drawerSearchController.clear();
                                          _drawerSearchFocusNode.unfocus();
                                          setState(() {
                                            _isDrawerSearchExpanded = false;
                                          });
                                        }
                                      },
                                      child: Container(
                                        width: 32,
                                        height: 32,
                                        alignment: Alignment.center,
                                        decoration: BoxDecoration(
                                          shape: BoxShape.circle,
                                          gradient: const LinearGradient(
                                            begin: Alignment.topLeft,
                                            end: Alignment.bottomRight,
                                            colors: [Color(0xFF34D399), Color(0xFF10B981)],
                                          ),
                                          boxShadow: [
                                            BoxShadow(
                                              color: const Color(
                                                0xFF10B981,
                                              ).withValues(alpha: 0.55),
                                              blurRadius: 10,
                                              offset: const Offset(0, 2),
                                            ),
                                          ],
                                        ),
                                        child: const Icon(
                                          Icons.arrow_upward_rounded,
                                          size: 18,
                                          color: Color(0xFF071622),
                                        ),
                                      ),
                                    ),
                                  ),
                                ] else ...[
                                  Semantics(
                                    label: 'Dictar por voz',
                                    button: true,
                                    child: IconButton(
                                      icon: const Icon(
                                        Icons.mic_rounded,
                                        size: 19,
                                        color: Color(0xFF10B981),
                                      ),
                                      padding: EdgeInsets.zero,
                                      constraints: const BoxConstraints.tightFor(
                                        width: 32,
                                        height: 32,
                                      ),
                                      onPressed: widget.onVoice ?? inputConfig.onVoice,
                                    ),
                                  ),
                                  Semantics(
                                    label: 'Cerrar búsqueda',
                                    button: true,
                                    child: IconButton(
                                      icon: const Icon(
                                        Icons.close_rounded,
                                        size: 18,
                                        color: Colors.white70,
                                      ),
                                      padding: EdgeInsets.zero,
                                      constraints: const BoxConstraints.tightFor(
                                        width: 28,
                                        height: 28,
                                      ),
                                      onPressed: () {
                                        _drawerSearchController.clear();
                                        _drawerSearchFocusNode.unfocus();
                                        setState(() {
                                          _isDrawerSearchExpanded = false;
                                        });
                                      },
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),

            // Estado 3: Scrim semi-transparente del drawer
            if (_dockMode == NanoNavDockMode.rightDrawer)
              Positioned.fill(
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () {
                    setState(() {
                      _dockMode = NanoNavDockMode.rightCollapsed;
                    });
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    color: Colors.black.withValues(alpha: 0.45),
                  ),
                ),
              ),

            // Estado 3: Panel lateral derecho (Right Glass Sheet)
            AnimatedPositioned(
              duration: const Duration(milliseconds: 280),
              curve: Curves.easeOutCubic,
              top: 0,
              bottom: keyboardInset > 0 ? keyboardInset : 0,
              right: _dockMode == NanoNavDockMode.rightDrawer ? 0 : -300,
              width: 285,
              child: SafeArea(
                top: true,
                bottom: keyboardInset == 0,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(0, 6, 10, 6),
                  child: GestureDetector(
                    onHorizontalDragUpdate: (details) {
                      if (details.primaryDelta != null && details.primaryDelta! > 6) {
                        HapticFeedback.lightImpact();
                        setState(() {
                          _dockMode = NanoNavDockMode.rightCollapsed;
                        });
                      }
                    },
                    onVerticalDragUpdate: (details) {
                      if (details.primaryDelta != null && details.primaryDelta! > 10) {
                        HapticFeedback.mediumImpact();
                        setState(() {
                          _dockMode = NanoNavDockMode.bottom;
                        });
                      }
                    },
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(28),
                        gradient: isDark
                            ? const LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: [Color(0xF2102040), Color(0xF7081226)],
                              )
                            : const LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: [Color(0xF8FFFFFF), Color(0xF0F0F5FF)],
                              ),
                        border: Border.all(
                          color: isDark
                              ? Colors.white.withValues(alpha: 0.24)
                              : Colors.white.withValues(alpha: 0.75),
                          width: 1.2,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: isDark ? 0.60 : 0.20),
                            blurRadius: 32,
                            offset: const Offset(-6, 8),
                          ),
                          BoxShadow(
                            color: NanoNavTokens.activeAccent(
                              brightness,
                            ).withValues(alpha: isDark ? 0.15 : 0.08),
                            blurRadius: 20,
                            spreadRadius: -2,
                          ),
                        ],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(28),
                        child: BackdropFilter(
                          filter: ImageFilter.blur(sigmaX: 30, sigmaY: 30),
                          child: Stack(
                            children: [
                              // Reflejo especular superior iOS (Glass Bevel Highlight)
                              Positioned(
                                top: 0,
                                left: 16,
                                right: 16,
                                height: 1.5,
                                child: DecoratedBox(
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      colors: [
                                        Colors.transparent,
                                        Colors.white.withValues(
                                          alpha: isDark ? 0.40 : 0.85,
                                        ),
                                        Colors.transparent,
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  // Grip superior del Drawer
                                  Center(
                                    child: Container(
                                      margin: const EdgeInsets.only(top: 8, bottom: 2),
                                      width: 36,
                                      height: 4,
                                      decoration: BoxDecoration(
                                        borderRadius: BorderRadius.circular(2),
                                        color: isDark
                                            ? Colors.white.withValues(alpha: 0.30)
                                            : Colors.black.withValues(alpha: 0.20),
                                      ),
                                    ),
                                  ),

                                  // Header del panel lateral
                                  Padding(
                                    padding: const EdgeInsets.fromLTRB(18, 8, 12, 8),
                                    child: Row(
                                      children: [
                                        Text(
                                          'Nano AI',
                                          style: TextStyle(
                                            fontFamily: 'Inter',
                                            fontSize: 18,
                                            fontWeight: FontWeight.w700,
                                            color: NanoNavTokens.text(brightness),
                                            letterSpacing: -0.4,
                                          ),
                                        ),
                                        const Spacer(),
                                        IconButton(
                                          icon: const Icon(Icons.close_rounded, size: 20),
                                          color: NanoNavTokens.textMuted(brightness),
                                          tooltip: 'Cerrar panel',
                                          onPressed: () {
                                            HapticFeedback.lightImpact();
                                            setState(() {
                                              _dockMode = NanoNavDockMode.rightCollapsed;
                                            });
                                          },
                                        ),
                                      ],
                                    ),
                                  ),
                                  const Divider(height: 1, thickness: 0.7),
                                  const SizedBox(height: 4),

                                  // Destinos de navegación
                                  Expanded(
                                    child: ListView(
                                      padding: const EdgeInsets.symmetric(horizontal: 8),
                                      children: [
                                        for (final d in NanoDestination.values)
                                          _buildSideDestinationTile(
                                            context,
                                            destination: d,
                                            isSelected: destination == d,
                                            brightness: brightness,
                                          ),
                                      ],
                                    ),
                                  ),

                                  const Divider(height: 1, thickness: 0.7),
                                  // Área de escritura universal y acciones en Drawer
                                  Padding(
                                    padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
                                    child: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        if (_isDrawerSearchExpanded)
                                          _buildDrawerSearchField(
                                            context,
                                            brightness,
                                            inputConfig: inputConfig,
                                          )
                                        else
                                          _buildSideActionTile(
                                            context,
                                            icon: Icons.edit_note_rounded,
                                            label: 'Escribir o ejecutar...',
                                            brightness: brightness,
                                            onTap: () {
                                              setState(() {
                                                _isDrawerSearchExpanded = true;
                                              });
                                              WidgetsBinding.instance.addPostFrameCallback((
                                                _,
                                              ) {
                                                if (mounted) {
                                                  _drawerSearchFocusNode.requestFocus();
                                                }
                                              });
                                            },
                                          ),
                                        const SizedBox(height: 4),
                                        _buildSideActionTile(
                                          context,
                                          icon: Icons.vertical_align_bottom_rounded,
                                          label: 'Dock inferior',
                                          brightness: brightness,
                                          onTap: () {
                                            setState(() {
                                              _dockMode = NanoNavDockMode.bottom;
                                            });
                                          },
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ],
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

  Widget _buildDrawerSearchField(
    BuildContext context,
    Brightness brightness, {
    NanoUniversalInputConfig? inputConfig,
  }) {
    final active = NanoNavTokens.activeAccent(brightness);
    final isDark = brightness == Brightness.dark;
    final text = NanoNavTokens.text(brightness);
    final muted = NanoNavTokens.textMuted(brightness);
    final hint = inputConfig?.hint ?? widget.searchHint;

    return ValueListenableBuilder<TextEditingValue>(
      valueListenable: _drawerSearchController,
      builder: (context, value, _) {
        final hasText = value.text.trim().isNotEmpty;

        return AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOutCubic,
          padding: const EdgeInsets.fromLTRB(10, 4, 6, 4),
          decoration: BoxDecoration(
            color: isDark
                ? (_drawerSearchFocusNode.hasFocus
                      ? const Color(0x801E3A68)
                      : const Color(0x60162B4E))
                : (_drawerSearchFocusNode.hasFocus
                      ? Colors.white
                      : const Color(0xF2FFFFFF)),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: _drawerSearchFocusNode.hasFocus
                  ? active
                  : (isDark
                        ? Colors.white.withValues(alpha: 0.22)
                        : Colors.black.withValues(alpha: 0.12)),
              width: _drawerSearchFocusNode.hasFocus ? 1.4 : 1.0,
            ),
            boxShadow: _drawerSearchFocusNode.hasFocus
                ? [
                    BoxShadow(
                      color: active.withValues(alpha: 0.25),
                      blurRadius: 12,
                      spreadRadius: -1,
                    ),
                  ]
                : [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: isDark ? 0.25 : 0.06),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ],
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Padding(
                padding: const EdgeInsets.only(right: 6),
                child: Icon(
                  Icons.edit_outlined,
                  size: 17,
                  color: _drawerSearchFocusNode.hasFocus ? active : muted,
                ),
              ),
              Expanded(
                child: TextField(
                  controller: _drawerSearchController,
                  focusNode: _drawerSearchFocusNode,
                  autofocus: true,
                  minLines: 1,
                  maxLines: 3,
                  cursorColor: active,
                  cursorWidth: 2.0,
                  cursorRadius: const Radius.circular(2),
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 13.5,
                    color: text,
                    fontWeight: FontWeight.w500,
                  ),
                  decoration: InputDecoration(
                    isDense: true,
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    disabledBorder: InputBorder.none,
                    errorBorder: InputBorder.none,
                    filled: false,
                    fillColor: Colors.transparent,
                    hintText: hint,
                    hintStyle: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 12.0,
                      color: muted.withValues(alpha: 0.75),
                      fontWeight: FontWeight.w400,
                    ),
                    contentPadding: const EdgeInsets.symmetric(vertical: 6, horizontal: 2),
                  ),
                  onSubmitted: (query) {
                    final trimmed = query.trim();
                    if (trimmed.isNotEmpty) {
                      HapticFeedback.mediumImpact();
                      if (inputConfig?.onSubmit != null) {
                        inputConfig!.onSubmit!(trimmed);
                      } else if (widget.onSearch != null) {
                        widget.onSearch!(trimmed);
                      } else {
                        NanoSearchDispatcher.dispatch(context, trimmed, ref: ref);
                      }
                      _drawerSearchController.clear();
                      setState(() {
                        _dockMode = NanoNavDockMode.rightCollapsed;
                        _isDrawerSearchExpanded = false;
                      });
                    }
                  },
                ),
              ),
              if (inputConfig?.onAttach != null)
                Semantics(
                  label: 'Adjuntar',
                  button: true,
                  child: IconButton(
                    icon: Icon(Icons.attach_file_rounded, size: 17, color: muted),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints.tightFor(width: 26, height: 26),
                    onPressed: inputConfig!.onAttach,
                  ),
                ),
              if (hasText)
                Semantics(
                  label: 'Limpiar',
                  button: true,
                  child: IconButton(
                    icon: Container(
                      width: 17,
                      height: 17,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: isDark
                            ? Colors.white.withValues(alpha: 0.20)
                            : Colors.black.withValues(alpha: 0.12),
                      ),
                      child: Icon(
                        Icons.close_rounded,
                        size: 11,
                        color: isDark ? Colors.white : Colors.black87,
                      ),
                    ),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints.tightFor(width: 24, height: 24),
                    onPressed: () {
                      _drawerSearchController.clear();
                    },
                  ),
                ),
              Padding(
                padding: const EdgeInsets.only(left: 2),
                child: hasText
                    ? Material(
                        color: Colors.transparent,
                        shape: const CircleBorder(),
                        child: InkWell(
                          customBorder: const CircleBorder(),
                          onTap: () {
                            final query = _drawerSearchController.text.trim();
                            if (query.isNotEmpty) {
                              HapticFeedback.mediumImpact();
                              if (inputConfig?.onSubmit != null) {
                                inputConfig!.onSubmit!(query);
                              } else if (widget.onSearch != null) {
                                widget.onSearch!(query);
                              } else {
                                NanoSearchDispatcher.dispatch(context, query, ref: ref);
                              }
                              _drawerSearchController.clear();
                              setState(() {
                                _dockMode = NanoNavDockMode.rightCollapsed;
                                _isDrawerSearchExpanded = false;
                              });
                            }
                          },
                          child: Container(
                            width: 30,
                            height: 30,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: isDark
                                  ? NanoNavTokens.activeGradientDark
                                  : NanoNavTokens.activeGradientLight,
                              boxShadow: [
                                BoxShadow(
                                  color: active.withValues(alpha: 0.45),
                                  blurRadius: 8,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: const Icon(
                              Icons.arrow_upward_rounded,
                              size: 16,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      )
                    : Semantics(
                        label: 'Contraer',
                        button: true,
                        child: IconButton(
                          icon: const Icon(Icons.close_rounded, size: 17),
                          color: muted,
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints.tightFor(width: 26, height: 26),
                          onPressed: () {
                            _drawerSearchController.clear();
                            setState(() {
                              _isDrawerSearchExpanded = false;
                            });
                          },
                        ),
                      ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildCyberDockItem(
    BuildContext context, {
    required IconData icon,
    required bool isActive,
    required String tooltip,
    required VoidCallback onTap,
    bool isLeftDock = false,
    double itemSize = 36.0,
    double iconSize = 19.0,
  }) {
    final iconWidget = AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      width: itemSize,
      height: itemSize,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: isActive
            ? const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0x4D10B981), Color(0x24059669)],
              )
            : null,
        color: isActive ? null : Colors.white.withValues(alpha: 0.05),
        border: Border.all(
          color: isActive ? const Color(0xFF10B981) : Colors.white.withValues(alpha: 0.12),
          width: isActive ? 1.5 : 1.0,
        ),
        boxShadow: isActive
            ? [
                BoxShadow(
                  color: const Color(0xFF10B981).withValues(alpha: 0.70),
                  blurRadius: 14,
                  spreadRadius: 0.5,
                ),
                BoxShadow(
                  color: const Color(0xFF059669).withValues(alpha: 0.30),
                  blurRadius: 20,
                  spreadRadius: -2,
                ),
              ]
            : null,
      ),
      child: Center(
        child: Icon(
          icon,
          size: iconSize,
          color: isActive ? const Color(0xFF10B981) : Colors.white.withValues(alpha: 0.85),
        ),
      ),
    );

    final indicatorWidget = AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      width: 3.0,
      height: itemSize * 0.52,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.horizontal(
          left: isLeftDock ? Radius.zero : const Radius.circular(3),
          right: isLeftDock ? const Radius.circular(3) : Radius.zero,
        ),
        color: isActive ? const Color(0xFF10B981) : Colors.transparent,
        boxShadow: isActive
            ? [
                BoxShadow(
                  color: const Color(0xFF10B981).withValues(alpha: 0.95),
                  blurRadius: 8,
                  spreadRadius: 0.8,
                ),
              ]
            : null,
      ),
    );

    // Semantics en lugar de Tooltip: evita Overlay.of() que falla en custom stacks
    return Semantics(
      label: tooltip,
      button: true,
      child: SizedBox(
        height: itemSize + 4.0,
        child: Stack(
          alignment: Alignment.center,
          children: [
            Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: onTap,
                customBorder: const CircleBorder(),
                splashColor: const Color(0x3310B981),
                highlightColor: const Color(0x1A10B981),
                child: Padding(padding: const EdgeInsets.all(2.0), child: iconWidget),
              ),
            ),
            Positioned(
              left: isLeftDock ? 0 : null,
              right: isLeftDock ? null : 0,
              child: indicatorWidget,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCyberDockDestination(
    BuildContext context, {
    required NanoDestination destination,
    required bool isActive,
    required VoidCallback onTap,
    bool isLeftDock = false,
    double itemSize = 36.0,
    double iconSize = 19.0,
  }) {
    final iconWidget = AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      width: itemSize,
      height: itemSize,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: isActive
            ? const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0x4D10B981), Color(0x24059669)],
              )
            : null,
        color: isActive ? null : Colors.white.withValues(alpha: 0.05),
        border: Border.all(
          color: isActive ? const Color(0xFF10B981) : Colors.white.withValues(alpha: 0.12),
          width: isActive ? 1.5 : 1.0,
        ),
        boxShadow: isActive
            ? [
                BoxShadow(
                  color: const Color(0xFF10B981).withValues(alpha: 0.70),
                  blurRadius: 14,
                  spreadRadius: 0.5,
                ),
                BoxShadow(
                  color: const Color(0xFF059669).withValues(alpha: 0.30),
                  blurRadius: 20,
                  spreadRadius: -2,
                ),
              ]
            : null,
      ),
      child: Center(
        child: NanoGlyph(
          type: destination.glyph,
          size: iconSize,
          color: isActive ? const Color(0xFF10B981) : Colors.white.withValues(alpha: 0.85),
          glow: isActive,
        ),
      ),
    );

    final indicatorWidget = AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      width: 3.0,
      height: itemSize * 0.52,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.horizontal(
          left: isLeftDock ? Radius.zero : const Radius.circular(3),
          right: isLeftDock ? const Radius.circular(3) : Radius.zero,
        ),
        color: isActive ? const Color(0xFF10B981) : Colors.transparent,
        boxShadow: isActive
            ? [
                BoxShadow(
                  color: const Color(0xFF10B981).withValues(alpha: 0.95),
                  blurRadius: 8,
                  spreadRadius: 0.8,
                ),
              ]
            : null,
      ),
    );

    // Semantics en lugar de Tooltip: evita Overlay.of() que falla en custom stacks
    return Semantics(
      label: destination.label,
      button: true,
      child: SizedBox(
        height: itemSize + 4.0,
        child: Stack(
          alignment: Alignment.center,
          children: [
            Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: onTap,
                customBorder: const CircleBorder(),
                splashColor: const Color(0x3310B981),
                highlightColor: const Color(0x1A10B981),
                child: Padding(padding: const EdgeInsets.all(2.0), child: iconWidget),
              ),
            ),
            Positioned(
              left: isLeftDock ? 0 : null,
              right: isLeftDock ? null : 0,
              child: indicatorWidget,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSideDestinationTile(
    BuildContext context, {
    required NanoDestination destination,
    required bool isSelected,
    required Brightness brightness,
  }) {
    final active = NanoNavTokens.activeAccent(brightness);
    final muted = NanoNavTokens.textMuted(brightness);
    final isDark = brightness == Brightness.dark;

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 3),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        color: isSelected
            ? (isDark ? active.withValues(alpha: 0.16) : active.withValues(alpha: 0.10))
            : Colors.transparent,
        border: isSelected
            ? Border.all(color: active.withValues(alpha: 0.40), width: 1.0)
            : null,
      ),
      child: ListTile(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        dense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 0),
        leading: NanoGlyph(
          type: destination.glyph,
          size: 20,
          color: isSelected ? active : muted,
          glow: isSelected,
        ),
        title: Text(
          destination.label,
          style: TextStyle(
            fontFamily: 'Inter',
            fontSize: 14.5,
            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
            color: isSelected ? active : NanoNavTokens.text(brightness),
          ),
        ),
        trailing: isSelected
            ? Container(
                width: 7,
                height: 7,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: active,
                  boxShadow: [
                    BoxShadow(color: active.withValues(alpha: 0.8), blurRadius: 6),
                  ],
                ),
              )
            : null,
        onTap: () {
          HapticFeedback.selectionClick();
          widget.onDestinationSelected(destination.index);
          setState(() {
            _dockMode = NanoNavDockMode.rightCollapsed;
          });
        },
      ),
    );
  }

  Widget _buildSideActionTile(
    BuildContext context, {
    required IconData icon,
    required String label,
    required Brightness brightness,
    required VoidCallback onTap,
  }) {
    final muted = NanoNavTokens.textMuted(brightness);
    final isDark = brightness == Brightness.dark;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () {
          HapticFeedback.lightImpact();
          onTap();
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            color: isDark
                ? Colors.white.withValues(alpha: 0.05)
                : Colors.black.withValues(alpha: 0.04),
          ),
          child: Row(
            children: [
              Icon(icon, size: 18, color: muted),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: muted,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
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
          allowSideDock: true,
          slotId: slotId,
          selectedIndex: selectedIndex ?? NanoDestination.automation.index,
          // HOME-BLEED-01 — la cáscara de la barra sale en TODA la app:
          // detrás del dock se ve el mismo fondo de la pantalla.
          transparentDock: true,
          // NAV-FLOAT-01 — flotación real: la barra NO reserva franja en
          // el layout (antes el contenido se comprimía ~190px). El fondo
          // pinta completo y las pantallas hijas reservan su propio
          // padding de scroll (kNanoBarScrollReserve).
          floatOverContent: true,
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
