import 'package:flutter/foundation.dart';
import '../../domain/bot/bot_definition.dart';
import '../../domain/bot/bot_event.dart';

/// QUÉ HACE:
/// Almacena el contexto vivo y la memoria efímera de una ejecución agéntica.
///
/// CÓMO FUNCIONA:
/// Mantiene las referencias al bot, al evento detonante, a los hechos
/// factuales de la memoria SQLite y a la bitácora de pasos ejecutados.
///
/// POR QUÉ:
/// Garantiza trazabilidad y permite que las herramientas consulten el estado
/// actual sin romper la inmutabilidad de la definición del bot.
class BotExecutionContext {
  final BotDefinition bot;
  final BotEvent event;
  final Map<String, dynamic> memoryFacts;
  final List<String> executionLogs;
  final int startedAtMs;

  BotExecutionContext({
    required this.bot,
    required this.event,
    this.memoryFacts = const {},
    List<String>? logs,
    int? startedAtMs,
  })  : executionLogs = logs ?? [],
        startedAtMs = startedAtMs ?? DateTime.now().millisecondsSinceEpoch;

  /// Registra un paso en la traza de auditoría del ciclo agéntico.
  void log(String step) {
    final elapsed = DateTime.now().millisecondsSinceEpoch - startedAtMs;
    executionLogs.add("[+${elapsed}ms] $step");
    if (kDebugMode) {
      debugPrint("[BotRuntime:${bot.name}] $step");
    }
  }

  /// Retorna el tiempo transcurrido total en milisegundos.
  int get elapsedMs =>
      DateTime.now().millisecondsSinceEpoch - startedAtMs;

  /// Obtiene un hecho de memoria o un valor por defecto.
  T? getFact<T>(String key) {
    final value = memoryFacts[key];
    if (value is T) return value;
    return null;
  }
}
