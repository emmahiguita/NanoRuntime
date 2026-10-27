part of 'engine_status_card.dart';

class _SystemReadyMark extends StatefulWidget {
  const _SystemReadyMark({required this.ready});

  final bool ready;

  @override
  State<_SystemReadyMark> createState() => _SystemReadyMarkState();
}

class _SystemReadyMarkState extends State<_SystemReadyMark>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _syncPulse();
  }

  @override
  void didUpdateWidget(covariant _SystemReadyMark oldWidget) {
    super.didUpdateWidget(oldWidget);
    _syncPulse();
  }

  void _syncPulse() {
    final isTest = WidgetsBinding.instance.runtimeType.toString().contains(
      'Test',
    );
    final canAnimate =
        widget.ready &&
        !isTest &&
        !MediaQuery.disableAnimationsOf(context) &&
        TickerMode.of(context);
    if (canAnimate && !_pulse.isAnimating) {
      _pulse.repeat(reverse: true);
    } else if (!canAnimate) {
      _pulse
        ..stop()
        ..value = widget.ready ? 0.5 : 0;
    }
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final color = widget.ready
        ? AutomationVisual.of(context).success
        : AutomationVisual.of(context).accent;
    return AnimatedBuilder(
      animation: _pulse,
      builder: (context, _) {
        final t = _pulse.value;
        return SizedBox.square(
          dimension: 64,
          child: Stack(
            alignment: Alignment.center,
            children: [
              Container(
                width: 58 + t * 4,
                height: 58 + t * 4,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: color.withValues(alpha: 0.15 + t * 0.12),
                    width: 1.2,
                  ),
                ),
              ),
              Container(
                width: 46 + t * 2,
                height: 46 + t * 2,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: color.withValues(alpha: 0.28 + t * 0.15),
                    width: 1.2,
                  ),
                ),
              ),
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.14 + t * 0.08),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: color.withValues(alpha: 0.20 + t * 0.20),
                      blurRadius: 8 + t * 4,
                    ),
                  ],
                ),
                child: Icon(
                  widget.ready ? Icons.check_rounded : Icons.pause_rounded,
                  color: color,
                  size: 18,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
