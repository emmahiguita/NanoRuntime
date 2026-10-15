/// WHATSAPP-WEB-FEED-PROVIDER — Adaptador reactivo del feed de WhatsApp Web al hub.
///
/// **QUÉ HACE:**
/// Gestiona el switch de activación persistente y convierte los resúmenes observados
/// en el WebView de WhatsApp Web en elementos de conversación unificados para el Hub.
///
/// **CÓMO FUNCIONA:**
/// Lee SharedPreferences para recordar el estado, observa los eventos del bridge de JavaScript,
/// y enriquece los alias con números de teléfono si están presentes en el nombre de contacto.
///
/// **POR QUÉ:**
/// Provee una fuente no destructiva para visualizar y sincronizar chats de WhatsApp Web
/// sin duplicar tarjetas ni alterar el historial nativo persistido (< 200 líneas).
library;

import 'dart:async';
import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../domain/whatsapp_media_payload.dart';
import '../../engine/messaging/conversation_agent.dart';
import '../../engine/messaging/canonical_message.dart';
import '../../engine/messaging/canonical_message_store.dart';
import '../../engine/messaging/conversation_hub_providers.dart';
import '../../engine/web_bridge/whatsapp_web_bridge_controller.dart';
import '../../engine/web_bridge/whatsapp_web_message_filter.dart';
import 'messaging_conversation_identity.dart';

const _enabledPreferenceKey = 'messaging_whatsapp_web_feed_enabled';

final whatsappWebFeedEnabledProvider =
    AsyncNotifierProvider<WhatsAppWebFeedSettingsNotifier, bool>(
      WhatsAppWebFeedSettingsNotifier.new,
    );

final whatsappWebSessionProvider = StreamProvider<WhatsAppWebSessionInfo>(
  (ref) => _withCurrent(
    whatsAppWebBridgeController.sessionStream,
    () => whatsAppWebBridgeController.currentSession,
  ),
);

final whatsappWebConversationsProvider =
    StreamProvider<List<WhatsAppWebConversationSummary>>(
      (ref) => _withCurrent(
        whatsAppWebBridgeController.conversationsStream,
        () => whatsAppWebBridgeController.currentConversations,
      ),
    );

// Suscribe primero y luego emite el estado actual: no pierde el evento que
// llega entre el primer yield y la suscripción de un stream broadcast.
Stream<T> _withCurrent<T>(Stream<T> changes, T Function() current) =>
    Stream<T>.multi((sink) {
      final sub = changes.listen(
        sink.add,
        onError: sink.addError,
        onDone: sink.close,
      );
      sink.add(current());
      sink.onCancel = sub.cancel;
    });

final whatsappWebConversationItemsProvider =
    Provider<List<ConversationSummaryItem>>((ref) {
      final enabled = ref.watch(whatsappWebFeedEnabledProvider).valueOrNull;
      if (enabled != true) return const [];
      final webItems =
          ref.watch(whatsappWebConversationsProvider).valueOrNull ??
          whatsAppWebBridgeController.currentConversations;
      unawaited(_persistWebSnapshot(webItems));
      // Filtra antes de unir Web con Android: un aviso no crea una tarjeta ni
      // sustituye la vista previa de un mensaje real en la deduplicación.
      return webItems
          .where(
            (item) => WhatsAppWebMessageFilter.allows(
              conversationId: item.id,
              displayName: item.displayName,
              lastMessage: item.lastMessage,
            ),
          )
          .map(_toConversationItem)
          .toList(growable: false);
    });

Future<void> _persistWebSnapshot(
  List<WhatsAppWebConversationSummary> items,
) async {
  for (final item in items) {
    if (!WhatsAppWebMessageFilter.allows(
      conversationId: item.id,
      displayName: item.displayName,
      lastMessage: item.lastMessage,
    )) {
      continue;
    }
    final summary = _toConversationItem(item);
    if (item.lastMessage.trim().isNotEmpty) {
      await canonicalMessageStore.upsert(
        CanonicalMessage.observed(
          conversationId: summary.conversationId,
          provider: CanonicalMessageProvider.whatsappWeb,
          body: item.lastMessage,
          occurredAtMs: item.lastAtMs,
          sender: item.displayName,
          rawMetadata: {'source': 'visible_chat_preview'},
        ),
      );
      await canonicalMessageStore.recordCoverage(
        conversationId: summary.conversationId,
        provider: CanonicalMessageProvider.whatsappWeb,
        fromMs: item.lastAtMs,
        toMs: item.lastAtMs,
        gapBefore: true,
      );
    }
  }
}

final class WhatsAppWebFeedSettingsNotifier extends AsyncNotifier<bool> {
  @override
  Future<bool> build() async {
    final prefs = await SharedPreferences.getInstance();
    final enabled = prefs.getBool(_enabledPreferenceKey) ?? false;
    await whatsAppWebBridgeController.setConversationFeedEnabled(enabled);
    return enabled;
  }

  Future<void> setEnabled(bool enabled) async {
    final previous = state.valueOrNull ?? false;
    state = AsyncData(enabled);
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_enabledPreferenceKey, enabled);
      await whatsAppWebBridgeController.setConversationFeedEnabled(enabled);
    } catch (error, stackTrace) {
      // Un fallo de activación no debe dejar un switch verde persistido.
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_enabledPreferenceKey, previous);
      try {
        await whatsAppWebBridgeController.setConversationFeedEnabled(previous);
      } catch (_) {
        // Conserva el error original; no recarga ni borra la sesión vinculada.
      }
      state = AsyncError(error, stackTrace);
      await Future<void>.delayed(Duration.zero);
      state = AsyncData(previous);
      rethrow;
    }
  }
}

ConversationSummaryItem _toConversationItem(
  WhatsAppWebConversationSummary item,
) {
  final cleanName = item.displayName.trim();
  final account = whatsAppWebBridgeController.conversationAccount ?? '';
  // El nombre del contacto no demuestra su teléfono: solo una etiqueta
  // íntegramente telefónica aporta esa evidencia, nunca "Cliente 3001234567".
  // Hash de una etiqueta débil, no JID: mantiene el alias acotado para SQLite.
  final rowHash = sha256.convert(utf8.encode(item.id)).toString();
  final scopedId = 'waweb:${Uri.encodeComponent(account)}/$rowHash';
  // Alias heredado solo para localizar historial dentro de su cuenta SQLite;
  // la política de identidad nunca fusiona por este ID derivado del título.
  final aliases = <String>[scopedId, 'waweb:${item.id}'];
  final phoneDigits = item.isGroup
      ? null
      : MessagingConversationIdentity.extractPhoneDigits(cleanName);
  if (phoneDigits != null && phoneDigits.isNotEmpty) {
    aliases.add('phone:$phoneDigits');
    aliases.add('$phoneDigits@s.whatsapp.net');
  }

  return ConversationSummaryItem(
    conversationId: scopedId,
    accountFingerprint: account,
    conversationAliases: aliases,
    displayName: cleanName,
    packageName: 'com.whatsapp',
    lastMessage: item.lastMessage,
    lastAtMs: item.lastAtMs,
    hasPendingReply: false,
    humanOwns: true,
    activeRole: 'WhatsApp Web',
    agentId: ConversationAgentId.personal,
    entryCount: 1,
    isGroup: item.isGroup,
    groupTitle: item.isGroup ? cleanName : null,
  );
}
