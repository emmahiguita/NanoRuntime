import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Scrubber invisible táctil estilo iOS para desplazamiento y salto rápido entre ventanas.
/// 
/// - QUÉ HACE: Provee un borde táctil lateral de desplazamiento que es 100% invisible en
///   reposo, sin marcos, flechas ni textos que ensucien el diseño visual de la app.
/// - CÓMO FUNCIONA: Escucha el [ScrollController] y los gestos en el bisel derecho. Al
///   desplazar o arrastrar en el borde, muestra una cápsula ultradelgada estilo iOS
///   con desvanecimiento automático (fade-out) tras 1 segundo de inactividad, permitiendo
///   scrollear fluidamente sin que videos de YouTube capturen el gesto.
/// - POR QUÉ: Otorga una experiencia ejecutiva idéntica a iOS (Scrubber dinámico),
///   elimina la barra tosca visual previa y cumple estrictamente <200 líneas bajo SOLID.
class BrowserWindowScrollRail extends StatefulWidget {
  final ScrollController scrollController;
  final int totalWindows;
  final int activeIndex;
  final ValueChanged<int>? onJumpToWindow;

  const BrowserWindowScrollRail({
    super.key,
    required this.scrollController,
    required this.totalWindows,
    this.activeIndex = 0,
    this.onJumpToWindow,
  });

  @override
  State<BrowserWindowScrollRail> createState() => _BrowserWindowScrollRailState();
}

class _BrowserWindowScrollRailState extends State<BrowserWindowScrollRail> {
  bool _visible = false, _isDragging = false;
  double _scrollProgress = 0.0;
  int _lastHapticWindow = -1;
  Timer? _fadeTimer;

  @override
  void initState() {
    super.initState();
    widget.scrollController.addListener(_onScrollUpdated);
  }

  @override
  void didUpdateWidget(covariant BrowserWindowScrollRail oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.scrollController != widget.scrollController) {
      oldWidget.scrollController.removeListener(_onScrollUpdated);
      widget.scrollController.addListener(_onScrollUpdated);
    }
  }

  @override
  void dispose() {
    widget.scrollController.removeListener(_onScrollUpdated);
    _fadeTimer?.cancel();
    super.dispose();
  }

  void _onScrollUpdated() {
    if (!mounted || !widget.scrollController.hasClients) return;
    final pos = widget.scrollController.position;
    if (pos.maxScrollExtent <= 0) return;

    final progress = (pos.pixels / pos.maxScrollExtent).clamp(0.0, 1.0);
    setState(() {
      _scrollProgress = progress;
      _visible = true;
    });

    _scheduleFadeOut();
  }

  void _scheduleFadeOut() {
    _fadeTimer?.cancel();
    _fadeTimer = Timer(const Duration(milliseconds: 1100), () {
      if (mounted && !_isDragging) {
        setState(() => _visible = false);
      }
    });
  }

  void _handleDrag(double localY, double trackHeight) {
    if (!widget.scrollController.hasClients || trackHeight <= 0) return;
    final ratio = (localY / trackHeight).clamp(0.0, 1.0);
    final pos = widget.scrollController.position;
    widget.scrollController.jumpTo(ratio * pos.maxScrollExtent);

    // Haptic feedback al cruzar el umbral de cada ventana
    if (widget.totalWindows > 1) {
      final currentWin = (ratio * (widget.totalWindows - 1)).round();
      if (currentWin != _lastHapticWindow) {
        _lastHapticWindow = currentWin;
        HapticFeedback.selectionClick();
        widget.onJumpToWindow?.call(currentWin);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.totalWindows <= 1) return const SizedBox.shrink();

    final isLandscape = MediaQuery.of(context).orientation == Orientation.landscape;
    final topMargin = isLandscape ? 10.0 : 40.0;
    final bottomMargin = isLandscape ? 10.0 : 90.0;

    return Positioned(
      right: 0,
      top: topMargin,
      bottom: bottomMargin,
      width: 24.0, // Bisel táctil ergonómico transparente
      child: LayoutBuilder(
        builder: (context, constraints) {
          final trackHeight = constraints.maxHeight;
          final thumbHeight = (trackHeight * 0.18).clamp(32.0, 64.0);
          final travelDistance = (trackHeight - thumbHeight).clamp(0.0, trackHeight);
          final thumbTop = _scrollProgress * travelDistance;

          return GestureDetector(
            behavior: HitTestBehavior.translucent,
            onVerticalDragStart: (details) {
              _fadeTimer?.cancel();
              setState(() {
                _isDragging = true;
                _visible = true;
              });
              _handleDrag(details.localPosition.dy, trackHeight);
            },
            onVerticalDragUpdate: (details) {
              _handleDrag(details.localPosition.dy, trackHeight);
            },
            onVerticalDragEnd: (_) {
              setState(() => _isDragging = false);
              _scheduleFadeOut();
            },
            onVerticalDragCancel: () {
              setState(() => _isDragging = false);
              _scheduleFadeOut();
            },
            child: Container(
              color: Colors.transparent, // Completamente invisible en reposo
              alignment: Alignment.topRight,
              padding: const EdgeInsets.only(right: 3),
              child: AnimatedOpacity(
                duration: const Duration(milliseconds: 250),
                curve: Curves.easeOutCubic,
                opacity: _visible ? 1.0 : 0.0,
                child: Transform.translate(
                  offset: Offset(0, thumbTop),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    width: _isDragging ? 5.5 : 3.5,
                    height: thumbHeight,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: _isDragging ? 0.70 : 0.38),
                      borderRadius: BorderRadius.circular(10),
                      boxShadow: _isDragging
                          ? [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.35),
                                blurRadius: 4,
                                offset: const Offset(-1, 1),
                              ),
                            ]
                          : null,
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
