// browser_ai_gateway.dart — Puerta de enlace serializada para consultas de IA vía navegador.
// QUÉ HACE: Enruta prompts a proveedores web oficiales preservando sesiones persistentes.
// CÓMO FUNCIONA: Usa BrowserAiSynchronizer para exclusión mutua, verifica login y extrae respuestas.
// POR QUÉ: Permite respuestas de alta inteligencia sin API key ni consumo de RAM local.
library;

import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../browser/application/browser_tab_notifier.dart';
import '../domain/browser_ai_query.dart';
import '../domain/browser_ai_response.dart';
import '../domain/browser_ai_sanitizer.dart';
import '../infrastructure/browser_ai_preferences.dart';
import 'browser_ai_provider_registry.dart';
import 'browser_ai_session_manager.dart';
import 'browser_ai_synchronizer.dart';

class BrowserAiGateway {
  final Ref _ref;
  final BrowserAiProviderRegistry _registry;
  final BrowserAiSessionManager _sessionManager;
  final BrowserAiSanitizer _sanitizer;
  final BrowserAiSynchronizer _synchronizer = BrowserAiSynchronizer();

  /// Espera acotada a que el proveedor confirme sesión activa (delegado en BrowserAiSynchronizer).
  static Future<bool> waitUntilLoggedIn(
    Future<bool> Function() check, {
    List<Duration> retryDelays = const [
      Duration(milliseconds: 400),
      Duration(milliseconds: 800),
      Duration(milliseconds: 1200),
      Duration(milliseconds: 1600),
    ],
    Duration timeout = const Duration(seconds: 4),
  }) => BrowserAiSynchronizer.waitUntilLoggedIn(
    check,
    retryDelays: retryDelays,
    timeout: timeout,
  );

  BrowserAiGateway(
    this._ref, {
    BrowserAiProviderRegistry? registry,
    BrowserAiSessionManager? sessionManager,
    BrowserAiSanitizer sanitizer = const BrowserAiSanitizer(),
  }) : _registry = registry ?? _ref.read(browserAiProviderRegistryProvider),
       _sessionManager = sessionManager ?? _ref.read(browserAiSessionManagerProvider),
       _sanitizer = sanitizer;

  /// Ejecuta una consulta hacia un proveedor web de IA con exclusión mutua.
  Future<BrowserAiResponse> query(BrowserAiQuery query) async {
    // Si es 'auto', resolver con el proveedor preferido o fallback a 'deepseek'
    String targetId = query.providerId;
    if (targetId == 'auto') {
      final preferred = _ref.read(preferredAiProviderStateProvider);
      targetId = preferred == 'auto' ? 'deepseek' : preferred;
    }

    final provider = _registry.getProvider(targetId) ?? _registry.getProvider('deepseek');
    if (provider == null) {
      return BrowserAiResponse.failure(
        providerId: targetId,
        error: 'Proveedor "$targetId" no registrado en Nano AI.',
        requestId: query.requestId,
      );
    }

    return await _synchronizer.synchronized(provider.id, () async {
      try {
        final controller = await _sessionManager.getOrCreateController(provider);
        if (controller == null) {
          return BrowserAiResponse.failure(
            providerId: provider.id,
            error: 'No se pudo inicializar la pestaña para ${provider.displayName}.',
            requestId: query.requestId,
          );
        }

        final ready = await BrowserAiSynchronizer.waitUntilLoggedIn(
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
            reason: 'Inicia sesión en ${provider.displayName} para continuar.',
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
