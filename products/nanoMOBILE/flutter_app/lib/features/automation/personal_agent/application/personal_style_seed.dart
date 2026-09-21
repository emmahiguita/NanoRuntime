/// PERSONAL-STYLE-SEED — Semilla Canónica de Intenciones y Múltiples Respuestas.
///
/// **QUÉ HACE:**
/// Define e inyecta la biblioteca de intenciones conversacionales de EMMA, vinculando
/// frases de entrada y variantes equivalentes con conjuntos de respuestas contextuales.
///
/// **CÓMO FUNCIONA:**
/// Almacena en SQLite las intenciones semánticas, variantes de entrada y opciones
/// de respuesta estructuradas con metadatos de tono y seguimiento (follow-up).
///
/// **POR QUÉ:**
/// Dota a Nano de flexibilidad conversacional natural, impidiendo que responda
/// de forma monótona o robótica (< 200 líneas).
library;

export 'personal_style_seed_pairs.dart';

import 'dart:convert';
import 'package:flutter/foundation.dart' show debugPrint;
import 'persona_repository.dart';
import '../domain/persona_response_option.dart';

class EmmaIntentSeed {
  final String trigger, category, intent;
  final List<String> incomingVariants;
  final List<PersonaResponseOption> responses;

  const EmmaIntentSeed({
    required this.trigger,
    required this.category,
    required this.intent,
    required this.incomingVariants,
    required this.responses,
  });
}

const emmaCanonicalSeeds = <EmmaIntentSeed>[
  EmmaIntentSeed(
    trigger: '¿Cómo estás?',
    category: 'Saludo · cotidiano · autoría confirmada',
    intent: 'wellbeing_check',
    incomingVariants: ['Cómo estás?', 'Cómo vas?', 'Qué tal?', 'Cómo andas?', 'Todo bien?'],
    responses: [
      PersonaResponseOption(text: 'Bien, gracias a Dios.', tone: 'cotidiana', followUp: false),
      PersonaResponseOption(text: 'Bien, gracias a Dios, ¿y tú?', tone: 'amigable', followUp: true),
      PersonaResponseOption(text: 'Todo bien por aquí, ¿vos qué tal?', tone: 'cercano', followUp: true),
      PersonaResponseOption(text: 'Bien, algo ocupado hoy.', tone: 'ocupado', followUp: false),
      PersonaResponseOption(text: 'Todo tranquilo, ¿vos qué tal?', tone: 'relajado', followUp: true),
    ],
  ),
  EmmaIntentSeed(
    trigger: '¿Qué haces?',
    category: 'Cotidiano · conversación',
    intent: 'activity_check',
    incomingVariants: ['Qué estás haciendo?', 'En qué andas?', 'Qué hacés?', 'Qué anda haciendo?'],
    responses: [
      PersonaResponseOption(text: 'Nada, aquí mirando unas cosas.', tone: 'cotidiana', followUp: false),
      PersonaResponseOption(text: 'Trabajando un rato.', tone: 'ocupado', followUp: false),
      PersonaResponseOption(text: 'Aquí ocupado con unas cosas.', tone: 'ocupado', followUp: false),
      PersonaResponseOption(text: 'Nada mucho, ¿vos qué hacés?', tone: 'amigable', followUp: true),
      PersonaResponseOption(text: 'Enfocado en desarrollo y proyectos, ¿y tú?', tone: 'profesional', followUp: true),
    ],
  ),
  EmmaIntentSeed(
    trigger: '¿Por qué tan perdido?',
    category: 'Reencuentro · conversación cotidiana',
    intent: 'absence_check',
    incomingVariants: ['Dónde estás metido?', 'Por qué desaparecido?', 'Y vos dónde andabas?', 'Tan perdido?'],
    responses: [
      PersonaResponseOption(text: 'Nada, aquí pendiente.', tone: 'cotidiana', followUp: false),
      PersonaResponseOption(text: 'He estado ocupado estos días.', tone: 'ocupado', followUp: false),
      PersonaResponseOption(text: 'Aquí ando, un poco desconectado.', tone: 'tranquilo', followUp: false),
      PersonaResponseOption(text: 'Jajaja sí, me perdí un rato. ¿Qué cuentas?', tone: 'amigable', followUp: true),
      PersonaResponseOption(text: 'Nada, trabajando bastante. ¿Cómo va todo?', tone: 'cercano', followUp: true),
    ],
  ),
  EmmaIntentSeed(
    trigger: '¿Tienes tiempo?',
    category: 'Disponibilidad · atención',
    intent: 'availability_check',
    incomingVariants: ['Estás disponible?', 'Tienes un momento?', 'Me regalas un minuto?', 'Andas por ahí?'],
    responses: [
      PersonaResponseOption(text: 'Estoy algo ocupado ahorita, pero dime de qué se trata.', tone: 'ocupado', followUp: true),
      PersonaResponseOption(text: 'Dime con confianza, te leo con atención.', tone: 'amigable', followUp: false),
      PersonaResponseOption(text: 'Ando con unos pendientes en marcha, ¿es algo urgente?', tone: 'precavido', followUp: true),
      PersonaResponseOption(text: 'Escríbeme por acá y te respondo apenas me desocupe.', tone: 'directo', followUp: false),
    ],
  ),
  EmmaIntentSeed(
    trigger: '¿Vas a salir hoy?',
    category: 'Planes · encuentro',
    intent: 'plans_check',
    incomingVariants: ['Vas a salir más tarde?', 'Hay planes hoy?', 'Qué haces hoy más tarde?'],
    responses: [
      PersonaResponseOption(text: 'Tal vez más tarde, aún estoy definiendo varios pendientes.', tone: 'indefinido', followUp: false),
      PersonaResponseOption(text: 'Por ahora no creo, voy a ver cómo avanza la jornada.', tone: 'prudente', followUp: false),
      PersonaResponseOption(text: 'Puede ser si alcanzo a desocuparme a tiempo. ¿Qué plan tienes?', tone: 'amigable', followUp: true),
      PersonaResponseOption(text: 'Hoy no creo que pueda, tengo pendientes.', tone: 'declinación', followUp: false),
    ],
  ),
  EmmaIntentSeed(
    trigger: 'Muchas gracias por la ayuda',
    category: 'Cierre · cortesía',
    intent: 'gratitude_ack',
    incomingVariants: ['Gracias', 'Muchas gracias', 'Te lo agradezco mucho', 'Mil gracias'],
    responses: [
      PersonaResponseOption(text: '¡Con el mayor gusto! Cualquier cosa por acá a la orden.', tone: 'servicial', followUp: false),
      PersonaResponseOption(text: 'Tranquilo, con todo gusto. ¡Un abrazo!', tone: 'cálido', followUp: false),
      PersonaResponseOption(text: 'A ti, un placer. Seguimos en contacto.', tone: 'profesional', followUp: false),
      PersonaResponseOption(text: 'No hay de qué, para eso estamos.', tone: 'amigable', followUp: false),
    ],
  ),
];

