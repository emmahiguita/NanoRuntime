import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/services/nano_runtime_api.dart';
import '../../../../core/theme/design_tokens.dart';
import '../../domain/messaging_platform.dart';
import '../../engine/messaging/conversation_agent.dart';
import '../../engine/messaging/conversation_hub_providers.dart';
import '../widgets/conversation_detail_sheet.dart';
import 'messaging_apps_bar.dart';
import 'messaging_center_header.dart';
import 'messaging_center_providers.dart';
import 'messaging_conversation_card.dart';
import 'messaging_filter_chips.dart';
import 'messaging_search_bar.dart';
import '../../application/whatsapp_contacts_provider.dart';
import 'whatsapp_contact_card.dart';

/// Vista principal unificada del Centro de Mensajería — datos REALES.
///
/// Jerarquía de datos (sin simulación):
/// 1. Hub history — conversaciones procesadas por el pipeline (BD SQLite).
/// 2. Live notifications — notificaciones activas de Android aún no procesadas.
/// 3. Estado vacío honesto — muestra CTA de permisos si el listener no está
///    conectado, o "sin mensajes" si está conectado pero no hay nada.
class MessagingCenterView extends ConsumerWidget {
  const MessagingCenterView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final filteredConversations = ref.watch(filteredMessagingConversationsProvider);
    final allHubAsync = ref.watch(allHubConversationsProvider);
    final liveAsync = ref.watch(liveNotificationsProvider);
    final accessAsync = ref.watch(notificationAccessProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 1. Header principal
        const MessagingCenterHeader(),
        const SizedBox(height: NanoSpacing.lg),

        // 2. Fila horizontal de Apps
        const MessagingAppsBar(),
        const SizedBox(height: NanoSpacing.md),

        // 3. Barra de búsqueda y comandos
        const MessagingSearchBar(),
        const SizedBox(height: NanoSpacing.md),

        // 4. Banner de estado de conexión (solo si hay problema)
        accessAsync.when(
          data: (status) {
            if (!status.accessGranted) {
              return _PermissionBanner(
                icon: Icons.notifications_off_rounded,
                color: const Color(0xFFFF6B35),
                title: 'Permiso de Notificaciones requerido',
                subtitle: 'NanoAI necesita acceso para leer y responder mensajes.',
                actionLabel: 'Conceder permiso',
                onAction: () async {
                  await NanoRuntimeApi.instance.openNotificationAccessSettings();
                  // Forzar refresh del estado
                  ref.invalidate(notificationAccessProvider);
                },
              );
            }
            if (!status.connected) {
              return _PermissionBanner(
                icon: Icons.link_off_rounded,
                color: const Color(0xFFFFBB00),
                title: 'Listener desconectado',
                subtitle: 'El servicio de notificaciones no está activo.',
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

        // 5. Filtro por pestañas (Todos, No leídos, etc.)
        const MessagingFilterChips(),
        const SizedBox(height: NanoSpacing.md),

        // 6. Lista de conversaciones o contactos según la pestaña activa
        ref.watch(selectedCategoryTabProvider) == MessagingCategoryFilter.contacts
            ? _buildContactsList(context, ref)
            : _buildConversationList(
                context,
                ref,
                allHubAsync: allHubAsync,
                liveAsync: liveAsync,
                filteredConversations: filteredConversations,
              ),
      ],
    );
  }

  Widget _buildConversationList(
    BuildContext context,
    WidgetRef ref, {
    required AsyncValue<List<ConversationSummaryItem>> allHubAsync,
    required AsyncValue<List<ConversationSummaryItem>> liveAsync,
    required List<ConversationSummaryItem> filteredConversations,
  }) {
    // Carga inicial
    if (allHubAsync.isLoading && liveAsync.isLoading) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(32),
          child: CircularProgressIndicator(color: Color(0xFF00FF88)),
        ),
      );
    }

    // Error en ambas fuentes
    if (allHubAsync.hasError && liveAsync.hasError) {
      return _ErrorCard(error: allHubAsync.error.toString());
    }

    // Fuente 1: historial del hub (DB SQLite — pipeline procesado)
    final hubItems = allHubAsync.value ?? const [];

    // Fuente 2: notificaciones vivas de Android
    final liveItems = liveAsync.value ?? const [];

    // Si hay filtros activos, usar conversaciones filtradas del hub
    // Si no hay filtros, combinar hub + live (deduplicar por conversationId base)
    final List<ConversationSummaryItem> itemsToShow;
    if (filteredConversations.isNotEmpty) {
      itemsToShow = filteredConversations;
    } else if (hubItems.isNotEmpty) {
      // Hub tiene historial: mostrarlo como fuente primaria de verdad
      // Complementar con live solo si no está en hub
      final hubIds = hubItems.map((i) => i.conversationId).toSet();
      final newLiveOnly = liveItems
          .where((l) => !hubIds.contains(l.conversationId.replaceFirst('live:', '')))
          .toList();
      itemsToShow = [...hubItems, ...newLiveOnly];
    } else if (liveItems.isNotEmpty) {
      // Sin historial pero hay notificaciones activas ahora
      itemsToShow = liveItems;
    } else {
      itemsToShow = const [];
    }

    if (itemsToShow.isEmpty) {
      return _buildEmptyState(context, ref);
    }

