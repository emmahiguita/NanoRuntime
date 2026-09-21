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
  })  : _registry = registry ?? _ref.read(browserAiProviderRegistryProvider),
        _sessionManager =
            sessionManager ?? _ref.read(browserAiSessionManagerProvider),
        _sanitizer = sanitizer;

  /// Ejecuta una consulta hacia un proveedor web de IA garantizando exclusión mutua.
  Future<BrowserAiResponse> query(BrowserAiQuery query) async {
    final providerId =
        query.providerId == 'auto' ? 'deepseek' : query.providerId;
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
        final controller = await _sessionManager.getOrCreateController(provider);
        if (controller == null) {
          return BrowserAiResponse.failure(
            providerId: provider.id,
            error: 'No se pudo inicializar la pestaña para ${provider.displayName}.',
            requestId: query.requestId,
          );
        }

        bool ready = false;
        for (int i = 0; i < 8; i++) {
          if (await provider.isLoggedIn(controller)) {
            ready = true;
            break;
          }
          await Future.delayed(const Duration(milliseconds: 500));
        }

        if (!ready) {
          _sessionManager.setPendingPrompt(provider.id, query.prompt);
          final session = _sessionManager.getSession(provider.id);
          if (session?.tabId != null) {
            _ref.read(browserTabProvider.notifier).selectTab(session!.tabId!);
          }

          return BrowserAiResponse.userActionRequired(
            providerId: provider.id,
            reason: 'Inicia sesión en ${provider.displayName} (se abrió la pestaña). '
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
            error: 'No se encontró el campo de texto en ${provider.displayName}.',
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

  Future<T> _synchronized<T>(String key, Future<T> Function() action) async {
    while (_providerLocks.containsKey(key)) {
      try {
        await _providerLocks[key];
      } catch (_) {}
    }
    final completer = Completer<void>();
    _providerLocks[key] = completer.future;
    try {
      return await action();
    } finally {
      _providerLocks.remove(key);
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
    if (controller != null) {
      final session = _sessionManager.getSession(provider.id);
      if (session?.tabId != null) {
        _ref.read(browserTabProvider.notifier).selectTab(session!.tabId!);
        return true;
      }
    }
    return false;
  }
}

/// Provider global de Riverpod para BrowserAiGateway.
final browserAiGatewayProvider = Provider<BrowserAiGateway>((ref) {
  return BrowserAiGateway(ref);
});
