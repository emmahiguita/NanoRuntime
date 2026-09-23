/// Intenciones sociales verificadas y sus opciones no monótonas.
library;

import '../domain/persona_response_option.dart';
import 'emma_intent_seed.dart';

const emmaSocialSeeds = <EmmaIntentSeed>[
  EmmaIntentSeed(
    trigger: '¿Cómo estás?',
    category: 'Saludo · cotidiano · autoría confirmada',
    intent: 'wellbeing_check',
    incomingVariants: [
      'Cómo estás?',
      'Cómo vas?',
      'Qué tal?',
      'Cómo andas?',
      'Todo bien?',
    ],
    responses: [
      PersonaResponseOption(text: 'Bien, gracias a Dios.', tone: 'cotidiana'),
      PersonaResponseOption(
        text: 'Bien, gracias a Dios, ¿y tú?',
        tone: 'amigable',
        followUp: true,
      ),
      PersonaResponseOption(
        text: 'Todo bien por aquí, ¿vos qué tal?',
        tone: 'cercano',
        followUp: true,
      ),
      PersonaResponseOption(text: 'Bien, algo ocupado hoy.', tone: 'ocupado'),
      PersonaResponseOption(
        text: 'Todo tranquilo, ¿vos qué tal?',
        tone: 'relajado',
        followUp: true,
      ),
    ],
  ),
  EmmaIntentSeed(
    trigger: '¿Qué haces?',
    category: 'Cotidiano · conversación',
    intent: 'activity_check',
    incomingVariants: [
      'Qué estás haciendo?',
      'En qué andas?',
      'Qué hacés?',
      'Qué anda haciendo?',
    ],
    responses: [
      PersonaResponseOption(
        text: 'Nada, aquí mirando unas cosas.',
        tone: 'cotidiana',
      ),
      PersonaResponseOption(text: 'Trabajando un rato.', tone: 'ocupado'),
      PersonaResponseOption(
        text: 'Aquí ocupado con unas cosas.',
        tone: 'ocupado',
      ),
      PersonaResponseOption(
        text: 'Nada mucho, ¿vos qué hacés?',
        tone: 'amigable',
        followUp: true,
      ),
      PersonaResponseOption(
        text: 'Enfocado en desarrollo y proyectos, ¿y tú?',
        tone: 'profesional',
        followUp: true,
      ),
    ],
  ),
  EmmaIntentSeed(
    trigger: '¿Por qué tan perdido?',
    category: 'Reencuentro · conversación cotidiana',
    intent: 'absence_check',
    incomingVariants: [
      'Dónde estás metido?',
      'Por qué desaparecido?',
      'Y vos dónde andabas?',
      'Tan perdido?',
    ],
    responses: [
      PersonaResponseOption(text: 'Nada, aquí pendiente.', tone: 'cotidiana'),
      PersonaResponseOption(
        text: 'He estado ocupado estos días.',
        tone: 'ocupado',
      ),
      PersonaResponseOption(
        text: 'Aquí ando, un poco desconectado.',
        tone: 'tranquilo',
      ),
      PersonaResponseOption(
        text: 'Jajaja sí, me perdí un rato. ¿Qué cuentas?',
        tone: 'amigable',
        followUp: true,
      ),
      PersonaResponseOption(
        text: 'Nada, trabajando bastante. ¿Cómo va todo?',
        tone: 'cercano',
        followUp: true,
      ),
    ],
  ),
];