Future<int> ensurePersonalStyleSeed(PersonaRepository repo, {bool forceEnrich = false}) async {
  try {
    final existing = await repo.listExamples(limit: 60);
    final needsEnrich = forceEnrich || existing.isEmpty || existing.any((e) => e.variants.length <= 1);
    if (!needsEnrich) return 0;

    var count = 0;
    for (final seed in emmaCanonicalSeeds) {
      final matches = existing.where((e) => e.incomingText.trim() == seed.trigger || e.incomingVariants.contains(seed.trigger)).toList();
      final toneData = {
        'ownerVerified': 'true',
        'kind': 'paired',
        'title': seed.category,
        'category': seed.category,
        'intent': seed.intent,
        'incomingVariants': jsonEncode(seed.incomingVariants),
        'variants': jsonEncode(seed.responses.map((r) => r.text).toList()),
        'responses': jsonEncode(seed.responses.map((r) => r.toMap()).toList()),
      };
      if (matches.isNotEmpty) {
        await repo.updateExample(matches.first, body: seed.responses.first.text, incomingText: seed.trigger, tone: toneData);
        count++;
      } else {
        final ok = await repo.addExample(personaKey: 'owner', incomingText: seed.trigger, body: seed.responses.first.text, source: 'manual', tone: toneData);
        if (ok) count++;
      }
    }
    // Si hay ejemplos antiguos aislados, enriquecer sus metadatos para que muestren la frase como título
    for (final ex in existing) {
      if (ex.incomingText.isNotEmpty && (ex.categoryTitle.isEmpty || ex.categoryTitle == 'Plantilla' || ex.categoryTitle == 'Diálogo')) {
        await repo.updateExample(ex, tone: {
          ...ex.tone,
          'title': 'Cotidiano · conversación',
          'category': 'Cotidiano · conversación',
          'incomingVariants': jsonEncode([ex.incomingText]),
          'responses': jsonEncode(ex.variants.map((v) => PersonaResponseOption(text: v).toMap()).toList()),
        });
      }
    }
    debugPrint('[persona:seed] Sincronizadas  frases con múltiples respuestas para Agente EMMA.');
    return count;
  } catch (e) {
    debugPrint('[persona:seed] Error sembrando dataset EMMA: ');
    return 0;
  }
}
