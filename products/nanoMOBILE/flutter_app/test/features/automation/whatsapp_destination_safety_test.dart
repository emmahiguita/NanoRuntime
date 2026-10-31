import 'package:flutter_test/flutter_test.dart';
import 'package:nanoai/features/automation/application/whatsapp_contacts_provider.dart';
import 'package:nanoai/features/automation/domain/whatsapp_contact.dart';
import 'package:nanoai/features/automation/engine/execution/handlers/whatsapp_command_input.dart';
import 'package:nanoai/features/automation/engine/execution/handlers/whatsapp_contact_resolver.dart';

// Doble explícito de agenda. Valida selección/parseo; no acredita envíos reales.
class AgendaDoble extends WhatsAppContactsService {
  AgendaDoble(this.entries);
  final List<WhatsAppContact> entries;
  @override
  Future<bool> hasPermission() async => true;
  @override
  Future<List<WhatsAppContact>> getContacts() async => entries;
}

WhatsAppContact entry(String name, String phone, {bool verified = false}) =>
    WhatsAppContact(
      id: phone,
      name: name,
      number: phone,
      jid: verified ? '$phone@s.whatsapp.net' : '',
      isWhatsAppVerified: verified,
    );

void main() {
  test('conserva nombre completo y espacios del mensaje', () {
    final parsed = WhatsAppCommandInput.parse(
      '"Nombre Completo" hola  otra vez',
    )!;
    expect(parsed.contact, 'Nombre Completo');
    expect(parsed.message, 'hola  otra vez');
  });
  test('un usuario con dígitos sigue siendo usuario', () {
    expect(WhatsAppCommandInput.isUsername('@dev123456789'), isTrue);
    expect(WhatsAppCommandInput.isUsername('@123456789'), isFalse);
  });
  test('rechaza un nombre con dos números, no escoge el primero', () async {
    final resolver = WhatsAppContactResolver(
      AgendaDoble([
        entry('Persona', '573000000001'),
        entry('Persona', '573000000002'),
      ]),
    );
    expect(await resolver.resolve('Persona'), isNull);
  });
  test('la fonética no autoriza un destinatario', () async {
    final resolver = WhatsAppContactResolver(
      AgendaDoble([entry('Nombre Largo', '573000000001')]),
    );
    expect(await resolver.resolve('Nombre'), isNull);
  });
  test(
    'duplica filas del mismo teléfono sin perder verificación real',
    () async {
      final resolver = WhatsAppContactResolver(
        AgendaDoble([
          entry('Persona', '573000000001'),
          entry('Persona', '573000000001', verified: true),
        ]),
      );
      expect((await resolver.resolve('Persona'))!.isWhatsAppVerified, isTrue);
    },
  );
  test('conserva un grupo verificado sin convertir su JID en teléfono', () async {
    final resolver = WhatsAppContactResolver(AgendaDoble([
      const WhatsAppContact(id: 'group', name: 'Grupo de prueba', number: '',
        jid: '120000000000000@g.us', isGroup: true, isWhatsAppVerified: true),
    ]));
    expect((await resolver.resolve('Grupo de prueba'))!.isGroup, isTrue);
  });
  test(
    'un teléfono explícito sin agenda no inventa cuenta verificada',
    () async {
      final resolver = WhatsAppContactResolver(AgendaDoble([]));
      final contact = await resolver.resolve('+57 300 0000001');
      expect(contact!.number, '573000000001');
      expect(contact.isWhatsAppVerified, isFalse);
      expect(contact.jid, isEmpty);
    },
  );

  test('H4: resuelve teléfono de contacto de agenda aunque no tenga fila MIME verificada', () {
    const contact = WhatsAppContact(
      id: 'local_1',
      name: 'Contacto Agenda Simple',
      number: '+57 310 999 8877',
      jid: '',
      isWhatsAppVerified: false,
    );
    expect(contact.jid, isEmpty);
    expect(contact.isWhatsAppVerified, isFalse);
    expect(contact.detectionLabel, 'WhatsApp no verificado');
  });

  test('H5: etiqueta factual de detección diferencia MIME y no verificado', () {
    const personal = WhatsAppContact(
      id: 'p1',
      name: 'Amigo',
      number: '573001234567',
      jid: '573001234567@s.whatsapp.net',
      isWhatsAppVerified: true,
      isBusiness: false,
    );
    expect(personal.detectionLabel, 'WhatsApp en agenda');

    const business = WhatsAppContact(
      id: 'b1',
      name: 'Negocio',
      number: '573007654321',
      jid: '573007654321@s.whatsapp.net',
      isWhatsAppVerified: true,
      isBusiness: true,
    );
    expect(business.detectionLabel, 'WhatsApp Business en agenda');
  });
}
