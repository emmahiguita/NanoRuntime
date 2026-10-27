import '../../engine/conversation/dialogue_state_tracker.dart';

/// QUÉ: distingue contenido compartido de una respuesta a un turno pendiente.
/// CÓMO: consulta la última pregunta observada; no concede permisos al contacto.
/// POR QUÉ: «dale» puede continuar el diálogo sin autorizar pagos ni compromisos.
abstract final class PersonalTurnContinuity {
  static final _url = RegExp(r'(?:https?://|www\.)\S+', caseSensitive: false);
  static final _acknowledgement = RegExp(
    r'^(?:ok|okay|dale|listo|de una|perfecto|genial|entendido)[\s.,!?]*$',
    caseSensitive: false,
  );
  static final _linkRequest = RegExp(
    r'\b(?:env[ií]ame|m[aá]ndame|p[aá]same|comparte|comp[aá]rteme)\b'
    r'.*\b(?:link|enlace|v[ií]nculo)\b',
    caseSensitive: false,
  );

  /// Las interrogaciones dentro de una URL son parámetros, no una pregunta.
  static bool isBareLink(String text) =>
      _url.hasMatch(text) && text.replaceAll(_url, '').trim().isEmpty;

  static bool answersPendingQuestion(
    String text,
    ConversationDialogueState? state,
  ) => state?.hasPendingQuestion == true && _acknowledgement.hasMatch(text);

  /// Se usa al reconstruir el turno pendiente desde una salida observada.
  static bool requestsLink(String text) => _linkRequest.hasMatch(text);

  /// La petición de enlace también queda pendiente si no llegó respuesta.
  /// No basta encontrar «envíame un link» en cualquier mensaje antiguo.
  static bool expectsLink(ConversationDialogueState? state) =>
      state?.hasPendingQuestion == true;
}
