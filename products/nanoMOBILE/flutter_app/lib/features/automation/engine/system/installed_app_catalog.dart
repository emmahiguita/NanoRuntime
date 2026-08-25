/// InstalledAppCatalog (A2) — resolución determinista de apps por nombre humano.
///
/// SRP: cachea apps factuales descubiertas y resuelve nombres humanos a
/// entidades grounded. NO lanza aplicaciones (el launch es del dispatcher).
/// El matching normaliza SOLO para comparar (lowercase/trim); el package/label
/// devuelto permanece sin modificar.
library;

import 'system_inventory.dart';
import 'system_models.dart';

/// Cómo se resolvió un match (proveniencia del match).
enum AppMatchKind { exactLabel, exactPackage, prefixLabel, token }

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
  /// Orden: exact label → exact package → prefix label → token. Ambigüedad
  /// real → [AppMatchAmbiguous] (nunca elige un target externo a ciegas).
  Future<AppMatchResult> findApp(String query) async {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return AppMatchNotFound(query);
    final list = await apps;

    final exactLabel = list
        .where((a) => a.label.trim().toLowerCase() == q)
        .toList(growable: false);
    if (exactLabel.length == 1) {
      return AppMatchResolved(exactLabel.single, AppMatchKind.exactLabel);
    }
    if (exactLabel.length > 1) return AppMatchAmbiguous(exactLabel);

    final exactPkg = list
        .where((a) => a.packageName.toLowerCase() == q)
        .toList(growable: false);
    if (exactPkg.length == 1) {
      return AppMatchResolved(exactPkg.single, AppMatchKind.exactPackage);
    }
    if (exactPkg.length > 1) return AppMatchAmbiguous(exactPkg);

    final prefix = list
        .where((a) => a.label.trim().toLowerCase().startsWith(q))
        .toList(growable: false);
    if (prefix.length == 1) {
      return AppMatchResolved(prefix.single, AppMatchKind.prefixLabel);
    }
    if (prefix.length > 1) return AppMatchAmbiguous(prefix);

    final token = list
        .where((a) {
          final tokens = a.label.trim().toLowerCase().split(RegExp(r'\s+'));
          return tokens.any((t) => t == q);
        })
        .toList(growable: false);
    if (token.length == 1) {
      return AppMatchResolved(token.single, AppMatchKind.token);
    }
    if (token.length > 1) return AppMatchAmbiguous(token);

    return AppMatchNotFound(query);
  }
}
