part of 'personalization_studio_screen.dart';

/// PERSONALIZATION-STUDIO-EXAMPLE-CARD — Tarjeta de Frase Aprendida y Respuestas Múltiples.
///
/// **QUÉ HACE:**
/// Renderiza una intención conversacional completa mostrando la frase recibida, su categoría,
/// el total de variantes de respuesta y las opciones destacadas con soporte para expandir '+N más'.
///
/// **CÓMO FUNCIONA:**
/// Presenta diseño iOS Glass con viñetas ('•'), switch de activación rápida, y acciones
/// directas de '[Editar]' y '[+ Respuesta]' para enriquecer el repertorio del agente.
///
/// **POR QUÉ:**
/// Erradica el concepto ambiguo de 'Par real', sustituyéndolo por un modelo natural de
/// 'Frase recibida ➔ Múltiples respuestas posibles' con mínima sobrecarga visual (< 200 líneas).
class _PersonaExampleCard extends StatefulWidget {
  final PersonaExample example;
  final bool canEdit;
  final ValueChanged<bool>? onToggleEnabled;
  final VoidCallback? onEdit;
  final VoidCallback? onAddResponse;
  final VoidCallback? onDelete;

  const _PersonaExampleCard({
    required this.example,
    required this.canEdit,
    this.onToggleEnabled,
    this.onEdit,
    this.onAddResponse,
    this.onDelete,
  });

  @override
  State<_PersonaExampleCard> createState() => _PersonaExampleCardState();
}

class _PersonaExampleCardState extends State<_PersonaExampleCard> {
  bool _expanded = false;

  /// Delega la composicion; este State conserva su ciclo de vida y acciones.
  @override
  Widget build(BuildContext context) => _buildExample(context);

  Widget _btn(String label, IconData icon, Color color, VoidCallback? onTap) {
    return InkWell(
      borderRadius: BorderRadius.circular(5),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 11, color: color),
            const SizedBox(width: 3),
            Text(
              label,
              style: TextStyle(fontSize: 10, color: color, fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ),
    );
  }
}
