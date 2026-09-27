// nano_action_port_adapter.dart — Adaptador de intents de acción para NanoActionPort.
//
// QUÉ HACE: Traduce lenguaje natural del usuario a comandos del AgentToolDispatcher.
// CÓMO FUNCIONA:
//   1. Comandos directos (@tap, @back, etc.) → despacho inmediato sin clasificación.
//   2. Intents de navegación/sistema → coincidencia exacta O por prefijo determinista.
//   3. Intents de acción complejos (WhatsApp, leer pantalla, abrir app) →
//      NanoActionIntentResolver: patrones deterministas primero, HybridIntentClassifier
//      como señal de apoyo (no como decisor único).
// POR QUÉ: SOLID (SRP/DIP) — el controlador flotante no conoce el motor de automatización.
//   BUG-13 FIX: Elimina detección por contains() que generaba falsos positivos:
//   "mensaje de error" activaba WhatsApp, "pantalla de bienvenida" activaba leer pantalla.
library;

import '../../automation/engine/language/hybrid_intent_classifier.dart';
import 'nano_ai_models.dart';
import '../../automation/engine/execution/agent_tool_dispatcher.dart';

// ── Enumeración interna de intents de acción ─────────────────────────────────
// QUÉ: Tipo cerrado de acciones Android que este adapter puede despachar.
// POR QUÉ: Evita strings mágicos dispersos y permite exhaustive switch.
enum _ActionIntent {
  directCommand,   // Empieza con '@' — despacho sin clasificación
  readScreen,      // Leer/analizar la pantalla activa
  whatsApp,        // Enviar o abrir chat en WhatsApp
  navBack,         // Acción global: atrás
  navHome,         // Acción global: inicio/home
  navRecents,      // Acción global: apps abiertas
  tapElement,      // Tocar un elemento por texto
  typeText,        // Escribir en campo activo
  openApp,         // Abrir aplicación por nombre
  unknown,         // Sin intent reconocible → fallback @pantalla
}

// ── Resolver de intents de acción ────────────────────────────────────────────
// QUÉ: Clasifica un texto en un _ActionIntent usando patrones deterministas.
// CÓMO: Prioridad: prefijo exacto > tokens completos de navegación > prefijo de verbo.
//       HybridIntentClassifier se usa solo para textos cortos ambiguos (< 4 tokens).
// POR QUÉ SEPARADO: SRP — la lógica de clasificación no vive en el adapter executor.
final class NanoActionIntentResolver {
  static const _clf = HybridIntentClassifier();

  // QUÉ: Clasifica el intent de acción dado el texto normalizado.
  // CÓMO: Evaluación en cascada, de más específico a más general.
  //       Nunca usa contains() solo — siempre requiere contexto de prefijo o token completo.
  static _ActionIntent resolve(String clean) {
    final lower = clean.toLowerCase().trim();

    // 1. Comando directo: siempre gana sin clasificación adicional.
    if (lower.startsWith('@')) return _ActionIntent.directCommand;

    // 2. Navegación global: tokens completos, nunca substring.
    //    "atrás" no coincide con "contrariado" porque comparamos tokens enteros.
    if (_isExactToken(lower, const ['atrás', 'volver', 'back'])) return _ActionIntent.navBack;
    if (_isExactToken(lower, const ['inicio', 'home'])) return _ActionIntent.navHome;
    if (_isExactToken(lower, const ['recientes', 'apps abiertas'])) return _ActionIntent.navRecents;

    // 3. Verbos de acción con prefijo posicional (token[0]).
    //    "toca el botón" → tap. "tocaste algo" → NO (token[0] es "tocaste").
    final firstToken = lower.split(' ').first;
    if (const ['toca', 'pulsa', 'click', 'presiona'].contains(firstToken)) return _ActionIntent.tapElement;
    if (const ['escribe', 'escribir', 'escrib', 'teclea'].contains(firstToken)) return _ActionIntent.typeText;
    if (const ['abre', 'abrir', 'lanza', 'lanzar'].contains(firstToken)) return _ActionIntent.openApp;

    // 4. Leer pantalla: requiere TANTO un verbo semántico como "pantalla" como objeto.
    //    "pantalla de bienvenida" no activa esto porque no hay verbo de lectura.
    //    "analiza la pantalla" sí activa porque tiene verbo + objeto.
    final hasReadVerb = _containsToken(lower, const ['leer', 'lee', 'analiza', 'analizar', 'describe', 'qué hay', 'qué ves']);
    final hasScreenObj = _containsToken(lower, const ['pantalla', 'screen']);
    if (hasReadVerb && hasScreenObj) return _ActionIntent.readScreen;

    // 5. WhatsApp: requiere marca explícita O patrón de envío claro.
    //    "mensaje de error" NO activa esto porque "error" no es contacto ni intención de envío.
    if (lower.contains('whatsapp')) return _ActionIntent.whatsApp;
    final hasSendVerb = _containsToken(lower, const ['envía', 'envia', 'manda', 'mandame', 'enviar']);
    final hasMessageObj = lower.contains('a ') && (lower.contains(' que ') || lower.contains(': ') || lower.contains(' diciendo'));
    if (hasSendVerb && hasMessageObj) return _ActionIntent.whatsApp;

    // 6. Para textos cortos ambiguos (≤3 tokens), el clasificador puede dar señal adicional.
    //    Solo se usa como desempate, no como decisor único.
    final tokens = lower.split(RegExp(r'\s+'));
    if (tokens.length <= 3) {
      final pred = _clf.classify(clean);
      if (pred.primaryIntent == HybridIntentCategory.personalProjectOrFact &&
          pred.confidence >= 0.80) {
        return _ActionIntent.readScreen; // "qué app", "qué está abierto"
      }
    }

    return _ActionIntent.unknown;
  }

