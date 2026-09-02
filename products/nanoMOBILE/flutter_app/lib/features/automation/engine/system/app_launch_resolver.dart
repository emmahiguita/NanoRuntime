/// AppLaunchResolver (A2) — resolución determinista de "abre <app>".
///
/// El package SIEMPRE sale del [InstalledAppCatalog] (evidencia del
/// PackageManager). Jamás lo inventa el LLM ni lo sugiere contenido observado.
/// Si el nombre es ambiguo o no resuelve, devuelve null → NO se lanza nada.
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

  static const _openTerms = [
    'abrir',
    'abre',
    'lanza',
    'lanzar',
    'ejecuta',
    'ejecutar',
    'abrir la app',
    'abre la app',
    'abrir app',
    'abre app',
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

  String? _openTerm(String goal) {
    for (final t in _openTerms) {
      if (goal.startsWith('$t ')) return t;
    }
    return null;
  }
}
