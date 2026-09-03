import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../theme/design_tokens.dart';
import '../../theme/nano_motion.dart';
import 'owl_fab.dart';

typedef NavTabSpec = ({IconData icon, IconData sel, String label});

enum NanoNavigationDock { topLeft, topRight, bottomLeft, bottomRight }

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

/// Navegación única de Nano: FAB cerrado y panel glass al expandirse.
///
/// El marco nunca modifica las restricciones del contenido: el FAB vive en
/// una capa flotante independiente, se adapta a portrait/landscape y puede
/// acoplarse a las cuatro esquinas. Solo el FAB es dueño del gesto de arrastre,
/// evitando recognizers duplicados.
class NanoFloatingNavigationFrame extends StatefulWidget {
  const NanoFloatingNavigationFrame({
    super.key,
    required this.child,
    required this.tabs,
    required this.selectedIndex,
    required this.onDestinationSelected,
    this.style,
    this.hidden = false,
    this.initialDock = NanoNavigationDock.bottomRight,
  }) : assert(tabs.length > 0),
       assert(selectedIndex >= 0 && selectedIndex < tabs.length);

  final Widget child;
  final List<NavTabSpec> tabs;
  final int selectedIndex;
  final ValueChanged<int> onDestinationSelected;
  final NanoFloatingNavigationStyle? style;
  final bool hidden;
  final NanoNavigationDock initialDock;

  @override
  State<NanoFloatingNavigationFrame> createState() =>
      _NanoFloatingNavigationFrameState();
}

