/// Intenciones de disponibilidad, planes y cortesía.
library;

import '../domain/persona_response_option.dart';
import 'emma_intent_seed.dart';

const emmaRoutineSeeds = <EmmaIntentSeed>[
  EmmaIntentSeed(
    trigger: '¿Tienes tiempo?',
    category: 'Disponibilidad · atención',
    intent: 'availability_check',
    incomingVariants: [
      'Estás disponible?',
      'Tienes un momento?',
      'Me regalas un minuto?',
      'Andas por ahí?',
    ],
    responses: [
      PersonaResponseOption(
        text: 'Estoy algo ocupado ahorita, pero dime de qué se trata.',
        tone: 'ocupado',
        followUp: true,
      ),
      PersonaResponseOption(
        text: 'Dime con confianza, te leo con atención.',
        tone: 'amigable',
      ),
      PersonaResponseOption(
        text: 'Ando con unos pendientes en marcha, ¿es algo urgente?',
        tone: 'precavido',
        followUp: true,
      ),
      PersonaResponseOption(
        text: 'Escríbeme por acá y te respondo apenas me desocupe.',
        tone: 'directo',
      ),
    ],
  ),
  EmmaIntentSeed(
    trigger: '¿Vas a salir hoy?',
    category: 'Planes · encuentro',
    intent: 'plans_check',
    incomingVariants: [
      'Vas a salir más tarde?',
      'Hay planes hoy?',
      'Qué haces hoy más tarde?',
    ],
    responses: [
      PersonaResponseOption(
        text: 'Tal vez más tarde, aún estoy definiendo varios pendientes.',
        tone: 'indefinido',
      ),
      PersonaResponseOption(
        text: 'Por ahora no creo, voy a ver cómo avanza la jornada.',
        tone: 'prudente',
      ),
      PersonaResponseOption(
        text: 'Puede ser si alcanzo a desocuparme a tiempo. ¿Qué plan tienes?',
        tone: 'amigable',
        followUp: true,
      ),
      PersonaResponseOption(
        text: 'Hoy no creo que pueda, tengo pendientes.',
        tone: 'declinación',
      ),
    ],
  ),
  EmmaIntentSeed(
    trigger: 'Muchas gracias por la ayuda',
    category: 'Cierre · cortesía',
    intent: 'gratitude_ack',
    incomingVariants: [
      'Gracias',
      'Muchas gracias',
      'Te lo agradezco mucho',
      'Mil gracias',
    ],
    responses: [
      PersonaResponseOption(
        text: '¡Con el mayor gusto! Cualquier cosa por acá a la orden.',
        tone: 'servicial',
      ),
      PersonaResponseOption(
        text: 'Tranquilo, con todo gusto. ¡Un abrazo!',
        tone: 'cálido',
      ),
      PersonaResponseOption(
        text: 'A ti, un placer. Seguimos en contacto.',
        tone: 'profesional',
      ),
      PersonaResponseOption(
        text: 'No hay de qué, para eso estamos.',
        tone: 'amigable',
      ),
    ],
  ),
];
