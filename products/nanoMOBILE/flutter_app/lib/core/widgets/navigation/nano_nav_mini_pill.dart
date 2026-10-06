// nano_nav_mini_pill.dart — Estado mínimo compartido de la navegación.
// QUÉ HACE: Reduce el dock completo a una píldora real de tres puntos.
// CÓMO FUNCIONA: Separa la superficie visible de 42×26 del área táctil segura.
// POR QUÉ: Reutilizar una sola pieza evita estados mínimos visualmente distintos.
library;

import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:nanoai/core/theme/design_tokens.dart';

class NanoNavMiniPill extends StatelessWidget {
  const NanoNavMiniPill({
    super.key,
    required this.onExpand,
    this.semanticLabel = 'Mostrar navegación',
  });

  final VoidCallback onExpand;
  final String semanticLabel;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final themeColors = Theme.of(context).extension<NanoThemeExtension>()?.colors;
    final accent = themeColors?.accent ?? (dark ? const Color(0xFF2563EB) : const Color(0xFF1D6FE8));

    return Semantics(
      button: true,
      label: semanticLabel,
      child: SizedBox(
        width: 56,
        height: 44,
        child: Center(
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(15),
              boxShadow: [
                BoxShadow(
                  color: accent.withValues(alpha: dark ? 0.32 : 0.18),
                  blurRadius: 14,
                  spreadRadius: -2,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(15),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
                child: Material(
                  color: dark ? const Color(0xE6050D1A) : const Color(0xF2FFFFFF),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(15),
                    side: BorderSide(
                      color: accent.withValues(alpha: 0.70),
                      width: 1.2,
                    ),
                  ),
                  child: InkWell(
                    onTap: () {
                      HapticFeedback.lightImpact();
                      onExpand();
                    },
                    borderRadius: BorderRadius.circular(15),
                    child: SizedBox(
                      width: 44,
                      height: 28,
                      child: Icon(
                        Icons.more_horiz_rounded,
                        color: accent,
                        size: 22,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
