import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../browser/application/browser_tab_notifier.dart';
import '../domain/browser_ai_query.dart';
import '../domain/browser_ai_response.dart';
import '../domain/browser_ai_sanitizer.dart';
import 'browser_ai_provider_registry.dart';
import 'browser_ai_session_manager.dart';

/// QUÉ HACE:
/// Puerta de enlace serializada para consultas de IA vía navegador integrado.
///
/// CÓMO FUNCIONA:
/// 1. Serializa el acceso por proveedor (evita cruce de prompts y respuestas).
/// 2. Obtiene el controlador de WebView y valida la sesión activa.
/// 3. Sanitiza PII, registra conteo base y observa la estabilización del nuevo turno.
///
/// POR QUÉ:
/// Garantiza concurrencia segura sin mezclar respuestas de distintas conversaciones.
class BrowserAiGateway {
  final Ref _ref;
  final BrowserAiProviderRegistry _registry;
  final BrowserAiSessionManager _sessionManager;
  final BrowserAiSanitizer _sanitizer;
  final Map<String, Future<void>> _providerLocks = {};

  BrowserAiGateway(
    this._ref, {
    BrowserAiProviderRegistry? registry,
    BrowserAiSessionManager? sessionManager,
    BrowserAiSanitizer sanitizer = const BrowserAiSanitizer(),
  }) : _registry = registry ?? _ref.read(browserAiProviderRegistryProvider),
       _sessionManager =
           sessionManager ?? _ref.read(browserAiSessionManagerProvider),
       _sanitizer = sanitizer;

  /// Ejecuta una consulta hacia un proveedor web de IA garantizando exclusión mutua.
  Future<BrowserAiResponse> query(BrowserAiQuery query) async {
    final providerId = query.providerId == 'auto'
        ? 'deepseek'
        : query.providerId;
    final provider = _registry.getProvider(providerId);

    if (provider == null) {
      return BrowserAiResponse.failure(
        providerId: providerId,
        error: 'Proveedor "$providerId" no registrado.',
        requestId: query.requestId,
      );
    }

    return await _synchronized(provider.id, () async {
      try {
        final controller = await _sessionManager.getOrCreateController(
          provider,
        );
        if (controller == null) {
          return BrowserAiResponse.failure(
            providerId: provider.id,
            error:
                'No se pudo inicializar la pestaña para ${provider.displayName}.',
            requestId: query.requestId,
          );
        }

        final ready = await waitUntilLoggedIn(
          () => provider.isLoggedIn(controller),
        );

        if (!ready) {
          _sessionManager.setPendingPrompt(provider.id, query.prompt);
          final session = _sessionManager.getSession(provider.id);
          if (session?.tabId != null) {
            _ref.read(browserTabProvider.notifier).selectTab(session!.tabId!);
          }

          return BrowserAiResponse.userActionRequired(
            providerId: provider.id,
            reason:
                'Inicia sesión en ${provider.displayName} (se abrió la pestaña). '
                'Cuando termines, vuelve al chat y reenvía tu mensaje.',
            duration: Duration.zero,
            requestId: query.requestId,
          );
        }

        final safePrompt = _sanitizer.sanitize(query.prompt);
        final baselineCount = await provider.countMessages(controller);
        final submitted = await provider.submitPrompt(controller, safePrompt);
        if (!submitted) {
          return BrowserAiResponse.failure(
            providerId: provider.id,
            error:
                'No se encontró el campo de texto en ${provider.displayName}.',
            requestId: query.requestId,
          );
        }

        return await provider.waitForResponse(
          controller,
          query.timeout,
          baselineCount: baselineCount,
          requestId: query.requestId,
        );
      } catch (e) {
        return BrowserAiResponse.failure(
          providerId: provider.id,
          error: 'Error en consulta de navegador: $e',
          requestId: query.requestId,
        );
      }
    });
  }

