import 'package:flutter_test/flutter_test.dart';
import 'package:nanoai/features/automation/application/whatsapp_contacts_provider.dart';
import 'package:nanoai/features/automation/domain/whatsapp_contact.dart';
import 'package:nanoai/features/automation/engine/execution/handlers/whatsapp_tool_handler.dart';
import 'package:nanoai/features/automation/engine/execution/tool_call.dart';
import 'package:nanoai/features/automation/engine/platform/whatsapp_media_share.dart';
import 'package:nanoai/features/automation/engine/planning/contact_matcher.dart';
import 'package:nanoai/features/automation/engine/planning/whatsapp_intent_parser.dart';

class _FakeContactsService extends WhatsAppContactsService {
  final List<WhatsAppContact> contacts;
  _FakeContactsService(this.contacts);

  @override
  Future<bool> hasPermission() async => true;

  @override
  Future<List<WhatsAppContact>> getContacts() async => contacts;
}

class _FakeMediaShare extends WhatsAppMediaShare {
  String? lastContact;
  String? lastText;
  String? lastPath;
  String? lastCaption;
  bool? lastAutoSend;

  @override
  Future<bool> openChat({
    required String contact,
    String text = '',
    String? packageName,
    bool autoSend = true,
  }) async {
    lastContact = contact;
    lastText = text;
    lastAutoSend = autoSend;
    return true;
  }

  @override
  Future<bool> shareFile({
    required String path,
    required String contact,
    String caption = '',
    String? packageName,
  }) async {
    lastPath = path;
    lastContact = contact;
    lastCaption = caption;
    return true;
  }
}

