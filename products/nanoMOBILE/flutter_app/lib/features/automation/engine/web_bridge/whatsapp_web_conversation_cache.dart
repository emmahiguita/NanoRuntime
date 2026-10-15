/// Persiste la lista de conversaciones conocidas de WhatsApp Web por cuenta.
library;

import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'whatsapp_web_conversation_decoder.dart';

const _conversationCacheKey = 'wa_web_known_conversations_v1';

abstract final class WhatsAppWebConversationCache {
  static Future<void> save(
    String? account,
    List<WhatsAppWebConversationSummary> items,
  ) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        _conversationCacheKey,
        jsonEncode({
          'account': account ?? '',
          'items': items.map((c) => c.toJson()).toList(),
        }),
      );
    } catch (error) {
      debugPrint('[wa-web-feed] cache save failed type=${error.runtimeType}');
    }
  }

  static Future<
    ({String? account, List<WhatsAppWebConversationSummary> items})?
  >
  restore() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_conversationCacheKey);
      if (raw == null) return null;
      final data = jsonDecode(raw);
      if (data is! Map || data['items'] is! List) return null;
      final items = (data['items'] as List)
          .map(WhatsAppWebConversationSummary.fromJson)
          .whereType<WhatsAppWebConversationSummary>()
          .toList();
      final account = '${data['account'] ?? ''}';
      return (account: account.isEmpty ? null : account, items: items);
    } catch (error) {
      debugPrint(
        '[wa-web-feed] cache restore failed type=${error.runtimeType}',
      );
      return null;
    }
  }
}
