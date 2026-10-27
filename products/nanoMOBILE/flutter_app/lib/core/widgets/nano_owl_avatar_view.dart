part of 'nano_owl_avatar.dart';

/// Dibujo sin relojes propios; el State controla visibilidad y vida útil.
extension _NanoOwlAvatarStateView on _NanoOwlAvatarState {
  Widget buildView(BuildContext context) {
    final glowColor = switch (widget.state) {
      NanoOwlState.thinking => const Color(0xFF00E5FF),
      NanoOwlState.listening => const Color(0xFF10B981),
      NanoOwlState.responding => const Color(0xFF818CF8),
      NanoOwlState.success => const Color(0xFF10B981),
      _ => Colors.transparent,
    };

    return RepaintBoundary(
      child: GestureDetector(
        onTapDown: (_) => _pressController.forward(),
        onTapUp: (_) {
          _pressController.reverse();
          widget.onTap?.call();
        },
        onTapCancel: () => _pressController.reverse(),
        child: AnimatedBuilder(
          animation: Listenable.merge([
            _spriteController,
            _glowController,
            _pressController,
          ]),
          builder: (_, __) {
            final pressScale = 1.0 - (_pressController.value * 0.08);
            final glowVal = widget.enableGlow ? _glowController.value : 0.0;
            final isFly = widget.state == NanoOwlState.fly;
            final flyFloat = isFly
                ? math.sin(_spriteController.value * 2 * math.pi) * 3.5
                : 0.0;

            return Transform.translate(
              offset: Offset(0, flyFloat),
              child: Transform.scale(
                scale: pressScale,
                child: Container(
                  width: widget.size,
                  height: widget.size,
                  decoration: glowVal > 0.05
                      ? BoxDecoration(
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: glowColor.withValues(
                                alpha: 0.25 * glowVal,
                              ),
                              blurRadius: widget.size * 0.45 * glowVal,
                              spreadRadius: 1.5,
                            ),
                          ],
                        )
                      : null,
                  child: Image.asset(
                    _currentAsset(),
                    key: ValueKey(_currentAsset()),
                    fit: BoxFit.contain,
                    gaplessPlayback: true,
                    filterQuality: FilterQuality.medium,
                    cacheWidth:
                        (widget.size * MediaQuery.devicePixelRatioOf(context))
                            .ceil(),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