void main() {
  group('ContactMatcher Tests', () {
    final contacts = [
      const WhatsAppContact(
        id: '1',
        name: 'A Pokevzla',
        number: '+573105913746',
        jid: '573105913746@s.whatsapp.net',
        isBusiness: false,
      ),
      const WhatsAppContact(
        id: '2',
        name: 'Santana Luis',
        number: '+573108489301',
        jid: '573108489301@s.whatsapp.net',
        isBusiness: false,
      ),
      const WhatsAppContact(
        id: '3',
        name: 'Emmanuel Higuita Gomez',
        number: '+573147875609',
        jid: '573147875609@s.whatsapp.net',
        isBusiness: false,
      ),
      const WhatsAppContact(
        id: '4',
        name: 'Papá',
        number: '+573218605936',
        jid: '573218605936@s.whatsapp.net',
        isBusiness: false,
      ),
    ];

    test('matches "poke suela" to "A Pokevzla"', () {
      final match = ContactMatcher.findBest('poke suela', contacts);
      expect(match, isNotNull);
      expect(match!.name, 'A Pokevzla');
      expect(match.number, '+573105913746');
    });

    test('matches "pokezuela" to "A Pokevzla"', () {
      final match = ContactMatcher.findBest('pokezuela', contacts);
      expect(match, isNotNull);
      expect(match!.name, 'A Pokevzla');
    });

    test('matches "luis" to "Santana Luis"', () {
      final match = ContactMatcher.findBest('luis', contacts);
      expect(match, isNotNull);
      expect(match!.name, 'Santana Luis');
    });

    test('matches "higuita" to "Emmanuel Higuita Gomez"', () {
      final match = ContactMatcher.findBest('higuita', contacts);
      expect(match, isNotNull);
      expect(match!.name, 'Emmanuel Higuita Gomez');
    });

    test('matches "papa" without accent to "Papá"', () {
      final match = ContactMatcher.findBest('papa', contacts);
      expect(match, isNotNull);
      expect(match!.name, 'Papá');
    });

    test('returns null when query has no reasonable match', () {
      final match = ContactMatcher.findBest('astronauta desconocido', contacts);
      expect(match, isNull);
    });
  });

  group('WhatsAppIntentParser Tests', () {
    test('parses "busca a (Poke Suela)"', () {
      final intent = WhatsAppIntentParser.parse('busca a (Poke Suela)');
      expect(intent, isNotNull);
      expect(intent!.action, WhatsAppAction.findContact);
      expect(intent.contact, 'Poke Suela');
    });

    test('parses "busca a pokezuela en whatsapp"', () {
      final intent = WhatsAppIntentParser.parse('busca a pokezuela en whatsapp');
      expect(intent, isNotNull);
      expect(intent!.action, WhatsAppAction.findContact);
      expect(intent.contact, 'pokezuela');
    });

    test('parses "envíale a (Poke Suela) (Hola mundo)"', () {
      final intent = WhatsAppIntentParser.parse('envíale a (Poke Suela) (Hola mundo)');
      expect(intent, isNotNull);
      expect(intent!.action, WhatsAppAction.sendMessage);
      expect(intent.contact, 'Poke Suela');
      expect(intent.message, 'Hola mundo');
    });

    test('parses "envíale a (Poke Suela) el archivo /sdcard/doc.pdf"', () {
      final intent = WhatsAppIntentParser.parse('envíale a (Poke Suela) el archivo /sdcard/doc.pdf');
      expect(intent, isNotNull);
      expect(intent!.action, WhatsAppAction.shareFile);
      expect(intent.contact, 'Poke Suela');
      expect(intent.filePath, '/sdcard/doc.pdf');
    });
  });

  group('WhatsAppToolHandler integration with ContactMatcher', () {
    late _FakeContactsService contactsService;
    late _FakeMediaShare mediaShare;
    late WhatsAppToolHandler handler;

    final fakeContacts = [
      const WhatsAppContact(
        id: '1',
        name: 'A Pokevzla',
        number: '+573105913746',
        jid: '573105913746@s.whatsapp.net',
        isBusiness: false,
      ),
      const WhatsAppContact(
        id: '2',
        name: 'Papá',
        number: '+573218605936',
        jid: '573218605936@s.whatsapp.net',
        isBusiness: false,
      ),
      const WhatsAppContact(
        id: '3',
        name: 'Emm',
        number: '+573203527283',
        jid: '573203527283@s.whatsapp.net',
        isBusiness: false,
      ),
    ];

    setUp(() {
      contactsService = _FakeContactsService(fakeContacts);
      mediaShare = _FakeMediaShare();
      handler = WhatsAppToolHandler(share: mediaShare, contacts: contactsService);
    });

    test('listContacts finds "A Pokevzla" when query is "poke suela"', () async {
      final res = await handler.listContacts(
        const ToolCall(
          tool: 'whatsapp.contacts',
          args: {'query': 'poke suela'},
        ),
      );

      expect(res, contains('1 contacto(s)'));
      expect(res, contains('A Pokevzla'));
      expect(res, contains('+573105913746'));
    });

    test('sendMessage to "poke suela" resolves to A Pokevzla phone', () async {
      final res = await handler.sendMessage(
        const ToolCall(
          tool: 'whatsapp.send_message',
          args: {'contact': 'poke suela', 'text': 'Mensaje de prueba'},
        ),
      );

      expect(res, contains('Mensaje enviado a "A Pokevzla"'));
      expect(mediaShare.lastContact, '+573105913746');
      expect(mediaShare.lastText, 'Mensaje de prueba');
    });

    test('shareFile sends file to resolved contact', () async {
      final res = await handler.shareFile(
        const ToolCall(
          tool: 'whatsapp.share_file',
          args: {
            'contact': 'poke suela',
            'path': '/storage/emulated/0/documento.pdf',
            'caption': 'Aquí tienes el PDF',
          },
        ),
      );

      expect(res, contains('Archivo listo para "A Pokevzla"'));
      expect(mediaShare.lastContact, '+573105913746');
      expect(mediaShare.lastPath, '/storage/emulated/0/documento.pdf');
      expect(mediaShare.lastCaption, 'Aquí tienes el PDF');
    });

    // ── Pruebas solicitadas por el usuario para contacto 'Emm' ─────────────────

    test('1. busca a Emm en whatsapp encuentra su contacto y teléfono', () async {
      final res = await handler.listContacts(
        const ToolCall(
          tool: 'whatsapp.contacts',
          args: {'query': 'Emm'},
        ),
      );

      expect(res, contains('Emm'));
      expect(res, contains('+573203527283'));
    });

    test('2. escríbele a Emm envía mensaje a su número resuelto', () async {
      final res = await handler.sendMessage(
        const ToolCall(
          tool: 'whatsapp.send_message',
          args: {'contact': 'Emm', 'text': 'Hola Emm, esto es una prueba real'},
        ),
      );

      expect(res, contains('Mensaje enviado a "Emm" (+573203527283)'));
      expect(mediaShare.lastContact, '+573203527283');
      expect(mediaShare.lastText, 'Hola Emm, esto es una prueba real');
    });

    test('3. envíale un documento a Emm prepara el PDF para su número', () async {
      final res = await handler.shareFile(
        const ToolCall(
          tool: 'whatsapp.share_file',
          args: {
            'contact': 'Emm',
            'path': '/sdcard/Download/Informe_Ejecutivo_-_Datos_Shell.pdf',
            'caption': 'Aquí está el documento solicitado',
          },
        ),
      );

      expect(res, contains('Archivo listo para "Emm" (+573203527283)'));
      expect(mediaShare.lastContact, '+573203527283');
      expect(mediaShare.lastPath, '/sdcard/Download/Informe_Ejecutivo_-_Datos_Shell.pdf');
    });

    test('4. envíale una foto a Emm prepara la imagen para su número', () async {
      final res = await handler.shareFile(
        const ToolCall(
          tool: 'whatsapp.share_file',
          args: {
            'contact': 'Emm',
            'path': '/sdcard/Pictures/file_0000000013e481f58825cd146c7e1f06.png',
            'caption': 'Foto enviada desde Nano',
          },
        ),
      );

      expect(res, contains('Archivo listo para "Emm" (+573203527283)'));
      expect(mediaShare.lastContact, '+573203527283');
      expect(mediaShare.lastPath, '/sdcard/Pictures/file_0000000013e481f58825cd146c7e1f06.png');
    });
  });
}