class _NanoFloatingNavigationFrameState
    extends State<NanoFloatingNavigationFrame> {
  static const _gap = 12.0;
  static const _fabSize = 56.0;
  static const _portraitPanelHeight = 196.0;
  static const _compactPortraitPanelHeight = 240.0;
  static const _landscapePanelHeight = 80.0;

  late NanoNavigationDock _dock;
  bool _expanded = false;
  Offset? _dragOffset;
  Size _lastPanelSize = const Size.square(_fabSize);
  Size? _dragSize;
  // TER-22: coreografía de vuelo al soltar. _gliding señala al búho que
  // el trayecto animado a la esquina está en curso; se apaga al llegar.
  bool _gliding = false;
  Offset _flightDir = Offset.zero;
  bool get _atLeft =>
      _dock == NanoNavigationDock.topLeft ||
      _dock == NanoNavigationDock.bottomLeft;

  @override
  void initState() {
    super.initState();
    _dock = widget.initialDock;
  }

  @override
  void didUpdateWidget(covariant NanoFloatingNavigationFrame oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.hidden && !oldWidget.hidden && _expanded) {
      _expanded = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final style =
        widget.style ?? NanoFloatingNavigationStyle.fromTheme(context);
    // TER-22: trayecto de vuelo al soltar — navigation (480 ms) para que
    // el aleteo se aprecie; reduceMotion lo deja en 0 (pose instantáneo).
    final motion = NanoMotion.adapt(context, NanoMotionDurations.navigation);

    return LayoutBuilder(
      builder: (context, constraints) {
        final viewport = Size(constraints.maxWidth, constraints.maxHeight);
        final landscape = viewport.width > viewport.height;
        final availableWidth = math.max(0.0, viewport.width - (_gap * 2));
        final expandedWidth = math.min(
          availableWidth,
          landscape ? 660.0 : 344.0,
        );
        final compactPortrait = !landscape && expandedWidth < 320;
        final desiredExpandedHeight = landscape
            ? _landscapePanelHeight
            : compactPortrait
            ? _compactPortraitPanelHeight
            : _portraitPanelHeight;
        final availableHeight = math.max(0.0, viewport.height - (_gap * 2));
        final expandedHeight = math.min(desiredExpandedHeight, availableHeight);
        final panelSize = Size(
          _expanded ? expandedWidth : _fabSize,
          _expanded ? expandedHeight : _fabSize,
        );
        // TER-18: tamaño del último build — el drag usa el tamaño REAL del
        // panel (expandido o FAB) para no colapsar de golpe al arrastrar.
        _lastPanelSize = panelSize;
        final dockedOffset = _offsetForDock(viewport, panelSize);
        final position = _dragOffset ?? dockedOffset;

        return Stack(
          fit: StackFit.expand,
          clipBehavior: Clip.none,
          children: [
            // UI-REV-02: el drag (setState por cada onPanUpdate) no debe
            // repintar la pantalla entera. RepaintBoundary cachea la
            // superficie de la app — el arrastre del búho solo mueve su
            // capa y repinta el FAB. Sin esto, cada evento de drag
            // re-evaluaba el subtree completo (cards glass, blur, listas).
            RepaintBoundary(child: widget.child),
            if (!widget.hidden)
              AnimatedPositioned(
                duration: _dragOffset == null ? motion : Duration.zero,
                curve: NanoMotionCurves.glassSpring,
                // TER-22: llegada a la esquina — apaga la señal de vuelo
                // y suena la pose. Protegido: si un nuevo arrastre empezó
                // (_dragOffset != null), el onEnd espurio de la animación
                // cancelada no aterriza al búho a mitad de drag.
                onEnd: () {
                  if (_dragOffset == null && _gliding) {
                    setState(() => _gliding = false);
                  }
                },
                left: position.dx,
                top: position.dy,
                width: panelSize.width,
                height: panelSize.height,
                child: TapRegion(
                  onTapOutside: _expanded ? (_) => _collapse() : null,
                  child: _GlassNavigationPanel(
                    tabs: widget.tabs,
                    selectedIndex: widget.selectedIndex,
                    style: style,
                    expanded: _expanded,
                    landscape: landscape,
                    dockedAtLeft: _atLeft,
                    gliding: _gliding,
                    flightDirection: _flightDir,
                    onToggle: _toggle,
                    onNavigate: _navigate,
                    onPanStart: (_) => _startDrag(viewport),
                    onPanUpdate: (details) =>
                        _updateDrag(details: details, viewport: viewport),
                    onPanEnd: (_) => _finishDrag(viewport),
                    onPanCancel: () => _finishDrag(viewport),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }

  Offset _offsetForDock(Size viewport, Size panelSize, [NanoNavigationDock? dock]) {
    final d = dock ?? _dock;
    final atLeft =
        d == NanoNavigationDock.topLeft ||
        d == NanoNavigationDock.bottomLeft;
    final atTop =
        d == NanoNavigationDock.topLeft ||
        d == NanoNavigationDock.topRight;
    final right = math.max(_gap, viewport.width - panelSize.width - _gap);
    final bottom = math.max(_gap, viewport.height - panelSize.height - _gap);
    return Offset(atLeft ? _gap : right, atTop ? _gap : bottom);
  }

  void _toggle() {
    setState(() => _expanded = !_expanded);
    HapticFeedback.selectionClick();
  }

  void _collapse() {
    if (!_expanded) return;
    setState(() => _expanded = false);
  }

  void _navigate(int index) {
    if (index < 0 || index >= widget.tabs.length) return;
    setState(() => _expanded = false);
    widget.onDestinationSelected(index);
  }

  void _startDrag(Size viewport) {
    // TER-18: el drag arrastra el panel con SU tamaño actual (expandido o
    // FAB). Antes colapsaba el panel al instante: el búho despierto
    // desaparecía y reaparecía dormido en otra esquina (salto visual).
    final size = _expanded ? _lastPanelSize : const Size.square(_fabSize);
    setState(() {
      _dragSize = size;
      _dragOffset = _offsetForDock(viewport, size);
    });
  }

  void _updateDrag({
    required DragUpdateDetails details,
    required Size viewport,
  }) {
    final renderBox = context.findRenderObject() as RenderBox?;
    if (renderBox == null) return;
    final size = _dragSize ?? const Size.square(_fabSize);
    final local = renderBox.globalToLocal(details.globalPosition);
    final maxX = math.max(_gap, viewport.width - size.width - _gap);
    final maxY = math.max(_gap, viewport.height - size.height - _gap);
    setState(() {
      _dragOffset = Offset(
        (local.dx - (size.width / 2)).clamp(_gap, maxX).toDouble(),
        (local.dy - (size.height / 2)).clamp(_gap, maxY).toDouble(),
      );
    });
  }

  void _finishDrag(Size viewport) {
    final offset = _dragOffset;
    if (offset == null) return;
    final size = _dragSize ?? const Size.square(_fabSize);
    final center = offset + Offset(size.width / 2, size.height / 2);
    final left = center.dx <= viewport.width / 2;
    final top = center.dy <= viewport.height / 2;
    _dragSize = null;
    final newDock = switch ((top, left)) {
      (true, true) => NanoNavigationDock.topLeft,
      (true, false) => NanoNavigationDock.topRight,
      (false, true) => NanoNavigationDock.bottomLeft,
      (false, false) => NanoNavigationDock.bottomRight,
    };
    // TER-22: vector del trayecto (centro actual → centro del dock).
    // Inclina al búho hacia donde vuela; dirección nula si no se movió.
    final target = _offsetForDock(viewport, size, newDock);
    final dir = target + Offset(size.width / 2, size.height / 2) - center;
    final norm = dir.distance;
    setState(() {
      _dock = newDock;
      _dragOffset = null;
      _gliding = true;
      _flightDir = norm > 0.01 ? dir / norm : Offset.zero;
    });
    HapticFeedback.selectionClick();
  }
}

class _GlassNavigationPanel extends StatelessWidget {
  const _GlassNavigationPanel({
    required this.tabs,
    required this.selectedIndex,
    required this.style,
    required this.expanded,
    required this.landscape,
    required this.dockedAtLeft,
    required this.gliding,
    required this.flightDirection,
    required this.onToggle,
    required this.onNavigate,
    required this.onPanStart,
    required this.onPanUpdate,
    required this.onPanEnd,
    required this.onPanCancel,
  });

  final List<NavTabSpec> tabs;
  final int selectedIndex;
  final NanoFloatingNavigationStyle style;
  final bool expanded;
  final bool landscape;
  final bool dockedAtLeft;
  final bool gliding;
  final Offset flightDirection;
  final VoidCallback onToggle;
  final ValueChanged<int> onNavigate;
  final GestureDragStartCallback onPanStart;
  final GestureDragUpdateCallback onPanUpdate;
  final GestureDragEndCallback onPanEnd;
  final VoidCallback onPanCancel;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(24);

    // TER-18: fundido entre los dos modos — el panel no se corta de golpe
    // al colapsar ni el búho aparece seco al expandir.
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 180),
      switchInCurve: Curves.easeOut,
      switchOutCurve: Curves.easeIn,
      child: !expanded
          ? KeyedSubtree(
              key: const ValueKey('owl-collapsed'),
              // TER-17: colapsado — el búho ES el FAB completo. Sin panel
              // glass alrededor: el ClipRRect recortaría el personaje y
              // los Zzz. El búho trae su propio círculo, sombras y glow.
              child: OwlFloatingActionButton(
                size: _NanoFloatingNavigationFrameState._fabSize,
                expanded: false,
                gliding: gliding,
                flightDirection: flightDirection,
                onTap: onToggle,
                onPanStart: onPanStart,
                onPanUpdate: onPanUpdate,
                onPanEnd: onPanEnd,
                onPanCancel: onPanCancel,
              ),
            )
          : KeyedSubtree(key: const ValueKey('owl-panel'), child: _panel(context, radius)),
    );
  }

  Widget _panel(BuildContext context, BorderRadius radius) {
    return RepaintBoundary(
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: radius,
          boxShadow: [
            BoxShadow(
              color: style.shadow,
              blurRadius: 30,
              spreadRadius: -6,
              offset: const Offset(0, 10),
            ),
            BoxShadow(
              color: style.accent.withValues(alpha: 0.16),
              blurRadius: 24,
              spreadRadius: -8,
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: radius,
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
            child: DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: radius,
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [style.surfaceStart, style.surfaceEnd],
                ),
                border: Border.all(color: style.border, width: 1.1),
              ),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final enoughSpace = landscape
                      ? constraints.maxWidth >= 420 &&
                            constraints.maxHeight >= 72
                      : constraints.maxWidth >= 260 &&
                            constraints.maxHeight >= 176;
                  if (!enoughSpace) {
                    // TER-17: handle compacto = búho despierto (viendo
                    // y parpadeando) mientras el panel vive.
                    return Center(
                      child: OwlFloatingActionButton(
                        size: _NanoFloatingNavigationFrameState._fabSize,
                        expanded: true,
                        gliding: gliding,
                        flightDirection: flightDirection,
                        onTap: onToggle,
                        onPanStart: onPanStart,
                        onPanUpdate: onPanUpdate,
                        onPanEnd: onPanEnd,
                        onPanCancel: onPanCancel,
                      ),
                    );
                  }
                  return TweenAnimationBuilder<double>(
                    tween: Tween(begin: 0, end: 1),
                    duration: NanoMotion.adapt(
                      context,
                      NanoMotionDurations.quick,
                    ),
                    curve: NanoMotionCurves.standardDecel,
                    child: _ExpandedNavigation(
                      tabs: tabs,
                      selectedIndex: selectedIndex,
                      style: style,
                      landscape: landscape,
                      dockedAtLeft: dockedAtLeft,
                      gliding: gliding,
                      flightDirection: flightDirection,
                      onToggle: onToggle,
                      onNavigate: onNavigate,
                      onPanStart: onPanStart,
                      onPanUpdate: onPanUpdate,
                      onPanEnd: onPanEnd,
                      onPanCancel: onPanCancel,
                    ),
                    builder: (context, value, child) => Opacity(
                      opacity: value,
                      child: Transform.scale(
                        scale: 0.98 + (0.02 * value),
                        child: child,
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ExpandedNavigation extends StatelessWidget {
  const _ExpandedNavigation({
    required this.tabs,
    required this.selectedIndex,
    required this.style,
    required this.landscape,
    required this.dockedAtLeft,
    required this.gliding,
    required this.flightDirection,
    required this.onToggle,
    required this.onNavigate,
    required this.onPanStart,
    required this.onPanUpdate,
    required this.onPanEnd,
    required this.onPanCancel,
  });

  final List<NavTabSpec> tabs;
  final int selectedIndex;
  final NanoFloatingNavigationStyle style;
  final bool landscape;
  final bool dockedAtLeft;
  final bool gliding;
  final Offset flightDirection;
  final VoidCallback onToggle;
  final ValueChanged<int> onNavigate;
  final GestureDragStartCallback onPanStart;
  final GestureDragUpdateCallback onPanUpdate;
  final GestureDragEndCallback onPanEnd;
  final VoidCallback onPanCancel;

  @override
  Widget build(BuildContext context) {
    // TER-17: handle de arrastre = búho despierto (viendo y parpadea).
    final handle = OwlFloatingActionButton(
      size: _NanoFloatingNavigationFrameState._fabSize,
      expanded: true,
      gliding: gliding,
      flightDirection: flightDirection,
      onTap: onToggle,
      onPanStart: onPanStart,
      onPanUpdate: onPanUpdate,
      onPanEnd: onPanEnd,
      onPanCancel: onPanCancel,
    );

    if (landscape) {
      return Padding(
        padding: const EdgeInsets.all(10),
        child: Row(
          children: [
            if (dockedAtLeft) ...[handle, const SizedBox(width: 8)],
            for (var index = 0; index < tabs.length; index++)
              Expanded(
                child: _NavigationDestination(
                  spec: tabs[index],
                  selected: index == selectedIndex,
                  style: style,
                  onTap: () => onNavigate(index),
                ),
              ),
            if (!dockedAtLeft) ...[const SizedBox(width: 8), handle],
          ],
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
      child: Column(
        children: [
          Row(
            children: [
              handle,
              const SizedBox(width: 10),
              Expanded(
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      'Navegación',
                      style: TextStyle(
                        color: style.text,
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              ),
              IconButton(
                tooltip: 'Contraer navegación',
                visualDensity: VisualDensity.compact,
                onPressed: onToggle,
                icon: Icon(Icons.close_rounded, color: style.text, size: 20),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final columns = constraints.maxWidth < 290 ? 2 : 3;
                return GridView.builder(
                  padding: EdgeInsets.zero,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: columns,
                    mainAxisSpacing: 4,
                    crossAxisSpacing: 4,
                    childAspectRatio: columns == 2 ? 2.75 : 2.05,
                  ),
                  itemCount: tabs.length,
                  itemBuilder: (context, index) => _NavigationDestination(
                    spec: tabs[index],
                    selected: index == selectedIndex,
                    style: style,
                    onTap: () => onNavigate(index),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _NavigationDestination extends StatelessWidget {
  const _NavigationDestination({
    required this.spec,
    required this.selected,
    required this.style,
    required this.onTap,
  });

  final NavTabSpec spec;
  final bool selected;
  final NanoFloatingNavigationStyle style;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = selected ? style.accent : style.textMuted;
    return Semantics(
      button: true,
      selected: selected,
      label: spec.label,
      child: Material(
        color: selected ? style.accentSoft : Colors.transparent,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(14),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 5),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(selected ? spec.sel : spec.icon, size: 20, color: color),
                const SizedBox(height: 3),
                Flexible(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      spec.label,
                      maxLines: 1,
                      softWrap: false,
                      style: TextStyle(
                        color: color,
                        fontSize: 9.5,
                        fontWeight: selected
                            ? FontWeight.w700
                            : FontWeight.w600,
                      ),
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
