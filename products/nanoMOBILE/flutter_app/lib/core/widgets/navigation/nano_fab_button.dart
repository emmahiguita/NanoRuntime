// nano_fab_button.dart — Botón circular independiente de Nano AI estilo Liquid Glass.
//
// QUÉ HACE:
// Renderiza el botón circular de acción (FAB) en el extremo derecho de la navegación
// con efecto Liquid Glass y la estrella de cristal radiante de Nano AI.
//
// CÓMO FUNCIONA:
// - Despliega un disco circular translúcido con reflejos de lente y aro exterior lavanda.
// - Muestra la estrella NanoCrystalStar de 4 puntas en el centro con rotación fluida al abrir.
// - Al pulsar: feedback háptico y abre/cierra el menú de opciones (Mensajería, Tienda, Biblioteca).
// - Interactúa reactivamente con nanoNavModeProvider sin solapamiento de componentes.
//
// POR QUÉ:
// Satisface fielmente la referencia visual del diseño (< 130 líneas, SOLID).
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'nano_crystal_star.dart';
import 'nano_nav_mode_provider.dart';

class NanoFabButton extends ConsumerStatefulWidget {
  const NanoFabButton({
    super.key,
    this.size = 48.0,
    required this.brightness,
  });

  final double size;
  final Brightness brightness;

  @override
  ConsumerState<NanoFabButton> createState() => _NanoFabButtonState();
}

class _NanoFabButtonState extends ConsumerState<NanoFabButton> {
  bool _isPressed = false;

  void _handleTap() {
    HapticFeedback.mediumImpact();
    ref.read(nanoNavModeProvider.notifier).toggleFabMenu();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = widget.brightness == Brightness.dark;
    final navState = ref.watch(nanoNavModeProvider);
    final isOpen = navState.isFabMenuOpen;

    // Paleta Liquid Glass: blanco-azulado nacarado en claro, índigo cósmico en oscuro.
    final gradientColors = isDark
        ? [
            const Color(0xFF312E81),
            const Color(0xFF1E1B4B),
            const Color(0xFF0F172A),
          ]
        : [
            const Color(0xFFFFFFFF),
            const Color(0xFFF5F3FF),
            const Color(0xFFDDD6FE),
          ];

    final rimLightColor = isDark
        ? (isOpen ? const Color(0xFFA5B4FC) : const Color(0x60818CF8))
        : (isOpen ? const Color(0xFF818CF8) : const Color(0x70C4B5FD));

    final borderColor = isDark
        ? Colors.white.withValues(alpha: isOpen ? 0.65 : 0.35)
        : Colors.white.withValues(alpha: isOpen ? 0.98 : 0.85);

    return Semantics(
      button: true,
      label: isOpen ? 'Cerrar opciones de Nano' : 'Abrir opciones de Nano',
      hint: 'Muestra Mensajería, Tienda y Biblioteca',
      child: GestureDetector(
        onTapDown: (_) => setState(() => _isPressed = true),
        onTapUp: (_) => setState(() => _isPressed = false),
        onTapCancel: () => setState(() => _isPressed = false),
        onTap: _handleTap,
        child: AnimatedScale(
          scale: _isPressed ? 0.90 : (isOpen ? 1.04 : 1.0),
          duration: const Duration(milliseconds: 160),
          curve: Curves.easeOutCubic,
          child: Container(
            width: widget.size,
            height: widget.size,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                center: const Alignment(-0.35, -0.35),
                radius: 0.85,
                colors: gradientColors,
                stops: const [0.0, 0.55, 1.0],
              ),
              border: Border.all(
                color: borderColor,
                width: isOpen ? 1.5 : 1.1,
              ),
              boxShadow: [
                // Resplandor periférico violeta suave
                BoxShadow(
                  color: rimLightColor,
                  blurRadius: isOpen ? 14 : 10,
                  offset: const Offset(0, 3),
                  spreadRadius: isOpen ? 1.0 : 0.5,
                ),
                // Sombra de contacto
                BoxShadow(
                  color: Colors.black.withValues(alpha: isDark ? 0.35 : 0.08),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Center(
              child: AnimatedRotation(
                turns: isOpen ? 0.125 : 0.0,
                duration: const Duration(milliseconds: 220),
                curve: Curves.easeOutCubic,
                child: NanoCrystalStar(
                  size: widget.size * 0.58,
                  isDark: isDark,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
