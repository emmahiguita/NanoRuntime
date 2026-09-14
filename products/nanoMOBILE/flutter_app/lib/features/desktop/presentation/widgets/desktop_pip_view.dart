import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:nanoai/core/theme/design_tokens.dart';
import 'package:nanoai/features/desktop/presentation/widgets/desktop_stream_chrome.dart';

/// Floating interactive PiP (Picture-in-Picture) window for minimized remote desktop mode.
class DesktopPipView extends StatefulWidget {
  final ui.Image? frame;
  final Size screenSize;
  final VoidCallback onRestore;
  final VoidCallback onClose;
  final NanoColors colors;

  const DesktopPipView({
    super.key,
    required this.frame,
    required this.screenSize,
    required this.onRestore,
    required this.onClose,
    required this.colors,
  });

  @override
  State<DesktopPipView> createState() => _DesktopPipViewState();
}

class _DesktopPipViewState extends State<DesktopPipView> {
  static const double _pipWidth = 140.0;
  static const double _pipHeight = 92.0;

  late Offset _offset;
  bool _isDragging = false;

  @override
  void initState() {
    super.initState();
    _offset = Offset(
      widget.screenSize.width - _pipWidth - 16,
      widget.screenSize.height - _pipHeight - 100,
    );
  }

  @override
  void didUpdateWidget(DesktopPipView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.screenSize != oldWidget.screenSize) {
      final maxX = (widget.screenSize.width - _pipWidth - 12).clamp(12.0, double.infinity);
      final maxY = (widget.screenSize.height - _pipHeight - 48).clamp(48.0, double.infinity);
      final clampedX = _offset.dx.clamp(12.0, maxX);
      final clampedY = _offset.dy.clamp(48.0, maxY);
      _offset = Offset(clampedX, clampedY);
    }
  }

  void _snapToEdges() {
    final maxX = widget.screenSize.width - _pipWidth - 12;
    final maxY = widget.screenSize.height - _pipHeight - 48;

    double targetX = _offset.dx.clamp(12.0, maxX);
    double targetY = _offset.dy.clamp(48.0, maxY);

    if (targetX < widget.screenSize.width / 2) {
      targetX = 12.0;
    } else {
      targetX = maxX;
    }

    setState(() {
      _offset = Offset(targetX, targetY);
      _isDragging = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final accent = widget.colors.chromeActive;

    return AnimatedPositioned(
      duration: _isDragging ? Duration.zero : const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
      left: _offset.dx,
      top: _offset.dy,
      width: _pipWidth,
      height: _pipHeight,
      child: GestureDetector(
        onPanStart: (_) => setState(() => _isDragging = true),
        onPanUpdate: (details) {
          setState(() {
            final maxX = (widget.screenSize.width - _pipWidth).clamp(8.0, 2000.0);
            final maxY = (widget.screenSize.height - _pipHeight).clamp(8.0, 2000.0);
            _offset = Offset(
              (_offset.dx + details.delta.dx).clamp(8.0, maxX),
              (_offset.dy + details.delta.dy).clamp(8.0, maxY),
            );
          });
        },
        onPanEnd: (_) => _snapToEdges(),
        onTap: () {
          HapticFeedback.selectionClick();
          widget.onRestore();
        },
        child: Container(
          decoration: BoxDecoration(
            color: const Color(0xFF090D16),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: accent, width: 1.5),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.65),
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
              BoxShadow(
                color: accent.withValues(alpha: 0.25),
                blurRadius: 12,
                spreadRadius: 1,
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(14.5),
            child: Stack(
              fit: StackFit.expand,
              children: [
                if (widget.frame != null)
                  RawImage(
                    image: widget.frame,
                    fit: BoxFit.cover,
                    filterQuality: FilterQuality.medium,
                  )
                else
                  Container(
                    color: const Color(0xFF0F172A),
                    child: Center(
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: accent,
                      ),
                    ),
                  ),
                // Gradient scrim
                Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.black.withValues(alpha: 0.70),
                        Colors.transparent,
                        Colors.black.withValues(alpha: 0.80),
                      ],
                    ),
                  ),
                ),
                // Header bar with status badge and drag grip
                Positioned(
                  top: 6,
                  left: 8,
                  right: 6,
                  child: Row(
                    children: [
                      Container(
                        width: 7,
                        height: 7,
                        decoration: BoxDecoration(
                          color: accent,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: accent.withValues(alpha: 0.7),
                              blurRadius: 4,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 5),
                      const Text(
                        'LINUX ACTIVE',
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                          letterSpacing: 0.5,
                        ),
                      ),
                      const Spacer(),
                      GestureDetector(
                        onTap: () {
                          HapticFeedback.lightImpact();
                          widget.onClose();
                        },
                        child: Container(
                          padding: const EdgeInsets.all(2),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.5),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.close_rounded,
                            size: 14,
                            color: Colors.white70,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                // Footer hint button
                Positioned(
                  bottom: 6,
                  right: 8,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: accent,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.fullscreen_rounded, size: 11, color: Colors.black),
                        SizedBox(width: 3),
                        Text(
                          'Ampliar',
                          style: TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 9,
                            fontWeight: FontWeight.bold,
                            color: Colors.black,
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
    );
  }
}
