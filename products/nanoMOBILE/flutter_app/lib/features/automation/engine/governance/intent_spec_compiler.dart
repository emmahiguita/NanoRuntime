/// IntentSpecCompiler (A11) — compilación determinista y limitada de la
/// instrucción del usuario a un [IntentSpec].
///
/// No resuelve toda la interpretación NL: para goals conocidos compila preciso;
/// para goals desconocidos produce scope CONSERVADOR (solo `read`). Nunca otorga
/// autoridad wildcard.
library;

import 'intent_spec.dart';

class IntentSpecCompiler {
  const IntentSpecCompiler();

  IntentSpec compile(String goal) {
    final g = goal.trim().toLowerCase();

    // Envío de mensaje (scope al target extraído).
    if (_containsAny(g, [
      'responde',
      'responde a',
      'envía',
      'envia',
      'manda',
      'mensaje a',
      'contesta',
    ])) {
      return IntentSpec(
        id: 'intent:send-message',
        allowedEffects: const {ActionEffect.sendExternalMessage},
        targetScope: _extractTarget(g),
      );
    }

    // Cambio de estado (no hay tool actual que lo implemente: futuro).
    if (_containsAny(g, [
      'activa',
      'activar',
      'enciende',
      'encender',
      'desactiva',
      'desactivar',
      'apaga',
      'apagar',
      'cambia',
      'cambiar',
      'toggle',
    ])) {
      return const IntentSpec(
        id: 'intent:change-state',
        allowedEffects: {ActionEffect.changeSystemState},
      );
    }

    // Lectura.
    if (_containsAny(g, [
      'lee',
      'leer',
      'lista',
      'listar',
      'muestra',
      'mostrar',
      'dime',
      'ver',
      'cuáles',
      'cuales',
    ])) {
      return const IntentSpec(
        id: 'intent:read',
        allowedEffects: {ActionEffect.read},
      );
    }

    // Navegación.
    if (_containsAny(g, [
      'abre',
      'abrir',
      'ir a',
      've a',
      'entra',
      'entrar',
      'lanza',
      'lanzar',
    ])) {
      return const IntentSpec(
        id: 'intent:navigate',
        allowedEffects: {ActionEffect.navigate},
      );
    }

    // Desconocido → conservador (solo lectura; requiere clarificación aguas
    // arriba para efectos mayores).
    return const IntentSpec(
      id: 'intent:unknown',
      allowedEffects: {ActionEffect.read},
    );
  }

  String? _extractTarget(String goal) {
    // "responde a Juan que ..." → "juan"
    final g = goal.trim().toLowerCase();
    final prefixes = [
      'responde a ',
      'envía a ',
      'envia a ',
      'manda a ',
      'mensaje a ',
    ];
    for (final p in prefixes) {
      final idx = g.indexOf(p);
      if (idx >= 0) {
        final rest = g.substring(idx + p.length);
        final token = rest
            .split(RegExp(r'[\s,.]'))
            .firstWhere((t) => t.isNotEmpty, orElse: () => '');
        if (token.isNotEmpty) return token;
      }
    }
    return null;
  }

  bool _containsAny(String hay, List<String> terms) => terms.any(hay.contains);
}
