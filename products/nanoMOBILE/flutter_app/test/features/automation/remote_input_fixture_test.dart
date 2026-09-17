import 'package:flutter_test/flutter_test.dart';
import 'package:nanoai/features/automation/domain/automation_goal.dart';
import 'package:nanoai/features/automation/domain/automation_result.dart';
import 'package:nanoai/features/automation/engine/conversation/conversation_reply_composer.dart';
import 'package:nanoai/features/automation/engine/language/pragmatic_fast_path.dart';
import 'package:nanoai/features/automation/engine/messaging/conversation_memory.dart';
import 'package:nanoai/features/automation/engine/messaging/incoming_message.dart';
import 'package:nanoai/features/automation/engine/messaging/pending_reply.dart';
import 'package:nanoai/features/automation/engine/messaging/pending_reply_store.dart';
import 'package:nanoai/features/automation/engine/notifications/notification_object.dart';
import 'package:nanoai/features/automation/engine/scheduling/rule_dispatcher.dart';
import 'package:nanoai/features/automation/engine/scheduling/scheduled_rule.dart';
import 'package:nanoai/features/automation/engine/scheduling/trigger.dart';
import 'package:nanoai/features/automation/engine/scheduling/turn_supersede_guard.dart';
import 'package:nanoai/features/automation/personal_agent/application/conversation_decision_engine.dart';
import 'package:nanoai/features/automation/personal_agent/domain/conversation_agent_role.dart';
import 'package:nanoai/features/automation/personal_agent/domain/conversation_autonomy_mode.dart';
import 'package:nanoai/features/automation/personal_agent/domain/conversation_decision.dart';

NotificationObject _createFixtureNotification({
  required String text,
  String sender = 'Contacto Fixture',
  String packageName = 'com.whatsapp',
  String key = 'fixture_wa_001',
  int postTime = 1000000,
  String shortcutId = 'sc_fixture_01',
  String locusId = 'loc_fixture_01',
  String senderKey = '',
  String conversationId = '',
  bool canReply = true,
}) {
  return NotificationObject(
    key: key,
    packageName: packageName,
    title: sender,
    text: text,
    messageText: text,
    messageTimestamp: postTime,
    sender: sender,
    senderKey: senderKey.isNotEmpty ? senderKey : 'pk_$sender',
    senderUri: 'tel:5550000',
    conversationTitle: sender,
    conversationId: conversationId.isNotEmpty ? conversationId : 'conv_$sender',
    shortcutId: shortcutId,
    locusId: locusId,
    accountHint: '',
    isGroup: false,
    isSummary: false,
    isSelf: false,
    postTime: postTime,
    canReply: canReply,
    remoteInputKey: 'quick_reply',
    actionIndex: 0,
    actions: const ['Responder'],
    ongoing: false,
  );
}

