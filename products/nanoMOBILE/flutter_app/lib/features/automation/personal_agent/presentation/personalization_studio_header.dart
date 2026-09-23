part of 'personalization_studio_screen.dart';

// personalization_studio_header.dart
//
// QUÉ HACE:
// Cabecera adaptable (Portrait/Landscape) con Material Expressive para métricas, selector de scope y acciones.
//
// CÓMO FUNCIONA:
// - Detecta orientación mediante MediaQuery:
//   * Portrait: Column ergonómica con tarjetas métricas, selector y botones de acción.
//   * Landscape: Row ultra-compacto de una sola línea para no consumir espacio vertical útil.
// - Aplica bordes orgánicos, feedback táctil y micro-pills con acentos cromáticos.
//
// POR QUÉ:
// Erradica RenderFlex overflows en modo horizontal y garantiza usabilidad móvil profesional (< 200 líneas).

class _PersonalizationStudioHeader extends StatelessWidget {
  final Map<String, dynamic> summary;
  final String scope;
  final Map<String, _Scope> scopes;
  final bool canEdit;
  final bool working;
  final ValueChanged<String> onSelectScope;
  final VoidCallback onEditStyle;
  final VoidCallback onInjectEmma;
  final VoidCallback onRefresh;

  const _PersonalizationStudioHeader({
    required this.summary,
    required this.scope,
    required this.scopes,
    required this.canEdit,
    required this.working,
    required this.onSelectScope,
    required this.onEditStyle,
    required this.onInjectEmma,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    final isLandscape = MediaQuery.of(context).orientation == Orientation.landscape;

    if (isLandscape) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(12, 4, 12, 4),
        child: Row(
          children: [
            Expanded(flex: 3, child: _buildScopeField()),
            const SizedBox(width: 8),
            Expanded(
              flex: 4,
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: !canEdit ? null : onEditStyle,
                      icon: const Icon(Icons.tune_rounded, size: 12),
                      label: const Text('Estilo', style: TextStyle(fontSize: 10)),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 6),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 4),
                  FilledButton.icon(
                    onPressed: !canEdit ? null : onInjectEmma,
                    icon: const Icon(Icons.auto_awesome, size: 11),
                    label: const Text('EMMA', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 6),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                  ),
                  const SizedBox(width: 4),
                  Semantics(
                    label: 'Actualizar',
                    child: IconButton(
                      onPressed: working ? null : onRefresh,
                      icon: const Icon(Icons.refresh, size: 16),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0x0EFFFFFF),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0x22FFFFFF), width: 0.8),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _metricPill('FRASES', '${summary['examples'] ?? 0}', Icons.forum_rounded, const Color(0xFF00E676)),
                  const SizedBox(width: 8),
                  _metricPill('CONTACTOS', '${summary['contacts'] ?? 0}', Icons.people_alt_rounded, const Color(0xFF00D2FF)),
                  const SizedBox(width: 8),
                  _metricPill('MEMORIAS', '${summary['memories'] ?? 0}', Icons.psychology_rounded, const Color(0xFFFFD54F)),
                  const SizedBox(width: 8),
                  _metricPill('PLANTILLAS', '${summary['templates'] ?? 0}', Icons.view_quilt_rounded, const Color(0xFFCE93D8)),
                ],
              ),
            ),
          ],
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 6, 12, 4),
      child: Column(
        children: [
          Container(
            margin: const EdgeInsets.only(bottom: 6),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: const Color(0x0EFFFFFF),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0x22FFFFFF), width: 0.8),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _metricPill('FRASES', '${summary['examples'] ?? 0}', Icons.forum_rounded, const Color(0xFF00E676)),
                _metricPill('CONTACTOS', '${summary['contacts'] ?? 0}', Icons.people_alt_rounded, const Color(0xFF00D2FF)),
                _metricPill('MEMORIAS', '${summary['memories'] ?? 0}', Icons.psychology_rounded, const Color(0xFFFFD54F)),
                _metricPill('PLANTILLAS', '${summary['templates'] ?? 0}', Icons.view_quilt_rounded, const Color(0xFFCE93D8)),
              ],
            ),
          ),
          _buildScopeField(),
          const SizedBox(height: 6),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: !canEdit ? null : onEditStyle,
                  icon: const Icon(Icons.tune_rounded, size: 13),
                  label: const Text('Configurar estilo', style: TextStyle(fontSize: 10.5)),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Color(0x33FFFFFF)),
                    padding: const EdgeInsets.symmetric(vertical: 7, horizontal: 8),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                ),
              ),
              const SizedBox(width: 6),
              FilledButton.icon(
                onPressed: !canEdit ? null : onInjectEmma,
                icon: const Icon(Icons.auto_awesome, size: 12.5),
                label: const Text('Diálogos EMMA', style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold)),
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0x2B00E676),
                  foregroundColor: const Color(0xFF00E676),
                  padding: const EdgeInsets.symmetric(vertical: 7, horizontal: 8),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                    side: const BorderSide(color: Color(0x6000E676)),
                  ),
                ),
              ),
              const SizedBox(width: 4),
              Semantics(
                label: 'Actualizar',
                child: IconButton(
                  onPressed: working ? null : onRefresh,
                  icon: const Icon(Icons.refresh, size: 18),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildScopeField() {
    final effectiveValue = scopes.containsKey(scope) ? scope : (scopes.keys.firstOrNull ?? 'owner');
    return InputDecorator(
      decoration: InputDecoration(
        labelText: 'APLICAR PERFIL A:',
        labelStyle: const TextStyle(fontSize: 9, fontWeight: FontWeight.bold, letterSpacing: 0.4, color: Color(0xFF00E676)),
        filled: true,
        fillColor: const Color(0x0EFFFFFF),
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0x22FFFFFF), width: 0.8)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0x22FFFFFF), width: 0.8)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0x8000E676), width: 0.8)),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: effectiveValue,
          isExpanded: true,
          isDense: true,
          dropdownColor: const Color(0xFF162036),
          style: const TextStyle(fontSize: 11, color: Colors.white),
          items: [
            for (final item in scopes.values)
              DropdownMenuItem(
                value: item.id,
                child: Text(item.label, style: const TextStyle(fontSize: 10.5), overflow: TextOverflow.ellipsis),
              ),
          ],
          onChanged: working ? null : (v) { if (v != null) onSelectScope(v); },
        ),
      ),
    );
  }

  Widget _metricPill(String label, String value, IconData icon, Color color) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 9.5, color: color),
            const SizedBox(width: 3),
            Text(value, style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: color)),
          ],
        ),
        Text(label, style: const TextStyle(fontSize: 8, color: Colors.white54, letterSpacing: 0.3, fontWeight: FontWeight.w600)),
      ],
    );
  }
}
