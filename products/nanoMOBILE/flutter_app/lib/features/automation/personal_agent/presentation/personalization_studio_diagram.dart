part of 'personalization_studio_screen.dart';

/// PERSONALIZATION-STUDIO-DIAGRAM — Diagrama de Flujo Visual del Diálogo.
///
/// **QUÉ HACE:**
/// Representa gráficamente el flujo de mensajes del Agente EMMA:
/// [📩 Entrada] ➔ [🤖 Cerebro EMMA] ➔ [🎲 Rotación 1 de N] ➔ [💬 Respuesta WhatsApp].
///
/// **CÓMO FUNCIONA:**
/// Renderiza 4 nodos de decisión interconectados con diseño iOS Glass, badges luminosos
/// y un simulador interactivo de "Probar Rotación" que rota entre las respuestas disponibles.
///
/// **POR QUÉ:**
/// Permite al usuario comprender de un vistazo cómo se procesan sus múltiples variantes
/// de respuesta de forma inteligente y rotativa sin repeticiones mecánicas.
class _PersonalizationStudioDiagram extends StatefulWidget {
  final int totalExamples;
  const _PersonalizationStudioDiagram({required this.totalExamples});

  @override
  State<_PersonalizationStudioDiagram> createState() =>
      _PersonalizationStudioDiagramState();
}

class _PersonalizationStudioDiagramState
    extends State<_PersonalizationStudioDiagram> {
  bool _expanded = true;
  int _simIndex = 0;
  static const _sims = [
    '¡Hola! ¿Qué tal todo por allá?',
    'Buenas, ¿cómo va tu día?',
    'Hola qué más, ¿todo bien?',
    '¡Buenas buenas! Cuéntame.',
  ];

  /// Delega la composicion; este State conserva su ciclo de vida y acciones.
  @override
  Widget build(BuildContext context) => _buildDiagram(context);

  Widget _node(String s, String t, String d, IconData i, Color c) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 5, horizontal: 2),
        decoration: BoxDecoration(
          color: c.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: c.withValues(alpha: 0.35), width: 0.7),
        ),
        child: Column(
          children: [
            Icon(i, size: 11, color: c),
            const SizedBox(height: 2),
            Text(
              t,
              style: TextStyle(fontSize: 7.5, fontWeight: FontWeight.bold, color: c),
              maxLines: 1,
            ),
            Text(
              d,
              style: const TextStyle(fontSize: 6.5, color: Colors.white54),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  Widget _arrow() => const Padding(
    padding: EdgeInsets.symmetric(horizontal: 1.5),
    child: Icon(
      Icons.arrow_forward_ios_rounded,
      size: 7,
      color: Color(0x66FFFFFF),
    ),
  );
}
