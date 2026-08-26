import 'package:flutter/material.dart';
import '../../theme/design_tokens.dart';
import 'nano_dock_controller.dart';

/// Asa de arrastre y cabecera de identidad de marca del dock de navegacion.
class NanoDockHandle extends StatelessWidget {
  const NanoDockHandle({
    super.key,
    required this.colors,
    required this.dockController,
  });

  final NanoColors colors;
  final NanoDockController dockController;

  @override
  Widget build(BuildContext context) {
    final isHorizontal = dockController.isHorizontal;
    final isMinimized = dockController.isMinimized;
    final screenSize = MediaQuery.sizeOf(context);

    return GestureDetector(
      onPanStart: dockController.onDragStart,
      onPanUpdate: (details) =>
          dockController.onDragUpdate(details, screenSize),
      onPanEnd: dockController.onDragEnd,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: isHorizontal
            ? const EdgeInsets.symmetric(horizontal: 8, vertical: 4)
            : const EdgeInsets.symmetric(vertical: 6, horizontal: 6),
        child: isHorizontal
            ? Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Grip indicator vertical para barra horizontal
                  Container(
                    width: 3.5,
                    height: 20,
                    margin: const EdgeInsets.only(right: 6),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(999),
                      color: colors.primary.withValues(alpha: 0.7),
                    ),
                  ),
                  _buildBrandLogo(colors, isMinimized, true),
                ],
              )
            : Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Grip indicator horizontal para barra vertical
                  Container(
                    width: 20,
                    height: 3.5,
                    margin: const EdgeInsets.only(bottom: 6),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(999),
                      color: colors.primary.withValues(alpha: 0.7),
                    ),
                  ),
                  _buildBrandLogo(colors, isMinimized, false),
                ],
              ),
      ),
    );
  }

  Widget _buildBrandLogo(NanoColors colors, bool minimized, bool isHorizontal) {
    if (!minimized && !isHorizontal) {
      return ShaderMask(
        blendMode: BlendMode.srcIn,
        shaderCallback: (rect) {
          return LinearGradient(
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
            stops: const [0.0, 0.65, 0.85, 1.0],
            colors: [
              colors.textPrimary,
              colors.textPrimary,
              colors.accentCyan,
              colors.accentLavender,
            ],
          ).createShader(rect);
        },
        child: const Text(
          'NanoAI',
          style: TextStyle(
            fontFamily: 'Inter',
            fontWeight: FontWeight.w800,
            fontSize: 15,
            letterSpacing: -0.5,
          ),
        ),
      );
    } else {
      return ShaderMask(
        blendMode: BlendMode.srcIn,
        shaderCallback: (rect) {
          return LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [colors.accentCyan, colors.accentLavender],
          ).createShader(rect);
        },
        child: Text(
          'N',
          style: TextStyle(
            fontFamily: 'Inter',
            fontWeight: FontWeight.w900,
            fontSize: isHorizontal ? 17 : 19,
          ),
        ),
      );
    }
  }
}
