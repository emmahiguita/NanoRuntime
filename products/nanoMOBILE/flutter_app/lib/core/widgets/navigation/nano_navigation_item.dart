import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../theme/design_tokens.dart';
import '../../theme/nano_motion.dart';

/// Elemento individual de navegación interactivo con física táctil y bisel óptico.
class NanoNavigationItem extends StatefulWidget {
  const NanoNavigationItem({
    super.key,
    required this.label,
    required this.icon,
    required this.selectedIcon,
    required this.selected,
    required this.colors,
    required this.onTap,
    this.iconOnly = false,
  });

  final String label;
  final IconData icon;
  final IconData selectedIcon;
  final bool selected;
  final NanoColors colors;
  final VoidCallback onTap;
  final bool iconOnly;

  @override
  State<NanoNavigationItem> createState() => _NanoNavigationItemState();
}

class _NanoNavigationItemState extends State<NanoNavigationItem>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pressController;
  late final Animation<double> _scaleAnimation;
  bool _isHovered = false;

  @override
  void initState() {
    super.initState();
    _pressController = AnimationController(
      vsync: this,
      duration: NanoMotionDurations.press,
    );
    _scaleAnimation =
        Tween<double>(begin: 1.0, end: NanoPressResponse.scaleDown).animate(
          CurvedAnimation(
            parent: _pressController,
            curve: NanoMotionCurves.press,
            reverseCurve: NanoMotionCurves.glassSpring,
          ),
        );
  }

  @override
  void dispose() {
    _pressController.dispose();
    super.dispose();
  }

  void _handleTapDown(TapDownDetails _) {
    _pressController.forward();
  }

  void _handleTapUp(TapUpDetails _) {
    _pressController.reverse();
    HapticFeedback.selectionClick();
    widget.onTap();
  }

  void _handleTapCancel() {
    _pressController.reverse();
  }

  @override
  Widget build(BuildContext context) {
    final colors = widget.colors;
    final isDark = colors is NanoDarkColors;

    final bgGradient = widget.selected
        ? LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: isDark
                ? [
                    colors.primary.withValues(alpha: 0.95),
                    colors.accentMint.withValues(alpha: 0.85),
                  ]
                : [colors.primary, colors.accentSky],
          )
        : null;

    final borderGradient = widget.selected
        ? NanoBorders.metallicRim(colors, accent: colors.primary)
        : LinearGradient(
            colors: [
              colors.borderSecondaryColor.withValues(
                alpha: isDark
                    ? (_isHovered ? 0.25 : 0.12)
                    : (_isHovered ? 0.40 : 0.25),
              ),
              colors.borderSecondaryColor.withValues(
                alpha: isDark ? 0.06 : 0.10,
              ),
            ],
          );

    final fg = widget.selected
        ? (isDark ? const Color(0xFF000000) : Colors.white)
        : (_isHovered ? colors.textPrimary : colors.onSurfaceVariant);

    Widget content = AnimatedBuilder(
      animation: _scaleAnimation,
      builder: (context, child) =>
          Transform.scale(scale: _scaleAnimation.value, child: child),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: NanoShapes.full,
          boxShadow: widget.selected
              ? [
                  BoxShadow(
                    color: colors.primary.withValues(
                      alpha: isDark ? 0.35 : 0.20,
                    ),
                    blurRadius: 10,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Container(
          padding: const EdgeInsets.all(1.0),
          decoration: BoxDecoration(
            borderRadius: NanoShapes.full,
            gradient: borderGradient,
          ),
          child: Material(
            color: widget.selected
                ? Colors.transparent
                : (isDark
                      ? colors.surfaceVariant.withValues(
                          alpha: _isHovered ? 0.6 : 0.4,
                        )
                      : colors.surfaceVariant.withValues(
                          alpha: _isHovered ? 0.8 : 0.6,
                        )),
            borderRadius: NanoShapes.full,
            child: InkWell(
              onTapDown: _handleTapDown,
              onTapUp: _handleTapUp,
              onTapCancel: _handleTapCancel,
              borderRadius: NanoShapes.full,
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: NanoShapes.full,
                  gradient: bgGradient,
                ),
                padding: EdgeInsets.symmetric(
                  horizontal: widget.iconOnly ? 0 : 12,
                  vertical: 10,
                ),
                alignment: widget.iconOnly
                    ? Alignment.center
                    : Alignment.centerLeft,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: widget.iconOnly
                      ? MainAxisAlignment.center
                      : MainAxisAlignment.start,
                  children: [
                    Icon(
                      widget.selected ? widget.selectedIcon : widget.icon,
                      size: 18,
                      color: fg,
                    ),
                    if (!widget.iconOnly) ...[
                      const SizedBox(width: 8),
                      Flexible(
                        child: Text(
                          widget.label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: fg,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );

    if (widget.iconOnly) {
      content = Tooltip(
        message: widget.label,
        waitDuration: const Duration(milliseconds: 250),
        child: content,
      );
    }

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: content,
    );
  }
}
