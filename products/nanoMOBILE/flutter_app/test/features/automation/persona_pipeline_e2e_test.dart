import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nanoai/features/automation/engine/conversation/conversation_reply_composer.dart';
import 'package:nanoai/features/automation/engine/conversation/persona_style_resolver.dart';
import 'package:nanoai/features/automation/engine/notifications/notification_object.dart';
import 'package:nanoai/features/automation/personal_agent/application/persona_import.dart';
import 'package:nanoai/features/automation/personal_agent/application/persona_repository.dart';
import 'package:nanoai/features/automation/personal_agent/application/persona_retriever.dart';
import 'package:nanoai/features/automation/personal_agent/domain/conversation_agent_role.dart';
import 'package:nanoai/features/automation/personal_agent/domain/conversation_autonomy_mode.dart';
import 'package:nanoai/features/automation/personal_agent/domain/conversation_decision.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Persona Pipeline E2E (Import WhatsApp TXT -> FTS4 Retrieval -> Style Match)', () {
    const channelName = 'com.nanoai/automation_store';
    late List<Map<String, dynamic>> storeExamples;

    setUp(() {
      storeExamples = [];
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(const MethodChannel(channelName), (MethodCall call) async {
        if (call.method == 'exampleSearch') {
          final query = (call.arguments['query'] as String? ?? '').toLowerCase();
          final matches = storeExamples.where((e) {
            final inc = (e['incomingText'] as String? ?? '').toLowerCase();
            final body = (e['body'] as String? ?? '').toLowerCase();
            return inc.contains(query) || body.contains(query) ||
                query.split(' ').any((w) => w.length > 2 && (inc.contains(w) || body.contains(w)));
          }).toList();
          return matches;
        }
        return null;
      });
    });

    tearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(const MethodChannel(channelName), null);
    });

    test('WhatsApp TXT parsea pares y genera candidatos verificados', () {
      const chatContent = '12/03/24, 10:14 - Juan Pérez: Hola Emma, ¿cuándo sale la nueva versión de la app?\n'
          '12/03/24, 10:15 - Emmanuel Higuita: Hola Juan! La sacamos el próximo viernes con el nuevo motor.\n'
          '12/03/24, 10:16 - Juan Pérez: Listo de una, muchas gracias bro!\n'
          '12/03/24, 10:16 - Emmanuel Higuita: Dale hermano con gusto!\n';

      const pipeline = PersonaImportPipeline();
      final preview = pipeline.parse(
        content: chatContent,
        fileName: 'chat_juan.txt',
        scopeKey: 'owner',
        ownerName: 'Emmanuel Higuita',
      );

      expect(preview.candidates, isNotEmpty);
      final pairs = preview.candidates.where((c) => c.kind == 'paired').toList();
      expect(pairs.length, equals(2));

      final firstPair = pairs[0].example!;
      expect(firstPair['incomingText'], contains('¿cuándo sale la nueva versión'));
      expect(firstPair['body'], contains('La sacamos el próximo viernes'));

      final acceptedData = preview.accepted({0, 1}, ownerVerified: true);
      final acceptedExamples = acceptedData['examples'] as List<Map<String, Object?>>;
      expect(acceptedExamples.length, equals(2));
      expect((acceptedExamples[0]['tone'] as Map)['ownerVerified'], equals('true'));
    });

    test('PersonaStyleResolver resuelve consulta similar a partir de ejemplo importado', () async {
      storeExamples.add({
        'id': 101,
        'personaKey': 'owner',
        'body': 'Hola Juan! La sacamos el próximo viernes con el nuevo motor.',
        'incomingText': 'Hola Emma, ¿cuándo sale la nueva versión de la app?',
        'toneJson': jsonEncode({'ownerVerified': 'true', 'enabled': 'true'}),
        'source': 'import',
      });

      final retriever = PersonaRetriever(repository: PersonaRepository.instance);
      final resolver = RuntimePersonaStyleResolver(retriever: retriever);

      final match = await resolver.resolve(
        text: '¿cuándo sale la nueva versión de la app?',
        conversationId: 'wa_juan',
        minConfidence: 0.60,
      );

      expect(match, isNotNull);
      expect(match!.reply, contains('La sacamos el próximo viernes'));
      expect(match.confidence, greaterThanOrEqualTo(0.60));
      expect(match.understanding.intent, equals('persona_style_match'));
    });

    test('ConversationReplyComposer usa PersonaStyleResolver como vía primaria sin LLM', () async {
      storeExamples.add({
        'id': 102,
        'personaKey': 'owner',
        'body': 'Bien parcero, trabajando en la app a full.',
        'incomingText': 'Hola Emma cómo estás?',
        'toneJson': jsonEncode({'ownerVerified': 'true', 'enabled': 'true'}),
        'source': 'import',
      });

      final retriever = PersonaRetriever(repository: PersonaRepository.instance);
      final resolver = RuntimePersonaStyleResolver(retriever: retriever);

      final composer = RuntimeConversationReplyComposer(
        draftSource: (n) async => null, // LLM apagado
        styleResolver: resolver,
        decisionContext: (n) => const ConversationDecisionContext(
          agentRole: ConversationAgentRole.personal,
          autonomyMode: ConversationAutonomyMode.safeAuto,
          identityConfidence: 1.0,
        ),
      );

      final notif = NotificationObject(
        key: 'wa_test_hola_emma',
        packageName: 'com.whatsapp',
        title: 'Carlos',
        text: 'Hola Emma cómo estás?',
        messageText: 'Hola Emma cómo estás?',
        messageTimestamp: DateTime.now().millisecondsSinceEpoch,
        sender: 'Carlos',
        senderKey: 'carlos',
        senderUri: '',
        conversationTitle: 'Carlos',
        conversationId: 'wa_carlos',
        shortcutId: 'shortcut_wa_carlos',
        locusId: 'locus_wa_carlos',
        accountHint: '',
        isGroup: false,
        isSummary: false,
        postTime: DateTime.now().millisecondsSinceEpoch,
        canReply: true,
        remoteInputKey: 'key_reply',
        actionIndex: 0,
        actions: const ['Responder'],
        ongoing: false,
      );

      final result = await composer.compose(notif);
      expect(result, isNotNull);
      expect(result!.isFastPath, isTrue); // Determinista, 0 LLM
      expect(result.text, contains('Bien parcero'));
      expect(result.decision.disposition, equals(ConversationDisposition.autoSend));
    });
  });
}
