/// InstalledAppCatalog (A2) — resolución determinista de apps por nombre humano.
///
/// SRP: cachea apps factuales descubiertas y resuelve nombres humanos a
/// entidades grounded. NO lanza aplicaciones (el launch es del dispatcher).
/// El matching normaliza SOLO para comparar (lowercase/trim); el package/label
/// devuelto permanece sin modificar.
///
/// Orden de resolución (del más al menos específico):
///   1. exactLabel       — label instalado idéntico a la query.
///   2. exactPackage     — packageName idéntico a la query.
///   3. qualifiedLabel   — query termina en el label ("google chrome" → Chrome).
///   4. prefixLabel      — label empieza por la query ("what" → WhatsApp).
///   5. token            — un token del label coincide exacto con la query.
///   6. alias            — la query coincide con un alias estático del catálogo
///                         [AppAliasCatalog] (wasa→WhatsApp, deep seek→DeepSeek).
///   7. fuzzy            — Levenshtein/Soundex-es sobre labels Y aliases
///                         [AppFuzzyMatcher] (spotfy→Spotify, crome→Chrome).
///
/// Niveles 6 y 7 NUNCA seleccionan si hay ambigüedad: devuelven
/// [AppMatchAmbiguous] igual que los niveles superiores.
library;

import 'app_alias_catalog.dart';
import 'app_fuzzy_matcher.dart';
import 'system_inventory.dart';
import 'system_models.dart';

export 'app_alias_catalog.dart' show AppAliasCatalog;
export 'app_fuzzy_matcher.dart' show AppFuzzyMatcher, appFuzzyMatcher;

/// Cómo se resolvió un match (proveniencia del match).
enum AppMatchKind {
  exactLabel,
  exactPackage,
  qualifiedLabel,
  prefixLabel,
  token,
  alias,
  fuzzy,
}

/// Resultado tipado de [InstalledAppCatalog.findApp]. Nunca null-crash.
sealed class AppMatchResult {
  const AppMatchResult();

  bool get isResolved => this is AppMatchResolved;
  bool get isAmbiguous => this is AppMatchAmbiguous;
  bool get isNotFound => this is AppMatchNotFound;
}

/// Match único y grounded.
class AppMatchResolved extends AppMatchResult {
  final InstalledApp app;
  final AppMatchKind kind;
  const AppMatchResolved(this.app, this.kind);
}

/// Varios candidatos con la misma fuerza de match: NO auto-seleccionar.
class AppMatchAmbiguous extends AppMatchResult {
  final List<InstalledApp> candidates;
  const AppMatchAmbiguous(this.candidates);
}

/// Sin coincidencia para la query.
class AppMatchNotFound extends AppMatchResult {
  final String query;
  const AppMatchNotFound(this.query);
}

/// Catálogo de apps instaladas/launchable. Cachea un snapshot y lo refresca
/// explícitamente (lazy inicial + refresh). Sin TTL prematuro.
class InstalledAppCatalog {
  InstalledAppCatalog(this._inventory);

  final SystemInventory _inventory;
  List<InstalledApp>? _cache;

  /// Refresca el snapshot desde el inventario nativo (dedup por package).
  Future<List<InstalledApp>> refresh() async {
    final raw = await _inventory.listLaunchableApps();
    final seen = <String>{};
    final apps = <InstalledApp>[];
    for (final a in raw) {
      if (a.packageName.isEmpty || !seen.add(a.packageName)) continue;
      apps.add(a);
    }
    _cache = apps;
    return apps;
  }

  /// Snapshot cacheado (lazy initial load).
  Future<List<InstalledApp>> get apps async => _cache ?? await refresh();

  /// Resuelve [query] (nombre humano o package) contra el catálogo real.
  Future<AppMatchResult> findApp(String query) async =>
      matchApps(await apps, query);
}

// ────────────────────────────────────────────────────────────────────────────
// Función de matching pura (sin estado, compartida por InstalledAppCatalog y
// SystemGraph). Todos los niveles respetan la semántica de ambigüedad: si hay
// N>1 candidatos del mismo nivel → AppMatchAmbiguous (nunca elige a ciegas).
// ────────────────────────────────────────────────────────────────────────────

