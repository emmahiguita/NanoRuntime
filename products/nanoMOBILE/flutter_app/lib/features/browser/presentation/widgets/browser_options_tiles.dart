import 'package:flutter/material.dart';

/// Orbe de acción rápida circular con brillo para la hoja de opciones.
class GlassOrbAction extends StatefulWidget {
  final IconData icon;
  final String label;
  final Color accentColor;
  final bool isActive;
  final VoidCallback onTap;

  const GlassOrbAction({
    super.key, required this.icon, required this.label, required this.accentColor,
    this.isActive = false, required this.onTap,
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
        scale: _pressed ? 0.92 : 1.0,
        duration: const Duration(milliseconds: 140),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(
            width: 46, height: 46,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: widget.accentColor.withValues(alpha: widget.isActive ? 0.35 : 0.15),
              border: Border.all(color: widget.accentColor.withValues(alpha: widget.isActive ? 0.95 : 0.60), width: widget.isActive ? 1.6 : 1.0),
            ),
            alignment: Alignment.center,
            child: Icon(widget.icon, size: 20, color: widget.isActive ? Colors.white : widget.accentColor),
          ),
          const SizedBox(height: 5),
          Text(widget.label, style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w500, color: isDark ? const Color(0xFFE2E8F0) : const Color(0xFF334155))),
        ]),
      ),
    );
  }
}

/// Fila de menú estilizada para la hoja de opciones del navegador.
class GlassMenuRow extends StatefulWidget {
  final IconData icon;
  final Color accent;
  final String title;
  final String? subtitle, trailingBadge;
  final bool isHighlight;
  final VoidCallback onTap;

  const GlassMenuRow({
    super.key, required this.icon, required this.accent, required this.title,
    this.subtitle, this.trailingBadge, this.isHighlight = false, required this.onTap,
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

    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) => setState(() => _pressed = false),
      onTapCancel: () => setState(() => _pressed = false),
      onTap: widget.onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 140),
        padding: EdgeInsets.symmetric(horizontal: 6, vertical: isLand ? 3 : 7),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          color: _pressed ? (isDark ? Colors.white10 : Colors.black12) : Colors.transparent,
        ),
        child: Row(children: [
          Container(
            width: isLand ? 26 : 32, height: isLand ? 26 : 32,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(isLand ? 6 : 8),
              color: widget.accent.withValues(alpha: 0.16),
              border: Border.all(color: widget.accent.withValues(alpha: 0.40)),
            ),
            alignment: Alignment.center,
            child: Icon(widget.icon, size: isLand ? 14 : 17, color: widget.accent),
          ),
          SizedBox(width: isLand ? 8 : 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(
              widget.title,
              style: TextStyle(
                fontSize: isLand ? 12.0 : 13.5, fontWeight: FontWeight.w600,
                color: widget.isHighlight ? const Color(0xFFD946EF) : (isDark ? const Color(0xFFF1F5F9) : const Color(0xFF0F172A)),
              ),
            ),
            if (widget.subtitle != null)
              Text(widget.subtitle!, style: TextStyle(fontSize: isLand ? 9.5 : 11.0, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B))),
          ])),
          if (widget.trailingBadge != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(color: widget.accent.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(6), border: Border.all(color: widget.accent.withValues(alpha: 0.5))),
              child: Text(widget.trailingBadge!, style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.bold, color: widget.accent)),
            ),
          Icon(Icons.chevron_right_rounded, size: 18, color: isDark ? Colors.white24 : Colors.black26),
        ]),
      ),
    );
  }
}

/// Botón circular secundario de vidrio
class GlassCircleButton extends StatelessWidget {
  final IconData icon;
  final double size;
  final VoidCallback onTap;

  const GlassCircleButton({super.key, required this.icon, required this.size, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return InkWell(
      onTap: onTap, borderRadius: BorderRadius.circular(size / 2),
      child: Container(
        width: size, height: size,
        decoration: BoxDecoration(shape: BoxShape.circle, color: isDark ? Colors.white10 : Colors.black12, border: Border.all(color: isDark ? Colors.white12 : Colors.black12)),
        alignment: Alignment.center,
        child: Icon(icon, size: 18, color: isDark ? const Color(0xFFCBD5E1) : const Color(0xFF475569)),
      ),
    );
  }
}

/// Botón secundario en píldora glass (Marcadores, Historial)
class GlassSecondaryButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color accent;
  final VoidCallback onTap;

  const GlassSecondaryButton({super.key, required this.icon, required this.label, required this.accent, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return InkWell(
      onTap: onTap, borderRadius: BorderRadius.circular(12),
      child: Container(
        height: 40, padding: const EdgeInsets.symmetric(horizontal: 10),
        decoration: BoxDecoration(borderRadius: BorderRadius.circular(12), color: isDark ? Colors.white10 : Colors.black12, border: Border.all(color: isDark ? Colors.white12 : Colors.black12)),
        child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(icon, size: 16, color: accent),
          const SizedBox(width: 6),
          Text(label, style: TextStyle(fontSize: 12.0, fontWeight: FontWeight.w600, color: isDark ? const Color(0xFFF1F5F9) : const Color(0xFF0F172A))),
        ]),
      ),
    );
  }
}
