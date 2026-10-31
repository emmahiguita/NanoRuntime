part of 'chat_screen.dart';

// chat_screen_menu_tile.part.dart — Elemento de lista para el menú modal de Gestión de Chat.
// QUÉ HACE: Renderiza una fila interactiva estilo iOS con icono semántico directo, textos Inter y chevron.
// CÓMO FUNCIONA: Elimina contenedores de color saturado; presenta glifos limpios sobre Liquid Glass puro.
// POR QUÉ: Cumple con la directriz de diseño iOS profesional sin cards internas ni colores chillones (< 110 líneas).

extension _ChatScreenMenuTile on _ChatScreenState {
  Widget _buildCleanOptionTile({
    required IconData icon,
    required String label,
    required String subtitle,
    required NanoColors colors,
    required VoidCallback? onTap,
    Color? iconColor,
    bool isDestructive = false,
  }) {
    final effectiveColor = isDestructive
        ? const Color(0xFFFF3B30)
        : (iconColor ?? colors.onSurfaceVariant);
    final titleColor = isDestructive
        ? const Color(0xFFFF3B30)
        : colors.onSurface;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8.5),
          child: Row(
            children: [
              SizedBox(
                width: 28,
                height: 28,
                child: Center(
                  child: Icon(icon, color: effectiveColor, size: 20),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        letterSpacing: -0.15,
                        color: titleColor,
                      ),
                    ),
                    const SizedBox(height: 1.5),
                    Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 11,
                        color: isDestructive
                            ? const Color(0xFFFF3B30).withValues(alpha: 0.70)
                            : colors.onSurfaceVariant.withValues(alpha: 0.70),
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                CupertinoIcons.chevron_right,
                size: 13,
                color: isDestructive
                    ? const Color(0xFFFF3B30).withValues(alpha: 0.35)
                    : colors.onSurfaceVariant.withValues(alpha: 0.35),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _menuSectionHeader(String title, NanoColors colors) => Padding(
    padding: const EdgeInsets.only(left: 4, top: 12, bottom: 4),
    child: Text(
      title,
      style: TextStyle(
        fontFamily: 'Inter',
        fontSize: 10.5,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.8,
        color: colors.onSurfaceVariant.withValues(alpha: 0.50),
      ),
    ),
  );

  Widget _divider(NanoColors colors) => Divider(
    height: 1,
    thickness: 0.5,
    indent: 44,
    endIndent: 4,
    color: colors.outlineVariant.withValues(alpha: 0.18),
  );
}
