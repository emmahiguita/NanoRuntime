import 'package:flutter/material.dart';
import '../../theme/design_tokens.dart';
import '../../theme/nano_motion.dart';
import 'nano_dock_controller.dart';
import 'nano_navigation_panel.dart';

/// Barra de navegación con indicador líquido continuo que viaja físicamente entre pestañas.
class NanoSelectionMorphBar extends StatefulWidget {
  const NanoSelectionMorphBar({
    super.key,
    required this.tabs,
    required this.selectedIndex,
    required this.colors,
    required this.onTabSelected,
    required this.position,
    required this.isMinimized,
  });

  final List<NavTabSpec> tabs;
  final int selectedIndex;
  final NanoColors colors;
  final ValueChanged<int> onTabSelected;
  final NavPosition position;
  final bool isMinimized;

  @override
  State<NanoSelectionMorphBar> createState() => _NanoSelectionMorphBarState();
}

class _NanoSelectionMorphBarState extends State<NanoSelectionMorphBar>
    with SingleTickerProviderStateMixin {
  late final AnimationController _morphController;
  late Animation<double> _morphAnimation;

  double _previousIndex = 0.0;
  double _targetIndex = 0.0;

  @override
  void initState() {
    super.initState();
    _previousIndex = widget.selectedIndex.toDouble();
    _targetIndex = widget.selectedIndex.toDouble();

    _morphController = AnimationController(
      vsync: this,
      duration: NanoMotionDurations.standard,
    );

    _morphAnimation = CurvedAnimation(
      parent: _morphController,
      curve: NanoMotionCurves.emphasized,
    );
  }

  @override
  void didUpdateWidget(covariant NanoSelectionMorphBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.selectedIndex != widget.selectedIndex) {
      _previousIndex = _currentInterpolatedIndex();
      _targetIndex = widget.selectedIndex.toDouble();
      _morphController.forward(from: 0.0);
    }
  }

  @override
  void dispose() {
    _morphController.dispose();
    super.dispose();
  }

  double _currentInterpolatedIndex() {
    return _previousIndex + (_targetIndex - _previousIndex) * _morphAnimation.value;
  }

  @override
  Widget build(BuildContext context) {
    final isTop = widget.position == NavPosition.top;
    final colors = widget.colors;
    final isDark = colors is NanoDarkColors;

    final bgGradient = LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: isDark
          ? [
              colors.accentCyan.withValues(alpha: 0.95),
              colors.accentMint.withValues(alpha: 0.90),
            ]
          : [
              colors.primary,
              colors.accentSky,
            ],
    );

    final rimGradient = NanoBorders.metallicRim(
      colors,
      accent: isDark ? colors.accentCyan : colors.primary,
    );

    if (isTop) {
      return SizedBox(
        height: 42,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
          itemCount: widget.tabs.length,
          separatorBuilder: (_, __) => const SizedBox(width: 6),
          itemBuilder: (context, index) {
            final isSelected = index == widget.selectedIndex;
            final tab = widget.tabs[index];

            return _TabChip(
              label: tab.label,
              icon: isSelected ? tab.sel : tab.icon,
              isSelected: isSelected,
              iconOnly: widget.isMinimized,
              colors: colors,
              bgGradient: bgGradient,
              rimGradient: rimGradient,
              onTap: () => widget.onTabSelected(index),
            );
          },
        ),
      );
    } else {
      // En vertical: ajusta exactamente al tamaño de los iconos sin expandir infinitamente
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (int index = 0; index < widget.tabs.length; index++) ...[
            _TabChip(
              label: widget.tabs[index].label,
              icon: index == widget.selectedIndex
                  ? widget.tabs[index].sel
                  : widget.tabs[index].icon,
              isSelected: index == widget.selectedIndex,
              iconOnly: widget.isMinimized,
              colors: colors,
              bgGradient: bgGradient,
              rimGradient: rimGradient,
              onTap: () => widget.onTabSelected(index),
            ),
            if (index < widget.tabs.length - 1)
              const SizedBox(height: 5),
          ],
        ],
      );
    }
  }
}

class _TabChip extends StatefulWidget {
  const _TabChip({
    required this.label,
    required this.icon,
    required this.isSelected,
    required this.iconOnly,
    required this.colors,
    required this.bgGradient,
    required this.rimGradient,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool isSelected;
  final bool iconOnly;
  final NanoColors colors;
  final Gradient bgGradient;
  final Gradient rimGradient;
  final VoidCallback onTap;

  @override
  State<_TabChip> createState() => _TabChipState();
}

class _TabChipState extends State<_TabChip> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    final colors = widget.colors;
    final isDark = colors is NanoDarkColors;
    final isSelected = widget.isSelected;

    final fg = isSelected
        ? (isDark ? const Color(0xFF001524) : Colors.white)
        : colors.textSecondary.withValues(alpha: 0.90);

    return AnimatedScale(
      scale: _isPressed ? 0.92 : (isSelected ? 1.03 : 1.0),
      duration: const Duration(milliseconds: 140),
      curve: Curves.easeOutCubic,
      child: AnimatedContainer(
        duration: NanoMotionDurations.quick,
        curve: NanoMotionCurves.emphasized,
        decoration: BoxDecoration(
          borderRadius: NanoShapes.full,
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: (isDark ? colors.accentCyan : colors.primary)
                        .withValues(alpha: isDark ? 0.40 : 0.25),
                    blurRadius: 12,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Container(
          padding: const EdgeInsets.all(1.0),
          decoration: BoxDecoration(
            borderRadius: NanoShapes.full,
            gradient: isSelected
                ? widget.rimGradient
                : LinearGradient(
                    colors: [
                      colors.borderSecondaryColor
                          .withValues(alpha: isDark ? 0.18 : 0.35),
                      colors.borderSecondaryColor
                          .withValues(alpha: isDark ? 0.06 : 0.15),
                    ],
                  ),
          ),
          child: Material(
            color: isSelected
                ? Colors.transparent
                : (isDark
                    ? colors.surfaceVariant.withValues(alpha: 0.30)
                    : colors.surfaceVariant.withValues(alpha: 0.45)),
            borderRadius: NanoShapes.full,
            child: InkWell(
              onTap: widget.onTap,
              onTapDown: (_) => setState(() => _isPressed = true),
              onTapUp: (_) => setState(() => _isPressed = false),
              onTapCancel: () => setState(() => _isPressed = false),
              borderRadius: NanoShapes.full,
              child: AnimatedContainer(
                duration: NanoMotionDurations.quick,
                curve: NanoMotionCurves.emphasized,
                decoration: BoxDecoration(
                  borderRadius: NanoShapes.full,
                  gradient: isSelected ? widget.bgGradient : null,
                ),
                padding: EdgeInsets.symmetric(
                  horizontal: widget.iconOnly ? 7 : 11,
                  vertical: 7.5,
                ),
                alignment: widget.iconOnly ? Alignment.center : Alignment.centerLeft,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: widget.iconOnly
                      ? MainAxisAlignment.center
                      : MainAxisAlignment.start,
                  children: [
                    Icon(widget.icon, size: 19, color: fg),
                    if (!widget.iconOnly) ...[
                      const SizedBox(width: 7),
                      Flexible(
                        child: Text(
                          widget.label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 12,
                            fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
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
  }
}
