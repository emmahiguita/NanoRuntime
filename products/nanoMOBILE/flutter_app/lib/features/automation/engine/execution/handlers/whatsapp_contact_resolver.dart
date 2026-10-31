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
    var normalized = query.trim().toLowerCase();
    normalized = normalized.replaceFirst(
      RegExp(r'^(?:(?:este|el|al)\s+)?n[uú]mero\s+', caseSensitive: false),
      '',
    ).trim();
    if (normalized.isEmpty || _genericTerms.contains(normalized)) return null;

    if (!await _contacts.hasPermission()) {
      await _contacts.requestPermission();
    }
    final contacts = await _contacts.getContacts();

    final digits = normalized.replaceAll(RegExp(r'\D'), '');
    if (RegExp(r'^[+0-9 ().-]+$').hasMatch(normalized) &&
        digits.length >= 7 &&
        digits.length <= 15) {
      final saved = contacts.where((contact) {
        final savedDigits = contact.number.replaceAll(RegExp(r'\D'), '');
        // Coincidencias por sufijo podían sustituir país/número solicitado.
        return savedDigits == digits;
      }).toList();
      if (saved.isNotEmpty) return _uniqueNumber(saved);

      // Un número explícito sirve para una apertura manual, pero no prueba que
      // WhatsApp haya publicado una cuenta ni autoriza autoenvío verificado.
      return WhatsAppContact(
        id: digits,
        name: query,
        number: digits,
        jid: '',
        isBusiness: false,
        verificationSource: 'explicit_phone',
        isWhatsAppVerified: false,
      );
    }

    // La fonética sirve para sugerir, nunca para autorizar un envío. Un nombre
    // exacto con varios teléfonos exige aclaración; filas duplicadas de la
    // misma cuenta/número se consolidan sin fabricar verificación de WhatsApp.
    final exact = contacts
        .where(
          (c) =>
              ContactMatcher.normalize(c.name) ==
              ContactMatcher.normalize(query),
        )
        .toList();
    // Conserva los grupos de cuenta ya verificados para compartir archivos.
    // Su JID no se convierte en un teléfono ni se mezcla con personas homónimas.
    final groups = {
      for (final c in exact.where(
        (c) => c.isGroup && c.isWhatsAppVerified && c.jid.endsWith('@g.us'),
      ))
        c.jid: c,
    };
    final people = exact.where((c) => !c.isGroup).toList();
    if (groups.isNotEmpty) {
      return people.isEmpty && groups.length == 1 ? groups.values.single : null;
    }
    return _uniqueNumber(people);
  }

  WhatsAppContact? _uniqueNumber(List<WhatsAppContact> contacts) {
    final byNumber = <String, WhatsAppContact>{};
    for (final contact in contacts) {
      final number = contact.number.replaceAll(RegExp(r'\D'), '');
      if (number.length < 7 || contact.isGroup) continue;
      final previous = byNumber[number];
      if (previous == null ||
          (!previous.isWhatsAppVerified && contact.isWhatsAppVerified)) {
        byNumber[number] = contact;
      }
    }
    return byNumber.length == 1 ? byNumber.values.single : null;
  }
}

const Set<String> _genericTerms = {
  'destinatario',
  'contacto',
  'contacto de whatsapp',
  'contactos',
};
