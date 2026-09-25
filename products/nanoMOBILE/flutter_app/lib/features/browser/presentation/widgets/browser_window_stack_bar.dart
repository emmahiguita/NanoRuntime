import 'package:flutter/material.dart';

/// Barra de control compacta para la vista de ventanas apiladas.
/// 
/// - QUÉ HACE: Controla expansión/colapso de ventanas, adición de pestaña y menú ⋮.
/// - CÓMO FUNCIONA: Despacha callbacks a los notifiers y presenta un [PopupMenuButton] compacto.
/// - POR QUÉ: Reduce redundancia visual y evita saturación de controles (<200 líneas).
class BrowserWindowStackBar extends StatelessWidget {
  final int tabCount;
  final bool allMinimized;
  final VoidCallback onToggleAllMinimized, onAddTab, onOpenCarousel, onOpenFocused, onOpenOptions;

  const BrowserWindowStackBar({
    super.key, required this.tabCount, required this.allMinimized,
    required this.onToggleAllMinimized, required this.onAddTab, required this.onOpenCarousel,
    required this.onOpenFocused, required this.onOpenOptions,
  });

  @override
  Widget build(BuildContext context) {
    final isLand = MediaQuery.of(context).orientation == Orientation.landscape;
    return Padding(
      padding: EdgeInsets.fromLTRB(6, 0, 6, isLand ? 2 : 4),
      child: Row(children: [
        Flexible(
          child: Semantics(
            label: allMinimized ? 'Expandir ventanas' : 'Colapsar ventanas', button: true,
            child: InkWell(
              onTap: onToggleAllMinimized, borderRadius: BorderRadius.circular(10),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0x990B1322), borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
                ),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(allMinimized ? Icons.unfold_more_rounded : Icons.unfold_less_rounded, size: 13, color: const Color(0xFF10B981)),
                  const SizedBox(width: 4),
                  Text('Ventanas ($tabCount)', style: const TextStyle(fontSize: 11.0, fontWeight: FontWeight.bold, color: Color(0xFF94A3B8)), overflow: TextOverflow.ellipsis),
                ]),
              ),
            ),
          ),
        ),
        const SizedBox(width: 5),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 2),
          decoration: BoxDecoration(color: const Color(0x800F172A), borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.white.withValues(alpha: 0.10))),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            _StackActionBtn(icon: Icons.add_rounded, tooltip: 'Nueva Ventana', color: const Color(0xFF38BDF8), onTap: onAddTab),
            const SizedBox(width: 2),
            _StackMenuBtn(onOpenCarousel: onOpenCarousel, onOpenFocused: onOpenFocused, onOpenOptions: onOpenOptions),
          ]),
        ),
      ]),
    );
  }
}

class _StackActionBtn extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final Color color;
  final VoidCallback onTap;

  const _StackActionBtn({required this.icon, required this.tooltip, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) => Semantics(
    label: tooltip, button: true,
    child: InkWell(
      onTap: onTap, borderRadius: BorderRadius.circular(6),
      child: Container(
        width: 24, height: 24, alignment: Alignment.center,
        decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.05), borderRadius: BorderRadius.circular(6)),
        child: Icon(icon, size: 14, color: color),
      ),
    ),
  );
}

class _StackMenuBtn extends StatelessWidget {
  final VoidCallback onOpenCarousel, onOpenFocused, onOpenOptions;

  const _StackMenuBtn({required this.onOpenCarousel, required this.onOpenFocused, required this.onOpenOptions});

  @override
  Widget build(BuildContext context) => PopupMenuButton<String>(
    tooltip: '', padding: EdgeInsets.zero, color: const Color(0xFF0F172A), elevation: 8,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10), side: BorderSide(color: Colors.white.withValues(alpha: 0.12))),
    icon: const Icon(Icons.more_vert_rounded, size: 14, color: Color(0xFFE2E8F0)),
    onSelected: (v) {
      if (v == 'carousel') onOpenCarousel();
      if (v == 'focused') onOpenFocused();
      if (v == 'options') onOpenOptions();
    },
    itemBuilder: (_) => [
      const PopupMenuItem(value: 'carousel', height: 34, child: _MenuItem(icon: Icons.view_in_ar_rounded, label: 'Carrusel 3D', color: Color(0xFF10B981))),
      const PopupMenuItem(value: 'focused', height: 34, child: _MenuItem(icon: Icons.fullscreen_rounded, label: 'Vista Completa', color: Color(0xFFCBD5E1))),
      const PopupMenuItem(value: 'options', height: 34, child: _MenuItem(icon: Icons.settings_rounded, label: 'Opciones', color: Color(0xFF94A3B8))),
    ],
  );
}

class _MenuItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  const _MenuItem({required this.icon, required this.label, required this.color});

  @override
  Widget build(BuildContext context) => Row(children: [
    Icon(icon, size: 14, color: color),
    const SizedBox(width: 8),
    Text(label, style: TextStyle(color: color == const Color(0xFF94A3B8) ? Colors.white : color, fontSize: 11.5)),
  ]);
}

/// Barra superior cuando una ventana está maximizada en modo Stack.
class BrowserWindowMaximizedBar extends StatelessWidget {
  final VoidCallback onBackToStack, onOpenOptions;

  const BrowserWindowMaximizedBar({super.key, required this.onBackToStack, required this.onOpenOptions});

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(6, 0, 6, 3),
    child: Row(children: [
      Semantics(
        label: 'Volver a Ventanas', button: true,
        child: InkWell(
          onTap: onBackToStack, borderRadius: BorderRadius.circular(10),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(color: const Color(0x990B1322), borderRadius: BorderRadius.circular(10), border: Border.all(color: Colors.white.withValues(alpha: 0.12))),
            child: const Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(Icons.arrow_back_rounded, size: 13, color: Color(0xFF38BDF8)),
              SizedBox(width: 4),
              Text('Volver', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: Color(0xFF94A3B8))),
            ]),
          ),
        ),
      ),
      const Spacer(),
      _StackActionBtn(icon: Icons.more_vert_rounded, tooltip: 'Opciones', color: const Color(0xFFE2E8F0), onTap: onOpenOptions),
    ]),
  );
}
