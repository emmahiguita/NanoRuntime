part of 'chat_screen.dart';

// chat_screen_history_view.part.dart — Vista de lista y tarjetas de sesiones guardadas localmente.
// QUÉ HACE: Renderiza la lista cronológica de turnos del usuario y respuestas guardadas.
// CÓMO FUNCIONA: Usa tarjetas Liquid Glass con iconografía Cupertino y restaura el prompt seleccionado.
// POR QUÉ: Aplica principios SOLID dividiendo la lista de la hoja modal, manteniendo el archivo conciso (< 190 líneas).

class _HistoryListView extends StatelessWidget {
  final List<ChatMessage> messages;
  final NanoColors colors;
  final bool isDark;
  final ValueChanged<String> onSelectPrompt;

  const _HistoryListView({
    required this.messages,
    required this.colors,
    required this.isDark,
    required this.onSelectPrompt,
  });

  @override
  Widget build(BuildContext context) {
    if (messages.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 58,
                height: 58,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: colors.surface.withValues(
                    alpha: isDark ? 0.35 : 0.60,
                  ),
                  border: Border.all(
                    color: colors.outlineVariant.withValues(alpha: 0.25),
                    width: 0.8,
                  ),
                ),
                child: Center(
                  child: Icon(
                    CupertinoIcons.chat_bubble_2,
                    size: 26,
                    color: colors.onSurface.withValues(alpha: 0.65),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'No hay conversaciones registradas',
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: colors.onSurface.withValues(alpha: 0.85),
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Tus conversaciones se guardan de forma privada y cifrada en tu almacenamiento local.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 12.5,
                  color: colors.onSurface.withValues(alpha: 0.50),
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
      );
    }

    final userTurns = <int>[];
    for (var i = 0; i < messages.length; i++) {
      if (messages[i].sender == MessageSender.user) {
        userTurns.add(i);
      }
    }

    return ListView.builder(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      itemCount: userTurns.length,
      itemBuilder: (context, idx) {
        final uIdx = userTurns[idx];
        final userMsg = messages[uIdx];
        final aiMsg =
            (uIdx + 1 < messages.length &&
                messages[uIdx + 1].sender == MessageSender.ai)
            ? messages[uIdx + 1]
            : null;

        return Container(
          margin: const EdgeInsets.only(bottom: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            color: colors.surface.withValues(alpha: isDark ? 0.28 : 0.45),
            border: Border.all(
              color: colors.outlineVariant.withValues(
                alpha: isDark ? 0.25 : 0.18,
              ),
              width: 0.7,
            ),
          ),
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 14,
              vertical: 6,
            ),
            leading: Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: colors.accent.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: colors.accent.withValues(alpha: 0.25),
                  width: 0.7,
                ),
              ),
              child: Center(
                child: Icon(
                  CupertinoIcons.chat_bubble_text_fill,
                  color: colors.accent,
                  size: 16,
                ),
              ),
            ),
            title: Text(
              userMsg.text,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 13.5,
                fontWeight: FontWeight.w600,
                color: colors.onSurface,
              ),
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (aiMsg != null) ...[
                  const SizedBox(height: 3),
                  Text(
                    aiMsg.text,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 12,
                      color: colors.onSurface.withValues(alpha: 0.65),
                    ),
                  ),
                ],
                const SizedBox(height: 4),
                Row(
                  children: [
                    Icon(
                      CupertinoIcons.clock,
                      size: 11,
                      color: colors.onSurface.withValues(alpha: 0.4),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '${userMsg.timestamp.hour.toString().padLeft(2, '0')}:${userMsg.timestamp.minute.toString().padLeft(2, '0')} · ${userMsg.timestamp.day}/${userMsg.timestamp.month}/${userMsg.timestamp.year}',
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 10.5,
                        color: colors.onSurface.withValues(alpha: 0.45),
                      ),
                    ),
                  ],
                ),
              ],
            ),
            trailing: Icon(
              CupertinoIcons.chevron_right,
              size: 14,
              color: colors.onSurface.withValues(alpha: 0.35),
            ),
            onTap: () => onSelectPrompt(userMsg.text),
          ),
        );
      },
    );
  }
}