// personalization_scope_resolver.dart
//
// QUÉ HACE:
// Servicio canónico de resolución jerárquica de ámbitos (scopes) para el Agente Personal.
//
// CÓMO FUNCIONA:
// Resuelve scopes en estricto orden de precedencia:
// 1. Contacto específico (hash SHA-256 de conversationId y/o alias/teléfono WhatsApp).
// 2. Rol personal ('role:personal').
// 3. Propietario ('owner').
// 4. Global ('global').
//
// POR QUÉ:
// Garantiza que las intenciones aprendidas se recuperen en el mismo ámbito donde se guardaron,
// aislando contactos sin perder herencia del dueño (SOLID - SRP, < 180 líneas).

library;

import '../domain/personal_memory.dart' show personalizationScope;
import 'persona_repository.dart';

abstract interface class PersonalizationScopeResolver {
  Future<List<String>> resolveScopes({
    required String conversationId,
    required String senderId,
  });
}

final class CanonicalPersonalizationScopeResolver
    implements PersonalizationScopeResolver {
  final PersonaRepository? _repository;

  const CanonicalPersonalizationScopeResolver({
    PersonaRepository? repository,
  }) : _repository = repository;

  PersonaRepository get _repo => _repository ?? PersonaRepository.instance;

  @override
  Future<List<String>> resolveScopes({
    required String conversationId,
    required String senderId,
  }) async {
    final scopes = <String>[];

    // 1. Ámbito de contacto específico por identidad técnica de conversación
    final cleanConv = conversationId.trim();
    if (cleanConv.isNotEmpty) {
      final canonicalContact = personalizationScope(cleanConv);
      if (canonicalContact != 'owner' && !scopes.contains(canonicalContact)) {
        scopes.add(canonicalContact);
      }
    }

    // Si existe un perfil de relación vinculado o preparado por teléfono/JID
    final cleanSender = senderId.trim();
    if (cleanSender.isNotEmpty) {
      final senderLower = cleanSender.toLowerCase();
      try {
        final relationships = await _repo.listRelationships();
        for (final r in relationships) {
          final facts = r.facts;
          final matchWa = facts['whatsapp']?.trim() == cleanSender;
          final matchJid = facts['jid']?.trim().toLowerCase() == senderLower;
          final matchKey = r.relationshipKey.toLowerCase() == senderLower ||
              r.relationshipKey == 'unbound:wa_$cleanSender';
          final matchConv = facts['conversationId']?.trim() == cleanConv;

          if ((matchWa || matchJid || matchKey || matchConv) &&
              !scopes.contains(r.relationshipKey)) {
            scopes.add(r.relationshipKey);
          }
        }
      } catch (_) {}
    }

    // 2. Ámbito de rol personal
    if (!scopes.contains('role:personal')) {
      scopes.add('role:personal');
    }

    // 3. Ámbito de propietario
    if (!scopes.contains('owner')) {
      scopes.add('owner');
    }

    // 4. Ámbito global
    if (!scopes.contains('global')) {
      scopes.add('global');
    }

    return scopes;
  }
}
