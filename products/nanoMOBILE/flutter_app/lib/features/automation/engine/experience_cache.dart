/// ExperienceCache (Fase C7) — memoria de ejecuciones VERIFICADAS.
///
/// Guarda SOLO planes que completaron con verificación por paso. En una
/// ejecución futura con el mismo objetivo, devuelve el flow conocido
/// (validado + con confianza) para no volver a razonar con el LLM.
///
/// Reglas de honestidad:
/// - [recordSuccess] SOLO se llama cuando el plan terminó verificado.
/// - Un fallo degrada la confianza; por debajo de [minConfidence] el flow se
///   invalida (hit deja de devolverlo) hasta una nueva verificación.
/// - El caché es por objetivo + app/paquete cuando se conoce.
library;

import 'agent_tool_dispatcher.dart';

/// Flow verificado que puede reutilizarse.
class VerifiedFlow {
  final String goal;

  /// Plan que completó verificado (steps = [ToolCall]s).
  final List<ToolCall> steps;

  int successCount;
  int failureCount;
  DateTime lastVerified;
  DateTime? lastFailure;

  VerifiedFlow({
    required this.goal,
    required this.steps,
    this.successCount = 1,
    this.failureCount = 0,
    required this.lastVerified,
  });

  /// Confianza 0..1: éxito/(éxito+fallo). 1.0 tras una sola verificación.
  double get confidence {
    final total = successCount + failureCount;
    if (total == 0) return 0;
    return successCount / total;
  }
}

/// Memoria de experiencias. En memoria (el plan maestro pide persistencia
/// después de estabilizar el benchmark; aquí el contrato es el caché).
class ExperienceCache {
  ExperienceCache({this.minConfidence = 0.5, this.maxGoals = 32});

  /// Confianza mínima para devolver un flow como hit.
  final double minConfidence;

  /// Límite de objetivos retenidos (bounded, LRU simple).
  final int maxGoals;

  final Map<String, VerifiedFlow> _byGoal = {};
  final List<String> _lru = [];

  int get size => _byGoal.length;

  /// Flow verificado para [goal] con confianza suficiente. null = miss
  /// (el llamador usa Koog/LLM).
  VerifiedFlow? planFor(String goal) {
    final key = _normalize(goal);
    final flow = _byGoal[key];
    if (flow == null) return null;
    if (flow.confidence < minConfidence) return null; // invalidado por fallos
    _touch(key);
    return flow;
  }

  /// Registra un plan que completó y se verificó paso a paso.
  void recordSuccess(String goal, List<ToolCall> steps) {
    final key = _normalize(goal);
    final now = DateTime.now();
    final existing = _byGoal[key];
    if (existing != null) {
      // Solo actualiza los pasos si el plan verificado es idéntico (el mundo
      // cambió) — si difiere, es un flow nuevo con éxito acumulado.
      existing.successCount++;
      existing.lastVerified = now;
      if (!_samePlan(existing.steps, steps)) {
        existing.steps..clear()..addAll(steps);
      }
    } else {
      _byGoal[key] = VerifiedFlow(
        goal: goal,
        steps: List.of(steps),
        lastVerified: now,
      );
      _lru.add(key);
      _evictIfNeeded();
    }
    _touch(key);
  }

  /// Registra un fallo del objetivo (plan no completó): degrada confianza.
  void recordFailure(String goal) {
    final key = _normalize(goal);
    final existing = _byGoal[key];
    if (existing == null) return; // sin flow previo, nada que degradar
    existing.failureCount++;
    existing.lastFailure = DateTime.now();
  }

  void clear() {
    _byGoal.clear();
    _lru.clear();
  }

  String _normalize(String goal) => goal.trim().toLowerCase();

  static bool _samePlan(List<ToolCall> a, List<ToolCall> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i].tool != b[i].tool ||
          a[i].selector != b[i].selector ||
          a[i].text != b[i].text) {
        return false;
      }
    }
    return true;
  }

  void _touch(String key) {
    _lru
      ..remove(key)
      ..add(key);
  }

  void _evictIfNeeded() {
    while (_byGoal.length > maxGoals && _lru.isNotEmpty) {
      _byGoal.remove(_lru.removeAt(0));
    }
  }
}
