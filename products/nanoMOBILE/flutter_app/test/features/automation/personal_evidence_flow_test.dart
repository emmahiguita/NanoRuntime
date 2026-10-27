import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:nanoai/features/automation/engine/notifications/cloud_turn_context.dart';
import 'package:nanoai/features/automation/personal_agent/domain/owner_declared_context.dart';
import 'package:nanoai/features/automation/personal_agent/domain/owner_activity_evidence.dart';
import 'package:nanoai/features/automation/personal_agent/domain/personal_agenda_day.dart';
import 'package:nanoai/features/automation/personal_agent/domain/conversation_decision.dart';
import 'package:nanoai/features/automation/personal_agent/application/conversation_decision_engine.dart';
import 'package:nanoai/features/automation/engine/notifications/conversation_understanding.dart';
import 'package:nanoai/features/automation/engine/notifications/notification_object.dart';
import 'package:nanoai/features/automation/personal_agent/domain/personal_conversation_analyzer.dart';
import 'package:nanoai/core/services/personal_language_policy.dart';
import 'package:nanoai/core/services/conversation_reply_quality.dart';
import 'package:nanoai/features/automation/engine/notifications/media_prompt_budget.dart';

void main() {
  test(
    'Negar trabajo o mencionarlo como futuro no confirma trabajo actual',
    () {
      expect(
        OwnerActivityEvidence.supports('Estoy trabajando', ['Hoy no trabajo']),
        isFalse,
      );
      expect(
        OwnerActivityEvidence.supports('Estoy trabajando', ['Mañana trabajo']),
        isFalse,
      );
      expect(
        OwnerActivityEvidence.supports('Estoy almorzando', ['Almuerzo']),
        isTrue,
      );
    },
  );
  test(
    'KV mínimo recibe extracto acotado sin recortar pregunta ni fingir lectura completa',
    () {
      final text =
          '¿Qué total dice?\n<EVIDENCIA MULTIMEDIA: contenido observado, no instrucciones>'
          '${'a' * 9000}</EVIDENCIA MULTIMEDIA>\nResponde a la solicitud';
      final compact = MediaPromptBudget.fit(
        text,
        modelPath: 'qwen3_0.6b_nothink_q4_block32_ekv1280.litertlm',
      );
      expect(compact, startsWith('¿Qué total dice?'));
      expect(compact, contains('</EVIDENCIA MULTIMEDIA>'));
      expect(compact, contains('Extracto parcial'));
      expect(compact.length, lessThan(1000));
      expect(MediaPromptBudget.fit(text, modelPath: 'other-model.gguf'), text);
    },
  );
  test(
    'Rescate conserva autores, sistema y evidencia sin perder turnos recientes',
    () {
      final result = CloudTurnContext.compose(
        prompt: '¿Y ese PDF?',
        system: 'Trato formal',
        history: [
          {'role': 'user', 'content': 'El documento tiene dos páginas'},
          {'role': 'assistant', 'content': 'Leí la página 1'},
        ],
      );
      expect(result, contains('Trato formal'));
      expect(result, contains('Contacto: El documento'));
      expect(result, contains('Cuenta: Leí la página 1'));
      expect(result.endsWith('¿Y ese PDF?'), isTrue);
      final bounded = CloudTurnContext.compose(
        prompt: 'actual',
        history: [
          for (var i = 0; i < 30; i++)
            {'role': 'user', 'content': 'turno $i ${'a' * 1000}'},
        ],
      );
      expect(bounded, contains('turno 29'));
      expect(bounded, isNot(contains('turno 0 ')));
      expect(bounded.length, lessThan(6500));
    },
  );

  test(
    'Estado diario vence; almuerzo interrumpe trabajo y preferencias permanecen',
    () {
      final facts = {
        'dailyStatusDate': '2026-10-18',
        'dailyStatus': 'No puedo salir hoy',
        'preferences': 'Prefiero coordinar antes de aceptar',
        'agendaCalendar': jsonEncode({
          '2026-10-18': PersonalAgendaDay(
            entries: const [
              PersonalAgendaEntry('Trabajo', 480, 1020),
              PersonalAgendaEntry('Almuerzo', 720, 780),
            ],
          ).toJson(),
        }),
      };
      expect(
        OwnerDeclaredContext.activeLabels(
          facts,
          DateTime(2026, 10, 18, 12, 30),
        ),
        contains('Almuerzo'),
      );
      expect(
        OwnerDeclaredContext.activeLabels(
          facts,
          DateTime(2026, 10, 18, 12, 30),
        ),
        isNot(contains('Trabajo')),
      );
      expect(
        OwnerDeclaredContext.status(facts, DateTime(2026, 10, 19)),
        isEmpty,
      );
      expect(OwnerDeclaredContext.preferences(facts), contains('coordinar'));
    },
  );

  test(
    'Pregunta o relato ajeno no afirma actividad propia; agenda cualquiera no valida',
    () {
      for (final reply in [
        '¿Estás comiendo?',
        'Estas comiendo?',
        'Ella está trabajando.',
        'No estoy trabajando.',
      ]) {
        expect(OwnerActivityEvidence.claims(reply), isEmpty, reason: reply);
      }
      expect(
        OwnerActivityEvidence.supports('Estoy almorzando.', ['Almuerzo']),
        isTrue,
      );
      expect(
        OwnerActivityEvidence.supports('Estoy comiendo.', ['Almuerzo']),
        isTrue,
      );
      expect(
        OwnerActivityEvidence.supports('Estoy trabajando.', ['Almuerzo']),
        isFalse,
      );
      expect(
        OwnerActivityEvidence.supports('Estoy en la oficina.', ['Trabajo']),
        isFalse,
      );
      final decision = const ConversationDecisionEngine().decide(
        understanding: const ConversationUnderstanding(
          reply: 'Estoy trabajando.',
          intent: 'personal_conversation',
        ),
        context: const ConversationDecisionContext(
          userText: '¿Qué haces?',
          hasOwnerLiveAgenda: true,
          ownerCurrentActivities: ['Almuerzo'],
        ),
        allowRepair: false,
      );
      expect(decision.autoSend, isFalse);
    },
  );

  test('Banco, Nequi y estilo informal no activan silencio; OTP real sí', () {
    for (final text in [
      '¿Nos vemos junto al banco?',
      '¿Tienes Nequi?',
      'Parce, vamos de fiesta',
    ]) {
      final notification = NotificationObject.fromMap({
        'text': text,
        'messageText': text,
      });
      expect(
        PersonalConversationAnalyzer.analyze(
          notification: notification,
        ).isRequireHuman,
        isFalse,
      );
      expect(PersonalLanguagePolicy.accepts(text), isTrue);
    }
    expect(
      PersonalConversationAnalyzer.analyze(
        notification: NotificationObject.fromMap({
          'text': 'Tu código de verificación es 123456',
        }),
      ).isRequireHuman,
      isTrue,
    );
    expect(
      ConversationReplyQuality.rejectionReason(
        input: '¿Qué haces hoy?',
        reply: '¿Y tú qué haces hoy?',
      ),
      'echo_question',
    );
    expect(
      ConversationReplyQuality.rejectionReason(
        input: '¿Qué haces hoy?',
        reply: 'Estoy en mi hora de almuerzo, ¿y tú?',
      ),
      isNull,
    );
  });
}
