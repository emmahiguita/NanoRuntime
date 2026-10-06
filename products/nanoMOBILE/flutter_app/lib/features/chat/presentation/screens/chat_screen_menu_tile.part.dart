part of 'chat_screen.dart';

// QUÉ HACE:
// Componente de ítem individual para el menú modal de opciones del chat.
//
// CÓMO FUNCIONA:
// - Renderiza un contenedor táctil Material con icono contrastado, título, subtítulo e indicador de flecha.
// - Aplica micro-interacción y soporte de estados destructivos (rojo de alerta) con esquinas redondeadas suaves.
//
// POR QUÉ:
// Aplica el principio de Responsabilidad Única (SRP) de SOLID, aislando la construcción del widget de ítem
// para mantener los archivos estrictamente por debajo del umbral de 200 líneas.
extension _ChatScreenMenuTile on _ChatScreenState {
  /// QUÉ HACE: Construye cada ítem del menú con diseño Material Expressive y respuesta táctil.
  Widget _buildCleanOptionTile({
    required IconData icon,
    required String label,
    required String subtitle,
    required NanoColors colors,
    required VoidCallback? onTap,
    bool isDestructive = false,
  }) {
    final iconBgColor = isDestructive
        ? const Color(0xFFEF4444).withValues(alpha: 0.12)
        : colors.onSurface.withValues(alpha: 0.06);
    final iconColor = isDestructive
        ? const Color(0xFFEF4444)
        : colors.onSurface.withValues(alpha: 0.82);
    final titleColor = isDestructive
        ? const Color(0xFFEF4444)
        : colors.onSurface.withValues(alpha: 0.92);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 9),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: iconBgColor,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: iconColor, size: 19),
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
                        fontSize: 13.5,
                        fontWeight: FontWeight.w600,
                        color: titleColor,
                      ),
                    ),
                    const SizedBox(height: 1),
                    Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 11,
                        color: colors.onSurface.withValues(alpha: 0.50),
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                size: 18,
                color: colors.onSurface.withValues(alpha: 0.25),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