    // Sección de "EN VIVO" si tenemos live items y ningún filtro activo
    final bool showLiveBadge = liveItems.isNotEmpty && filteredConversations.isEmpty;
    final liveIds = liveItems.map((l) => l.conversationId).toSet();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (showLiveBadge && hubItems.isEmpty) ...[
          const _SectionLabel(
            icon: Icons.circle,
            iconColor: Color(0xFF00FF88),
            label: 'Activas ahora',
          ),
          const SizedBox(height: NanoSpacing.xs),
        ],
        ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: itemsToShow.length,
          itemBuilder: (context, index) {
            final item = itemsToShow[index];
            final isLive = liveIds.contains(item.conversationId);
            return MessagingConversationCard(
              item: item,
              isLive: isLive,
              onTap: () => ConversationDetailSheet.show(context, item),
            );
          },
        ),
      ],
    );
  }

  Widget _buildContactsList(BuildContext context, WidgetRef ref) {
    final hasPermissionAsync = ref.watch(contactsPermissionProvider);
    final allContactsAsync = ref.watch(allWhatsAppContactsProvider);
    final contacts = ref.watch(filteredWhatsAppContactsProvider);

    return hasPermissionAsync.when(
      data: (hasPermission) {
        if (!hasPermission) {
          return _PermissionBanner(
            icon: Icons.contacts_rounded,
            color: const Color(0xFF25D366),
            title: 'Permiso de Contactos requerido',
            subtitle: 'NanoAI necesita permiso de lectura de contactos para encontrar tus chats de WhatsApp.',
            actionLabel: 'Permitir acceso',
            onAction: () async {
              await ref.read(whatsappContactsServiceProvider).requestPermission();
              ref.invalidate(contactsPermissionProvider);
              ref.invalidate(allWhatsAppContactsProvider);
            },
          );
        }

        if (allContactsAsync.isLoading) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(32),
              child: CircularProgressIndicator(color: Color(0xFF25D366)),
            ),
          );
        }

        if (allContactsAsync.hasError) {
          return _ErrorCard(error: allContactsAsync.error.toString());
        }

        if (contacts.isEmpty) {
          return Container(
            padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 20),
            alignment: Alignment.center,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    color: const Color(0xFF25D366).withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: const Color(0xFF25D366).withValues(alpha: 0.3),
                    ),
                  ),
                  child: const Center(
                    child: Icon(
                      Icons.contact_phone_rounded,
                      size: 30,
                      color: Color(0xFF25D366),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'No se encontraron contactos de WhatsApp',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Asegúrate de tener contactos guardados con cuenta de WhatsApp en tu teléfono.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.5),
                    fontSize: 13,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 16),
                TextButton.icon(
                  onPressed: () {
                    ref.invalidate(allWhatsAppContactsProvider);
                  },
                  icon: const Icon(Icons.refresh_rounded, size: 16, color: Color(0xFF25D366)),
                  label: const Text(
                    'Actualizar contactos',
                    style: TextStyle(color: Color(0xFF25D366), fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
          );
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _SectionLabel(
              icon: Icons.people_alt_rounded,
              iconColor: const Color(0xFF25D366),
              label: '${contacts.length} Contactos de WhatsApp',
            ),
            const SizedBox(height: NanoSpacing.xs),
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: contacts.length,
              itemBuilder: (context, index) {
                final contact = contacts[index];
                return WhatsAppContactCard(
                  contact: contact,
                  onTap: () {
                    final item = ConversationSummaryItem(
                      conversationId: contact.jid,
                      displayName: contact.name,
                      packageName: contact.isBusiness ? 'com.whatsapp.w4b' : 'com.whatsapp',
                      lastMessage: contact.number.isNotEmpty ? contact.number : contact.jid,
                      lastAtMs: DateTime.now().millisecondsSinceEpoch,
                      agentId: ConversationAgentId.personal,
                    );
                    ConversationDetailSheet.show(context, item);
                  },
                );
              },
            ),
          ],
        );
      },
      loading: () => const Center(
        child: Padding(
          padding: EdgeInsets.all(32),
          child: CircularProgressIndicator(color: Color(0xFF25D366)),
        ),
      ),
      error: (e, _) => _ErrorCard(error: e.toString()),
    );
  }

  Widget _buildEmptyState(BuildContext context, WidgetRef ref) {
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
          const Text(
            'Sin mensajes activos',
            style: TextStyle(
              color: Colors.white,
              fontSize: 17,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Cuando recibas mensajes de WhatsApp, Telegram u otras apps, aparecerán aquí en tiempo real.',
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
              ref.read(selectedPlatformFilterProvider.notifier).state = null;
              ref.read(selectedCategoryTabProvider.notifier).state =
                  MessagingCategoryFilter.all;
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

// ─── Widgets de soporte ──────────────────────────────────────────────────────

class _PermissionBanner extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;
  final String actionLabel;
  final VoidCallback onAction;

  const _PermissionBanner({
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
    required this.actionLabel,
    required this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: NanoSpacing.sm),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.25), width: 1),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: color,
                    fontWeight: FontWeight.w700,
                    fontSize: 12.5,
                  ),
                ),
                Text(
                  subtitle,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.55),
                    fontSize: 11.5,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: onAction,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: color.withValues(alpha: 0.4)),
              ),
              child: Text(
                actionLabel,
                style: TextStyle(
                  color: color,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ErrorCard extends StatelessWidget {
  final String error;
  const _ErrorCard({required this.error});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(NanoSpacing.md),
      decoration: BoxDecoration(
        color: Colors.red.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.red.withValues(alpha: 0.25)),
      ),
      child: Text(
        'Error al cargar conversaciones: $error',
        style: const TextStyle(color: Colors.redAccent, fontSize: 13),
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String label;

  const _SectionLabel({
    required this.icon,
    required this.iconColor,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 8, color: iconColor),
        const SizedBox(width: 6),
        Text(
          label,
          style: TextStyle(
            color: iconColor,
            fontSize: 11,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.5,
          ),
        ),
      ],
    );
  }
}
