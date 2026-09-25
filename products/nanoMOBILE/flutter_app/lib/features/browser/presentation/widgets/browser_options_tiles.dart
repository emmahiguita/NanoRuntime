import 'package:flutter/material.dart';

/// Botón de acción rápida profesional para la barra superior del menú de opciones.
class GlassOrbAction extends StatefulWidget {
  final IconData icon;
  final String label;
  final Color accentColor;
  final bool isActive;
  final VoidCallback onTap;

  const GlassOrbAction({
    super.key,
    required this.icon,
    required this.label,
    required this.accentColor,
    this.isActive = false,
    required this.onTap,
  });

  @override
  State<GlassOrbAction> createState() => _GlassOrbActionState();
}

class _GlassOrbActionState extends State<GlassOrbAction> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) => setState(() => _pressed = false),
      onTapCancel: () => setState(() => _pressed = false),
      onTap: widget.onTap,
      child: AnimatedScale(
        scale: _pressed ? 0.94 : 1.0,
        duration: const Duration(milliseconds: 120),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            color: widget.isActive
                ? const Color(0xFF10B981).withValues(alpha: 0.16)
                : (isDark ? Colors.white.withValues(alpha: 0.05) : Colors.black.withValues(alpha: 0.04)),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: widget.isActive
                  ? const Color(0xFF10B981).withValues(alpha: 0.45)
                  : (isDark ? Colors.white.withValues(alpha: 0.08) : Colors.black.withValues(alpha: 0.06)),
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                widget.icon,
                size: 20,
                color: widget.isActive
                    ? const Color(0xFF34D399)
                    : (isDark ? const Color(0xFFCBD5E1) : const Color(0xFF475569)),
              ),
              const SizedBox(height: 4),
              Text(
                widget.label,
                style: TextStyle(
                  fontSize: 11.0,
                  fontWeight: FontWeight.w500,
                  color: widget.isActive
                      ? const Color(0xFF34D399)
                      : (isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Fila de menú estilizada y sobria para el menú de opciones del navegador.
class GlassMenuRow extends StatefulWidget {
  final IconData icon;
  final Color? accent;
  final String title;
  final String? subtitle, trailingBadge;
  final bool isHighlight;
  final VoidCallback onTap;

  const GlassMenuRow({
    super.key,
    required this.icon,
    this.accent,
    required this.title,
    this.subtitle,
    this.trailingBadge,
    this.isHighlight = false,
    required this.onTap,
  });

  @override
  State<GlassMenuRow> createState() => _GlassMenuRowState();
}

class _GlassMenuRowState extends State<GlassMenuRow> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isLand = MediaQuery.of(context).orientation == Orientation.landscape;
    final iconColor = widget.accent ?? (isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B));

    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) => setState(() => _pressed = false),
      onTapCancel: () => setState(() => _pressed = false),
      onTap: widget.onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        padding: EdgeInsets.symmetric(horizontal: 10, vertical: isLand ? 5 : 8),
        margin: const EdgeInsets.symmetric(vertical: 1.5),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
          color: _pressed
              ? (isDark ? Colors.white.withValues(alpha: 0.08) : Colors.black.withValues(alpha: 0.06))
              : Colors.transparent,
        ),
        child: Row(
          children: [
            Icon(widget.icon, size: isLand ? 17 : 20, color: iconColor),
            SizedBox(width: isLand ? 10 : 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.title,
                    style: TextStyle(
                      fontSize: isLand ? 12.0 : 13.5,
                      fontWeight: FontWeight.w500,
                      color: isDark ? const Color(0xFFF1F5F9) : const Color(0xFF0F172A),
                    ),
                  ),
                  if (widget.subtitle != null) ...[
                    const SizedBox(height: 1),
                    Text(
                      widget.subtitle!,
                      style: TextStyle(
                        fontSize: isLand ? 10.0 : 11.0,
                        color: isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            if (widget.trailingBadge != null)
              Container(
                margin: const EdgeInsets.only(right: 6),
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: const Color(0xFF10B981).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: const Color(0xFF10B981).withValues(alpha: 0.4)),
                ),
                child: Text(
                  widget.trailingBadge!,
                  style: const TextStyle(fontSize: 9.5, fontWeight: FontWeight.bold, color: Color(0xFF34D399)),
                ),
              ),
            Icon(Icons.chevron_right_rounded, size: 18, color: isDark ? Colors.white24 : Colors.black26),
          ],
        ),
      ),
    );
  }
}

/// Botón circular de cerrar para la hoja de opciones.
class GlassCircleButton extends StatelessWidget {
  final IconData icon;
  final double size;
  final VoidCallback onTap;

  const GlassCircleButton({super.key, required this.icon, required this.size, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(size / 2),
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: isDark ? Colors.white.withValues(alpha: 0.08) : Colors.black.withValues(alpha: 0.06),
          border: Border.all(color: isDark ? Colors.white.withValues(alpha: 0.08) : Colors.black.withValues(alpha: 0.06)),
        ),
        alignment: Alignment.center,
        child: Icon(icon, size: 17, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF475569)),
      ),
    );
  }
}

/// Botón secundario en píldora glass (Marcadores, Historial)
class GlassSecondaryButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color? accent;
  final VoidCallback onTap;

  const GlassSecondaryButton({super.key, required this.icon, required this.label, this.accent, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        height: 38,
        padding: const EdgeInsets.symmetric(horizontal: 10),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
          color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.black.withValues(alpha: 0.04),
          border: Border.all(color: isDark ? Colors.white.withValues(alpha: 0.08) : Colors.black.withValues(alpha: 0.06)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 16, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                fontSize: 12.0,
                fontWeight: FontWeight.w500,
                color: isDark ? const Color(0xFFE2E8F0) : const Color(0xFF1E293B),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