/// Matching puro sobre una lista de apps (compartido por [InstalledAppCatalog]
/// y [SystemGraph]). No toca inventario ni cache.
///
/// Orden: exact label → exact package → qualified label → prefix label → token
///        → alias → fuzzy.
AppMatchResult matchApps(
  List<InstalledApp> apps,
  String query, {
  AppFuzzyMatcher fuzzyMatcher = appFuzzyMatcher,
}) {
  final q = _normalizeAppName(query);
  if (q.isEmpty) return AppMatchNotFound(query);

  // 1. Exact label
  final exactLabel = apps
      .where((a) => a.label.trim().toLowerCase() == q)
      .toList(growable: false);
  if (exactLabel.length == 1) {
    return AppMatchResolved(exactLabel.single, AppMatchKind.exactLabel);
  }
  if (exactLabel.length > 1) return AppMatchAmbiguous(exactLabel);

  // 2. Exact package
  final exactPkg = apps
      .where((a) => a.packageName.toLowerCase() == q)
      .toList(growable: false);
  if (exactPkg.length == 1) {
    return AppMatchResolved(exactPkg.single, AppMatchKind.exactPackage);
  }
  if (exactPkg.length > 1) return AppMatchAmbiguous(exactPkg);

  // 3. Qualified label ("google chrome" → Chrome)
  final qualifiedLabel = apps.where((app) {
    final label = _normalizeAppName(app.label);
    if (label.length < 3 || label == q) return false;
    return q.endsWith(' $label');
  }).toList(growable: false);
  if (qualifiedLabel.length == 1) {
    return AppMatchResolved(qualifiedLabel.single, AppMatchKind.qualifiedLabel);
  }
  if (qualifiedLabel.length > 1) {
    return AppMatchAmbiguous(qualifiedLabel);
  }

  // 4. Prefix label
  final prefix = apps
      .where((a) => a.label.trim().toLowerCase().startsWith(q))
      .toList(growable: false);
  if (prefix.length == 1) {
    return AppMatchResolved(prefix.single, AppMatchKind.prefixLabel);
  }
  if (prefix.length > 1) return AppMatchAmbiguous(prefix);

  // 5. Token (un token del label == query)
  final token = apps.where((a) {
    final tokens = a.label.trim().toLowerCase().split(RegExp(r'\s+'));
    return tokens.any((t) => t == q);
  }).toList(growable: false);
  if (token.length == 1) {
    return AppMatchResolved(token.single, AppMatchKind.token);
  }
  if (token.length > 1) return AppMatchAmbiguous(token);

  // 6. Alias — AppAliasCatalog estático
  //    La query coincide con algún alias normalizado del package.
  //    Solo aplica si la app con ese package está instalada.
  final aliasMatches = <InstalledApp>[];
  for (final app in apps) {
    final aliases = AppAliasCatalog.aliasesFor(app.packageName);
    if (aliases.contains(q)) {
      aliasMatches.add(app);
    }
  }
  if (aliasMatches.length == 1) {
    return AppMatchResolved(aliasMatches.single, AppMatchKind.alias);
  }
  if (aliasMatches.length > 1) return AppMatchAmbiguous(aliasMatches);

  // 7. Fuzzy — Levenshtein + Soundex-es sobre labels Y aliases
  //    Recoge los candidatos con la mayor similitud, luego decide.
  final fuzzyMatches = _fuzzyMatchAll(apps, q, fuzzyMatcher);
  if (fuzzyMatches.length == 1) {
    return AppMatchResolved(fuzzyMatches.single, AppMatchKind.fuzzy);
  }
  if (fuzzyMatches.length > 1) return AppMatchAmbiguous(fuzzyMatches);

  return AppMatchNotFound(query);
}

// ────────────────────────────────────────────────────────────────────────────
// Helpers privados
// ────────────────────────────────────────────────────────────────────────────

/// Ejecuta el fuzzy sobre labels Y sobre los aliases de cada app.
/// Devuelve las apps cuyo score sea el máximo encontrado (puede haber empate).
/// Si ninguna supera el umbral → lista vacía.
List<InstalledApp> _fuzzyMatchAll(
  List<InstalledApp> apps,
  String q,
  AppFuzzyMatcher matcher,
) {
  // Acumula: (app, mejorScore) para esta query.
  final scores = <InstalledApp, double>{};

  for (final app in apps) {
    final label = _normalizeAppName(app.label);
    double best = 0.0;

    // Score contra label
    final labelScore = matcher.score(q, label);
    if (labelScore != null && labelScore.similarity > best) {
      best = labelScore.similarity;
    }

    // Score contra cada alias del catálogo estático
    final aliases = AppAliasCatalog.aliasesFor(app.packageName);
    for (final alias in aliases) {
      final aliasScore = matcher.score(q, alias);
      if (aliasScore != null && aliasScore.similarity > best) {
        best = aliasScore.similarity;
      }
    }

    if (best > 0.0) {
      scores[app] = best;
    }
  }

  if (scores.isEmpty) return const [];

  // Máximo score real encontrado.
  final maxScore = scores.values.reduce((a, b) => a > b ? a : b);

  // Solo los que estén en el máximo (empate → ambiguedad).
  // Tolerancia de 0.01 para igualdad de doubles.
  return scores.entries
      .where((e) => (e.value - maxScore).abs() < 0.01)
      .map((e) => e.key)
      .toList(growable: false);
}

String _normalizeAppName(String value) =>
    value.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');
