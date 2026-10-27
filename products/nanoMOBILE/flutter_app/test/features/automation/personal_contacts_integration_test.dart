import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nanoai/features/automation/personal_agent/application/personal_contacts_repository.dart';
import 'package:nanoai/features/automation/personal_agent/application/persona_context.dart';
import 'package:nanoai/features/automation/personal_agent/application/conversation_decision_engine.dart';
import 'package:nanoai/features/automation/personal_agent/domain/conversation_decision.dart';
import 'package:nanoai/features/automation/personal_agent/domain/conversation_autonomy_mode.dart';
import 'package:nanoai/features/automation/engine/notifications/conversation_understanding.dart';
import 'package:nanoai/features/automation/personal_agent/domain/personal_contact_policy.dart';
import 'package:nanoai/features/automation/engine/scheduling/rule_dispatcher.dart';
import 'package:nanoai/features/automation/engine/scheduling/scheduled_rule.dart';
import 'package:nanoai/features/automation/engine/scheduling/trigger.dart';
import 'package:nanoai/features/automation/engine/notifications/notification_object.dart';
import 'package:nanoai/features/automation/domain/automation_result.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('com.nanoai/automation_store');
  var relationships = <String, Map<String, dynamic>>{};
  var owners = <Map<String, dynamic>>[];
  setUp(() {
    relationships = {};
    owners = [];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          final args = call.arguments is Map ? call.arguments as Map : {};
          switch (call.method) {
            case 'personaList':
              return owners;
            case 'relationshipList':
              return relationships.values.toList();
            case 'relationshipUpsert':
              relationships[args['relationshipKey'] as String] =
                  Map<String, dynamic>.from(args);
              return 1;
            case 'exampleList':
              return [];
            default:
              return [];
          }
        });
  });
  tearDown(
    () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null),
  );

  test(
    'Repetir un alta conserva una ficha con múltiples grupos y conversaciones',
    () async {
      final repo = PersonalContactsRepository();
      await repo.save(
        name: 'Juan',
        conversationIds: ['chat-a'],
        groups: ['Amigos cercanos', 'Clientes'],
        style: 'inherit',
        autoReply: false,
      );
      final contact = (await repo.load()).single;
      await repo.save(
        existing: contact,
        name: 'Juan',
        conversationIds: ['chat-a', 'chat-b'],
        groups: ['Amigos cercanos', 'Clientes'],
        style: 'formal',
        autoReply: false,
      );
      expect(relationships, hasLength(1));
      final facts = (await repo.load()).single.facts;
      expect(PersonalContactPolicy.list(facts['groups']), [
        'Amigos cercanos',
        'Clientes',
      ]);
      expect(
        PersonalContactPolicy.effectiveFacts(facts)['styleRegister'],
        'formal',
      );
      final context = PersonaContext();
      owners = [
        {
          'personaKey': 'owner',
          'displayName': 'Emmanuel',
          'factsJson': jsonEncode({
            'tone': jsonEncode({'emojis': true, 'verbosity': 'breve'}),
          }),
        },
      ];
      await context.load();
      expect(context.allowsAutoReplyFor('chat-a'), isFalse);
      expect(context.allowsAutoReplyFor('chat-b'), isFalse);
      final prompt = await context.personaBlockFor(
        'Hola',
        'Juan',
        conversationId: 'chat-a',
      );
      expect(prompt, contains('Emojis moderados'));
      expect(prompt, contains('Breve'));
      await expectLater(
        repo.save(
          existing: contact,
          name: 'Juan',
          conversationIds: ['chat-b'],
          groups: [],
          style: 'casual',
          autoReply: false,
        ),
        throwsStateError,
      );
    },
  );

  test(
    'Nombres iguales no se fusionan y una conversación no se asigna dos veces',
    () async {
      final repo = PersonalContactsRepository();
      for (final id in ['a', 'b']) {
        await repo.save(
          name: 'Juan',
          conversationIds: [id],
          groups: ['Amigos'],
          style: 'casual',
          autoReply: true,
        );
      }
      expect(relationships, hasLength(2));
      await expectLater(
        repo.save(
          name: 'Otra persona',
          conversationIds: ['a'],
          groups: [],
          style: 'formal',
          autoReply: true,
        ),
        throwsStateError,
      );
      expect(relationships, hasLength(2));
    },
  );

  test(
    'Los contactos antiguos se recuperan una vez, sin adivinar la identidad',
    () async {
      owners = [
        {
          'personaKey': 'contact_1',
          'displayName': 'Ana',
          'factsJson': '{"styleRegister":"Formal","autoReply":"false"}',
        },
      ];
      final repo = PersonalContactsRepository();
      await repo.load();
      await repo.load();
      expect(relationships, hasLength(1));
      final recovered = (await repo.load()).single;
      expect(recovered.relationshipKey, startsWith('unbound:legacy:'));
      expect(recovered.facts['styleRegister'], 'formal');
      expect(PersonalContactPolicy.conversations(recovered), isEmpty);
    },
  );

  test(
    'La pausa horaria atraviesa medianoche y se aplica en el contexto real',
    () async {
      owners = [
        {
          'personaKey': 'owner',
          'displayName': 'Emmanuel',
          'factsJson': jsonEncode({
            'quietHoursEnabled': 'true',
            'quietHoursStart': '1380',
            'quietHoursEnd': '360',
          }),
        },
      ];
      final context = PersonaContext();
      expect(context.allowsAutoReplyFor('chat'), isFalse);
      await context.load();
      expect(
        context.allowsAutoReplyFor('chat', now: DateTime(2026, 10, 17, 23)),
        isFalse,
      );
      expect(
        context.allowsAutoReplyFor('chat', now: DateTime(2026, 10, 18, 5, 59)),
        isFalse,
      );
      expect(
        context.allowsAutoReplyFor('chat', now: DateTime(2026, 10, 18, 6)),
        isTrue,
      );
    },
  );

  test('Autonomía total no evita el bloqueo explícito de un contacto', () {
    final decision = const ConversationDecisionEngine().decide(
      understanding: const ConversationUnderstanding(reply: 'Hola'),
      context: const ConversationDecisionContext(
        autonomyMode: ConversationAutonomyMode.autonomous,
        personalAutoReplyAllowed: false,
      ),
    );
    expect(decision.disposition, ConversationDisposition.holdForApproval);
  });

  test(
    'Las reglas fijas respetan el permiso antes y después de la pausa',
    () async {
      final notification = NotificationObject.fromMap({
        'key': 'test',
        'package': 'com.whatsapp',
        'title': 'Juan',
        'sender': 'Juan',
        'text': 'hola',
        'messageText': 'hola',
        'shortcutId': 'juan',
        'canReply': true,
        'remoteInputKey': 'reply',
        'actionIndex': 0,
        'actions': ['Responder'],
        'postTime': DateTime.now().millisecondsSinceEpoch,
      });
      final rule = ScheduledRule(
        id: 'fixed',
        trigger: const NotificationTrigger(),
        action: RuleAction.reply,
        message: 'Hola',
        createdAt: DateTime.now(),
      );
      var allowed = false;
      var sends = 0;
      final dispatcher = RuleDispatcher(
        (goal, {options}) async {
          sends++;
          return const AutomationResult(
            executionId: 'unexpected',
            status: AutomationResultStatus.failed,
            reason: 'test',
          );
        },
        decisionContext: (_) => ConversationDecisionContext(
          autonomyMode: ConversationAutonomyMode.autonomous,
          personalAutoReplyAllowed: allowed,
        ),
        replyDelay: () {
          allowed = false;
          return const Duration(milliseconds: 5);
        },
      );
      await dispatcher.dispatch(rule, notification);
      expect(sends, 0);
      allowed = true;
      final delayed = await dispatcher.dispatch(rule, notification);
      expect(delayed.outcome, RuleOutcome.ignored);
      expect(sends, 0);
    },
  );
}
