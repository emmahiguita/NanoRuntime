part of 'glass_surface.dart';

/// Solo crea un reloj para reflejos solicitados explícitamente. Se detiene al
/// ocultarse la ruta, suspender la app o activar reducción de movimiento.
class _GlassSurfaceState extends State<GlassSurface>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  AnimationController? _ambient;
  Offset _pointer = Offset.zero;
  bool _pressed = false;
  bool _resumed = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _resumed =
        WidgetsBinding.instance.lifecycleState == null ||
        WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _syncReflection();
  }

  @override
  void didUpdateWidget(covariant GlassSurface oldWidget) {
    super.didUpdateWidget(oldWidget);
    _syncReflection();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final resumed = state == AppLifecycleState.resumed;
    if (_resumed == resumed) return;
    setState(() {
      _resumed = resumed;
    });
    _syncReflection();
  }

  bool get _motion =>
      !MediaQuery.disableAnimationsOf(context) &&
      TickerMode.of(context) &&
      _resumed;

  void _syncReflection() {
    final needed = widget.autoReflect && widget.reflectionController == null;
    if (needed && _motion) {
      _ambient ??= AnimationController(
        vsync: this,
        duration: NanoMotionDurations.ambient,
      );
      if (!_ambient!.isAnimating) _ambient!.repeat(reverse: true);
    } else {
      _ambient?.stop();
    }
  }

  /// El puntero cambia únicamente la luz y una inclinación pequeña; no consume
  /// gestos del hijo ni ejecuta acciones al arrastrar una lista.
  void _track(PointerEvent event) {
    if (!widget.interactive || !_motion) return;
    final box = context.findRenderObject();
    if (box is! RenderBox || !box.hasSize || box.size.isEmpty) return;
    final p = box.globalToLocal(event.position);
    final next = Offset(
      (p.dx / box.size.width * 2 - 1).clamp(-1, 1),
      (p.dy / box.size.height * 2 - 1).clamp(-1, 1),
    );
    if ((next - _pointer).distanceSquared < .0004 && _pressed) return;
    setState(() {
      _pointer = next;
      _pressed = true;
    });
  }

  void _release() {
    if (!_pressed && _pointer == Offset.zero) return;
    setState(() {
      _pointer = Offset.zero;
      _pressed = false;
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _ambient?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final animation = widget.reflectionController ?? _ambient;
    final content = _GlassSurfaceBody(widget: widget, light: _pointer);
    Widget surface = animation != null && _motion
        ? AnimatedBuilder(
            animation: animation,
            child: widget.child,
            builder: (context, child) => _GlassSurfaceBody(
              widget: widget,
              light: _pressed ? _pointer : Offset(animation.value * 2 - 1, -.7),
            ),
          )
        : content;
    final motion = _motion;
    surface = AnimatedContainer(
      duration: motion ? NanoMotionDurations.standard : Duration.zero,
      curve: NanoMotionCurves.glassSpring,
      transformAlignment: Alignment.center,
      transform: Matrix4.identity()
        ..setEntry(3, 2, .001)
        ..rotateX(motion ? -_pointer.dy * widget.tiltIntensity : 0)
        ..rotateY(motion ? _pointer.dx * widget.tiltIntensity : 0),
      child: AnimatedScale(
        scale: motion && _pressed ? .988 : 1,
        duration: motion ? NanoMotionDurations.press : Duration.zero,
        curve: NanoMotionCurves.press,
        child: surface,
      ),
    );
    if (widget.onTap != null || widget.onLongPress != null) {
      surface = Semantics(
        button: true,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: widget.onTap == null
              ? null
              : () {
                  HapticFeedback.selectionClick();
                  widget.onTap!();
                },
          onLongPress: widget.onLongPress,
          child: surface,
        ),
      );
    }
    return MouseRegion(
      cursor: widget.onTap != null
          ? SystemMouseCursors.click
          : MouseCursor.defer,
      child: Listener(
        onPointerDown: _track,
        onPointerMove: _track,
        onPointerUp: (_) => _release(),
        onPointerCancel: (_) => _release(),
        child: surface,
      ),
    );
  }
}
