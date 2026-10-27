import 'dart:ui';

import 'package:flutter/material.dart';

/// Superficie metálica unificada para canales, búsqueda, avisos y filtros.
class MessagingControlDeck extends StatelessWidget {
  final Widget child;

  const MessagingControlDeck({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 13, sigmaY: 13),
        child: DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: isDark
                  ? [
                      const Color(0xFF172033).withValues(alpha: 0.44),
                      const Color(0xFF0F172A).withValues(alpha: 0.30),
                    ]
                  : [
                      Colors.white.withValues(alpha: 0.43),
                      const Color(0xFFEFF6FF).withValues(alpha: 0.24),
                    ],
            ),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: isDark
                  ? Colors.white.withValues(alpha: 0.14)
                  : Colors.white.withValues(alpha: 0.66),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.24 : 0.07),
                blurRadius: 22,
                offset: const Offset(0, 7),
              ),
              BoxShadow(
                color: Colors.white.withValues(alpha: isDark ? 0.04 : 0.55),
                blurRadius: 1.5,
                offset: const Offset(0, -1),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(10, 10, 10, 9),
            child: child,
          ),
        ),
      ),
    );
  }
}
