import 'package:flutter/material.dart';

/// QUÉ HACE: Barra de control compacta para la vista de ventanas apiladas.
/// CÓMO FUNCIONA: Muestra "Ventanas (N)" toggle + botón "+" y menú "⋮" con
///   acciones secundarias (Carrusel 3D, Vista Completa, Búho IA, Opciones).
/// POR QUÉ: Reduce redundancia visual; cada acción vive en UN solo lugar.
///   Carrusel y Vista Completa se mueven dentro del menú para no saturar la barra.
class BrowserWindowStackBar extends StatelessWidget {
  final int tabCount;
  final bool allMinimized;
  final VoidCallback onToggleAllMinimized;
  final VoidCallback onAddTab;
  final VoidCallback onOpenCarousel;  // Accesible desde menú ⋮
  final VoidCallback onOpenFocused;   // Accesible desde menú ⋮
  final VoidCallback onOpenOptions;
  final VoidCallback? onAskOwl;

  const BrowserWindowStackBar({
    super.key,
    required this.tabCount,
    required this.allMinimized,
    required this.onToggleAllMinimized,
    required this.onAddTab,
    required this.onOpenCarousel,
    required this.onOpenFocused,
    required this.onOpenOptions,
    this.onAskOwl,
  });

  @override
  Widget build(BuildContext context) {
    final isLand = MediaQuery.of(context).orientation == Orientation.landscape;
    return Padding(
      padding: EdgeInsets.fromLTRB(8, 0, 8, isLand ? 2 : 6),
      child: Row(
        children: [
          // Toggle expandir/colapsar todas las ventanas
          Flexible(
            child: Semantics(
              label: allMinimized ? 'Expandir ventanas' : 'Colapsar ventanas',
              button: true,
              child: InkWell(
                onTap: onToggleAllMinimized,
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0x990B1322),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        allMinimized ? Icons.unfold_more_rounded : Icons.unfold_less_rounded,
                        size: 14, color: const Color(0xFFF59E0B),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'Ventanas ($tabCount)',
                        style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: Color(0xFF94A3B8)),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 6),
          // Grupo de acciones rápidas: solo Nueva Ventana + Menú ⋮
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
            decoration: BoxDecoration(
              color: const Color(0x800F172A),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.white.withValues(alpha: 0.10)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Nueva ventana — acción frecuente, visible siempre
                _StackActionBtn(
                  icon: Icons.add_rounded,
                  tooltip: 'Nueva Ventana',
                  color: const Color(0xFF38BDF8),
                  onTap: onAddTab,
                ),
                const SizedBox(width: 2),
                // Menú contextual con acciones secundarias (sin saturar la barra)
                _StackMenuBtn(
                  onOpenCarousel: onOpenCarousel,
                  onOpenFocused: onOpenFocused,
                  onAskOwl: onAskOwl,
                  onOpenOptions: onOpenOptions,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Botón ultra compacto estilo Material 3 para la barra de ventanas apiladas.
/// Usa Semantics en lugar de Tooltip para evitar el error "No Overlay".
class _StackActionBtn extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final Color color;
  final VoidCallback onTap;

  const _StackActionBtn({
    required this.icon, required this.tooltip,
    required this.color, required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: tooltip,
      button: true,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          width: 26, height: 26, alignment: Alignment.center,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, size: 15, color: color),
        ),
      ),
    );
  }
}

/// Menú "⋮" con acciones secundarias agrupadas para evitar redundancia visual.
/// QUÉ: Carrusel 3D, Vista Enfocada, Búho IA y Opciones.
/// POR QUÉ: Mantiene la barra compacta; acciones menos frecuentes quedan en el menú.
class _StackMenuBtn extends StatelessWidget {
  final VoidCallback onOpenCarousel, onOpenFocused, onOpenOptions;
  final VoidCallback? onAskOwl;

  const _StackMenuBtn({
    required this.onOpenCarousel, required this.onOpenFocused,
    required this.onOpenOptions, this.onAskOwl,
  });

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<String>(
      tooltip: '',
      padding: EdgeInsets.zero,
      color: const Color(0xFF0F172A),
      elevation: 8,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(color: Colors.white.withValues(alpha: 0.12)),
      ),
      icon: const Icon(Icons.more_vert_rounded, size: 15, color: Color(0xFFE2E8F0)),
      onSelected: (v) {
        if (v == 'carousel') onOpenCarousel();
        if (v == 'focused') onOpenFocused();
        if (v == 'owl') onAskOwl?.call();
        if (v == 'options') onOpenOptions();
      },
      itemBuilder: (_) => [
        const PopupMenuItem(value: 'carousel', height: 36, child: _MenuItem(icon: Icons.view_in_ar_rounded, label: 'Carrusel 3D', color: Color(0xFF10B981))),
        const PopupMenuItem(value: 'focused', height: 36, child: _MenuItem(icon: Icons.fullscreen_rounded, label: 'Vista Completa', color: Color(0xFFCBD5E1))),
        if (onAskOwl != null) const PopupMenuItem(value: 'owl', height: 36, child: _MenuItem(icon: Icons.auto_awesome_rounded, label: 'Búho IA', color: Color(0xFF10B981))),
        const PopupMenuItem(value: 'options', height: 36, child: _MenuItem(icon: Icons.settings_rounded, label: 'Opciones', color: Color(0xFF94A3B8))),
      ],
    );
  }
}

/// Ítem de menú compacto con icono y texto.
class _MenuItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  const _MenuItem({required this.icon, required this.label, required this.color});

  @override
  Widget build(BuildContext context) => Row(children: [
    Icon(icon, size: 15, color: color),
    const SizedBox(width: 8),
    Text(label, style: TextStyle(color: color == const Color(0xFF94A3B8) ? Colors.white : color, fontSize: 12)),
  ]);
}

/// Barra superior cuando una ventana está maximizada en modo Stack.
/// QUÉ: Botón "← Volver" + acciones Búho IA y Opciones.
class BrowserWindowMaximizedBar extends StatelessWidget {
  final VoidCallback onBackToStack, onOpenOptions;
  final VoidCallback? onAskOwl;

  const BrowserWindowMaximizedBar({
    super.key,
    required this.onBackToStack,
    required this.onOpenOptions,
    this.onAskOwl,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 0, 8, 4),
      child: Row(
        children: [
          // Botón "← Volver" funcional sin componente muerto
          Semantics(
            label: 'Volver a Ventanas',
            button: true,
            child: InkWell(
              onTap: onBackToStack,
              borderRadius: BorderRadius.circular(12),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0x990B1322),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.arrow_back_rounded, size: 14, color: Color(0xFF38BDF8)),
                    SizedBox(width: 4),
                    Text('Volver', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF94A3B8))),
                  ],
                ),
              ),
            ),
          ),
          const Spacer(),
          // Búho IA si disponible
          if (onAskOwl != null) ...[
            _StackActionBtn(icon: Icons.auto_awesome_rounded, tooltip: 'Búho IA', color: const Color(0xFF10B981), onTap: onAskOwl!),
            const SizedBox(width: 4),
          ],
          _StackActionBtn(icon: Icons.more_vert_rounded, tooltip: 'Opciones', color: const Color(0xFFE2E8F0), onTap: onOpenOptions),
        ],
      ),
    );
  }
}
