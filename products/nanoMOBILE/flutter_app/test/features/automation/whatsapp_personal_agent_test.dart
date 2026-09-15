import 'package:flutter_test/flutter_test.dart';
import 'package:nanoai/features/automation/domain/automation_result.dart';
import 'package:nanoai/features/automation/engine/business/business_facts.dart';
import 'package:nanoai/features/automation/engine/conversation/conversation_reply_composer.dart';
import 'package:nanoai/features/automation/engine/language/pragmatic_fast_path.dart';
import 'package:nanoai/features/automation/engine/messaging/conversation_key.dart';
import 'package:nanoai/features/automation/engine/messaging/messaging_package.dart';
import 'package:nanoai/features/automation/engine/notifications/conversation_understanding.dart';
import 'package:nanoai/features/automation/engine/notifications/notification_draft_writer.dart';
import 'package:nanoai/features/automation/engine/notifications/notification_object.dart';
import 'package:nanoai/features/automation/engine/scheduling/rule_dispatcher.dart';
import 'package:nanoai/features/automation/engine/scheduling/scheduled_rule.dart';
import 'package:nanoai/features/automation/engine/scheduling/trigger.dart';
import 'package:nanoai/features/automation/engine/scheduling/turn_supersede_guard.dart';
import 'package:nanoai/features/automation/personal_agent/application/conversation_decision_engine.dart';
import 'package:nanoai/features/automation/personal_agent/domain/conversation_agent_role.dart';
import 'package:nanoai/features/automation/personal_agent/domain/conversation_autonomy_mode.dart';
import 'package:nanoai/features/automation/personal_agent/domain/conversation_decision.dart';

NotificationObject _createNotification({
  required String text,
  String sender = 'Juan Perez',
  String packageName = 'com.whatsapp',
  String key = 'wa_key_001',
  int postTime = 1000000,
  String shortcutId = 'sc_juan',
  String locusId = 'loc_juan',
}) {
  return NotificationObject(
    key: key,
    packageName: packageName,
    title: sender,
    text: text,
    messageText: text,
    messageTimestamp: postTime,
    sender: sender,
    senderKey: 'pk_$sender',
    senderUri: 'tel:5551234',
    conversationTitle: sender,
    conversationId: 'conv_$sender',
    shortcutId: shortcutId,
    locusId: locusId,
    accountHint: '',
    isGroup: false,
    isSummary: false,
    postTime: postTime,
    canReply: true,
    remoteInputKey: 'quick_reply',
    actionIndex: 0,
    actions: const ['Responder'],
    ongoing: false,
  );
}

