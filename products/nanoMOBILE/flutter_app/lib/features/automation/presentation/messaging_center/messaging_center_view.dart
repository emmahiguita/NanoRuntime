/// MESSAGING-CENTER-VIEW — Vista principal unificada del Centro de Mensajería.
///
/// **QUÉ HACE:**
/// Orquesta la interfaz de usuario del Centro de Mensajería: encabezado, apps conectadas,
/// barra de búsqueda, estado de listener y conmutación entre conversaciones y contactos.
///
/// **CÓMO FUNCIONA:**
/// Implementa [WidgetsBindingObserver] para invalidar automáticamente [allHubConversationsProvider]
/// al detectar [AppLifecycleState.resumed], refrescando SQLite sin tener que cerrar la app.
///
/// **POR QUÉ:**
/// Elimina el bug donde los mensajes recibidos en background no aparecían en el hub al volver.
/// Cumple principios SOLID (SRP), arquitectura limpia y límite estricto de < 200 líneas.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/services/nano_runtime_api.dart';
import '../../../../core/theme/design_tokens.dart';
import '../../../../core/widgets/navigation/nano_nav_constants.dart';
import '../../domain/messaging_platform.dart';
import '../../engine/business/business_facts_providers.dart';
import '../business/business_document_library_dialog.dart';
import 'messaging_apps_bar.dart';
import 'messaging_center_banners.dart';
import 'messaging_center_header.dart';
import 'messaging_error_card.dart';
import 'messaging_center_providers.dart';
import 'messaging_contacts_view.dart';
import 'messaging_conversations_view.dart';
import 'messaging_filter_chips.dart';
import 'messaging_search_bar.dart';
import 'notification_history_provider.dart';

class MessagingCenterView extends ConsumerStatefulWidget {
  const MessagingCenterView({super.key});

  @override
  ConsumerState<MessagingCenterView> createState() =>
      _MessagingCenterViewState();
}

class _MessagingCenterViewState extends ConsumerState<MessagingCenterView>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Al volver de segundo plano (resumed), invalidamos la lista para recargar de SQLite.
    if (state == AppLifecycleState.resumed) {
      ref.invalidate(notificationHistoryConversationsProvider);
      ref.invalidate(allHubConversationsProvider);
      ref.invalidate(notificationAccessProvider);
    }
  }

  @override
  Widget build(BuildContext context) {
    final accessAsync = ref.watch(notificationAccessProvider);
    final currentTab = ref.watch(selectedCategoryTabProvider);
    final businessFacts = ref.watch(businessFactsNotifierProvider);
    final isLandscape =
        MediaQuery.orientationOf(context) == Orientation.landscape;
    final bottomReserve =
        isLandscape
            ? kNanoBarScrollReserveLandscape
            : kNanoBarScrollReserve;

    return CustomScrollView(
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      slivers: [
        SliverPadding(
          padding: EdgeInsets.fromLTRB(
            NanoSpacing.md,
            isLandscape ? NanoSpacing.xs : NanoSpacing.md,
            NanoSpacing.md,
            0,
          ),
          sliver: SliverList(
            delegate: SliverChildListDelegate([
              // 1. Header principal estilizado
              MessagingCenterHeader(
                onOpenLibrary:
                    () => BusinessDocumentLibraryDialog.show(
                      context,
                      businessFacts,
                    ),
              ),
              const SizedBox(height: NanoSpacing.md),

              // 2. Fila horizontal de selección de apps
              const MessagingAppsBar(),
              const SizedBox(height: NanoSpacing.sm),

              // 3. Barra de búsqueda rápida
              const MessagingSearchBar(),
              const SizedBox(height: NanoSpacing.sm),

              // 4. Banner de estado de conexión del listener de notificaciones
              accessAsync.when(
                data: (status) {
                  if (!status.accessGranted) {
                    return MessagingPermissionBanner(
                      icon: Icons.notifications_off_rounded,
                      color: const Color(0xFFFF6B35),
                      title: 'Permiso de Notificaciones requerido',
                      subtitle:
                          'NanoAI necesita acceso para leer y responder mensajes en segundo plano.',
                      actionLabel: 'Conceder permiso',
                      onAction: () async {
                        await NanoRuntimeApi.instance
                            .openNotificationAccessSettings();
                        ref.invalidate(notificationAccessProvider);
                      },
                    );
                  }
                  if (!status.connected) {
                    return MessagingPermissionBanner(
                      icon: Icons.link_off_rounded,
                      color: const Color(0xFFFFBB00),
                      title: 'Listener desconectado',
                      subtitle:
                          'El servicio de captura de notificaciones está inactivo.',
                      actionLabel: 'Reconectar',
                      onAction: () async {
                        await NanoRuntimeApi.instance
                            .openNotificationAccessSettings();
                        ref.invalidate(notificationAccessProvider);
                      },
                    );
                  }
                  return const SizedBox.shrink();
                },
                loading: () => const SizedBox.shrink(),
                error:
                    (error, _) => MessagingErrorCard(
                      error: error,
                      onRetry:
                          () => ref.invalidate(notificationAccessProvider),
                    ),
              ),

              // 5. Filtros de categorías (Todos, No leídos, Personal, Negocios, Contactos)
              const MessagingFilterChips(),
              const SizedBox(height: NanoSpacing.sm),
            ]),
          ),
        ),
        currentTab == MessagingCategoryFilter.contacts
            ? const MessagingContactsView()
            : const MessagingConversationsView(),
        SliverToBoxAdapter(child: SizedBox(height: bottomReserve)),
      ],
    );
  }
}
