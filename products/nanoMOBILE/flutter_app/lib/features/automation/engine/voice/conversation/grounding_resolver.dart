/// A16 — GroundingResolver: resuelve pronombres y referencias a entidades
/// grounded del [ConversationalWorldState]. Determinista, sin LLM.
///
/// "respóndele" → activePerson; "esa app" → activeApp; "ese mensaje" →
/// activeConversation/activePerson. Si es ambiguo o sin evidencia, devuelve
/// null (Nano pregunta aclaración, nunca adivina un target de escritura).
library;

import 'conversational_world_state.dart';

class GroundingResolver {
  const GroundingResolver();

  static const _personPronouns = {
    'él',
    'el',
    'ella',
    'le',
    'lo',
    'la',
    'les',
    'lui',
    'ella misma',
    'él mismo',
  };

  static const _appWords = {
    'app',
    'aplicación',
    'aplicacion',
    'esa app',
    'la app',
  };

  static const _messageWords = {
    'mensaje',
    'notificación',
    'notificacion',
    'ese mensaje',
    'el mensaje',
    'ese mensaje suyo',
    'lo que dijo',
  };

  static const _ordinals = {
    'primero',
    'primer',
    'el primero',
    'segundo',
    'el segundo',
    'tercero',
    'el tercero',
  };

  /// Resuelve una referencia de voz a la entidad grounded del mundo activo.
  /// Devuelve la entidad (string) o null si no es resoluble de forma segura.
  String? resolve(String reference, ConversationalWorldState world) {
    final r = reference.toLowerCase().trim();
    if (r.isEmpty) return null;

    // Pronombres de persona → la persona activa.
    if (_personPronouns.contains(r)) {
      return world.activePerson ?? world.activeConversation;
    }

    // "esa app" / "la app" → la app activa.
    if (_appWords.any(r.contains)) {
      return world.activeApp;
    }

    // "ese mensaje" / "la notificación" → la conversación/persona activa.
    if (_messageWords.any(r.contains)) {
      return world.activeConversation ?? world.activePerson;
    }

    // Ordinal ("el segundo") → no resoluble sin una lista ordenada: se delega
    // al llamador con la lista real. Aquí se devuelve null (sin adivinar).
    if (_ordinals.any(r.contains)) {
      return null;
    }

    // Referente por nombre guardado ("juan" → entidad).
    final byName = world.resolve(r);
    if (byName != null) return byName.entity;

    return null;
  }
}
