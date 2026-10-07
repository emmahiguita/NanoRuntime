import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:nanoai/core/widgets/nano_owl_avatar.dart';
import 'terminal_session_item.dart';

/// Barra superior de navegación y pestañas para el entorno de terminal.
///
/// QUÉ HACE:
/// Proporciona los controles de navegación (retroceder, centro de control terminal,
/// visor gráfico Linux), pestañas dinámicas con indicador de estado por sesión,
/// botón de creación (+) y alternador de modo cuadrado (1:1).
///
/// CÓMO FUNCIONA:
/// Recibe la lista de sesiones activas y callbacks para interacción de pestañas.
/// Renderiza un ListView horizontal con chips estéticos y botones de acceso directo.
///
/// POR QUÉ:
/// Cumple con Single Responsibility Principle (SRP): desacopla la presentación
/// visual del encabezado del ciclo de vida general del terminal.
class TerminalTopBar extends StatelessWidget {
  final List<TerminalSessionItem> sessions;
  final int activeIndex;
  final bool isSquareMode;
  final Color chromeColor;
  final Color fgColor;
  final bool isDark;
  final ValueChanged<int> onSelectTab;
  final ValueChanged<int> onCloseTab;
  final VoidCallback onAddTab;
  final VoidCallback onToggleSquare;

  const TerminalTopBar({
    super.key,
    required this.sessions,
    required this.activeIndex,
    required this.isSquareMode,
    required this.chromeColor,
    required this.fgColor,
    required this.isDark,
    required this.onSelectTab,
    required this.onCloseTab,
    required this.onAddTab,
    required this.onToggleSquare,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 40,
      padding: const EdgeInsets.only(left: 4, right: 4),
      decoration: BoxDecoration(
        color: chromeColor.withValues(alpha: isDark ? 0.82 : 0.90),
        border: Border(
          bottom: BorderSide(color: fgColor.withValues(alpha: 0.12)),
        ),
      ),
      child: Row(
        children: [
          // Botón de navegación atrás
          Semantics(
            label: 'Atrás',
            button: true,
            child: IconButton(
              visualDensity: VisualDensity.compact,
              constraints: const BoxConstraints(minWidth: 34, minHeight: 34),
              padding: const EdgeInsets.all(4),
              onPressed: () => Navigator.of(context).maybePop(),
              icon: Icon(Icons.arrow_back_rounded, size: 18, color: fgColor),
            ),
          ),
          const SizedBox(width: 2),
          const NanoOwlAvatar(size: 26, state: NanoOwlState.idle),
          const SizedBox(width: 4),
          // Lista horizontal de pestañas de sesión
          Expanded(
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: sessions.length,
              itemBuilder: (context, index) {
                final s = sessions[index];
                final isActive = index == activeIndex;
                final tabColor = s.color ?? fgColor;

                return GestureDetector(
                  onTap: () => onSelectTab(index),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    margin: const EdgeInsets.only(top: 4, right: 2),
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    decoration: BoxDecoration(
                      color: isActive
                          ? (isDark
                              ? const Color(0xFF030712).withValues(alpha: 0.92)
                              : Colors.white)
                          : Colors.transparent,
                      borderRadius:
                          const BorderRadius.vertical(top: Radius.circular(8)),
                      border: isActive
                          ? Border(top: BorderSide(color: tabColor, width: 2))
                          : null,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 7,
                          height: 7,
                          decoration: BoxDecoration(
                            color: tabColor,
                            shape: BoxShape.circle,
                            boxShadow: isActive
                                ? [
                                    BoxShadow(
                                      color: tabColor.withValues(alpha: 0.5),
                                      blurRadius: 4,
                                    ),
                                  ]
                                : null,
                          ),
                        ),
                        const SizedBox(width: 7),
                        Text(
                          s.name,
                          style: TextStyle(
                            fontFamily: 'JetBrainsMono',
                            fontSize: 11.5,
                            fontWeight:
                                isActive ? FontWeight.w600 : FontWeight.w400,
                            color: isActive
                                ? fgColor
                                : fgColor.withValues(alpha: 0.45),
                          ),
                        ),
                        if (sessions.length > 1) ...[
                          const SizedBox(width: 6),
                          GestureDetector(
                            onTap: () => onCloseTab(s.id),
                            child: Icon(
                              Icons.close,
                              size: 13,
                              color: fgColor.withValues(alpha: 0.35),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          // Botón Cuadro Geométrico (1:1)
          _buildActionBtn(
            label: isSquareMode ? 'Modo expandido' : 'Cuadro Geométrico (1:1)',
            onTap: onToggleSquare,
            isSelected: isSquareMode,
            icon: isSquareMode
                ? Icons.crop_square_rounded
                : Icons.aspect_ratio_rounded,
          ),
          const SizedBox(width: 2),
          // Botón agregar nueva sesión bash
          _buildActionBtn(
            label: 'Nueva pestaña',
            onTap: onAddTab,
            icon: Icons.add,
          ),
          const SizedBox(width: 4),
          // Botón centro de terminales
          _buildActionBtn(
            label: 'Centro Terminal',
            onTap: () => context.go('/terminal'),
            icon: Icons.apps_rounded,
          ),
          const SizedBox(width: 4),
          // Botón Visor Linux VNC/GUI
          _buildActionBtn(
            label: 'Visor Linux',
            onTap: () => context.push('/desktop'),
            icon: Icons.desktop_windows_rounded,
          ),
        ],
      ),
    );
  }

  Widget _buildActionBtn({
    required String label,
    required VoidCallback onTap,
    required IconData icon,
    bool isSelected = false,
  }) {
    return Semantics(
      label: label,
      button: true,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: 32,
          height: 32,
          margin: const EdgeInsets.only(right: 2),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(6),
            color: isSelected
                ? fgColor.withValues(alpha: 0.20)
                : fgColor.withValues(alpha: 0.06),
            border: isSelected
                ? Border.all(color: fgColor.withValues(alpha: 0.5), width: 1)
                : null,
          ),
          child: Icon(
            icon,
            size: 16,
            color: isSelected ? fgColor : fgColor.withValues(alpha: 0.6),
          ),
        ),
      ),
    );
  }
}