  /// Espera acotada y con backoff a que el DOM de sesión quede disponible.
  ///
  /// QUÉ HACE: Reintenta [check] con retardos crecientes hasta que devuelve
  ///           true o se supera el deadline.
  /// POR QUÉ EL TIMEOUT ES 4s: El WebView de InAppWebView puede tardar 2-3s
  ///           en montar el DOM la primera vez. Con 1.5s fallaba siempre en
  ///           la primera apertura de pestaña → userActionRequired innecesario.
  static Future<bool> waitUntilLoggedIn(
    Future<bool> Function() check, {
    List<Duration> retryDelays = const [
      Duration(milliseconds: 400),  // primer reintento rápido
      Duration(milliseconds: 800),  // segundo reintento
      Duration(milliseconds: 1200), // tercer reintento
      Duration(milliseconds: 1600), // cuarto reintento (DOM ya cargado)
    ],
    Duration timeout = const Duration(seconds: 4), // aumentado de 1.5s a 4s
  }) async {
    final deadline = DateTime.now().add(timeout);

    // Helper: ejecuta [check] con el tiempo restante o aborta si ya expiró.
    Future<bool> checkBeforeDeadline() async {
      final remaining = deadline.difference(DateTime.now());
      if (remaining <= Duration.zero) return false;
      return check().timeout(remaining, onTimeout: () => false);
    }

    // Intento inmediato (tab ya tenía sesión activa)
    if (await checkBeforeDeadline()) return true;

    // Reintentos con backoff para esperar carga del DOM
    for (final delay in retryDelays) {
      final remaining = deadline.difference(DateTime.now());
      if (remaining <= Duration.zero) return false;
      await Future<void>.delayed(delay < remaining ? delay : remaining);
      if (await checkBeforeDeadline()) return true;
    }
    return false;
  }

  /// Exclusión mutua por proveedor.
  ///
  /// QUÉ HACE: Garantiza que solo un [action] por proveedor corra a la vez.
  /// BUG CORREGIDO: la versión anterior usaba `while + await _providerLocks[key]`
  ///   que podía deadlock si [action] lanzaba y el Completer quedaba sin completar
  ///   en waiters secundarios. Ahora usamos una cadena de futures: cada llamada
  ///   espera al Future anterior antes de crear el suyo.
  Future<T> _synchronized<T>(String key, Future<T> Function() action) async {
    // Encadenamos: esperar el future previo (si hay) antes de correr action.
    final previous = _providerLocks[key] ?? Future<void>.value();
    final completer = Completer<void>();
    // Registrar el nuevo "turno" antes de await para que los siguientes
    // llamantes encolen correctamente.
    _providerLocks[key] = completer.future;
    try {
      await previous; // esperar al anterior sin deadlock
      return await action();
    } finally {
      // Limpiar la entrada solo si sigue siendo nuestra (evita borrar la de otro)
      if (identical(_providerLocks[key], completer.future)) {
        _providerLocks.remove(key);
      }
      if (!completer.isCompleted) completer.complete();
    }
  }

  /// Lista el estado de todos los proveedores registrados.
  Future<List<Map<String, dynamic>>> listProviders() async {
    final list = <Map<String, dynamic>>[];
    for (final p in _registry.allProviders) {
      final session = _sessionManager.getSession(p.id);
      list.add({
        'id': p.id,
        'name': p.displayName,
        'url': p.defaultUrl.toString(),
        'hasTab': session?.tabId != null,
        'isLoggedIn': session?.isLoggedIn ?? false,
      });
    }
    return list;
  }

  /// Abre o enfoca la pestaña del proveedor para que el usuario inicie sesión.
  Future<bool> openProviderTab(String providerId) async {
    final provider = _registry.getProvider(providerId);
    if (provider == null) return false;

    final controller = await _sessionManager.getOrCreateController(provider);
    final session = _sessionManager.getSession(provider.id);
    if (session?.tabId != null) {
      _ref.read(browserTabProvider.notifier).selectTab(session!.tabId!);
      return true;
    }
    return controller != null;
  }
}

/// Provider global de Riverpod para BrowserAiGateway.
final browserAiGatewayProvider = Provider<BrowserAiGateway>((ref) {
  return BrowserAiGateway(ref);
});
