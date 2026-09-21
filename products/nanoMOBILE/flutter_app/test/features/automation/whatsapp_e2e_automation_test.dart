// whatsapp_e2e_automation_test.dart
// ¿Qué hace?
//   Automatiza las 4 pruebas de WhatsApp para el contacto 'Emm':
//   1. Buscar contacto.
//   2. Escribir mensaje.
//   3. Enviar documento PDF.
//   4. Enviar foto / imagen.
//
// ¿Cómo funciona?
//   Simula el flujo completo de producción (End-to-End):
//   Objetivo en lenguaje natural -> Catálogo Determinista -> Intent Parser ->
//   Contact Matcher -> Tool Handler -> Native Media Share Bridge.
//
// ¿Por qué?
//   Garantiza que toda la cadena de automatización funcione sin errores,
//   sin bloqueos y con validación factual de números y rutas de archivo.

import 'package:flutter_test/flutter_test.dart';
import 'package:nanoai/features/automation/application/whatsapp_contacts_provider.dart';
import 'package:nanoai/features/automation/domain/whatsapp_contact.dart';
import 'package:nanoai/features/automation/engine/execution/handlers/whatsapp_tool_handler.dart';
import 'package:nanoai/features/automation/engine/execution/plan_execution_coordinator.dart';
import 'package:nanoai/features/automation/engine/execution/tool_call.dart';
import 'package:nanoai/features/automation/engine/execution/tool_outcome.dart';
import 'package:nanoai/features/automation/engine/execution/tool_registry.dart';
import 'package:nanoai/features/automation/engine/platform/whatsapp_media_share.dart';
import 'package:nanoai/features/automation/engine/planning/deterministic_catalog.dart';
import 'package:nanoai/features/automation/engine/planning/whatsapp_intent_parser.dart';

class _FakeContactsService extends WhatsAppContactsService {
  final List<WhatsAppContact> contacts;
  _FakeContactsService(this.contacts);

  @override
  Future<bool> hasPermission() async => true;

  @override
  Future<List<WhatsAppContact>> getContacts() async => contacts;
}

class _RecordingMediaShare extends WhatsAppMediaShare {
  String? lastOpenedContact;
  String? lastSentText;
  bool? lastAutoSend;

  String? lastSharedPath;
  String? lastSharedContact;
  String? lastSharedCaption;

  @override
  Future<bool> openChat({
    required String contact,
    String text = '',
    String? packageName,
    bool autoSend = true,
  }) async {
    lastOpenedContact = contact;
    lastSentText = text;
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
    lastSharedPath = path;
    lastSharedContact = contact;
    lastSharedCaption = caption;
    return true;
  }
}

