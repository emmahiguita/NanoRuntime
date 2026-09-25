import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/messaging_platform.dart';
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
              color: const Color(0xFF00FF88).withValues(alpha: 0.08),
              shape: BoxShape.circle,
              border: Border.all(
                color: const Color(0xFF00FF88).withValues(alpha: 0.2),
              ),
            ),
            child: const Center(
              child: Icon(
                Icons.mark_chat_unread_rounded,
                size: 32,
                color: Color(0xFF00FF88),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            archived ? 'Sin conversaciones archivadas' : 'Sin mensajes activos',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 17,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            archived
                ? 'Las conversaciones que archives en Nano aparecerán aquí.'
                : 'Los chats observados desde las notificaciones reales aparecerán aquí.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.5),
              fontSize: 13,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 20),
          TextButton.icon(
            onPressed: () {
              ref.invalidate(liveNotificationsProvider);
              ref.invalidate(allHubConversationsProvider);
              ref.invalidate(archivedConversationIdsProvider);
            },
            icon: const Icon(
              Icons.refresh_rounded,
              size: 16,
              color: Color(0xFF00FF88),
            ),
            label: const Text(
              'Actualizar',
              style: TextStyle(
                color: Color(0xFF00FF88),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
