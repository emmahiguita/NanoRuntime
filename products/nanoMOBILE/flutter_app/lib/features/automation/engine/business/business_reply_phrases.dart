// QUÉ: redacta variaciones seguras para respuestas comerciales frecuentes.
// CÓMO: rota frases por minuto sin agregar datos que no estén configurados.
// POR QUÉ: evita una voz robótica manteniendo el contenido factual y predecible.
library;

import '../messaging/tone_profile.dart';
import 'business_response_templates.dart';

String businessGreeting({
  required String name,
  required ToneProfile tone,
  required String message,
  BusinessResponseTemplates? templates,
}) {
  // Un texto editado por el negocio tiene prioridad sobre las variaciones base.
  final edited = templates?.render(BusinessResponseTemplates.greeting, {
    'negocio': name,
  });
  if (edited != null) return edited;
  final prefix = tone.emojis ? '👋 ' : '';
  final close = tone.verbosity == ToneVerbosity.breve
      ? '¿En qué podemos ayudarte?'
      : 'Cuéntanos qué necesitas; podemos orientarte sobre productos, envíos o pagos.';
  final options = tone.warmth == ToneWarmth.cercano
      ? [
          '¡Hola! Gracias por escribir a $name. $close',
          '¡Buenas! Te damos la bienvenida a $name. $close',
          '¡Hola! Qué gusto atenderte en $name. $close',
        ]
      : [
          'Un cordial saludo. Gracias por contactar a $name. $close',
          'Bienvenido/a a $name. $close',
          'Hola. Es un gusto atenderle en $name. $close',
        ];
  return '$prefix${_pick(options, message)}';
}

/// Redacta el saludo que acompaña una consulta usando el nombre configurado.
String businessGreetingPrefix({
  required String name,
  required ToneProfile tone,
  required BusinessResponseTemplates templates,
}) =>
    templates.render(BusinessResponseTemplates.greetingPrefix, {
      'negocio': name,
    }) ??
    (tone.warmth == ToneWarmth.cercano
        ? '${tone.emojis ? "👋 " : ""}¡Hola! Te damos la bienvenida a $name.'
        : '${tone.emojis ? "👋 " : ""}Un cordial saludo. Bienvenido/a a $name.');

/// Devuelve el cierre guardado o conserva la elección vigente de tono comercial.
String businessSalesClosing({
  required ToneProfile tone,
  required BusinessResponseTemplates templates,
}) {
  final persuasive = tone.sales == ToneSales.persuasivo;
  final fallback = tone.warmth == ToneWarmth.cercano
      ? (persuasive
            ? '¿Qué detalle quieres que revisemos para continuar?'
            : '¿En qué más te podemos ayudar?')
      : (persuasive
            ? '¿Qué detalle desea que revisemos para continuar?'
            : '¿Tiene alguna otra inquietud?');
  return templates.render(BusinessResponseTemplates.salesClosing, const {}) ??
      fallback;
}

String businessHumanReply(
  ToneProfile tone,
  String message, {
  BusinessResponseTemplates? templates,
}) {
  // Mantiene derivación humana real; la frase solo personaliza su redacción.
  final edited = templates?.render(
    BusinessResponseTemplates.humanHandoff,
    const {},
  );
  if (edited != null) return edited;
  final options = tone.warmth == ToneWarmth.cercano
      ? const [
          'Claro. Un asesor debe continuar esta conversación para ayudarte personalmente.',
          'Con gusto. Voy a dejar esta conversación lista para atención de un asesor.',
        ]
      : const [
          'Con mucho gusto. Un asesor debe continuar la atención personalmente.',
          'Claro. Dejaremos la conversación preparada para la atención de un asesor.',
        ];
  return '${tone.emojis ? "👋 " : ""}${_pick(options, message)}';
}

String businessMissingReply({
  required List<String> missing,
  required ToneProfile tone,
  required String message,
  BusinessResponseTemplates? templates,
}) {
  final facts = missing.join(', ');
  // Inserta únicamente los datos faltantes detectados por el motor.
  final edited = templates?.render(BusinessResponseTemplates.missingFacts, {
    'datos': facts,
  });
  if (edited != null) return edited;
  final options = tone.warmth == ToneWarmth.cercano
      ? [
          'No tengo confirmado $facts. ¿Quieres que te comunique con un asesor?',
          'Para responderte bien debo confirmar $facts. ¿Te contactamos con un asesor?',
        ]
      : [
          'No tenemos confirmado $facts. ¿Desea que le comuniquemos con un asesor?',
          'Para responder correctamente debemos confirmar $facts. ¿Desea atención de un asesor?',
        ];
  return _pick(options, message);
}

String businessUnknownReply({
  required bool hasLink,
  required ToneProfile tone,
  required String message,
  BusinessResponseTemplates? templates,
}) {
  final subject = hasLink
      ? 'No puedo verificar el contenido del enlace desde esta conversación.'
      : 'No entendí del todo la consulta.';
  // El motivo procede de la detección local de enlace o comprensión.
  final edited = templates?.render(BusinessResponseTemplates.unknownMessage, {
    'motivo': subject,
  });
  if (edited != null) return edited;
  final close = tone.warmth == ToneWarmth.cercano
      ? [
          '¿Puedes contarme qué necesitas o prefieres hablar con un asesor?',
          'Cuéntame un poco más o te comunico con un asesor, ¿qué prefieres?',
        ]
      : [
          '¿Podría indicarnos qué necesita o prefiere hablar con un asesor?',
          '¿Desea ampliar la consulta o prefiere atención de un asesor?',
        ];
  return '${tone.emojis ? "👋 " : ""}$subject ${_pick(close, message)}';
}

String _pick(List<String> options, String seed) {
  final minute = DateTime.now().millisecondsSinceEpoch ~/ 60000;
  return options[(seed.hashCode ^ minute).abs() % options.length];
}
