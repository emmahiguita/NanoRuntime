/// AppLaunchResolver (A2) — resolución determinista de "abre <app>".
///
/// El package SIEMPRE sale del [InstalledAppCatalog] (evidencia del
/// PackageManager). Jamás lo inventa el LLM ni lo sugiere contenido observado.
/// Si el nombre es ambiguo o no resuelve, devuelve null → NO se lanza nada.
///
/// IMPORTANT — orden de _openTerms: los términos más largos van PRIMERO para
/// que el scan greedy los evalúe antes que un prefijo más corto del mismo verbo
/// ("abre la app de spotify" no debe recortarse en "abre" dejando "la app de
/// spotify" como query).
library;

import '../execution/agent_tool_dispatcher.dart' show ToolCall;
import '../execution/goal_verifier.dart' show GoalExpectation;
import 'installed_app_catalog.dart';
import 'system_models.dart';

/// Plan grounded de launch: ToolCall con package real + expectativa de goal.
class AppLaunchPlan {
  final ToolCall call;
  final GoalExpectation expectation;
  final InstalledApp app;

  const AppLaunchPlan({
    required this.call,
    required this.expectation,
    required this.app,
  });
}

/// Resuelve "abre <app>" a un [AppLaunchPlan]. null = no es un goal de
/// apertura, o la app no resuelve de forma unívoca (→ fallo honesto aguas
/// arriba, jamás un launch a ciegas).
class AppLaunchResolver {
  AppLaunchResolver(this._catalog);

  final InstalledAppCatalog _catalog;

  // Términos ordenados de MÁS LARGO a MÁS CORTO (longest-match-first).
  // No reordenar manualmente: el test de _openTerm depende de este orden.
  static const _openTerms = [
    // ── Frases largas primero ──────────────────────────────────────────────
    'abre el chat de',
    'abre la app de',
    'lanza la app de',
    'abrir la app de',
    // ── Frases medias ──────────────────────────────────────────────────────
    'abre la app',
    'abrir la app',
    'lanza la app',
    'inicia la app',
    'abrir app',
    'abre app',
    'llévame a',
    'llevame a',
    'vamos a',
    'entrar al',
    'entrar a',
    'entra al',
    'entra a',
    'inicia el',
    'inicia la',
    'lanza el',
    'lanza la',
    'abre el',
    'abre la',
    'pon el',
    'pon la',
    'ir a',
    've a',
    // ── Verbos cortos / sin artículo ──────────────────────────────────────
    'muéstrame',
    'muestrame',
    'ejecutar',
    'ejecuta',
    'arrancar',
    'arranca',
    'iniciar',
    'inicia',
    'lanzar',
    'lanza',
    'abrir',
    'abre',
    'poner',
    'entrar',
    'entra',
    'dame',
    'pon',
  ];

  Future<AppLaunchPlan?> resolve(String goal) async {
    final g = goal.trim().toLowerCase();
    final term = _openTerm(g);
    if (term == null) return null;
    final query = g.substring(term.length).trim();
    if (query.isEmpty) return null;

    final match = await _catalog.findApp(query);
    if (match is! AppMatchResolved) return null; // ambiguo/no encontrado
    final app = match.app;
    if (!app.isLaunchCandidate) return null; // disabled/no-launchable

    return AppLaunchPlan(
      app: app,
      call: ToolCall(
        tool: 'launch_app',
        args: {'packageName': app.packageName},
      ),
      expectation: GoalExpectation(expectedPackage: app.packageName),
    );
  }

  /// Devuelve el término de apertura que hace match con [goal] (longest-match).
  /// El término se evalúa como prefijo seguido de espacio o fin de cadena.
  String? _openTerm(String goal) {
    for (final t in _openTerms) {
      if (goal == t) return t; // goal exacto al término (sin nombre de app: null arriba)
      if (goal.startsWith('$t ')) return t;
    }
    return null;
  }
}
