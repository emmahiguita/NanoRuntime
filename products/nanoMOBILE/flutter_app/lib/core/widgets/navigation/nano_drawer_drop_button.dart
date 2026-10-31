// nano_drawer_drop_button.dart — Botón de activación iOS Liquid Glass con silueta de búho Nano.
// QUÉ HACE: Presenta la cápsula de activación con cabeza de búho Nano y chevron según diseño iOS.
// CÓMO FUNCIONA: Superficie esmerilada con BackdropFilter, haptic feedback y gesto opcional de arrastre.
// POR QUÉ: Reemplaza el botón tosco anterior por un control premium con identidad propia de Nano.
library;

import 'dart:ui';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'nano_owl_vector_icon.dart';

class NanoDrawerDropButton extends StatefulWidget {
  const NanoDrawerDropButton({
    super.key,
    required this.isOpen,
    required this.primary,
    required this.onTap,
    required this.onDragDown,
  });

  final bool isOpen;
  final Color primary;
  final VoidCallback onTap;
  final VoidCallback onDragDown;

  @override
  State<NanoDrawerDropButton> createState() => _NanoDrawerDropButtonState();
}

class _NanoDrawerDropButtonState extends State<NanoDrawerDropButton> {
  double _dragDy = 0.0;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    const brandBlue = Color(0xFF2563EB);

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {
        HapticFeedback.lightImpact();
        widget.onTap();
      },
      onPanUpdate: (d) {
        setState(() => _dragDy = (_dragDy + d.delta.dy).clamp(0.0, 300.0));
      },
      onPanEnd: (details) {
        final vy = details.velocity.pixelsPerSecond.dy;
        if (_dragDy > 60 || vy > 200) {
          HapticFeedback.mediumImpact();
          widget.onDragDown();
        }
        setState(() => _dragDy = 0.0);
      },
      child: Transform.translate(
        offset: Offset(0, _dragDy * 0.25),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.35 : 0.06),
                blurRadius: 10,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                curve: Curves.easeOutCubic,
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: isDark
                        ? [
                            const Color(0xFF1E293B).withValues(alpha: widget.isOpen ? 0.90 : 0.80),
                            const Color(0xFF0F172A).withValues(alpha: widget.isOpen ? 0.85 : 0.72),
                          ]
                        : [
                            Colors.white.withValues(alpha: widget.isOpen ? 0.96 : 0.88),
                            const Color(0xFFF8FAFC).withValues(alpha: widget.isOpen ? 0.92 : 0.78),
                          ],
                  ),
                  border: Border.all(
                    color: isDark
                        ? Colors.white.withValues(alpha: widget.isOpen ? 0.28 : 0.16)
                        : (widget.isOpen
                            ? brandBlue.withValues(alpha: 0.35)
                            : Colors.black.withValues(alpha: 0.08)),
                    width: 0.85,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const NanoOwlVectorIcon(
                      width: 23,
                      height: 19,
                      color: brandBlue,
                    ),
                    const SizedBox(width: 5),
                    AnimatedRotation(
                      turns: widget.isOpen ? 0.5 : 0.0,
                      duration: const Duration(milliseconds: 200),
                      curve: Curves.easeOutCubic,
                      child: const Icon(
                        CupertinoIcons.chevron_down,
                        size: 13,
                        color: brandBlue,
                      ),
                    ),
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
