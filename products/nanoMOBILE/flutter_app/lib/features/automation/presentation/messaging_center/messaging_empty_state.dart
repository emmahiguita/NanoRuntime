import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/design_tokens.dart';
import '../../domain/messaging_platform.dart';
import 'notification_history_provider.dart'
    show notificationHistoryConversationsProvider;
import 'messaging_center_providers.dart';

/// [MessagingEmptyState]
///
/// QUÉ HACE:
/// Despliega el estado vacío limpio y honesto cuando no hay mensajes recibidos
/// ni conversaciones activas registradas en los filtros seleccionados.
///
/// CÓMO FUNCIONA:
/// Muestra un icono estético de mensajería con brillo sutil y un botón de "Actualizar"
/// que resetea los filtros de búsqueda y categoría para refrescar el stream de Android.
///
/// POR QUÉ:
/// Desacopla la lógica de visualización del estado vacío para mantener los componentes
/// modulares (< 200 líneas) conforme al principio de responsabilidad única.
class MessagingEmptyState extends ConsumerWidget {
  const MessagingEmptyState({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final archived =
        ref.watch(selectedCategoryTabProvider) ==
        MessagingCategoryFilter.archived;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final colors = NanoThemeExtension.of(context).colors;
    final accentColor = isDark ? const Color(0xFF00FF88) : colors.primary;

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 20),
      alignment: Alignment.center,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: accentColor.withValues(alpha: isDark ? 0.08 : 0.10),
              shape: BoxShape.circle,
              border: Border.all(
                color: accentColor.withValues(alpha: isDark ? 0.2 : 0.35),
              ),
            ),
            child: Center(
              child: Icon(
                Icons.mark_chat_unread_rounded,
                size: 32,
                color: accentColor,
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            archived
                ? 'Sin conversaciones archivadas'
                : 'Sin conversaciones registradas',
            style: TextStyle(
              color: isDark ? Colors.white : colors.onSurface,
              fontSize: 17,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            archived
                ? 'Las conversaciones que archives en Nano aparecerán aquí.'
                : 'Nano guardará los mensajes nuevos que Android muestre en notificaciones. No se importan chats antiguos de WhatsApp.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: isDark
                  ? Colors.white.withValues(alpha: 0.5)
                  : colors.onSurfaceVariant,
              fontSize: 13,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 20),
          TextButton.icon(
            onPressed: () {
              // Recarga el archivo local y el snapshot Android; ambos alimentan la lista.
              ref.invalidate(notificationHistoryConversationsProvider);
              ref.invalidate(liveNotificationsProvider);
              ref.invalidate(allHubConversationsProvider);
              ref.invalidate(archivedConversationIdsProvider);
            },
            icon: Icon(Icons.refresh_rounded, size: 16, color: accentColor),
            label: Text(
              'Actualizar',
              style: TextStyle(color: accentColor, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}
