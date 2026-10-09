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
import 'messaging_ambient_backdrop.dart';
import 'messaging_apps_bar.dart';
import 'messaging_center_banners.dart';
import 'messaging_control_deck.dart';
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isLandscape =
        MediaQuery.orientationOf(context) == Orientation.landscape;
    final bottomReserve = isLandscape
        ? kNanoBarScrollReserveLandscape
        : kNanoBarScrollReserve;

    return Stack(
      children: [
        Positioned.fill(
          child: ColoredBox(
            color: isDark ? const Color(0xFF09111F) : const Color(0xFFF8FAFC),
          ),
        ),
        // El paisaje y su neblina terminan antes de la primera conversación.
        MessagingAmbientBackdrop(isDark: isDark),
        CustomScrollView(
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          slivers: [
            SliverPadding(
              padding: EdgeInsets.fromLTRB(
                NanoSpacing.md,
                isLandscape ? 2 : 6,
                NanoSpacing.md,
                0,
              ),
              sliver: SliverList(
                delegate: SliverChildListDelegate([
                  // 1. Encabezado iOS Glassed compacto
                  MessagingCenterHeader(
                    onOpenLibrary: () => BusinessDocumentLibraryDialog.show(
                      context,
                      businessFacts,
                    ),
                  ),
                  const SizedBox(height: 10),
                  MessagingControlDeck(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const MessagingAppsBar(),
                        const SizedBox(height: 10),
                        const MessagingSearchBar(),
                        accessAsync.when(
                          data: (status) {
                            if (!status.accessGranted) {
                              return Padding(
                                padding: const EdgeInsets.only(top: 9),
                                child: MessagingPermissionBanner(
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
                                ),
                              );
                            }
                            if (!status.connected) {
                              return Padding(
                                padding: const EdgeInsets.only(top: 9),
                                child: MessagingPermissionBanner(
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
                                ),
                              );
                            }
                            return const SizedBox.shrink();
                          },
                          loading: () => const SizedBox.shrink(),
                          error: (error, _) => Padding(
                            padding: const EdgeInsets.only(top: 9),
                            child: MessagingErrorCard(
                              error: error,
                              onRetry: () =>
                                  ref.invalidate(notificationAccessProvider),
                            ),
                          ),
                        ),
                        const SizedBox(height: 10),
                        const MessagingFilterChips(),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                ]),
              ),
            ),
            currentTab == MessagingCategoryFilter.contacts
                ? const MessagingContactsView()
                : const MessagingConversationsView(),
            SliverToBoxAdapter(child: SizedBox(height: bottomReserve)),
          ],
        ),
      ],
    );
  }
}
