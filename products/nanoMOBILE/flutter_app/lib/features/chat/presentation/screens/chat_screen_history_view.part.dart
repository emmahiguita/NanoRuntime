part of 'chat_screen.dart';

// QUÉ HACE:
// Vista de lista y tarjetas de elementos del historial de conversaciones guardadas en Nano AI.
//
// CÓMO FUNCIONA:
// - Filtra los turnos iniciados por el usuario y los asocia a sus respuestas de IA.
// - Presenta avatares, marcas de tiempo y fragmentos de texto en tarjetas estilizadas de vidrio.
// - Al pulsar una tarjeta, restaura el prompt en el campo de texto y enfoca el teclado.
//
// POR QUÉ:
// Aplica principios SOLID dividiendo la vista de lista de la hoja modal principal,
// manteniendo el código modular, legible y menor a 150 líneas.
class _HistoryListView extends StatelessWidget {
  final List<ChatMessage> messages;
  final ScrollController scrollCtrl;
  final NanoColors colors;
  final bool isDark;
  final ValueChanged<String> onSelectPrompt;

  const _HistoryListView({
    required this.messages,
    required this.scrollCtrl,
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
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      colors.glassPrimary.withValues(alpha: 0.85),
                      colors.glassSurface.withValues(alpha: 0.40),
                    ],
                  ),
                  border: Border.all(
                    color: colors.onSurface.withValues(alpha: 0.15),
                    width: 1.0,
                  ),
                ),
                child: Center(
                  child: Icon(
                    Icons.history_rounded,
                    size: 28,
                    color: colors.onSurface.withValues(alpha: 0.70),
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
                  color: colors.onSurface.withValues(alpha: 0.8),
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Tus conversaciones se guardan de forma privada y cifrada en tu almacenamiento local.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 12.5,
                  color: colors.onSurface.withValues(alpha: 0.5),
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
      controller: scrollCtrl,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      itemCount: userTurns.length,
      itemBuilder: (context, idx) {
        final uIdx = userTurns[idx];
        final userMsg = messages[uIdx];
        final aiMsg = (uIdx + 1 < messages.length &&
                messages[uIdx + 1].sender == MessageSender.ai)
            ? messages[uIdx + 1]
            : null;

        return Container(
          margin: const EdgeInsets.only(bottom: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            color: isDark ? const Color(0x331E293B) : const Color(0x0C000000),
            border: Border.all(
              color: isDark
                  ? Colors.white.withValues(alpha: 0.08)
                  : Colors.black.withValues(alpha: 0.06),
            ),
          ),
          child: ListTile(
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            leading: CircleAvatar(
              radius: 17,
              backgroundColor: colors.accent.withValues(alpha: 0.14),
              child: Icon(
                Icons.chat_bubble_outline_rounded,
                color: colors.accent,
                size: 16,
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
                      Icons.access_time_rounded,
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
            onTap: () => onSelectPrompt(userMsg.text),
          ),
        );
      },
    );
  }
}
