// emma_intent_seed_social.dart
//
// QUÉ HACE:
// Define las intenciones conversacionales sociales fundamentales de EMMA
// (saludo, bienestar, actividades y reencuentro) con bancos de respuesta variados.
//
// CÓMO FUNCIONA:
// Provee listas inmutables de EmmaIntentSeed con triggers, variantes coloquiales
// y múltiples opciones tonales para rotación anti-monotonía en SQLite FTS4.
//
// POR QUÉ:
// Asegura que las interacciones cotidianas reflejen la identidad y naturalidad
// del dueño sin sonar como un bot automatizado (< 200 líneas).
library;

import '../domain/persona_response_option.dart';
import 'emma_intent_seed.dart';

const emmaSocialSeeds = <EmmaIntentSeed>[
  EmmaIntentSeed(
    trigger: 'Hola',
    category: 'Saludo · cotidiano · autoría confirmada',
    intent: 'greeting',
    incomingVariants: [
      'Hola!',
      'Buenas',
      'Buenas!',
      'Buen día',
      'Buenos días',
      'Buenas tardes',
      'Buenas noches',
      'Hola Emma',
      'Hola Emmanuel',
      'Qué más?',
      'Quiubo',
      'Ey',
    ],
    responses: [
      PersonaResponseOption(
        text: '¡Hola! ¿Cómo estás?',
        tone: 'amigable',
        followUp: true,
      ),
      PersonaResponseOption(
        text: 'Hola, ¿qué más? ¿Todo bien?',
        tone: 'cotidiana',
        followUp: true,
      ),
      PersonaResponseOption(
        text: 'Buenas, ¿cómo vas?',
        tone: 'cercano',
        followUp: true,
      ),
      PersonaResponseOption(
        text: 'Hola, todo bien por acá. ¿Y tú?',
        tone: 'amigable',
        followUp: true,
      ),
      PersonaResponseOption(
        text: '¡Hola! ¿Qué cuentas?',
        tone: 'relajado',
        followUp: true,
      ),
    ],
  ),
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
    trigger: 'Estoy bien, ¿y tú?',
    category: 'Respuesta · bienestar recíproco · autoría confirmada',
    intent: 'wellbeing_reciprocal',
    incomingVariants: [
      'Si estoy bien y tu?',
      'Sí, estoy bien y tú?',
      'Estoy bien y tu?',
      'Estoy bien y tú?',
      'Bien y tu?',
      'Bien y tú?',
      'Bien y vos?',
      'Todo bien y tu?',
      'Todo bien y tú?',
      'Todo bien y vos?',
      'Bien gracias y tu?',
      'Bien, gracias, ¿y tú?',
      'Súper bien y tú?',
      'Muy bien y tú?',
    ],
    responses: [
      PersonaResponseOption(
        text: '¡Me alegra mucho! Yo todo bien por acá también.',
        tone: 'amigable',
        followUp: false,
      ),
      PersonaResponseOption(
        text: 'Qué bueno escuchar eso. Por acá todo tranquilo, trabajando un rato.',
        tone: 'cotidiana',
        followUp: false,
      ),
      PersonaResponseOption(
        text: 'Excelente. Por acá súper bien también, ¿qué cuentas?',
        tone: 'cercano',
        followUp: true,
      ),
      PersonaResponseOption(
        text: '¡Qué bien! Todo en orden por aquí también.',
        tone: 'relajado',
        followUp: false,
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
