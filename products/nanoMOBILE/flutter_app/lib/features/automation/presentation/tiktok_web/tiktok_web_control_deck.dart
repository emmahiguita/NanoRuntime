// tiktok_web_control_deck.dart
//
// QUÉ HACE: barra inferior de control de la bandeja TikTok: accesos rápidos a
//   conversaciones reales, estado del bridge y campo de respuesta.
// CÓMO FUNCIONA: recibe datos ya parseados por el adapter y devuelve acciones
//   por callbacks (sin conocer WebView ni scripts — DIP).
// POR QUÉ: separar el deck de la pantalla mantiene ambos widgets bajo 200
//   líneas y permite rediseñar la barra sin tocar el ciclo de vida del WebView.

import 'package:flutter/material.dart';

import 'tiktok_web_types.dart';

class TikTokWebControlDeck extends StatelessWidget {
  const TikTokWebControlDeck({
    super.key,
    required this.conversations,
    required this.activeChatName,
    required this.busy,
    required this.composer,
    required this.statusText,
    required this.onRefreshConversations,
    required this.onOpenConversation,
    required this.onBackToList,
    required this.onSend,
  });

  final List<TikTokConversation> conversations;
  final String? activeChatName;
  final bool busy;
  final TextEditingController composer;
  final String? statusText;
  final Future<void> Function() onRefreshConversations;
  final Future<void> Function(int index) onOpenConversation;
  final Future<void> Function() onBackToList;
  final Future<void> Function(String text) onSend;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return SafeArea(
      top: false,
      child: Container(
        color: isDark ? const Color(0xF20F172A) : const Color(0xF2FFFFFF),
        padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Cabecera: volver a la lista + chat activo + estado + refresco
            Row(
              children: [
                if (activeChatName != null)
                  IconButton(
                    tooltip: 'Volver a la lista',
                    visualDensity: VisualDensity.compact,
                    onPressed: busy ? null : onBackToList,
                    icon: const Icon(Icons.arrow_back, size: 20),
                  )
                else
                  Icon(Icons.forum_outlined, size: 16, color: scheme.primary),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    activeChatName == null
                        ? 'Bandeja TikTok · ${conversations.length} chats'
                        : 'Escribiendo a $activeChatName',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                      color: isDark ? Colors.white : const Color(0xFF0F172A),
                    ),
                  ),
                ),
                if (statusText != null) ...[
                  Flexible(
                    child: Text(
                      statusText!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 11, color: scheme.primary),
                    ),
                  ),
                  const SizedBox(width: 6),
                ],
                IconButton(
                  tooltip: 'Actualizar bandeja',
                  visualDensity: VisualDensity.compact,
                  onPressed: busy ? null : onRefreshConversations,
                  icon: busy
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.refresh, size: 20),
                ),
              ],
            ),
            // Accesos rápidos: una chip por conversación real de la bandeja
            if (conversations.isNotEmpty)
              SizedBox(
                height: 40,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: conversations.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 6),
                  itemBuilder: (context, i) {
                    final chat = conversations[i];
                    return ActionChip(
                      visualDensity: VisualDensity.compact,
                      avatar: chat.hasUnread
                          ? CircleAvatar(
                              radius: 8,
                              backgroundColor: scheme.primary,
                              child: Text(
                                '${chat.unread}',
                                style: const TextStyle(
                                  fontSize: 8.5,
                                  color: Colors.white,
                                ),
                              ),
                            )
                          : const Icon(Icons.person_outline, size: 14),
                      label: Text(
                        chat.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      onPressed: busy ? null : () => onOpenConversation(chat.index),
                    );
                  },
                ),
              ),
            const SizedBox(height: 6),
            // Respuesta: campo + envío (Enter del teclado también envía)
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: composer,
                    enabled: !busy,
                    minLines: 1,
                    maxLines: 3,
                    textInputAction: TextInputAction.send,
                    onSubmitted: (text) {
                      final clean = text.trim();
                      if (clean.isNotEmpty) onSend(clean);
                    },
                    decoration: InputDecoration(
                      isDense: true,
                      hintText: 'Responder en TikTok…',
                      hintStyle: const TextStyle(fontSize: 13),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                IconButton.filled(
                  tooltip: 'Enviar respuesta',
                  onPressed: busy
                      ? null
                      : () {
                          final clean = composer.text.trim();
                          if (clean.isNotEmpty) onSend(clean);
                        },
                  icon: const Icon(Icons.send_rounded, size: 18),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
