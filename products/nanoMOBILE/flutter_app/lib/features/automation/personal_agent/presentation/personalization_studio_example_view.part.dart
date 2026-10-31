part of 'personalization_studio_screen.dart';

/// Composicion visual extraida: conserva acciones y estado existentes.
extension _StudioExampleView on _PersonaExampleCardState {
  Widget _buildExample(BuildContext context) {
    final ex = widget.example;
    final isEn = ex.enabled;
    final title = ex.displayTrigger;
    final category = ex.category;
    final storedTag = ConversationSemanticTag.fromStorageKey(ex.intent);
    final semanticTag = storedTag == ConversationSemanticTag.conversation
        ? ConversationSemanticClassifier.classify(ex.incomingText)
        : storedTag;
    final responses = ex.responseOptions;
    final total = responses.length;
    final visibleCount = _expanded ? total : (total > 3 ? 3 : total);

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: isEn ? const Color(0x1800E676) : const Color(0x0AFFFFFF),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isEn ? const [Color(0x1E00E676), Color(0x0800E676)] : const [Color(0x12FFFFFF), Color(0x05FFFFFF)],
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: isEn ? const Color(0x6000E676) : const Color(0x20FFFFFF), width: 0.8),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        ConversationSemanticBadge(tag: semanticTag, compact: true),
                        const SizedBox(width: 5),
                        Expanded(
                          child: Text(
                            '$category · $total ${total == 1 ? 'respuesta' : 'respuestas'}',
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 9.5,
                              color: Color(0xFF00E676),
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              SizedBox(
                height: 20,
                child: Switch(
                  value: isEn,
                  activeTrackColor: const Color(0xFF00E676),
                  onChanged: widget.canEdit ? widget.onToggleEnabled : null,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          for (int i = 0; i < visibleCount; i++)
            Padding(
              padding: const EdgeInsets.only(bottom: 2.5),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Padding(
                    padding: EdgeInsets.only(top: 3, right: 5),
                    child: Text(
                      '•',
                      style: TextStyle(color: Color(0xFF00E676), fontSize: 11, fontWeight: FontWeight.bold),
                    ),
                  ),
                  Expanded(
                    child: Text(
                      '“${responses[i].text}”',
                      style: TextStyle(
                        fontSize: 10.5,
                        height: 1.25,
                        color: responses[i].enabled
                            ? Colors.white.withValues(alpha: 0.88)
                            : Colors.white38,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ),
                  if (responses[i].tone.isNotEmpty &&
                      responses[i].tone != 'cotidiana')
                    Container(
                      margin: const EdgeInsets.only(left: 4),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 4,
                        vertical: 1,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0x1800D2FF),
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(
                          color: const Color(0x4000D2FF),
                          width: 0.5,
                        ),
                      ),
                      child: Text(
                        responses[i].tone,
                        style: const TextStyle(
                          fontSize: 7.5,
                          color: Color(0xFF00D2FF),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          if (total > 3)
            InkWell(
              borderRadius: BorderRadius.circular(4),
              onTap: () => setState(() => _expanded = !_expanded),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Text(
                  _expanded ? '▲ Mostrar menos' : '+${total - 3} más',
                  style: const TextStyle(
                    fontSize: 9.5,
                    color: Color(0xFFFFD54F),
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          const SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              _btn(
                'Editar',
                Icons.edit_outlined,
                const Color(0xFF81C784),
                widget.canEdit ? widget.onEdit : null,
              ),
              const SizedBox(width: 8),
              _btn(
                '+ Respuesta',
                Icons.add_circle_outline,
                const Color(0xFF00D2FF),
                widget.canEdit ? widget.onAddResponse : null,
              ),
              const SizedBox(width: 8),
              _btn(
                'Eliminar',
                Icons.delete_outline,
                const Color(0xFFE57373),
                widget.canEdit ? widget.onDelete : null,
              ),
            ],
          ),
        ],
      ),
    );
  }

}
