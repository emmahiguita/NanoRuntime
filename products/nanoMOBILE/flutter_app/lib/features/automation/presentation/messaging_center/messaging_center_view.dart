/// MESSAGING-CENTER-VIEW — Vista principal unificada del Centro de Mensajería.
///
/// **QUÉ HACE:**
/// Orquesta la interfaz de usuario del Centro de Mensajería: encabezado, apps conectadas,
/// barra de búsqueda, estado de listener y conmutación entre conversaciones y contactos.
///
/// **CÓMO FUNCIONA:**
/// Compone componentes especializados ([MessagingAppsBar], [MessagingSearchBar],
/// [MessagingFilterChips], [MessagingConversationsView] y [MessagingContactsView])
/// delegando la lógica de presentación a submódulos de responsabilidad única.
///
/// **POR QUÉ:**
/// Implementa Clean Architecture y principios SOLID asegurando que cada componente
/// sea modular, testeable y menor a 200 líneas de código.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/services/nano_runtime_api.dart';
import '../../../../core/theme/design_tokens.dart';
import '../../domain/messaging_platform.dart';
import 'messaging_apps_bar.dart';
import 'messaging_center_banners.dart';
import 'messaging_center_header.dart';
import 'messaging_center_providers.dart';
import 'messaging_contacts_view.dart';
import 'messaging_conversations_view.dart';
import 'messaging_filter_chips.dart';
import 'messaging_search_bar.dart';

class MessagingCenterView extends ConsumerWidget {
  const MessagingCenterView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final accessAsync = ref.watch(notificationAccessProvider);
    final currentTab = ref.watch(selectedCategoryTabProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 1. Header principal estilizado
        const MessagingCenterHeader(),
        const SizedBox(height: NanoSpacing.lg),

        // 2. Fila horizontal de selección de apps
        const MessagingAppsBar(),
        const SizedBox(height: NanoSpacing.md),

        // 3. Barra de búsqueda rápida
        const MessagingSearchBar(),
        const SizedBox(height: NanoSpacing.md),

        // 4. Banner de estado de conexión del listener de notificaciones
        accessAsync.when(
          data: (status) {
            if (!status.accessGranted) {
              return MessagingPermissionBanner(
                icon: Icons.notifications_off_rounded,
                color: const Color(0xFFFF6B35),
                title: 'Permiso de Notificaciones requerido',
                subtitle: 'NanoAI necesita acceso para leer y responder mensajes en segundo plano.',
                actionLabel: 'Conceder permiso',
                onAction: () async {
                  await NanoRuntimeApi.instance.openNotificationAccessSettings();
                  ref.invalidate(notificationAccessProvider);
                },
              );
            }
            if (!status.connected) {
              return MessagingPermissionBanner(
                icon: Icons.link_off_rounded,
                color: const Color(0xFFFFBB00),
                title: 'Listener desconectado',
                subtitle: 'El servicio de captura de notificaciones está inactivo.',
                actionLabel: 'Reconectar',
                onAction: () async {
                  await NanoRuntimeApi.instance.openNotificationAccessSettings();
                  ref.invalidate(notificationAccessProvider);
                },
              );
            }
            return const SizedBox.shrink();
          },
          loading: () => const SizedBox.shrink(),
          error: (_, __) => const SizedBox.shrink(),
        ),

        // 5. Filtros de categorías (Todos, No leídos, Personal, Negocios, Contactos)
        const MessagingFilterChips(),
        const SizedBox(height: NanoSpacing.md),

        // 6. Contenido dinámico según la pestaña activa
        currentTab == MessagingCategoryFilter.contacts
            ? const MessagingContactsView()
            : const MessagingConversationsView(),
      ],
    );
  }
}
