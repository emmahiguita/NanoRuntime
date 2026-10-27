part of 'messaging_center_providers.dart';

/// Carga las fuentes locales. WhatsApp Web queda fuera para que cada cambio
/// del DOM no vuelva a consultar SQLite, notificaciones y asignaciones.
final _localHubConversationsProvider =
    FutureProvider<List<ConversationSummaryItem>>((ref) async {
      // Las cuatro fuentes son independientes. Esperarlas en serie hacía que
      // cada refresco Web/notificación sumara todas sus latencias y ocultara
      // la lista completa detrás de un spinner.
      // Captura Ref antes de esperar: un refresco puede desmontar este provider.
      final ownership = ref.watch(conversationOwnershipStoreProvider);
      final targetMode = ref.watch(settingsProvider).waTargetContactsMode;
      final assignments = ref.watch(conversationAssignmentStoreProvider);
      final sources = await Future.wait<List<ConversationSummaryItem>>([
        ref.watch(
          conversationHubListProvider(ConversationAgentId.personal).future,
        ),
        ref.watch(
          conversationHubListProvider(ConversationAgentId.business).future,
        ),
        ref.watch(liveNotificationsProvider.future),
        ref.watch(notificationHistoryConversationsProvider.future),
      ]);
      final personalList = sources[0];
      final businessList = sources[1];
      final liveList = sources[2];
      final notificationHistory = sources[3];
      await Future.wait<void>([ownership.load(), assignments.load()]);

      final merged = MessagingDedupMerger.deduplicateAndSort([
        ...personalList,
        ...businessList,
        ...notificationHistory,
        ...liveList,
      ]);
      // Ser un historial solo de lectura no equivale a una pausa del agente.
      // Lista, menú y detalle consultan la misma autorización persistida.
      return [
        for (final item in merged)
          item.withHumanOwnership(
            ConversationOwnershipPolicy.humanOwns(
              targetContactsMode: targetMode,
              ownership: ConversationOwnershipPolicy.ownershipForConversation(
                store: ownership,
                conversationId: item.conversationId,
                packageName: item.packageName,
                isGroup: item.isGroup,
                aliases: item.conversationAliases,
              ),
            ),
            assignedAgent: messagingAssignedAgent(item, assignments),
          ),
      ];
    });

/// Web no espera al archivo Android. Riverpod descarta los resultados de
/// generaciones anteriores; aquí no se crean suscripciones ni tareas sueltas.
final allHubConversationsProvider = FutureProvider<List<ConversationSummaryItem>>((
  ref,
) {
  final local = ref.watch(_localHubConversationsProvider);
  final web = ref.watch(whatsappWebConversationItemsProvider);
  if (local.hasValue || web.isNotEmpty) {
    return MessagingDedupMerger.deduplicateAndSort([
      ...local.valueOrNull ?? const <ConversationSummaryItem>[],
      ...web,
    ]);
  }
  // Sin datos aún, conserva el error/carga real en vez de fingir un inbox vacío.
  return ref
      .watch(_localHubConversationsProvider.future)
      .then(
        (rows) => MessagingDedupMerger.deduplicateAndSort([...rows, ...web]),
      );
});

/// Permite advertir carga parcial sin ocultar los chats Web disponibles.
final localMessagingLoadErrorProvider = Provider<bool>(
  (ref) => ref.watch(_localHubConversationsProvider).hasError,
);
