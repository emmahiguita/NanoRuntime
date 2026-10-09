// nano_metallic_button.dart
//
// QUÉ HACE:
// Renderiza botones interactivos con estética metálica iOS / VisionOS: reflejo especular,
// gradiente metálico pulido, micro-interacción al tacto (scale) y alta legibilidad.
//
// CÓMO FUNCIONA:
// - Usa AnimatedScale para respuesta háptica visual inmediata al presionar.
// - Aplica LinearGradient metálico y un borde sutil con brillo direccional.
// - Proporciona variantes: primary (acento metálico), danger (carmesí glass) y cancel (vidrio neutro).
//
// POR QUÉ:
// Reemplaza botones azules planos genéricos con una apariencia premium uniforme en modales y chats.

import 'package:flutter/material.dart';

enum NanoMetallicButtonStyle { primary, danger, subtle }

class NanoMetallicButton extends StatefulWidget {
  final String label;
  final IconData? icon;
  final VoidCallback? onPressed;
  final NanoMetallicButtonStyle style;
  final bool isExpanded;
  final bool isLoading;

  const NanoMetallicButton({
    super.key,
    required this.label,
    this.icon,
    this.onPressed,
    this.style = NanoMetallicButtonStyle.primary,
    this.isExpanded = false,
    this.isLoading = false,
  });

  @override
  State<NanoMetallicButton> createState() => _NanoMetallicButtonState();
}

class _NanoMetallicButtonState extends State<NanoMetallicButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isEnabled = widget.onPressed != null && !widget.isLoading;

    // Configuración de paleta según el estilo visual
    final (bgGradient, borderColor, textColor, iconColor) = switch (widget.style) {
      NanoMetallicButtonStyle.danger => (
        LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: isDark
              ? [const Color(0xFFEF4444), const Color(0xFFB91C1C)]
              : [const Color(0xFFF87171), const Color(0xFFDC2626)],
        ),
        Colors.white.withValues(alpha: 0.35),
        Colors.white,
        Colors.white,
      ),
      NanoMetallicButtonStyle.subtle => (
        LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: isDark
              ? [const Color(0x33334155), const Color(0x1F1E293B)]
              : [const Color(0xFFF1F5F9), const Color(0xFFE2E8F0)],
        ),
        isDark ? Colors.white.withValues(alpha: 0.15) : const Color(0xFFCBD5E1),
        isDark ? const Color(0xFFE2E8F0) : const Color(0xFF334155),
        isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
      ),
      NanoMetallicButtonStyle.primary => (
        LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isDark
              ? [const Color(0xFF2563EB), const Color(0xFF1D4ED8)]
              : [const Color(0xFF3B82F6), const Color(0xFF2563EB)],
        ),
        Colors.white.withValues(alpha: isDark ? 0.40 : 0.60),
        Colors.white,
        Colors.white,
      ),
    };

    final content = AnimatedScale(
      scale: (_pressed && isEnabled) ? 0.96 : 1.0,
      duration: const Duration(milliseconds: 100),
      curve: Curves.easeOutCubic,
      child: AnimatedOpacity(
        opacity: isEnabled ? 1.0 : 0.5,
        duration: const Duration(milliseconds: 150),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            gradient: bgGradient,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: borderColor, width: 1.0),
            boxShadow: isDark
                ? [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.35),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.08),
                      blurRadius: 4,
                      offset: const Offset(0, 1),
                    ),
                  ],
          ),
          child: Row(
            mainAxisSize: widget.isExpanded ? MainAxisSize.max : MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (widget.isLoading) ...[
                SizedBox(
                  width: 15,
                  height: 15,
                  child: CircularProgressIndicator(strokeWidth: 2, color: textColor),
                ),
                const SizedBox(width: 8),
              ] else if (widget.icon != null) ...[
                Icon(widget.icon, size: 16, color: iconColor),
                const SizedBox(width: 6),
              ],
              Text(
                widget.label,
                style: TextStyle(
                  color: textColor,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  letterSpacing: -0.1,
                ),
              ),
            ],
          ),
        ),
      ),
    );

    return GestureDetector(
      onTapDown: isEnabled ? (_) => setState(() => _pressed = true) : null,
      onTapUp: isEnabled ? (_) => setState(() => _pressed = false) : null,
      onTapCancel: isEnabled ? () => setState(() => _pressed = false) : null,
      onTap: isEnabled ? widget.onPressed : null,
      child: content,
    );
  }
}
