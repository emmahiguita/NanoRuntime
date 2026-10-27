/// QUÉ: orienta el registro sin prohibir vocabulario de una conversación real.
/// CÓMO: la identidad y el contacto eligen el estilo; calidad verifica el texto.
/// POR QUÉ: «parce» no es una razón para perder una respuesta del dueño.
abstract final class PersonalLanguagePolicy {
  static const instructions =
      'Usa el trato y estilo declarados por el dueño para este contacto. '
      'Sin estilo declarado, usa español claro y cercano. '
      'Comprende bromas, risas y expresiones informales; no fuerces jerga ni intimidad.';

  // Se rechaza una salida incompatible; nunca se sustituye por otra frase fija.
  static bool accepts(String text) => text.trim().isNotEmpty;
}
