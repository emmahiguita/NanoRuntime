import 'package:flutter_test/flutter_test.dart';
import 'package:nanoai/features/automation/domain/automation_result.dart';
import 'package:nanoai/features/automation/engine/business/business_facts.dart';
import 'package:nanoai/features/automation/engine/conversation/conversation_reply_composer.dart';
import 'package:nanoai/features/automation/engine/language/pragmatic_fast_path.dart';
import 'package:nanoai/features/automation/engine/language/turn_complexity_classifier.dart';
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
import 'package:nanoai/features/automation/engine/scheduling/burst_turn_gate.dart';
import 'package:nanoai/features/automation/engine/language/dialogue_state.dart';
import 'package:nanoai/features/automation/engine/language/safe_conversation_repair.dart';
import 'package:nanoai/features/automation/engine/language/safe_repair_options.dart';
import 'package:nanoai/features/automation/engine/messaging/conversation_memory.dart';
import 'package:nanoai/features/automation/engine/scheduling/event_dedupe_store.dart';

NotificationObject _createNotification({
  required String text,
  String sender = 'Juan Perez',
  String packageName = 'com.whatsapp',
  String key = 'wa_key_001',
  int postTime = 1000000,
  int? messageTimestamp,
  String shortcutId = 'sc_juan',
  String locusId = 'loc_juan',
  bool isSelf = false,
}) {
  return NotificationObject(
    key: key,
    packageName: packageName,
    title: sender,
    text: text,
    messageText: text,
    messageTimestamp: messageTimestamp ?? postTime,
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
    isSelf: isSelf,
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
      const facts = BusinessFacts(
        products: [
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

    test(
      'Risas informales y desordenadas ("Jajajsjsjsja") enrutan a rol PERSONAL',
      () {
        final routing = routeConversationAgent(
          messageText: 'Jajajsjsjsja',
          facts: const BusinessFacts(),
          hasRelationship: true,
          hasActiveProduct: false,
        );
        expect(routing.role, ConversationAgentRole.personal);
        expect(routing.commercialIntent, isFalse);
      },
    );

    test(
      'Pregunta de familia/dueño ("¿está tu papá?") enruta a rol PERSONAL',
      () {
        final routing = routeConversationAgent(
          messageText: '¿está tu papá en la casa?',
          facts: const BusinessFacts(),
          hasRelationship: true,
          hasActiveProduct: false,
        );
        expect(routing.role, ConversationAgentRole.personal);
        expect(routing.commercialIntent, isFalse);
      },
    );

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

    test(
      'Turno mixto (personal + comercial) conserva commercialIntent para inyectar catálogo',
      () {
        const facts = BusinessFacts(
          products: [
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
      },
    );
  });

  group(
    'WhatsApp Personal Agent — ConversationDecisionEngine (Gating y Veracidad)',
    () {
      const engine = ConversationDecisionEngine();

      test(
        'Anti-Eco: Retiene para aprobación si el modelo repitió el mensaje del cliente',
        () {
          const understanding = ConversationUnderstanding(
            reply: 'Bien y tú, ¿cómo estás?',
            intent: 'saludo',
            requiresAction: false,
          );
          const context = ConversationDecisionContext(
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
        },
      );

      test(
        'Anti-Callcenter: Repara muletillas de operador en turnos personales',
        () {
          const understanding = ConversationUnderstanding(
            reply: '¡Hola! ¿En qué puedo ayudarte hoy?',
            intent: 'saludo',
            requiresAction: false,
          );
          const context = ConversationDecisionContext(
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
          expect(
            decision.repairedText,
            isNot(contains('¿En qué puedo ayudarte')),
          );
          expect(
            decision.reasons.any(
              (r) =>
                  r.contains('calidad reparada') || r.contains('call-center'),
            ),
            isTrue,
          );
        },
      );

      test(
        'Question Mirror: Repara si el modelo espeja preguntas de actividad sin datos',
        () {
          const understanding = ConversationUnderstanding(
            reply: '¿Y tú qué haces hoy?',
            intent: 'actividad',
            requiresAction: false,
          );
          const context = ConversationDecisionContext(
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
            decision.reasons.any(
              (r) => r.contains('calidad reparada') || r.contains('LIVE STATE'),
            ),
            isTrue,
          );
        },
      );

      test(
        'Live State: "y que vas hacer hoy?" repara con planes honestos y no con desplazamiento ("si voy a ir hoy")',
        () {
          const understanding = ConversationUnderstanding(
            reply: 'Estoy trabajando en unas cosas.',
            intent: 'actividad',
            requiresAction: false,
          );
          const context = ConversationDecisionContext(
            userText: 'y que vas hacer hoy?',
            agentRole: ConversationAgentRole.personal,
            autonomyMode: ConversationAutonomyMode.autonomous,
          );

          final decision = engine.decide(
            understanding: understanding,
            context: context,
          );

          expect(decision.disposition, ConversationDisposition.qualityRepair);
          expect(decision.repairedText, isNotNull);
          expect(decision.repairedText, isNot(contains('si voy a ir hoy')));
          expect(decision.repairedText, contains('hacer hoy'));
        },
      );

      test(
        'Soberanía Humana: Retiene SIEMPRE si el dueño tiene el control del chat',
        () {
          const understanding = ConversationUnderstanding(
            reply: 'Hola Juan, todo bien.',
            intent: 'saludo',
            requiresAction: false,
          );
          const context = ConversationDecisionContext(
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
            decision.reasons.any(
              (r) => r.contains('humano controla la conversación'),
            ),
            isTrue,
          );
        },
      );

      test(
        'Identidad Débil: Retiene si no hay evidencia de plataforma (< safeToWriteThreshold)',
        () {
          const understanding = ConversationUnderstanding(
            reply: 'Hola Juan, todo bien.',
            intent: 'saludo',
            requiresAction: false,
          );
          const context = ConversationDecisionContext(
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
        },
      );

      test('Modo Desactivado: Silencio absoluto sin envíos', () {
        const understanding = ConversationUnderstanding(
          reply: 'Hola!',
          intent: 'saludo',
          requiresAction: false,
        );
        const context = ConversationDecisionContext(
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

      test(
        'SafeAuto con Hechos Faltantes: Retiene afirmaciones de datos ausentes',
        () {
          const understanding = ConversationUnderstanding(
            reply: 'El teléfono vale \$500.',
            intent: 'precio',
            missingFacts: ['precio_telefono'],
            requiresAction: false,
          );
          const context = ConversationDecisionContext(
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
        },
      );

      test('Flujo Exitoso: Saludo natural y limpio autoriza autoSend', () {
        const understanding = ConversationUnderstanding(
          reply: 'Hola Juan, ¿cómo estás?',
          intent: 'saludo',
          requiresAction: false,
        );
        const context = ConversationDecisionContext(
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
    },
  );

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

    test(
      'Resuelve pregunta recíproca de bienestar concluyendo sin rebotar la pregunta ("¿y tú?")',
      () async {
        final res1 = await fastPath.resolve(
          text: 'Bien y tu ?',
          conversationId: 'conv_123',
        );
        expect(res1, isNotNull);
        expect(res1!.act, contains('reciprocalQuestion'));
        expect(res1.reply.isNotEmpty, isTrue);
        // NO debe rebotar la pregunta "¿y tú?" o "¿y vos?" a quien ya contestó que está bien
        expect(res1.reply.toLowerCase().contains('y tú'), isFalse);
        expect(res1.reply.toLowerCase().contains('y tu'), isFalse);
        expect(res1.reply.toLowerCase().contains('y vos'), isFalse);

        final res2 = await fastPath.resolve(
          text: 'Estoy bien y tu ?',
          conversationId: 'conv_123',
        );
        expect(res2, isNotNull);
        expect(res2!.act, contains('reciprocalQuestion'));
        expect(res2.reply.isNotEmpty, isTrue);
        expect(res2.reply.toLowerCase().contains('y tú'), isFalse);
        expect(res2.reply.toLowerCase().contains('y tu'), isFalse);
        expect(res2.reply.toLowerCase().contains('y vos'), isFalse);

        final res3 = await fastPath.resolve(
          text: 'Bien Tk y tu!?',
          conversationId: 'conv_123',
        );
        expect(res3, isNotNull);
        expect(res3!.act, contains('reciprocalQuestion'));
        expect(res3.reply.isNotEmpty, isTrue);
        expect(res3.reply.toLowerCase().contains('y tú'), isFalse);
        expect(res3.reply.toLowerCase().contains('y tu'), isFalse);
        expect(res3.reply.toLowerCase().contains('y vos'), isFalse);
      },
    );

    test(
      'Resuelve aclaración de bienestar ("Ya te dije que estoy bien") de forma natural sin fallo de borrador',
      () async {
        final resClarification = await fastPath.resolve(
          text: 'Ya te dije que estoy bien',
          conversationId: 'conv_clarify',
        );
        expect(resClarification, isNotNull);
        expect(resClarification!.act, contains('wellbeingClarification'));
        expect(
          resClarification.reply,
          anyOf(
            contains('Ah bueno'),
            contains('Ah listo'),
            contains('Jaja bueno'),
            contains('Jaja listo'),
            contains('Listo pues'),
            contains('qué bien'),
            contains('todo bien'),
          ),
        );

        final resClarification2 = await fastPath.resolve(
          text: 'Te dije que bien',
          conversationId: 'conv_clarify2',
        );
        expect(resClarification2, isNotNull);
        expect(resClarification2!.act, contains('wellbeingClarification'));

        const classifier = TurnComplexityClassifier();
        expect(
          classifier.classify('Ya te dije que estoy bien').eligibleForSocialPrompt,
          isTrue,
        );
        expect(
          classifier.classify('Te dije que bien').eligibleForSocialPrompt,
          isTrue,
        );
      },
    );

    test(
      'Resuelve declaración pura de bienestar del interlocutor ("Bien", "Estoy bien", "Todo bien")',
      () async {
        final resWellbeing = await fastPath.resolve(
          text: 'Bien',
          conversationId: 'conv_wb',
        );
        expect(resWellbeing, isNotNull);
        expect(resWellbeing!.act, contains('userWellbeing'));
        expect(
          resWellbeing.reply.toLowerCase(),
          anyOf(
            contains('bueno'),
            contains('alegra'),
            contains('bien'),
          ),
        );

        final resWellbeing2 = await fastPath.resolve(
          text: 'Estoy bien',
          conversationId: 'conv_wb2',
        );
        expect(resWellbeing2, isNotNull);
        expect(resWellbeing2!.act, contains('userWellbeing'));
      },
    );

    test(
      'Resuelve saludo compuesto con bienestar ("Hola, ¿todo bien?") sin invocar al motor LLM',
      () async {
        final res = await fastPath.resolve(
          text: 'Hola, ¿todo bien?',
          conversationId: 'conv_123',
        );
        expect(res, isNotNull);
        expect(res!.reply.isNotEmpty, isTrue);

        final resUser = await fastPath.resolve(
          text: '¿Qué tal todo? ¿Cómo vas hoy?',
          conversationId: 'conv_user_phrase',
        );
        expect(resUser, isNotNull);
        expect(resUser!.reply.isNotEmpty, isTrue);
      },
    );

    test(
      'Resuelve reaseguro social ("me alegra", "qué bueno") con reciprocidad cálida y sin preguntas ni consultas',
      () async {
        final resAlegra = await fastPath.resolve(
          text: 'me alegra',
          conversationId: 'conv_alegra',
        );
        expect(resAlegra, isNotNull);
        expect(resAlegra!.reply.isNotEmpty, isTrue);
        expect(resAlegra.act, contains('socialReassurance'));
        expect(resAlegra.reply.contains('?'), isFalse);
        expect(resAlegra.reply.toLowerCase().contains('colaborar'), isFalse);
        expect(resAlegra.reply.toLowerCase().contains('porto alegre'), isFalse);

        final resQueBueno = await fastPath.resolve(
          text: 'qué bueno saberlo',
          conversationId: 'conv_bueno',
        );
        expect(resQueBueno, isNotNull);
        expect(resQueBueno!.reply.contains('?'), isFalse);
      },
    );

    test(
      'TurnComplexityClassifier clasifica preguntas recíprocas y compuestas como socialMinimal',
      () {
        const classifier = TurnComplexityClassifier();
        expect(
          classifier.classify('Hola, ¿todo bien?').eligibleForSocialPrompt,
          isTrue,
        );
        expect(
          classifier.classify('Bien y tu ?').eligibleForSocialPrompt,
          isTrue,
        );
        expect(
          classifier.classify('Bien Tk y tu!?').eligibleForSocialPrompt,
          isTrue,
        );
        expect(
          classifier.classify('Estoy bien y tu ?').eligibleForSocialPrompt,
          isTrue,
        );
        expect(
          classifier.classify('Hola cómo estás?').eligibleForSocialPrompt,
          isTrue,
        );
        // Contenido narrativo NO debe ser socialMinimal
        expect(
          classifier
              .classify('Hola todo bien? estoy trabajando en la oficina')
              .eligibleForSocialPrompt,
          isFalse,
        );
      },
    );

    test(
      'TurnComplexityClassifier clasifica actividad y bienestar como socialMinimal',
      () {
        const classifier = TurnComplexityClassifier();
        expect(
          classifier
              .classify('Me alegra que estés bien, que vas hacer hoy ?')
              .eligibleForSocialPrompt,
          isTrue,
        );
        expect(
          classifier.classify('que vas hacer hoy ?').eligibleForSocialPrompt,
          isTrue,
        );
        expect(
          classifier.classify('que vas a hacer hoy ?').eligibleForSocialPrompt,
          isTrue,
        );
        expect(
          classifier.classify('que haras hoy').eligibleForSocialPrompt,
          isTrue,
        );
        expect(
          classifier.classify('qué harás hoy?').eligibleForSocialPrompt,
          isTrue,
        );
        expect(
          classifier.classify('Hola, cómo estás ?').eligibleForSocialPrompt,
          isTrue,
        );
        expect(classifier.classify('Hol').eligibleForSocialPrompt, isTrue);
      },
    );

    test(
      'PragmaticFastPath responde a preguntas de actividad y planes ("que haras hoy") y tolera typos',
      () async {
        final resHaras = await fastPath.resolve(
          text: 'que haras hoy',
          conversationId: 'conv_haras',
        );
        expect(resHaras, isNotNull);
        expect(resHaras!.act, contains('askActivity'));
        expect(
          resHaras.reply.toLowerCase(),
          anyOf(
            contains('tranquilo'),
            contains('casa'),
            contains('cosas'),
            contains('nada'),
          ),
        );

        final resHarasAccent = await fastPath.resolve(
          text: '¿Qué harás hoy?',
          conversationId: 'conv_haras2',
        );
        expect(resHarasAccent, isNotNull);
        expect(resHarasAccent!.act, contains('askActivity'));

        final resActivity = await fastPath.resolve(
          text: 'Me alegra que estés bien, que vas hacer hoy ?',
          conversationId: 'conv_123',
        );
        expect(resActivity, isNotNull);
        expect(resActivity!.reply.isNotEmpty, isTrue);

        final resTypo = await fastPath.resolve(
          text: 'Hol',
          conversationId: 'conv_123',
        );
        expect(resTypo, isNotNull);
        expect(resTypo!.reply.isNotEmpty, isTrue);
      },
    );

    test(
      'PragmaticFastPath — Situaciones cotidianas ampliadas (10 nuevas categorías)',
      () async {
        // 1. Disponibilidad / Ocupación
        final rAvail = await fastPath.resolve(
          text: '¿Estás ocupado?',
          conversationId: 'conv_sit_1',
        );
        expect(rAvail, isNotNull);
        expect(rAvail!.act, contains('askAvailability'));
        expect(rAvail.reply, anyOf(contains('ocupado'), contains('momento')));

        // 2. Comida / Alimentación
        final rFood = await fastPath.resolve(
          text: '¿Ya almorzaste?',
          conversationId: 'conv_sit_2',
        );
        expect(rFood, isNotNull);
        expect(rFood!.act, contains('askFood'));
        expect(rFood.reply.toLowerCase(), anyOf(contains('almor'), contains('com'), contains('ando')));

        // 3. Ubicación física / Casa
        final rLoc = await fastPath.resolve(
          text: '¿Estás en la casa?',
          conversationId: 'conv_sit_3',
        );
        expect(rLoc, isNotNull);
        expect(rLoc!.act, contains('askPhysicalLocation'));
        expect(rLoc.reply.toLowerCase(), anyOf(contains('casa'), contains('acá'), contains('aquí'), contains('pendiente'), contains('vueltas'), contains('diligencias')));

        // 4. Familia / Entorno
        final rFam = await fastPath.resolve(
          text: '¿Cómo está tu familia?',
          conversationId: 'conv_sit_4',
        );
        expect(rFam, isNotNull);
        expect(rFam!.act, contains('askFamily'));
        expect(rFam.reply, anyOf(contains('Dios'), contains('bien')));

        // 5. Descanso / Noche
        final rSleep = await fastPath.resolve(
          text: '¿Vas a dormir?',
          conversationId: 'conv_sit_5',
        );
        expect(rSleep, isNotNull);
        expect(rSleep!.act, contains('askSleep'));
        expect(rSleep.reply.toLowerCase(), anyOf(contains('dormir'), contains('despierto'), contains('sueño'), contains('acuesto'), contains('pendiente'), contains('atento'), contains('desconectarme')));

        // 6. Música / Beats
        final rMusic = await fastPath.resolve(
          text: '¿Qué estás escuchando?',
          conversationId: 'conv_sit_6',
        );
        expect(rMusic, isNotNull);
        expect(rMusic!.act, contains('askMusic'));
        expect(rMusic.reply.toLowerCase(), anyOf(contains('rap'), contains('música'), contains('instrumentales'), contains('todo')));

        // 7. Clima
        final rWeather = await fastPath.resolve(
          text: '¿Está lloviendo por allá?',
          conversationId: 'conv_sit_7',
        );
        expect(rWeather, isNotNull);
        expect(rWeather!.act, contains('askWeatherSocial'));
        expect(rWeather.reply.toLowerCase(), anyOf(contains('clima'), contains('fresco'), contains('frío'), contains('nublado'), contains('tranquilo'), contains('acá')));

        // 8. Llamada
        final rCall = await fastPath.resolve(
          text: '¿Te puedo llamar?',
          conversationId: 'conv_sit_8',
        );
        expect(rCall, isNotNull);
        expect(rCall!.act, contains('askCall'));
        expect(rCall.reply.toLowerCase(), anyOf(contains('mensaje'), contains('texto'), contains('acá'), contains('llamada'), contains('ocupado')));

        // 9. Ausencia / Perdido
        final rLost = await fastPath.resolve(
          text: '¿Por qué tan perdido?',
          conversationId: 'conv_sit_9',
        );
        expect(rLost, isNotNull);
        expect(rLost!.act, contains('askLostOrMissing'));
        expect(rLost.reply.toLowerCase(), anyOf(contains('aquí'), contains('ocupado'), contains('trabajando'), contains('pendiente')));

        // 10. Opinión
        final rOp = await fastPath.resolve(
          text: '¿Cómo lo ves?',
          conversationId: 'conv_sit_10',
        );
        expect(rOp, isNotNull);
        expect(rOp!.act, contains('askOpinionSocial'));
        expect(rOp.reply.toLowerCase(), anyOf(contains('bien'), contains('bueno'), contains('bacano'), contains('aguanta')));
      },
    );

    test(
      'PragmaticFastPath — Matriz de Estilo Personal de Emmanuel: Rap, Invitaciones, Bienestar y Afirmaciones',
      () async {
        // Rap
        final resRap = await fastPath.resolve(
          text: 'vamos a rapear hoy?',
          conversationId: 'conv_rap',
        );
        expect(resRap, isNotNull);
        expect(resRap!.act, contains('askRap'));
        expect(
          resRap.reply.toLowerCase().contains('rap') ||
              resRap.reply.toLowerCase().contains('rimas'),
          isTrue,
        );

        // Invitación
        final resInv = await fastPath.resolve(
          text: '¿Vamos?',
          conversationId: 'conv_inv',
        );
        expect(resInv, isNotNull);
        expect(resInv!.act, contains('invitation'));
        final invitationReply = resInv.reply.toLowerCase();
        expect(
          invitationReply,
          anyOf(
            contains('vamos'),
            contains('hagámosle'),
            contains('dale'),
            contains('hora'),
            contains('bien'),
          ),
        );

        // Bienestar con "Bien, gracias a Dios"
        final resWellbeing = await fastPath.resolve(
          text: '¿Cómo estás?',
          conversationId: 'conv_wb',
        );
        expect(resWellbeing, isNotNull);
        expect(resWellbeing!.act, contains('askWellbeing'));
        expect(
          resWellbeing.reply,
          anyOf(contains('gracias a Dios'), contains('bien'), contains('Bien')),
        );

        // Afirmación
        final resAffirm = await fastPath.resolve(
          text: 'Sí de una',
          conversationId: 'conv_aff',
        );
        expect(resAffirm, isNotNull);
        expect(resAffirm!.act, contains('affirmation'));

        // Rechazo suave / negación
        final resDecline = await fastPath.resolve(
          text: 'hoy no creo',
          conversationId: 'conv_dec',
        );
        expect(resDecline, isNotNull);
        expect(resDecline!.act, contains('negation'));
      },
    );

    test(
      'Obligaciones no bloquean saludos y se limpian al enviar mensaje',
      () async {
        final memoryStore = MemoryConversationMemoryStore();
        memoryStore.addUnresolvedObligation('conv_test', '¿Cuánto vale?');

        final fastPathWithMemory = PragmaticFastPath(
          memoryFor: (id) => memoryStore.memoryFor(id),
        );

        // Saludo entrante NO debe ser bloqueado por obligaciones
        final greetingRes = await fastPathWithMemory.resolve(
          text: 'Hola',
          conversationId: 'conv_test',
        );
        expect(greetingRes, isNotNull);

        // Outbound limpia obligaciones
        memoryStore.appendOutbound(
          'conv_test',
          '¡Hola! ¿Cómo vas?',
          kind: ConversationMemoryEntryKind.outboundDispatched,
          atMs: DateTime.now().millisecondsSinceEpoch,
        );
        expect(
          memoryStore.memoryFor('conv_test')?.unresolvedObligations.isEmpty,
          isTrue,
        );
      },
    );

    test(
      'Pregunta substantiva retorna null para activar el pipeline LLM',
      () async {
        final res = await fastPath.resolve(
          text: '¿Tienen disponible la camiseta en talla M?',
          conversationId: 'conv_123',
        );

        expect(res, isNull);
      },
    );
  });

  group('WhatsApp Personal Agent — TurnSupersedeGuard', () {
    test(
      'Mensaje nuevo incrementa la versión monotónica de la conversación',
      () {
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
      },
    );

    test(
      'Mensajes de conversaciones distintas tienen secuencias monotónicas independientes',
      () {
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
      },
    );

    test(
      'Borrador en vuelo superado por nuevo mensaje es ignorado honestamente en RuleDispatcher',
      () async {
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
      },
    );
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

    test(
      'Canal Business deshabilita FastPath para asegurar tratamiento comercial',
      () async {
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
      },
    );

    test('Fallback a FastPath cuando draftSource LLM retorna null', () async {
      final composer = RuntimeConversationReplyComposer(
        draftSource: (notif) async => null,
        fastPath: const PragmaticFastPath(),
      );

      final notif = _createNotification(text: 'Hola');
      final result = await composer.compose(notif);

      expect(result, isNotNull);
      expect(result!.isFastPath, isTrue);
      expect(result.text.isNotEmpty, isTrue);
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
              options: [
                'Sí, lo tenemos.',
                'Tenemos stock para entrega inmediata.',
              ],
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

  group(
    'WhatsApp Personal Agent — Reconstrucción de Turno y Segmentación Temporal',
    () {
      test(
        'BurstTurnGate separa histórico desfasado (>60s) y conserva solo el cluster activo',
        () async {
          final gate = BurstTurnGate(settle: const Duration(milliseconds: 50));
          final events = [
            _createNotification(
              text: 'Bien y tu ?',
              key: 'wa_1',
              postTime: 1000000,
              messageTimestamp: 1000000, // T0 (3:08 PM)
            ),
            _createNotification(
              text: 'Bien Tk y tu!?',
              key: 'wa_2',
              postTime: 1060000,
              messageTimestamp: 1060000, // T0 + 60s (3:09 PM)
            ),
            _createNotification(
              text: 'Hola, ¿todo bien?',
              key: 'wa_3',
              postTime: 2000000,
              messageTimestamp: 2000000, // T0 + 1000s (brecha > 60s)
            ),
          ];

          NotificationObject? aggregatedSeen;
          await gate.submitAll(events, (aggregated) async {
            aggregatedSeen = aggregated;
            return [
              const RuleDispatchResult(
                ruleId: 'r1',
                outcome: RuleOutcome.replyDispatchedUnverified,
                dispatchedText: '¡Todo bien por acá!',
              ),
            ];
          });

          expect(aggregatedSeen, isNotNull);
          // Solo el cluster más reciente debe constituir el texto activo
          expect(aggregatedSeen!.messageText, 'Hola, ¿todo bien?');
          expect(aggregatedSeen!.messageText.contains('Bien y tu ?'), isFalse);
        },
      );

      test(
        'BurstTurnGate une ráfagas legítimas en rápida sucesión (<10s)',
        () async {
          final gate = BurstTurnGate(settle: const Duration(milliseconds: 50));
          final events = [
            _createNotification(
              text: 'Necesito ayuda',
              key: 'wa_1',
              postTime: 1000000,
              messageTimestamp: 1000000,
            ),
            _createNotification(
              text: 'Con el navegador',
              key: 'wa_2',
              postTime: 1002000,
              messageTimestamp: 1002000, // +2s
            ),
            _createNotification(
              text: 'Se cierra al abrir',
              key: 'wa_3',
              postTime: 1004000,
              messageTimestamp: 1004000, // +2s
            ),
          ];

          NotificationObject? aggregatedSeen;
          await gate.submitAll(events, (aggregated) async {
            aggregatedSeen = aggregated;
            return [
              const RuleDispatchResult(
                ruleId: 'r1',
                outcome: RuleOutcome.replyDispatchedUnverified,
                dispatchedText: '¿Qué versión estás usando?',
              ),
            ];
          });

          expect(aggregatedSeen, isNotNull);
          expect(
            aggregatedSeen!.messageText,
            'Necesito ayuda\nCon el navegador\nSe cierra al abrir',
          );
        },
      );
    },
  );

  group('WhatsApp Personal Agent — Ingestión de Mensajes Propios (isSelf)', () {
    test(
      'NotificationObject con isSelf preserva bandera de autoría propia',
      () {
        final notif = _createNotification(
          text: '¡Hola! ¿Cómo vas?',
          key: 'wa_self_01',
          isSelf: true,
        );

        expect(notif.isSelf, isTrue);
        expect(notif.text, '¡Hola! ¿Cómo vas?');
      },
    );

    test('NotificationObject.fromMap parsea isSelf correctamente', () {
      final notif = NotificationObject.fromMap({
        'key': 'wa_self_02',
        'package': 'com.whatsapp',
        'sender': 'Eh',
        'text': 'Todo en orden por acá',
        'isSelf': true,
      });

      expect(notif.isSelf, isTrue);
    });

    test('NotificationObject.fromMap detecta sender Tú y You como isSelf automáticamente', () {
      final notifTu = NotificationObject.fromMap({
        'key': 'wa_self_tu',
        'package': 'com.whatsapp',
        'sender': 'Tú',
        'text': 'Hola, ¿qué haces?',
      });
      expect(notifTu.isSelf, isTrue);

      final notifYou = NotificationObject.fromMap({
        'key': 'wa_self_you',
        'package': 'com.whatsapp',
        'sender': 'You',
        'text': 'What are you doing?',
      });
      expect(notifYou.isSelf, isTrue);
    });
  });

  group('WhatsApp Personal Agent — Diálogos de Cobertura Conversacional (A a L)', () {
    const fastPath = PragmaticFastPath();
    const classifier = TurnComplexityClassifier();

    test(
      'Caso A: Saludo y reciprocidad pura responde sin bucle de saludo',
      () async {
        final res = await fastPath.resolve(
          text: 'Bien y tú?',
          conversationId: 'c1',
        );
        expect(res, isNotNull);
        expect(res!.reply, isNotEmpty);
        expect(res.reply.startsWith('¡Hola! ¿Cómo vas?'), isFalse);
        expect(res.reply.toLowerCase().contains('bien'), isTrue);
      },
    );

    test('Caso B: Error de escritura ("Bien Tk y tu!?") es tolerado', () async {
      final res = await fastPath.resolve(
        text: 'Bien Tk y tu!?',
        conversationId: 'c1',
      );
      expect(res, isNotNull);
      expect(res!.reply, isNotEmpty);
      expect(res.act, contains('reciprocalQuestion'));
    });

    test(
      'Caso C: Saludo con solicitud sustantiva NO es absorbido por FastPath',
      () async {
        const complexMsg =
            'Hola, todo bien? Necesito ayuda con mi app, no abre';
        final complexity = classifier.classify(complexMsg);
        expect(complexity.eligibleForSocialPrompt, isFalse);
        final res = await fastPath.resolve(
          text: complexMsg,
          conversationId: 'c1',
        );
        expect(res, isNull); // Debe ir obligatoriamente al pipeline LLM
      },
    );

    test(
      'Caso D: Referencia anafórica ("lo de la app") es detectada como contextual',
      () {
        const anaphoraMsg = 'Solo cuando activo lo de la app';
        final complexity = classifier.classify(anaphoraMsg);
        expect(complexity.isContextual, isTrue);
        expect(complexity.eligibleForSocialPrompt, isFalse);
      },
    );

    test(
      'Caso E: Corrección ("No, me refería al celular") es detectada como no social mínima',
      () {
        const msg = 'No, me refería al celular, no al PC';
        expect(isCorrectionMessage(msg), isTrue);
      },
    );

    test(
      'Caso F: Relato ("Hoy tuve un día pesado") es clasificado como narrativo',
      () {
        const msg = 'Hoy tuve un día pesado y ando muy cansado del trabajo';
        final complexity = classifier.classify(msg);
        expect(complexity.isNarrative, isTrue);
        expect(complexity.eligibleForSocialPrompt, isFalse);
      },
    );

    test(
      'Caso G: Actividad desconocida ("¿En qué ciudad estás?") responde sin inventar',
      () async {
        final res = await fastPath.resolve(
          text: '¿En qué ciudad estás?',
          conversationId: 'c1',
        );
        expect(res, isNotNull);
        expect(res!.reply, contains('Medellín'));
      },
    );

    test(
      'Caso H: Múltiples intenciones / preguntas complejas no usan FastPath',
      () async {
        const multiMsg =
            'Hola, ¿cómo estás? ¿A qué hora abren hoy y tienen domicilio?';
        final complexity = classifier.classify(multiMsg);
        expect(complexity.eligibleForSocialPrompt, isFalse);
        final res = await fastPath.resolve(
          text: multiMsg,
          conversationId: 'c1',
        );
        expect(res, isNull);
      },
    );

    test(
      'Caso K: Cierre ("Listo, muchas gracias!") no prolonga con preguntas de retorno',
      () async {
        final res = await fastPath.resolve(
          text: 'Muchas gracias!',
          conversationId: 'c1',
        );
        expect(res, isNotNull);
        expect(res!.reply.contains('?'), isFalse);
      },
    );

    test('Caso L: Distinción de canales: comercial vs personal', () {
      final personalRouting = routeConversationAgent(
        messageText: '¡Hola! ¿Cómo vas amigo?',
        facts: const BusinessFacts(),
        hasRelationship: true,
        hasActiveProduct: false,
      );
      expect(personalRouting.role, ConversationAgentRole.personal);
      expect(personalRouting.commercialIntent, isFalse);

      final salesRouting = routeConversationAgent(
        messageText: '¿Cuánto vale el producto negro?',
        facts: const BusinessFacts(
          products: [
            BusinessProduct(
              id: 'p1',
              name: 'producto',
              details: 'negro',
              price: 100,
            ),
          ],
        ),
        hasRelationship: false,
        hasActiveProduct: true,
      );
      expect(salesRouting.role, ConversationAgentRole.sales);
      expect(salesRouting.commercialIntent, isTrue);
    });
  });

  group('WhatsApp Personal Agent — Regresiones Arquitectónicas y Diálogo', () {
    test(
      'Regresión 1: Notificaciones históricas reemitidas por Android no se concatenan',
      () async {
        final gate = BurstTurnGate(
          settle: const Duration(milliseconds: 10),
          maxWait: const Duration(milliseconds: 50),
        );

        final now = DateTime.now().millisecondsSinceEpoch;
        final old1 = _createNotification(
          key: 'k1',
          sender: 'Emma Hg',
          text: 'Hola',
          messageTimestamp: now - 3600000,
        );
        final old2 = _createNotification(
          key: 'k2',
          sender: 'Emma Hg',
          text: 'Bien y tu ?',
          messageTimestamp: now - 3500000,
        );
        final fresh = _createNotification(
          key: 'k3',
          sender: 'Emma Hg',
          text: '¿Sigues ahí?',
          messageTimestamp: now,
        );

        NotificationObject? receivedTurn;
        await gate.submitAll([old1, old2, fresh], (turn) async {
          receivedTurn = turn;
          return [
            const RuleDispatchResult(
              ruleId: 'r1',
              outcome: RuleOutcome.replyVerified,
            ),
          ];
        });

        expect(receivedTurn, isNotNull);
        expect(receivedTurn!.messageText, equals('¿Sigues ahí?'));
        expect(receivedTurn!.messageText.contains('Hola'), isFalse);
      },
    );

    test(
      'Regresión 2: Dos mensajes iguales legítimos con diferencia temporal se atienden independientemente',
      () async {
        final gate = BurstTurnGate(
          settle: const Duration(milliseconds: 10),
          maxWait: const Duration(milliseconds: 50),
        );

        final now = DateTime.now().millisecondsSinceEpoch;
        final msg1 = _createNotification(
          key: 'k1',
          sender: 'Emma Hg',
          text: 'Hola',
          messageTimestamp: now - 1800000,
        );
        final msg2 = _createNotification(
          key: 'k2',
          sender: 'Emma Hg',
          text: 'Hola',
          messageTimestamp: now,
        );

        NotificationObject? receivedTurn;
        await gate.submitAll([msg1, msg2], (turn) async {
          receivedTurn = turn;
          return [
            const RuleDispatchResult(
              ruleId: 'r1',
              outcome: RuleOutcome.replyVerified,
            ),
          ];
        });

        expect(receivedTurn, isNotNull);
        // El mensaje más reciente es el turno activo sin duplicar
        expect(receivedTurn!.messageText, equals('Hola'));
      },
    );

    test(
      'Regresión 3: Timestamps ausentes o 0 tienen fallback determinista a hora local',
      () async {
        final gate = BurstTurnGate(
          settle: const Duration(milliseconds: 10),
          maxWait: const Duration(milliseconds: 50),
        );

        final zeroStampMsg = _createNotification(
          key: 'k_zero',
          sender: 'Emma Hg',
          text: 'Mensaje sin stamp',
          messageTimestamp: 0,
          postTime: 0,
        );

        NotificationObject? receivedTurn;
        await gate.submitAll([zeroStampMsg], (turn) async {
          receivedTurn = turn;
          return [
            const RuleDispatchResult(
              ruleId: 'r1',
              outcome: RuleOutcome.replyVerified,
            ),
          ];
        });

        expect(receivedTurn, isNotNull);
        expect(receivedTurn!.messageText, equals('Mensaje sin stamp'));
      },
    );

    test('Regresión 4: Eco de mensaje propio duplicado es deduplicado', () {
      final dedupe = MemoryEventDedupeStore();
      final now = DateTime.now().millisecondsSinceEpoch;
      dedupe.recordVerifiedOutbound('conv_1', 'Hola', atMs: now);

      expect(dedupe.isKnownOutbound('conv_1', 'Hola'), isTrue);
      expect(dedupe.isKnownOutbound('conv_1', 'hola '), isTrue);
      expect(dedupe.isKnownOutbound('conv_1', 'Otro texto'), isFalse);

      final verdictEcho = dedupe.reserve(
        'evt_echo',
        conversationId: 'conv_1',
        text: 'Hola',
        atMs: now + 5000,
      );
      expect(verdictEcho, equals(DedupeVerdict.bounceback));

      final verdictEchoPreBurst = dedupe.reserve(
        'evt_echo_pre',
        conversationId: 'conv_1',
        text: 'Hola',
        eventOnly: true,
        atMs: now + 5000,
      );
      expect(verdictEchoPreBurst, equals(DedupeVerdict.bounceback));

      final verdictOther = dedupe.reserve(
        'evt_other',
        conversationId: 'conv_1',
        text: 'Otro texto diferente',
        atMs: now + 5000,
      );
      expect(verdictOther, isNot(equals(DedupeVerdict.bounceback)));
    });

    test(
      'Regresión 5: Intervención manual del dueño es registrada en memoria con procedencia',
      () {
        final memoryStore = MemoryConversationMemoryStore();
        const convId = 'whatsapp:emma_hg';
        final now = DateTime.now().millisecondsSinceEpoch;

        // Dueño escribe directamente en WhatsApp (isSelf observado sin despacho previo de Nano)
        memoryStore.reconcileOutbound(
          convId,
          'Hola Emma, ya estoy aquí',
          atMs: now,
        );

        final mem = memoryStore.memoryFor(convId);
        expect(mem, isNotNull);
        expect(mem!.entries.length, 1);
        expect(
          mem.entries.first.kind,
          ConversationMemoryEntryKind.outboundObservedManual,
        );
        expect(mem.lastManualInterventionMs, equals(now));
      },
    );

    test(
      'Regresión 6: Ráfaga prolongada es delimitada por maxTurnSpanMs (120s)',
      () async {
        final gate = BurstTurnGate(
          settle: const Duration(milliseconds: 10),
          maxWait: const Duration(milliseconds: 50),
        );

        final now = DateTime.now().millisecondsSinceEpoch;
        // Cadena de mensajes con 40 segundos de diferencia cada uno (acumulado: 160s > 120s)
        final m0 = _createNotification(
          key: 'm0',
          sender: 'Emma',
          text: 'Primer mensaje',
          messageTimestamp: now - 160000,
        );
        final m1 = _createNotification(
          key: 'm1',
          sender: 'Emma',
          text: 'Segundo mensaje',
          messageTimestamp: now - 120000,
        );
        final m2 = _createNotification(
          key: 'm2',
          sender: 'Emma',
          text: 'Tercer mensaje',
          messageTimestamp: now - 80000,
        );
        final m3 = _createNotification(
          key: 'm3',
          sender: 'Emma',
          text: 'Cuarto mensaje',
          messageTimestamp: now,
        );

        NotificationObject? receivedTurn;
        await gate.submitAll([m0, m1, m2, m3], (turn) async {
          receivedTurn = turn;
          return [
            const RuleDispatchResult(
              ruleId: 'r1',
              outcome: RuleOutcome.replyVerified,
            ),
          ];
        });

        expect(receivedTurn, isNotNull);
        // El mensaje m0 (hace 160s) excede maxTurnSpanMs respecto al ancla actual (ahora),
        // por lo que no se concatena al turno activo
        expect(receivedTurn!.messageText.contains('Primer mensaje'), isFalse);
        expect(receivedTurn!.messageText.contains('Cuarto mensaje'), isTrue);
      },
    );

    test(
      'Regresión 7: Continuación ("Bien y tú?") sin saludo observable del dueño no es rechazada',
      () {
        const decisionEngine = ConversationDecisionEngine();
        const context = ConversationDecisionContext(
          humanOwnsConversation: false,
          identityConfidence: 0.95,
          autonomyMode: ConversationAutonomyMode.autonomous,
          agentRole: ConversationAgentRole.personal,
          userText: 'Bien y tu ?',
          senderName: 'Emma Hg',
        );

        const understanding = ConversationUnderstanding(
          reply: '¡Hola! Todo bien por acá también.',
          intent: 'reciprocalQuestion',
          relation: 'responde',
          options: [],
          questions: [],
          missingFacts: [],
          requiresAction: false,
        );

        final decision = decisionEngine.decide(
          understanding: understanding,
          context: context,
        );

        expect(
          decision.reasons.contains(
            'saludo fuera de turno (pregunta-saludo sin saludo previo)',
          ),
          isFalse,
        );
        expect(decision.confidence, greaterThanOrEqualTo(0.60));
      },
    );

    test(
      'Regresión 8: Multi-intención con solicitud sustantiva ("cuánto vale y hacen envíos?")',
      () {
        const text = 'Hola, ¿cuánto vale el producto y hacen envíos?';
        final signals = linguisticAnalyzer.analyze(text);
        expect(signals.isMultiIntent, isTrue);
        expect(signals.detectedIntents, contains('precio'));
        expect(signals.detectedIntents, contains('envio'));

        const classifier = TurnComplexityClassifier();
        final complexity = classifier.classify(text);
        expect(complexity.isComplex, isTrue);
        expect(complexity.eligibleForSocialPrompt, isFalse);
      },
    );

    test(
      'Regresión 9: Negación y contraejemplo ("No quiero cancelar, gracias")',
      () {
        const text = 'No quiero cancelar, gracias';
        final signals = linguisticAnalyzer.analyze(text);
        expect(signals.hasNegation, isTrue);
        expect(signals.negationScope, contains('cancelar'));

        const classifier = TurnComplexityClassifier();
        final complexity = classifier.classify(text);
        expect(complexity.eligibleForSocialPrompt, isFalse);
      },
    );

    test(
      'Regresión 10: Corrección de referencia ("No, me refería al móvil, no al PC")',
      () {
        const text = 'No, me refería al móvil, no al PC';
        final signals = linguisticAnalyzer.analyze(text);
        expect(signals.isCorrection, isTrue);
        expect(signals.correctionTarget, contains('móvil'));

        const classifier = TurnComplexityClassifier();
        final complexity = classifier.classify(text);
        expect(complexity.isNarrative, isTrue);
        expect(complexity.eligibleForSocialPrompt, isFalse);
      },
    );

    test(
      'Regresión 11: FastPath no secuestra turno sustantivo finalizado en "ok" ("necesito el precio · ok")',
      () async {
        var llmCalled = false;
        final composer = RuntimeConversationReplyComposer(
          draftSource: (n) async {
            llmCalled = true;
            return const NotificationDraftResult(
              reply: 'El precio es de \$50.000 COP',
              understanding: ConversationUnderstanding(
                reply: 'El precio es de \$50.000 COP',
                intent: 'commercialInquiry',
              ),
            );
          },
          fastPath: PragmaticFastPath(
            memoryFor: (_) => null,
            contextEntryFor: (_) => null,
            ownerName: () => 'Emma',
          ),
          decisionEngine: const ConversationDecisionEngine(),
        );

        final notif = _createNotification(text: 'necesito el precio · ok');

        final draft = await composer.compose(
          notif,
          decisionContext: const ConversationDecisionContext(
            agentRole: ConversationAgentRole.personal,
            autonomyMode: ConversationAutonomyMode.autonomous,
            identityConfidence: 1.0,
          ),
        );

        // FastPath NO debió secuestrar el turno respondiendo un simple "dale" o saludo
        expect(llmCalled, isTrue);
        expect(draft?.text, contains('El precio es'));
      },
    );

    test(
      'Regresión 12: Preguntas de planes/actividad ("y que vas hacer hoy?") devuelven variabilidad natural y no confunden con ir',
      () async {
        final fastPath = PragmaticFastPath(
          memoryFor: (_) => null,
          contextEntryFor: (_) => null,
          ownerName: () => 'Emma',
        );

        final rFast = await fastPath.resolve(
          text: 'y que vas hacer hoy?',
          conversationId: 'conv_plans_today',
        );

        expect(rFast, isNotNull);
        expect(rFast!.act, contains('askActivity'));
        // Debe ser respuesta natural de estar en casa o no saber, NUNCA "si voy a ir hoy"
        expect(rFast.reply.toLowerCase().contains('si voy a ir'), isFalse);
        expect(
          rFast.reply.toLowerCase(),
          anyOf(
            contains('casa'),
            contains('no sé'),
            contains('no se'),
            contains('haciendo'),
            contains('tranquilo'),
          ),
        );

        // Y la reparación determinista también debe dar respuestas de estar en casa/no sé
        final repaired = safeConversationRepair.repair(
          RepairCase.liveStateAffirmed,
          reply: 'Voy a ir al centro comercial hoy.',
          userText: 'y que vas hacer hoy?',
        );
        expect(repaired, isNotNull);
        expect(repaired!.toLowerCase().contains('si voy a ir'), isFalse);
        expect(
          repaired.toLowerCase(),
          anyOf(
            contains('casa'),
            contains('no sé'),
            contains('no se'),
            contains('hacer'),
            contains('haré'),
          ),
        );
      },
    );

    test(
      'Regresión 13: Variabilidad amplia garantizada (> 10 opciones diferentes en bancos de diálogo)',
      () {
        // Safe repair options
        expect(safeRepairActivityOptions.toSet().length, greaterThanOrEqualTo(11));
        expect(safeRepairGoingOptions.toSet().length, greaterThanOrEqualTo(11));
        expect(safeRepairGeneralLiveStateOptions.toSet().length, greaterThanOrEqualTo(11));
        expect(safeRepairRedundantOptions.toSet().length, greaterThanOrEqualTo(11));
        expect(safeRepairCallCenterGreetingOptions.toSet().length, greaterThanOrEqualTo(11));

        // Fast path banks
        expect(activityPlansCandidates.toSet().length, greaterThanOrEqualTo(11));
        expect(activityGoingCandidates.toSet().length, greaterThanOrEqualTo(11));
        expect(wellbeingRecentlyGreetedCandidates.toSet().length, greaterThanOrEqualTo(11));
        expect(wellbeingStandardCandidates.toSet().length, greaterThanOrEqualTo(11));
        expect(greetingRecentlyGreetedCandidates.toSet().length, greaterThanOrEqualTo(11));
        expect(greetingStandardCandidates.toSet().length, greaterThanOrEqualTo(11));
        expect(thanksCandidates.toSet().length, greaterThanOrEqualTo(11));
        expect(farewellNightCandidates.toSet().length, greaterThanOrEqualTo(11));
        expect(farewellTomorrowCandidates.toSet().length, greaterThanOrEqualTo(11));
        expect(farewellAfternoonCandidates.toSet().length, greaterThanOrEqualTo(11));
        expect(farewellGeneralCandidates.toSet().length, greaterThanOrEqualTo(11));
        expect(laughterCandidates.toSet().length, greaterThanOrEqualTo(11));
        expect(reciprocalCandidates.toSet().length, greaterThanOrEqualTo(11));
        expect(userWellbeingActivityCandidates.toSet().length, greaterThanOrEqualTo(11));
        expect(rapCandidates.toSet().length, greaterThanOrEqualTo(11));
        expect(invitationCandidates.toSet().length, greaterThanOrEqualTo(11));
        expect(wellbeingClarificationCandidates.toSet().length, greaterThanOrEqualTo(11));
        expect(userWellbeingPureCandidates.toSet().length, greaterThanOrEqualTo(11));
        expect(trainingCandidates.toSet().length, greaterThanOrEqualTo(11));
        expect(trainingWithGreetingCandidates.toSet().length, greaterThanOrEqualTo(11));
        expect(dayCandidates.toSet().length, greaterThanOrEqualTo(11));
        expect(dayWithGreetingCandidates.toSet().length, greaterThanOrEqualTo(11));
        expect(availabilityCandidates.toSet().length, greaterThanOrEqualTo(11));
        expect(lunchCandidates.toSet().length, greaterThanOrEqualTo(11));
        expect(dinnerCandidates.toSet().length, greaterThanOrEqualTo(11));
        expect(foodGeneralCandidates.toSet().length, greaterThanOrEqualTo(11));
        expect(physicalLocationCandidates.toSet().length, greaterThanOrEqualTo(11));
        expect(familyCandidates.toSet().length, greaterThanOrEqualTo(11));
        expect(sleepCandidates.toSet().length, greaterThanOrEqualTo(11));
        expect(musicCandidates.toSet().length, greaterThanOrEqualTo(11));
        expect(weatherSocialCandidates.toSet().length, greaterThanOrEqualTo(11));
        expect(callCandidates.toSet().length, greaterThanOrEqualTo(11));
        expect(lostOrMissingCandidates.toSet().length, greaterThanOrEqualTo(11));
        expect(opinionSocialCandidates.toSet().length, greaterThanOrEqualTo(11));
        expect(planReminderCandidates.toSet().length, greaterThanOrEqualTo(11));
        expect(presenceCandidates.toSet().length, greaterThanOrEqualTo(11));
        expect(helpTaskCandidates.toSet().length, greaterThanOrEqualTo(11));
        expect(helpGeneralCandidates.toSet().length, greaterThanOrEqualTo(11));
        expect(locationCandidates.toSet().length, greaterThanOrEqualTo(11));
      },
    );
  });
}
