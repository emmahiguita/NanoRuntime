/// Política única para decidir quién controla una conversación.
///
/// QUÉ HACE:
/// Convierte el modo de destinatarios y el ownership persistido en una
/// respuesta inequívoca: `true` significa que Nano no puede enviar.
///
/// CÓMO FUNCIONA:
/// En modo `selected`, solo una selección explícita del bot habilita el chat.
/// En modo global, se respeta un takeover humano activo y temporal.
///
/// POR QUÉ:
/// La interfaz y el pipeline deben aplicar la misma regla; de lo contrario la
/// pantalla puede mostrar «IA activa» mientras el motor bloquea el mensaje.
library;

import '../domain/conversation_owner.dart';

abstract final class ConversationOwnershipPolicy {
  static bool humanOwns({
    required String targetContactsMode,
    required ConversationOwnership? ownership,
  }) {
    if (targetContactsMode == 'selected') {
      return ownership?.owner != ConversationOwner.bot;
    }
    return ownership?.humanOwns ?? false;
  }
}
