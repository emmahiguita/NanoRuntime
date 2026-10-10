// personal_conversation_analyzer.dart
//
// QUÉ HACE:
// Analiza integralmente los mensajes entrantes para Nano Personal, evaluando
// dominio, riesgo, estado del turno y determinando la acción (SILENT, AUTO, REQUIRE_HUMAN).
//
// CÓMO FUNCIONA:
// - Detecta procesos de selección y empleo (PeakU, Computrabajo) estructurando [RecruitmentEvent].
// - Aplica silencio inteligente ante reacciones, stickers y emojis de cierre en turnos resueltos.
// - Discierne saludos genuinos de alertas bancarias, códigos 2FA y temas de alto riesgo.
//
// POR QUÉ:
// Evita respuestas robóticas o imprudentes, protege la privacidad del usuario
// y asegura que los mensajes críticos sean atendidos personalmente por el dueño.

library;

import '../../engine/conversation/dialogue_state_tracker.dart';
import '../../engine/notifications/notification_object.dart';
import 'personal_action_policy.dart';
import 'recruitment_event.dart';

abstract final class PersonalConversationAnalyzer {
  static final _pureReactionEmojiOrSticker = RegExp(
    r'^(?:👍|❤️|🙏|😂|🤣|👏|🙌|🤝|👌|🔥|✨|😍|🥰|😎|'
    r'💟\s*sticker|\[sticker\]|sticker|'
    r'ok|okay|dale|listo|gracias|muchas gracias|mil gracias|de una|perfecto|genial|entendido|aja|jaja|jeje)[\s.,!?]*$',
    caseSensitive: false,
    unicode: true,
  );

  static final _greetingEmojiOrText = RegExp(
    r'^(?:👋|hola|buen día|buenos días|buenas tardes|buenas noches|buenas|hey|hi|saludos)[\s.,!?]*$',
    caseSensitive: false,
    unicode: true,
  );

  static final _otpOrSecurityRegex = RegExp(
    r'(?:código\s+de\s+seguridad|tu\s+código\s+es|verification\s+code|código\s+de\s+verificación|otp|clave\s+dinámica|transferencia\s+exitosa|banco|davivienda|bancolombia|bbva|nequi|daviplata)',
    caseSensitive: false,
  );

  /// Analiza la notificación entrante y el estado de diálogo para emitir una [PersonalDecision].
  static PersonalDecision analyze({
    required NotificationObject notification,
    ConversationDialogueState? dialogueState,
  }) {
    final rawText = notification.messageText.isNotEmpty
        ? notification.messageText
        : notification.text;
    final text = rawText.trim();
    final lower = text.toLowerCase();

    // 1. Reacciones de notificación nativas ("Reaccionó con ❤️ a...")
    if (lower.startsWith('reaccionó') || lower.startsWith('reagiu') || lower.startsWith('reacted')) {
      return const PersonalDecision(
        domain: PersonalDomain.social,
        intent: PersonalIntent.socialAcknowledgement,
        turnState: PersonalTurnState.resolved,
        action: PersonalAction.silent,
        reason: 'Reacción nativa a mensaje anterior; turno finalizado.',
      );
    }

    // 2. Detección de Dominio Reclutamiento / Selección de Empleo (PeakU, Computrabajo, etc.)
    final recruitment = RecruitmentEvent.extract(text);
    if (recruitment != null) {
      return PersonalDecision(
        domain: PersonalDomain.recruitment,
        intent: PersonalIntent.jobProcessUpdate,
        turnState: PersonalTurnState.waitingForUser,
        action: PersonalAction.requireHuman,
        requiresHuman: true,
        recruitmentEvent: recruitment,
        reason: 'Oferta laboral o prueba técnica en ${recruitment.platform}: requiere atención humana.',
      );
    }

    // 3. Detección de Seguridad, Bancos y Códigos OTP
    if (_otpOrSecurityRegex.hasMatch(text)) {
      return const PersonalDecision(
        domain: PersonalDomain.security2fa,
        intent: PersonalIntent.otpCode,
        turnState: PersonalTurnState.waitingForUser,
        action: PersonalAction.requireHuman,
        requiresHuman: true,
        reason: 'Mensaje de seguridad bancaria o código de verificación: silencio preventivo.',
      );
    }

    // 4. Saludos puros (apertura de turno)
    if (_greetingEmojiOrText.hasMatch(text)) {
      return const PersonalDecision(
        domain: PersonalDomain.social,
        intent: PersonalIntent.greeting,
        turnState: PersonalTurnState.openGreeting,
        action: PersonalAction.autoReply,
        reason: 'Saludo de apertura de conversación.',
      );
    }

    // 5. Emojis aislados, stickers o acuses de cierre (👍, ❤️, 🙏, jaja)
    if (_pureReactionEmojiOrSticker.hasMatch(text)) {
      final isTurnResolved = dialogueState != null && dialogueState.turnCount > 0;
      return PersonalDecision(
        domain: PersonalDomain.social,
        intent: PersonalIntent.socialAcknowledgement,
        turnState: isTurnResolved ? PersonalTurnState.resolved : PersonalTurnState.socialClosing,
        action: PersonalAction.silent,
        reason: 'Acuse, emoji o sticker de cierre de turno; no requiere respuesta.',
      );
    }

    // 6. Mensaje general interactivo
    return const PersonalDecision(
      domain: PersonalDomain.general,
      intent: PersonalIntent.generalInquiry,
      turnState: PersonalTurnState.openQuestion,
      action: PersonalAction.autoReply,
      reason: 'Mensaje sustantivo estándar.',
    );
  }
}