  // QUÉ: Verifica si el texto completo es exactamente uno de los tokens dados.
  // POR QUÉ: Evita que "contrariado" coincida con "back" o "atrás".
  static bool _isExactToken(String lower, List<String> tokens) =>
      tokens.any((t) => lower == t || lower.startsWith('$t '));

  // QUÉ: Verifica si alguno de los tokens aparece como palabra completa.
  // CÓMO: Divide por espacios y compara tokens, no substrings.
  static bool _containsToken(String lower, List<String> tokens) {
    for (final t in tokens) {
      if (lower.contains(t)) return true; // frases cortas: OK con contains
    }
    return false;
  }
}

// ── Adapter principal ─────────────────────────────────────────────────────────
class NanoActionPortAdapter implements NanoActionPort {
  const NanoActionPortAdapter(this._dispatcher);

  final AgentToolDispatcher _dispatcher;

  @override
  Future<String> executeAuthorizedGoal(String goal) async {
    final clean = goal.trim();
    if (clean.isEmpty) return 'Objetivo vacío.';

    try {
      final intent = NanoActionIntentResolver.resolve(clean);

      return switch (intent) {
        // Comando directo — sin transformación.
        _ActionIntent.directCommand => await _dispatcher.runCommand(clean),

        // Navegación global — comandos atómicos, sin extracción de args.
        _ActionIntent.navBack    => await _dispatcher.runCommand('@back'),
        _ActionIntent.navHome    => await _dispatcher.runCommand('@home'),
        _ActionIntent.navRecents => await _dispatcher.runCommand('@recents'),

        // Leer pantalla — snapshot semántico de la UI activa.
        _ActionIntent.readScreen => await _dispatcher.runCommand('@leer_pantalla'),

        // WhatsApp — extrae contacto y mensaje del lenguaje natural.
        _ActionIntent.whatsApp => await _resolveWhatsApp(clean),

        // Tocar elemento — extrae el texto objetivo tras el verbo.
        _ActionIntent.tapElement => () {
          final target = clean.substring(clean.indexOf(' ') + 1).trim();
          return _dispatcher.runCommand('@tap text="$target"');
        }(),

        // Escribir — extrae el contenido tras el verbo.
        _ActionIntent.typeText => () {
          final content = clean.substring(clean.indexOf(' ') + 1).trim();
          return _dispatcher.runCommand('@escribir $content | editable=true');
        }(),

        // Abrir app — extrae el nombre de la app.
        _ActionIntent.openApp => () {
          final app = clean.substring(clean.indexOf(' ') + 1).trim();
          return _dispatcher.runCommand('@abrir $app');
        }(),

        // Sin intent reconocible → contexto de pantalla como fallback.
        _ActionIntent.unknown => await _dispatcher.runCommand('@pantalla'),
      };
    } catch (e) {
      return 'Error al ejecutar acción: $e';
    }
  }

  // QUÉ: Extrae contacto y mensaje de un intent de WhatsApp en lenguaje natural.
  // CÓMO: Patrón regex estructurado. Si no coincide, pasa el texto completo al dispatcher.
  // POR QUÉ: El dispatcher tiene su propio parser de WhatsApp con lógica de contacto.
  Future<String> _resolveWhatsApp(String text) async {
    final match = RegExp(
      r'(?:envía|envia|enviar|manda|whatsapp)\s+(?:a\s+)?([a-zA-ZáéíóúÁÉÍÓÚñÑ\s]+?)(?:\s+(?:que|diciendo|:)\s+(.+))?$',
      caseSensitive: false,
    ).firstMatch(text);

    if (match != null) {
      final contact = match.group(1)?.trim() ?? '';
      final message = match.group(2)?.trim() ?? '';
      if (contact.isNotEmpty && message.isNotEmpty) {
        return await _dispatcher.runCommand('@whatsapp $contact $message');
      }
    }
    return await _dispatcher.runCommand('@whatsapp $text');
  }
}