void main() {
  group('WhatsApp Automated End-to-End Suite: Contacto Emm (+573203527283)', () {
    late _RecordingMediaShare mediaShare;
    late WhatsAppToolHandler handler;
    late DeterministicFlowCatalog catalog;

    final deviceContacts = [
      const WhatsAppContact(
        id: '1',
        name: 'Emm',
        number: '+573203527283',
        jid: '573203527283@s.whatsapp.net',
        isBusiness: false,
      ),
      const WhatsAppContact(
        id: '2',
        name: 'A Pokevzla',
        number: '+573105913746',
        jid: '573105913746@s.whatsapp.net',
        isBusiness: false,
      ),
    ];

    setUp(() {
      mediaShare = _RecordingMediaShare();
      handler = WhatsAppToolHandler(
        share: mediaShare,
        contacts: _FakeContactsService(deviceContacts),
      );
      catalog = defaultDeterministicCatalog;
    });


    test('Prueba 1: Buscar al contacto Emm y abrir WhatsApp (con y sin paréntesis)', () async {
      const goals = [
        'busca a (Emm) en whatsapp',
        'busca a Emm en whatsapp',
        'buscar a Emm en whatsapp',
      ];

      for (final goal in goals) {
        final flow = catalog.forGoal(goal);
        expect(flow, isNotNull, reason: 'El catálogo debe capturar la orden: $goal');
        expect(flow!.steps.first.tool, 'whatsapp.open_chat');

        final intent = WhatsAppIntentParser.parse(goal);
        expect(intent, isNotNull);
        expect(intent!.action, WhatsAppAction.findContact);
        expect(intent.contact.toLowerCase(), 'emm');

        final result = await handler.openChat(
          ToolCall(tool: 'whatsapp.open_chat', args: {'contact': intent.contact}),
        );

        expect(result, contains('Chat abierto con "Emm" (+573203527283)'));
        expect(mediaShare.lastOpenedContact, '+573203527283');
        expect(
          PlanExecutionCoordinator.executionStatusFor(result),
          ToolExecutionStatus.completed,
          reason: 'El feedback no debe ser clasificado como fallo por el coordinador',
        );
      }
    });

    test('Prueba 2: Escribir y enviar mensaje a Emm', () async {
      const goal = 'escríbele a (Emm) (Hola Emm, prueba automatizada completada) en whatsapp';

      final flow = catalog.forGoal(goal);
      expect(flow, isNotNull);
      expect(flow!.steps.first.tool, 'whatsapp.send_message');

      final intent = WhatsAppIntentParser.parse(goal);
      expect(intent, isNotNull);
      expect(intent!.action, WhatsAppAction.sendMessage);
      expect(intent.contact, 'Emm');
      expect(intent.message, 'Hola Emm, prueba automatizada completada');

      final result = await handler.sendMessage(
        ToolCall(
          tool: 'whatsapp.send_message',
          args: {'contact': intent.contact, 'text': intent.message!},
        ),
      );

      expect(result, contains('Mensaje enviado a "Emm" (+573203527283)'));
      expect(
        PlanExecutionCoordinator.executionStatusFor(result),
        ToolExecutionStatus.completed,
      );
      expect(mediaShare.lastOpenedContact, '+573203527283');
      expect(mediaShare.lastSentText, 'Hola Emm, prueba automatizada completada');
      expect(mediaShare.lastAutoSend, isTrue);
    });

    test('Prueba 3: Enviar documento PDF a Emm', () async {
      const goal = 'envíale un documento a (Emm) (/sdcard/Download/Informe_Ejecutivo_-_Datos_Shell.pdf) en whatsapp';

      final flow = catalog.forGoal(goal);
      expect(flow, isNotNull);
      expect(flow!.steps.first.tool, 'whatsapp.share_file');

      final intent = WhatsAppIntentParser.parse(goal);
      expect(intent, isNotNull);
      expect(intent!.action, WhatsAppAction.shareFile);
      expect(intent.contact, 'Emm');
      expect(intent.filePath, '/sdcard/Download/Informe_Ejecutivo_-_Datos_Shell.pdf');

      final result = await handler.shareFile(
        ToolCall(
          tool: 'whatsapp.share_file',
          args: {
            'contact': intent.contact,
            'path': intent.filePath!,
            'caption': 'Informe PDF enviado',
          },
        ),
      );

      expect(result, contains('Archivo listo para "Emm" (+573203527283)'));
      expect(
        PlanExecutionCoordinator.executionStatusFor(result),
        ToolExecutionStatus.completed,
      );
      expect(mediaShare.lastSharedContact, '+573203527283');
      expect(mediaShare.lastSharedPath, '/sdcard/Download/Informe_Ejecutivo_-_Datos_Shell.pdf');
    });

    test('Prueba 4: Enviar foto a Emm', () async {
      const goal = 'envíale una foto a (Emm) (/sdcard/Pictures/file_0000000013e481f58825cd146c7e1f06.png) en whatsapp';

      final flow = catalog.forGoal(goal);
      expect(flow, isNotNull);
      expect(flow!.steps.first.tool, 'whatsapp.share_file');

      final intent = WhatsAppIntentParser.parse(goal);
      expect(intent, isNotNull);
      expect(intent!.action, WhatsAppAction.shareFile);
      expect(intent.contact, 'Emm');
      expect(intent.filePath, '/sdcard/Pictures/file_0000000013e481f58825cd146c7e1f06.png');

      final result = await handler.shareFile(
        ToolCall(
          tool: 'whatsapp.share_file',
          args: {
            'contact': intent.contact,
            'path': intent.filePath!,
            'caption': 'Foto de prueba',
          },
        ),
      );

      expect(result, contains('Archivo listo para "Emm" (+573203527283)'));
      expect(
        PlanExecutionCoordinator.executionStatusFor(result),
        ToolExecutionStatus.completed,
      );
      expect(mediaShare.lastSharedContact, '+573203527283');
      expect(mediaShare.lastSharedPath, '/sdcard/Pictures/file_0000000013e481f58825cd146c7e1f06.png');
    });

    test('Prueba 5: Gobernanza y registro de whatsapp.share_file en ToolRegistry', () {
      final registry = ToolRegistry.builtin;
      final tool = registry.lookup('whatsapp.share_file');
      expect(tool, isNotNull, reason: 'whatsapp.share_file debe estar en ToolRegistry');
      expect(tool!.name, 'whatsapp.share_file');
      expect(tool.requiresConfirmation, isFalse);

      final alias = registry.lookup('compartir');
      expect(alias, isNotNull);
      expect(alias!.name, 'whatsapp.share_file');

      final policy = PolicyEngine(registry: registry);
      final decision = policy.decide('whatsapp.share_file', stepsUsed: 0);
      expect(decision.allowed, isTrue, reason: 'La política debe permitir la herramienta');
      expect(decision.denied, isFalse);
    });

    test('Prueba 6: Desde llamadas busca a (Emm) en whatsapp y envíale un mensaje', () async {
      const goal = 'desde llamadas en whatsapp busca a (Emm) y entra a su chat y envíale un mensaje (Hola Emm, mensaje desde llamadas)';

      final flow = catalog.forGoal(goal);
      expect(flow, isNotNull, reason: 'El catálogo debe capturar flujo desde llamadas');
      expect(flow!.steps.first.tool, 'whatsapp.send_message');

      final intent = WhatsAppIntentParser.parse(goal);
      expect(intent, isNotNull);
      expect(intent!.action, WhatsAppAction.sendMessage);
      expect(intent.contact, 'Emm');
      expect(intent.message, 'Hola Emm, mensaje desde llamadas');

      final result = await handler.sendMessage(
        ToolCall(
          tool: 'whatsapp.send_message',
          args: {'contact': intent.contact, 'text': intent.message!},
        ),
      );

      expect(result, contains('Mensaje enviado a "Emm" (+573203527283)'));
      expect(mediaShare.lastOpenedContact, '+573203527283');
      expect(mediaShare.lastSentText, 'Hola Emm, mensaje desde llamadas');
      expect(mediaShare.lastAutoSend, isTrue);
    });

    test('Prueba 7: Buscar al contacto por su número (3203527283) y resolver a Emm', () async {
      const goal = 'busca a (3203527283) en whatsapp';

      final flow = catalog.forGoal(goal);
      expect(flow, isNotNull, reason: 'El catálogo debe capturar búsqueda por número');
      expect(flow!.steps.first.tool, 'whatsapp.open_chat');

      final intent = WhatsAppIntentParser.parse(goal);
      expect(intent, isNotNull);
      expect(intent!.action, WhatsAppAction.findContact);
      expect(intent.contact, '3203527283');

      final result = await handler.openChat(
        ToolCall(tool: 'whatsapp.open_chat', args: {'contact': intent.contact}),
      );

      expect(result, contains('Chat abierto con "Emm" (+573203527283)'));
      expect(mediaShare.lastOpenedContact, '+573203527283');
      expect(
        PlanExecutionCoordinator.executionStatusFor(result),
        ToolExecutionStatus.completed,
      );
    });

    test('Prueba 8: Escribirle y enviarle mensaje a número directo (3203527283)', () async {
      const goal = 'escríbele a (3203527283) (Hola Emm, prueba automatizada buscando por numero) en whatsapp';

      final flow = catalog.forGoal(goal);
      expect(flow, isNotNull, reason: 'El catálogo debe capturar envío por número');
      expect(flow!.steps.first.tool, 'whatsapp.send_message');

      final intent = WhatsAppIntentParser.parse(goal);
      expect(intent, isNotNull);
      expect(intent!.action, WhatsAppAction.sendMessage);
      expect(intent.contact, '3203527283');
      expect(intent.message, 'Hola Emm, prueba automatizada buscando por numero');

      final result = await handler.sendMessage(
        ToolCall(
          tool: 'whatsapp.send_message',
          args: {'contact': intent.contact, 'text': intent.message!},
        ),
      );

      expect(result, contains('Mensaje enviado a "Emm" (+573203527283)'));
      expect(mediaShare.lastOpenedContact, '+573203527283');
      expect(mediaShare.lastSentText, 'Hola Emm, prueba automatizada buscando por numero');
      expect(mediaShare.lastAutoSend, isTrue);
      expect(
        PlanExecutionCoordinator.executionStatusFor(result),
        ToolExecutionStatus.completed,
      );
    });
  });
}
