part of 'personalization_studio_screen.dart';

/// PERSONALIZATION-STUDIO-EXAMPLES-TAB — Pestaña de Frases Aprendidas e Intenciones.
///
/// **QUÉ HACE:**
/// Presenta el catálogo completo de frases aprendidas del Agente EMMA organizadas por intención,
/// permitiendo agregar nuevas frases, añadir respuestas dinámicas y editar variantes.
///
/// **CÓMO FUNCIONA:**
/// Integra el diagrama de flujo interactivo _PersonalizationStudioDiagram, botones de acción rápida
/// y la lista de tarjetas _PersonaExampleCard con adición de respuestas y expansión inline.
///
/// **POR QUÉ:**
/// Ofrece una interfaz conversacional limpia y humana según la especificación del usuario,
/// manteniendo el código modular, mantenible y estrictamente menor a 200 líneas.
class _PersonalizationStudioExamplesTab extends StatelessWidget {
  final List<PersonaExample> examples;
  final bool canEdit;
  final VoidCallback onAddPhrase;
  final VoidCallback onAddTemplate;
  final ValueChanged<PersonaExample> onEditExample;
  final ValueChanged<PersonaExample> onAddResponse;
  final ValueChanged<PersonaExample> onDeleteExample;
  final void Function(PersonaExample, bool) onToggleExample;
  final VoidCallback? onLoadMore;

  const _PersonalizationStudioExamplesTab({
    required this.examples,
    required this.canEdit,
    required this.onAddPhrase,
    required this.onAddTemplate,
    required this.onEditExample,
    required this.onAddResponse,
    required this.onDeleteExample,
    required this.onToggleExample,
    this.onLoadMore,
  });

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 90),
      children: [
        _PersonalizationStudioDiagram(totalExamples: examples.length),
        Row(
          children: [
            Expanded(
              child: FilledButton.icon(
                onPressed: !canEdit ? null : onAddPhrase,
                icon: const Icon(Icons.add_circle_outline, size: 14),
                label: const Text('+ Agregar frase', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF00E676),
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
              ),
            ),
            const SizedBox(width: 6),
            OutlinedButton.icon(
              onPressed: !canEdit ? null : onAddTemplate,
              icon: const Icon(Icons.view_quilt_outlined, size: 14),
              label: const Text('Plantilla', style: TextStyle(fontSize: 11)),
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: Color(0x33FFFFFF)),
                padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        if (examples.isEmpty)
          const Padding(
            padding: EdgeInsets.all(16),
            child: Center(
              child: Text(
                'Sin frases aprendidas. Pulsa "+ Agregar frase" para definir tu primera intención con múltiples respuestas.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 11, color: Colors.grey),
              ),
            ),
          ),
        for (final example in examples)
          _PersonaExampleCard(
            example: example,
            canEdit: canEdit,
            onToggleEnabled: (v) => onToggleExample(example, v),
            onEdit: () => onEditExample(example),
            onAddResponse: () => onAddResponse(example),
            onDelete: () => onDeleteExample(example),
          ),
        if (examples.length >= 100 && onLoadMore != null)
          TextButton(
            onPressed: !canEdit ? null : onLoadMore,
            child: const Text('Cargar más frases', style: TextStyle(fontSize: 11)),
          ),
      ],
    );
  }
}
