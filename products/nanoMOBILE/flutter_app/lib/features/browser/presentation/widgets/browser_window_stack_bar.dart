import 'package:flutter/material.dart';

/// Barra de control rápida para la vista de ventanas apiladas.
/// 
/// - ¿Qué hace?: Muestra el botón de colapsar/expandir todas las ventanas ("Ventanas (N)"),
///   y botones rápidos para nueva ventana, carrusel 3D, vista enfocada y menú de opciones.
/// - ¿Cómo funciona?: Renderiza botones compactos con fondos translúcidos y bordes sutiles.
/// - ¿Por qué?: Separa los controles de navegación del layout apilado (Single Responsibility).
class BrowserWindowStackBar extends StatelessWidget {
  final int tabCount;
  final bool allMinimized;
  final VoidCallback onToggleAllMinimized;
  final VoidCallback onAddTab;
  final VoidCallback onOpenCarousel;
  final VoidCallback onOpenFocused;
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
    final isLandscape = MediaQuery.of(context).orientation == Orientation.landscape;
    return Padding(
      padding: EdgeInsets.fromLTRB(8, 0, 8, isLandscape ? 2 : 6),
      child: Row(
        children: [
          Flexible(
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
                      size: 14,
                      color: const Color(0xFFF59E0B),
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
          const SizedBox(width: 6),
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
                _StackActionBtn(
                  icon: Icons.add_rounded,
                  tooltip: 'Nueva Ventana',
                  color: const Color(0xFF38BDF8),
                  onTap: onAddTab,
                ),
                const SizedBox(width: 2),
                _StackActionBtn(
                  icon: Icons.view_in_ar_rounded,
                  tooltip: 'Carrusel 3D',
                  color: const Color(0xFF10B981),
                  onTap: onOpenCarousel,
                ),
                const SizedBox(width: 2),
                _StackActionBtn(
                  icon: Icons.fullscreen_rounded,
                  tooltip: 'Vista Completa',
                  color: const Color(0xFFCBD5E1),
                  onTap: onOpenFocused,
                ),
                if (onAskOwl != null) ...[
                  const SizedBox(width: 2),
                  _StackActionBtn(
                    icon: Icons.auto_awesome_rounded,
                    tooltip: 'Búho IA — Consultar Web AI',
                    color: const Color(0xFF10B981),
                    onTap: onAskOwl!,
                  ),
                ],
                const SizedBox(width: 2),
                _StackActionBtn(
                  icon: Icons.more_vert_rounded,
                  tooltip: 'Opciones',
                  color: const Color(0xFFE2E8F0),
                  onTap: onOpenOptions,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Botón ultra compacto estilo iOS para la barra de ventanas apiladas.
class _StackActionBtn extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final Color color;
  final VoidCallback onTap;

  const _StackActionBtn({required this.icon, required this.tooltip, required this.color, required this.onTap});

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
          decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.05), borderRadius: BorderRadius.circular(8)),
          child: Icon(icon, size: 15, color: color),
        ),
      ),
    );
  }
}

/// Barra de navegación superior cuando una ventana individual está maximizada en modo Stack.
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
          InkWell(
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
                  Text('Volver a Ventanas', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF94A3B8))),
                ],
              ),
            ),
          ),
          const Spacer(),
          if (onAskOwl != null)
            _StackActionBtn(icon: Icons.auto_awesome_rounded, tooltip: 'Búho IA — Consultar Web AI', color: const Color(0xFF10B981), onTap: onAskOwl!),
          const SizedBox(width: 4),
          _StackActionBtn(icon: Icons.more_vert_rounded, tooltip: 'Opciones', color: const Color(0xFFE2E8F0), onTap: onOpenOptions),
        ],
      ),
    );
  }
}