void main() {
  group('RemoteInput Fixture & Reconciliation Suite (Sprint 0)', () {
    test('P0 ReconcileOutbound exige tanto tiempo cercano (<=30s) COMO coincidencia de texto (&&)', () {
      final memory = MemoryConversationMemoryStore();
      final notif = _createFixtureNotification(text: 'Hola');
      final inbound = IncomingMessage.fromNotification(notif);
      final convId = inbound.conversation.key.id;
      const baseTime = 1000000;

      // 1. Mensaje entrante
      memory.appendInbound(inbound, atMs: baseTime);

      // 2. El bot despacha una respuesta
      memory.appendOutbound(
        convId,
        '¡Hola! Todo bien por acá.',
        kind: ConversationMemoryEntryKind.outboundDispatched,
        ruleId: 'rule_whatsapp',
        atMs: baseTime + 1000,
      );

      var entries = memory.memoryFor(convId)!.entries;
      expect(entries.length, 2);
      expect(entries[1].kind, ConversationMemoryEntryKind.outboundDispatched);
      expect(entries[1].text, '¡Hola! Todo bien por acá.');

      // 3. El usuario escribe manualmente algo completamente distinto dentro de los 30s
      // Con el bug (||), esto se reconciliaba falsamente como outboundVerified para el bot.
      // Con el fix (&&), NO debe reconciliar el mensaje del bot, sino registrarse como manual.
      memory.reconcileOutbound(
        convId,
        'Oye voy saliendo al supermercado',
        atMs: baseTime + 5000,
      );

      entries = memory.memoryFor(convId)!.entries;
      // Deben haber 3 entradas: inbound, outboundDispatched (intacto), outboundObservedManual
      expect(entries.length, 3);
      expect(entries[1].kind, ConversationMemoryEntryKind.outboundDispatched);
      expect(entries[2].kind, ConversationMemoryEntryKind.outboundObservedManual);
      expect(entries[2].text, 'Oye voy saliendo al supermercado');

      // 4. Ahora llega el eco o la confirmación de la plataforma con el texto EXACTO del bot
      memory.reconcileOutbound(
        convId,
        '¡Hola! Todo bien por acá.',
        atMs: baseTime + 6000,
      );

      entries = memory.memoryFor(convId)!.entries;
      // La entrada 1 debe promoverse a outboundVerified
      expect(entries[1].kind, ConversationMemoryEntryKind.outboundVerified);
      expect(entries[1].text, '¡Hola! Todo bien por acá.');
    });

    test('RuleDispatcher permite preparar borrador y lo retiene en PendingReplyStore cuando la identidad es débil', () async {
      final memory = MemoryConversationMemoryStore();
      final pendingStore = PendingReplyStore();
      final guard = TurnSupersedeGuard();
      final dispatchedGoals = <String>[];

      final composer = RuntimeConversationReplyComposer(
        draftSource: (notif) async => null,
        fastPath: PragmaticFastPath(
          memoryFor: memory.memoryFor,
          contextEntryFor: (_) => null,
          ownerName: () => 'Emma',
        ),
        decisionEngine: const ConversationDecisionEngine(),
      );

      final dispatcher = RuleDispatcher(
        (goal, {options}) async {
          dispatchedGoals.add(goal.text);
          return const AutomationResult(
            executionId: 'exec_1',
            status: AutomationResultStatus.completed,
            reason: 'ok',
          );
        },
        composer: composer,
        pendingReplyStore: pendingStore,
        supersedeGuard: guard,
        decisionContext: (notif) => const ConversationDecisionContext(
          agentRole: ConversationAgentRole.personal,
          autonomyMode: ConversationAutonomyMode.autonomous,
          // Confianza baja (ej. 0.35 por evidencia sólo de título)
          identityConfidence: 0.35,
          humanOwnsConversation: false,
        ),
      );

      // Notificación con evidencia mínima (baja confianza)
      final weakNotif = _createFixtureNotification(
        text: 'Hola',
        sender: 'Contacto Desconocido',
        key: 'wa_title_only',
        shortcutId: '',
        locusId: '',
        senderKey: '',
        conversationId: '',
      );

      final rule = ScheduledRule(
        id: 'rule_whatsapp_personal',
        trigger: const NotificationTrigger(packageName: 'com.whatsapp'),
        action: RuleAction.reply,
        enabled: true,
        dynamicReply: true,
        createdAt: DateTime.now(),
      );

      final result = await dispatcher.dispatch(rule, weakNotif);

      // NO debe ejecutarse un sideEffect directo a WhatsApp
      expect(dispatchedGoals, isEmpty);
      // Debe retener el borrador en PendingReplyStore
      expect(result.outcome, RuleOutcome.drafted);
      final pendingList = await pendingStore.allPending();
      expect(pendingList.length, 1);
      final pending = pendingList.first;
      expect(pending.draftText, isNotEmpty);
      expect(pending.status, PendingReplyStatus.pending);
    });

    test('RemoteInput End-to-End: Inbound produce respuesta real y despacha acción de envío', () async {
      final memory = MemoryConversationMemoryStore();
      final guard = TurnSupersedeGuard();
      final executedGoals = <AutomationGoal>[];

      final notif = _createFixtureNotification(
        text: 'Hola, ¿cómo estás?',
        sender: 'Emma Hg',
        postTime: 2000000,
      );

      final inbound = IncomingMessage.fromNotification(notif);
      final convId = inbound.conversation.key.id;
      guard.bump(convId);

      // Registramos el inbound en memoria
      memory.appendInbound(inbound, atMs: notif.postTime);

      final composer = RuntimeConversationReplyComposer(
        draftSource: (n) async => null,
        fastPath: PragmaticFastPath(
          memoryFor: memory.memoryFor,
          contextEntryFor: (_) => null,
          ownerName: () => 'Emma',
        ),
        decisionEngine: const ConversationDecisionEngine(),
      );

      final dispatcher = RuleDispatcher(
        (goal, {options}) async {
          executedGoals.add(goal);
          // Simulamos la ejecución del goal por el coordinator
          // El coordinator registra el outbound en memory
          final text = options?.replyText ?? '';
          memory.appendOutbound(
            convId,
            text,
            kind: ConversationMemoryEntryKind.outboundDispatched,
            ruleId: 'rule_wa_live',
            atMs: DateTime.now().millisecondsSinceEpoch,
          );
          return const AutomationResult(
            executionId: 'exec_live_1',
            status: AutomationResultStatus.completed,
            reason: 'ok',
          );
        },
        composer: composer,
        supersedeGuard: guard,
        decisionContext: (n) => const ConversationDecisionContext(
          agentRole: ConversationAgentRole.personal,
          autonomyMode: ConversationAutonomyMode.autonomous,
          identityConfidence: 1.0,
          humanOwnsConversation: false,
        ),
      );

      final rule = ScheduledRule(
        id: 'rule_wa_live',
        trigger: const NotificationTrigger(packageName: 'com.whatsapp'),
        action: RuleAction.reply,
        enabled: true,
        dynamicReply: true,
        createdAt: DateTime.now(),
      );

      final result = await dispatcher.dispatch(
        rule,
        notif,
        capturedConversationVersion: guard.versionOf(convId),
      );

      expect(result.outcome, RuleOutcome.replyVerified);
      expect(executedGoals.length, 1);
      expect(executedGoals.first.text, contains('responde a Emma Hg que'));

      // Verificar que ConversationMemoryStore registró el despacho
      final mem = memory.memoryFor(convId)!;
      final outDispatched = mem.entries.where(
        (e) => e.kind == ConversationMemoryEntryKind.outboundDispatched,
      );
      expect(outDispatched.length, 1);
      final dispatchedText = outDispatched.first.text;
      expect(dispatchedText, isNotEmpty);

      // Reconciliación estricta con eco real
      memory.reconcileOutbound(
        convId,
        dispatchedText,
        atMs: DateTime.now().millisecondsSinceEpoch,
      );

      final verified = memory.memoryFor(convId)!.entries.where(
        (e) => e.kind == ConversationMemoryEntryKind.outboundVerified,
      );
      expect(verified.length, 1);
      expect(verified.first.text, dispatchedText);
    });
  });
}
