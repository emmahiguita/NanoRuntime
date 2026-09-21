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
              border: Border.all(color: const Color(0xFF00FF88).withValues(alpha: 0.2)),
            ),
            child: const Center(
              child: Icon(Icons.mark_chat_unread_rounded, size: 32, color: Color(0xFF00FF88)),
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'Sin mensajes activos',
            style: TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 6),
          Text(
            'Cuando recibas mensajes de WhatsApp, Telegram u otras apps, aparecerán aquí en tiempo real.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.white.withValues(alpha: 0.5), fontSize: 13, height: 1.4),
          ),
          const SizedBox(height: 20),
          TextButton.icon(
            onPressed: () {
              ref.read(selectedPlatformFilterProvider.notifier).state = null;
              ref.read(selectedCategoryTabProvider.notifier).state = MessagingCategoryFilter.all;
              ref.read(messagingSearchQueryProvider.notifier).state = '';
              ref.invalidate(liveNotificationsProvider);
              ref.invalidate(allHubConversationsProvider);
            },
            icon: const Icon(Icons.refresh_rounded, size: 16, color: Color(0xFF00FF88)),
            label: const Text(
              'Actualizar',
              style: TextStyle(color: Color(0xFF00FF88), fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}
