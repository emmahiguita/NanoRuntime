/// Resolución segura de destinatarios para herramientas WhatsApp.
///
/// QUÉ HACE: convierte un nombre o número explícito en un contacto concreto.
/// CÓMO: consulta la agenda y delega coincidencias nominales a ContactMatcher.
/// POR QUÉ: un término genérico nunca debe seleccionar el primer contacto.
library;

import '../../../application/whatsapp_contacts_provider.dart';
import '../../../domain/whatsapp_contact.dart';
import '../../planning/contact_matcher.dart';

final class WhatsAppContactResolver {
  const WhatsAppContactResolver(this._contacts);

  final WhatsAppContactsService _contacts;

  Future<WhatsAppContact?> resolve(String query) async {
    final normalized = query.trim().toLowerCase();
    if (normalized.isEmpty || _genericTerms.contains(normalized)) return null;

    if (!await _contacts.hasPermission()) {
      await _contacts.requestPermission();
    }
    final contacts = await _contacts.getContacts();
    if (contacts.isEmpty) return null;

    final digits = normalized.replaceAll(RegExp(r'\D'), '');
    if (digits.length >= 7) {
      final saved = contacts.where((contact) {
        final savedDigits = contact.number.replaceAll(RegExp(r'\D'), '');
        return savedDigits == digits ||
            savedDigits.endsWith(digits) ||
            digits.endsWith(savedDigits);
      }).firstOrNull;
      if (saved != null) return saved;

      // Un número explícito es una identidad válida aunque no esté en agenda.
      return WhatsAppContact(
        id: digits,
        name: query,
        number: digits,
        jid: '$digits@s.whatsapp.net',
        isBusiness: false,
      );
    }

    return ContactMatcher.findBest(query, contacts);
  }
}

const Set<String> _genericTerms = {
  'destinatario',
  'contacto',
  'contacto de whatsapp',
  'contactos',
};