void main() {
  group('WhatsApp Personal Agent — Router de Roles Determinista', () {
    test('Saludo puro enruta a rol PERSONAL sin intención comercial', () {
      final routing = routeConversationAgent(
        messageText: 'Hola',
        facts: const BusinessFacts(),
        hasRelationship: true,
        hasActiveProduct: false,
      );
      expect(routing.role, ConversationAgentRole.personal);
      expect(routing.commercialIntent, isFalse);
    });

    test('Pregunta de producto enruta a SALES con commercialIntent=true', () {
      final facts = BusinessFacts(
        products: const [
          BusinessProduct(
            id: 'p1',
            name: 'teléfono',
            details: 'negro',
            price: 500,
            stock: 2,
          ),
        ],
      );
      final routing = routeConversationAgent(
        messageText: '¿Cuánto vale el teléfono negro?',
        facts: facts,
        hasRelationship: false,
        hasActiveProduct: false,
      );
      expect(routing.role, ConversationAgentRole.sales);
      expect(routing.commercialIntent, isTrue);
    });

    test('Social casual ("que haces bro") enruta a rol PERSONAL', () {
      final routing = routeConversationAgent(
        messageText: 'que haces bro',
        facts: const BusinessFacts(),
        hasRelationship: true,
        hasActiveProduct: false,
      );
      expect(routing.role, ConversationAgentRole.personal);
      expect(routing.commercialIntent, isFalse);
    });

    test('Risas informales y desordenadas ("Jajajsjsjsja") enrutan a rol PERSONAL', () {
      final routing = routeConversationAgent(
        messageText: 'Jajajsjsjsja',
        facts: const BusinessFacts(),
        hasRelationship: true,
        hasActiveProduct: false,
      );
      expect(routing.role, ConversationAgentRole.personal);
      expect(routing.commercialIntent, isFalse);
    });

    test('Pregunta de familia/dueño ("¿está tu papá?") enruta a rol PERSONAL', () {
      final routing = routeConversationAgent(
        messageText: '¿está tu papá en la casa?',
        facts: const BusinessFacts(),
        hasRelationship: true,
        hasActiveProduct: false,
      );
      expect(routing.role, ConversationAgentRole.personal);
      expect(routing.commercialIntent, isFalse);
    });

    test('Mensaje misceláneo sin señales enruta a GENERAL', () {
      final routing = routeConversationAgent(
        messageText: 'Parece que mañana llueve en la tarde',
        facts: const BusinessFacts(),
        hasRelationship: false,
        hasActiveProduct: false,
      );
      expect(routing.role, ConversationAgentRole.general);
      expect(routing.commercialIntent, isFalse);
    });

    test('Turno mixto (personal + comercial) conserva commercialIntent para inyectar catálogo', () {
      final facts = BusinessFacts(
        products: const [
          BusinessProduct(
            id: 'p1',
            name: 'teléfono',
            details: 'negro',
            price: 500,
            stock: 2,
          ),
        ],
      );
      final routing = routeConversationAgent(
        messageText: 'Hola bro, ¿está Emmanuel y todavía tienen el negro?',
        facts: facts,
        hasRelationship: true,
        hasActiveProduct: false,
        ownerName: 'Emmanuel',
      );
      expect(routing.role, ConversationAgentRole.personal);
      expect(routing.commercialIntent, isTrue);
    });
  });

  group('WhatsApp Personal Agent — ConversationDecisionEngine (Gating y Veracidad)', () {
    const engine = ConversationDecisionEngine();

    test('Anti-Eco: Retiene para aprobación si el modelo repitió el mensaje del cliente', () {
      const understanding = ConversationUnderstanding(
        reply: 'Bien y tú, ¿cómo estás?',
        intent: 'saludo',
        requiresAction: false,
      );
      final context = const ConversationDecisionContext(
        userText: 'BIEN Y TU COMO ESTAS?',
        agentRole: ConversationAgentRole.personal,
        autonomyMode: ConversationAutonomyMode.safeAuto,
      );

      final decision = engine.decide(
        understanding: understanding,
        context: context,
      );

      expect(decision.disposition, ConversationDisposition.holdForApproval);
      expect(
        decision.reasons.any((r) => r.contains('reply eco del cliente')),
        isTrue,
      );
    });

    test('Anti-Callcenter: Repara muletillas de operador en turnos personales', () {
      const understanding = ConversationUnderstanding(
        reply: '¡Hola! ¿En qué puedo ayudarte hoy?',
        intent: 'saludo',
        requiresAction: false,
      );
      final context = const ConversationDecisionContext(
        userText: 'Hola',
        agentRole: ConversationAgentRole.personal,
        autonomyMode: ConversationAutonomyMode.safeAuto,
      );

      final decision = engine.decide(
        understanding: understanding,
        context: context,
      );

      expect(decision.disposition, ConversationDisposition.qualityRepair);
      expect(decision.repairedText, isNotNull);
      expect(decision.repairedText, isNot(contains('¿En qué puedo ayudarte')));
      expect(
        decision.reasons.any((r) => r.contains('calidad reparada') || r.contains('call-center')),
        isTrue,
      );
    });

    test('Question Mirror: Repara si el modelo espeja preguntas de actividad sin datos', () {
      const understanding = ConversationUnderstanding(
        reply: '¿Y tú qué haces hoy?',
        intent: 'actividad',
        requiresAction: false,
      );
      final context = const ConversationDecisionContext(
        userText: '¿Qué haces hoy?',
        agentRole: ConversationAgentRole.personal,
        autonomyMode: ConversationAutonomyMode.safeAuto,
      );

      final decision = engine.decide(
        understanding: understanding,
        context: context,
      );

      expect(decision.disposition, ConversationDisposition.qualityRepair);
      expect(decision.repairedText, isNotNull);
      expect(
        decision.reasons.any((r) => r.contains('calidad reparada') || r.contains('LIVE STATE')),
        isTrue,
      );
    });

    test('Soberanía Humana: Retiene SIEMPRE si el dueño tiene el control del chat', () {
      const understanding = ConversationUnderstanding(
        reply: 'Hola Juan, todo bien.',
        intent: 'saludo',
        requiresAction: false,
      );
      final context = const ConversationDecisionContext(
        humanOwnsConversation: true,
        userText: 'Hola',
        agentRole: ConversationAgentRole.personal,
        autonomyMode: ConversationAutonomyMode.autonomous,
      );

      final decision = engine.decide(
        understanding: understanding,
        context: context,
      );

      expect(decision.disposition, ConversationDisposition.holdForApproval);
      expect(decision.confidence, 0.0);
      expect(
        decision.reasons.any((r) => r.contains('humano controla la conversación')),
        isTrue,
      );
    });

    test('Identidad Débil: Retiene si no hay evidencia de plataforma (< safeToWriteThreshold)', () {
      const understanding = ConversationUnderstanding(
        reply: 'Hola Juan, todo bien.',
        intent: 'saludo',
        requiresAction: false,
      );
      final context = const ConversationDecisionContext(
        identityConfidence: 0.35, // Título a secas (< 0.60)
        userText: 'Hola',
        agentRole: ConversationAgentRole.personal,
        autonomyMode: ConversationAutonomyMode.safeAuto,
      );

      final decision = engine.decide(
        understanding: understanding,
        context: context,
      );

      expect(decision.disposition, ConversationDisposition.holdForApproval);
      expect(
        decision.reasons.any((r) => r.contains('identidad débil')),
        isTrue,
      );
    });

    test('Modo Desactivado: Silencio absoluto sin envíos', () {
      const understanding = ConversationUnderstanding(
        reply: 'Hola!',
        intent: 'saludo',
        requiresAction: false,
      );
      final context = const ConversationDecisionContext(
        autonomyMode: ConversationAutonomyMode.disabled,
        userText: 'Hola',
      );

      final decision = engine.decide(
        understanding: understanding,
        context: context,
      );

      expect(decision.disposition, ConversationDisposition.holdForApproval);
      expect(decision.confidence, 0.0);
    });

    test('SafeAuto con Hechos Faltantes: Retiene afirmaciones de datos ausentes', () {
      const understanding = ConversationUnderstanding(
        reply: 'El teléfono vale \$500.',
        intent: 'precio',
        missingFacts: ['precio_telefono'],
        requiresAction: false,
      );
      final context = const ConversationDecisionContext(
        autonomyMode: ConversationAutonomyMode.safeAuto,
        agentRole: ConversationAgentRole.sales,
        userText: '¿Cuánto vale?',
      );

      final decision = engine.decide(
        understanding: understanding,
        context: context,
      );

      expect(decision.disposition, ConversationDisposition.holdForApproval);
      expect(
        decision.reasons.any((r) => r.contains('alucinación')),
        isTrue,
      );
    });

    test('Flujo Exitoso: Saludo natural y limpio autoriza autoSend', () {
      const understanding = ConversationUnderstanding(
        reply: 'Hola Juan, ¿cómo estás?',
        intent: 'saludo',
        requiresAction: false,
      );
      final context = const ConversationDecisionContext(
        userText: 'Hola',
        agentRole: ConversationAgentRole.personal,
        autonomyMode: ConversationAutonomyMode.safeAuto,
        identityConfidence: 1.0,
      );

      final decision = engine.decide(
        understanding: understanding,
        context: context,
      );

      expect(decision.disposition, ConversationDisposition.autoSend);
      expect(decision.confidence, greaterThanOrEqualTo(0.60));
    });
  });

  group('WhatsApp Personal Agent — PragmaticFastPath', () {
    const fastPath = PragmaticFastPath();

    test('Resuelve saludo puro en <1ms sin invocar al motor LLM', () async {
      final res = await fastPath.resolve(
        text: 'Hola',
        conversationId: 'conv_123',
      );

      expect(res, isNotNull);
      expect(res!.act, contains('greeting'));
      expect(res.reply.isNotEmpty, isTrue);
      expect(res.understanding.intent, contains('greeting'));
    });

    test('Resuelve agradecimiento puro sin invocar al motor LLM', () async {
      final res = await fastPath.resolve(
        text: 'Muchas gracias por todo!',
        conversationId: 'conv_123',
      );

      expect(res, isNotNull);
      expect(res!.act, contains('thanks'));
      expect(res.reply.isNotEmpty, isTrue);
      expect(res.understanding.intent, contains('thanks'));
    });

    test('Pregunta substantiva retorna null para activar el pipeline LLM', () async {
      final res = await fastPath.resolve(
        text: '¿Tienen disponible la camiseta en talla M?',
        conversationId: 'conv_123',
      );

      expect(res, isNull);
    });
  });

  group('WhatsApp Personal Agent — TurnSupersedeGuard', () {
    test('Mensaje nuevo incrementa la versión monotónica de la conversación', () {
      final guard = TurnSupersedeGuard();
      const convId = 'conv_juan';

      expect(guard.versionOf(convId), 0);
      final v1 = guard.bump(convId);
      expect(v1, 1);
      expect(guard.versionOf(convId), 1);

      // Llega un segundo mensaje del mismo chat
      final v2 = guard.bump(convId);
      expect(v2, 2);
      expect(guard.versionOf(convId), 2);
      expect(v2, greaterThan(v1));
    });

    test('Mensajes de conversaciones distintas tienen secuencias monotónicas independientes', () {
      final guard = TurnSupersedeGuard();
      const convA = 'conv_a';
      const convB = 'conv_b';

      final vA1 = guard.bump(convA);
      final vB1 = guard.bump(convB);
      expect(guard.versionOf(convA), vA1);
      expect(guard.versionOf(convB), vB1);

      final vA2 = guard.bump(convA);
      expect(guard.versionOf(convA), vA2);
      expect(guard.versionOf(convB), vB1); // B no cambia
    });

    test('Borrador en vuelo superado por nuevo mensaje es ignorado honestamente en RuleDispatcher', () async {
      final guard = TurnSupersedeGuard();
      final executedActions = <String>[];

      final dispatcher = RuleDispatcher(
        (goal, {options}) async {
          executedActions.add(goal.text);
          return const AutomationResult(
            executionId: 'exec_01',
            status: AutomationResultStatus.completed,
            reason: 'ok',
          );
        },
        supersedeGuard: guard,
        draftSource: (notif) async {
          // Simulamos que durante la redacción LLM llega un nuevo mensaje del mismo chat
          final convId = resolveConversationIdentity(notif).key.id;
          guard.bump(convId);
          return const NotificationDraftResult(
            reply: 'Respuesta vieja que no debe enviarse',
            understanding: ConversationUnderstanding(
              reply: 'Respuesta vieja que no debe enviarse',
              intent: 'saludo',
            ),
          );
        },
        decisionContext: (_) => const ConversationDecisionContext(
          agentRole: ConversationAgentRole.personal,
          autonomyMode: ConversationAutonomyMode.autonomous,
          identityConfidence: 1.0,
        ),
      );

      final notif = _createNotification(text: 'Mensaje inicial');
      final convId = resolveConversationIdentity(notif).key.id;
      // Registramos versión inicial antes del dispatch
      guard.bump(convId);

      final rule = ScheduledRule(
        id: 'rule_dynamic',
        trigger: const NotificationTrigger(packageName: 'com.whatsapp'),
        action: RuleAction.reply,
        enabled: true,
        dynamicReply: true,
        createdAt: DateTime.now(),
      );

      final result = await dispatcher.dispatch(rule, notif);

      expect(result.outcome, RuleOutcome.ignored);
      expect(result.reason, contains('turno superado'));
      expect(executedActions, isEmpty); // Jamás se ejecutó la acción de envío
    });
  });

  group('WhatsApp Personal Agent — RuntimeConversationReplyComposer', () {
    test('Compone mediante FastPath para saludos puros', () async {
      final composer = RuntimeConversationReplyComposer(
        draftSource: (notif) async => throw StateError('No debe llamar a LLM'),
        fastPath: const PragmaticFastPath(),
      );

      final notif = _createNotification(text: 'Hola');
      final result = await composer.compose(notif);

      expect(result, isNotNull);
      expect(result!.isFastPath, isTrue);
      expect(result.text.isNotEmpty, isTrue);
      expect(result.suggestions.isNotEmpty, isTrue);
    });

    test('Canal Business deshabilita FastPath para asegurar tratamiento comercial', () async {
      var llmCalled = false;
      final composer = RuntimeConversationReplyComposer(
        draftSource: (notif) async {
          llmCalled = true;
          return const NotificationDraftResult(
            reply: '¡Hola! Bienvenido a nuestra tienda.',
            understanding: ConversationUnderstanding(
              reply: '¡Hola! Bienvenido a nuestra tienda.',
              intent: 'saludo_comercial',
            ),
          );
        },
        fastPath: const PragmaticFastPath(),
      );

      final notif = _createNotification(
        text: 'Hola',
        packageName: MessagingPackage.whatsappBusiness,
      );
      final result = await composer.compose(notif);

      expect(result, isNotNull);
      expect(result!.isFastPath, isFalse);
      expect(llmCalled, isTrue);
      expect(result.text, contains('tienda'));
    });

    test('Inferencia LLM pasa por limpieza y decisión determinista', () async {
      final composer = RuntimeConversationReplyComposer(
        draftSource: (notif) async {
          return const NotificationDraftResult(
            reply: 'Sí, tenemos stock disponible del producto negro.',
            understanding: ConversationUnderstanding(
              reply: 'Sí, tenemos stock disponible del producto negro.',
              intent: 'consulta_stock',
              relation: 'continua',
              options: ['Sí, lo tenemos.', 'Tenemos stock para entrega inmediata.'],
            ),
          );
        },
        decisionContext: (notif) => const ConversationDecisionContext(
          agentRole: ConversationAgentRole.sales,
          autonomyMode: ConversationAutonomyMode.safeAuto,
          identityConfidence: 1.0,
        ),
      );

      final notif = _createNotification(text: '¿Tienen stock del negro?');
      final result = await composer.compose(notif);

      expect(result, isNotNull);
      expect(result!.isFastPath, isFalse);
      expect(result.understanding.relation, 'continua');
      expect(result.decision.disposition, ConversationDisposition.autoSend);
      expect(result.suggestions.length, greaterThanOrEqualTo(2));
    });
  });
}
