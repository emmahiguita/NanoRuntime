part of 'personalization_studio_screen.dart';

/// Composicion visual extraida: conserva acciones y estado existentes.
extension _StudioDiagramView on _PersonalizationStudioDiagramState {
  Widget _buildDiagram(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: const Color(0x0F00E676),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0x3300E676), width: 0.8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: () => setState(() => _expanded = !_expanded),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
              child: Row(
                children: [
                  const Icon(
                    Icons.account_tree_rounded,
                    size: 13,
                    color: Color(0xFF00E676),
                  ),
                  const SizedBox(width: 6),
                  const Expanded(
                    child: Text(
                      'DIAGRAMA DE FLUJO · ARQUITECTURA EMMA',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.3,
                        color: Color(0xFF00E676),
                      ),
                    ),
                  ),
                  Text(
                    _expanded ? 'Ocultar' : 'Ver flujo',
                    style: const TextStyle(fontSize: 9.5, color: Colors.white60),
                  ),
                  Icon(
                    _expanded ? Icons.keyboard_arrow_up_rounded : Icons.keyboard_arrow_down_rounded,
                    size: 14,
                    color: Colors.white60,
                  ),
                ],
              ),
            ),
          ),
          if (_expanded) ...[
            const Divider(height: 1, color: Color(0x1800E676)),
            Padding(
              padding: const EdgeInsets.all(8),
              child: Column(
                children: [
                  Row(
                    children: [
                      _node(
                        '1',
                        'ENTRADA',
                        'Disparador',
                        Icons.mark_chat_unread_outlined,
                        const Color(0xFF00D2FF),
                      ),
                      _arrow(),
                      _node(
                        '2',
                        'EMMA IA',
                        'Contexto',
                        Icons.psychology_rounded,
                        const Color(0xFFCE93D8),
                      ),
                      _arrow(),
                      _node(
                        '3',
                        'ROTACIÓN',
                        '1 de N',
                        Icons.casino_outlined,
                        const Color(0xFFFFD54F),
                      ),
                      _arrow(),
                      _node(
                        '4',
                        'SALIDA',
                        'WhatsApp',
                        Icons.send_rounded,
                        const Color(0xFF00E676),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0x0CFFFFFF),
                      borderRadius: BorderRadius.circular(7),
                      border: Border.all(
                        color: const Color(0x1FFFFFFF),
                        width: 0.7,
                      ),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.play_circle_outline_rounded,
                          size: 12,
                          color: Color(0xFFFFD54F),
                        ),
                        const SizedBox(width: 5),
                        Expanded(
                          child: Text(
                            'Turno ${_simIndex + 1}: "${_PersonalizationStudioDiagramState._sims[_simIndex]}"',
                            style: const TextStyle(
                              fontSize: 9.5,
                              fontStyle: FontStyle.italic,
                              color: Colors.white70,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        InkWell(
                          borderRadius: BorderRadius.circular(4),
                          onTap: () => setState(
                            () => _simIndex = (_simIndex + 1) % _PersonalizationStudioDiagramState._sims.length,
                          ),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 5,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0x22FFD54F),
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(
                                color: const Color(0x66FFD54F),
                                width: 0.6,
                              ),
                            ),
                            child: const Text(
                              'Probar 🎲',
                              style: TextStyle(
                                fontSize: 8,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFFFFD54F),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

}
