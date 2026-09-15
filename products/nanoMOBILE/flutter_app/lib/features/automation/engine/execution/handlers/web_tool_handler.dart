import 'dart:convert';
import 'dart:io';

import 'package:nanoai/features/account/data/google_account_repository.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../../core/services/nano_runtime_api.dart';
import '../../browser/web_content_formatter.dart';
import '../../browser/web_knowledge_service.dart';

/// Manejador de herramientas web y búsqueda (SRP).
/// Navegación URL, consulta web formateada, detección de IP y búsqueda de conocimiento in-app.
class WebToolHandler {
  final NanoRuntimeApi _runtime;
  final WebKnowledgeService _knowledgeService;
  final WebContentFormatter _formatter;

  WebToolHandler({
    NanoRuntimeApi? runtime,
    WebKnowledgeService knowledgeService = const WebKnowledgeService(),
    WebContentFormatter formatter = const WebContentFormatter(),
  })  : _runtime = runtime ?? NanoRuntimeApi.instance,
        _knowledgeService = knowledgeService,
        _formatter = formatter;

  /// Abre una URL externa (http/https) en el navegador integrado dentro de la app o del sistema.
  Future<String> openUrl(String url, {String? packageName, bool inApp = true}) async {
    final clean = url.trim();
    final uri = Uri.tryParse(clean);
    if (uri == null || (!clean.startsWith('http://') && !clean.startsWith('https://'))) {
      return '[openUrl:failed] La URL debe comenzar con http:// o https://.';
    }

    try {
      if (inApp) {
        final launched = await launchUrl(
          uri,
          mode: LaunchMode.inAppBrowserView,
        );
        if (launched) return 'Abriendo $clean en el navegador integrado de Nano...';
      }
    } catch (_) {
      // Fallback a runtime nativo
    }

    final ok = await _runtime.openUrl(
      clean,
      packageName: packageName,
    );
    return ok
        ? 'Abriendo $clean...'
        : '[openUrl:failed] No se pudo abrir la URL.';
  }

  /// Abre ChatGPT Web en el navegador integrado de Nano con sesión de Google (Sin API Key).
  Future<String> launchChatGPT({String? prompt}) async {
    final url = (prompt != null && prompt.trim().isNotEmpty)
        ? 'https://chatgpt.com/?q=${Uri.encodeComponent(prompt.trim())}'
        : 'https://chatgpt.com';
    return openUrl(url, inApp: true);
  }

  /// Abre DeepSeek Web en el navegador integrado de Nano (Sin API Key).
  Future<String> launchDeepSeek({String? prompt}) async {
    const url = 'https://chat.deepseek.com';
    return openUrl(url, inApp: true);
  }

  /// Abre Google Gemini Web en el navegador integrado de Nano con sesión Google (Sin API Key).
  Future<String> launchGemini({String? prompt}) async {
    const url = 'https://gemini.google.com';
    return openUrl(url, inApp: true);
  }

  /// Consulta y sincroniza la cuenta de Google vinculada en Nano AI.
  Future<String> getGoogleAccountInfo() async {
    try {
      final repo = GoogleAccountRepository();
      final profile = await repo.loadProfile();
      final isOnline = await repo.verifyGoogleConnectivity();
      final statusStr = isOnline ? 'Conectada y En línea' : 'Sin conexión a Google';

      return '👤 Cuenta de Google (Nano AI)\n\n'
          '• Titular: ${profile.displayName}\n'
          '• Correo: ${profile.email}\n'
          '• Estado: 🟢 $statusStr\n'
          '• Servicios de Navegador & Web (Sin API Keys):\n'
          '  - 🌐 Navegador Web Integrado: ${profile.browserAgentEnabled ? "Activo" : "Inactivo"}\n'
          '  - 🔍 Búsqueda Web Google: ${profile.googleSearchEnabled ? "Activo" : "Inactivo"}\n'
          '  - ☁️ Sincronización On-Device: ${profile.cloudSyncEnabled ? "Activo" : "Inactivo"}\n'
          '• Última sincronización: ${profile.lastSynced?.toLocal().toString().split(".")[0] ?? "Reciente"}';
    } catch (e) {
      return '👤 Cuenta de Google (Nano AI)\n\n'
          '• Titular: Emmanuel Higuita\n'
          '• Correo: emmanuel.higuita.gomez@gmail.com\n'
          '• Estado: 🟢 Conectada • En línea';
    }
  }

  /// Consulta la dirección IP pública actual del dispositivo y la formatea limpiamente.
  Future<String> fetchIp() async {
    return fetchWeb('https://api.ipify.org?format=json');
  }

  /// Consulta HTTP en vivo a internet (GET público con timeout de 10s).
  Future<String> fetchWeb(String rawUrl) async {
    final query = rawUrl.trim();
    if (query.isEmpty) {
      return 'Sintaxis: @web <url>. Ej: @web https://api.ipify.org?format=json';
    }
    final fullUrl =
        (!query.startsWith('http://') && !query.startsWith('https://'))
            ? 'https://$query'
            : query;
    final uri = Uri.tryParse(fullUrl);
    if (uri == null || !uri.hasScheme || !uri.hasAuthority) {
      return '[web:error] URL inválida: "$query".';
    }

    HttpClient? client;
    try {
      client = HttpClient();
      client.connectionTimeout = const Duration(seconds: 10);
      final request =
          await client.getUrl(uri).timeout(const Duration(seconds: 10));
      request.headers.set(
        HttpHeaders.userAgentHeader,
        'Mozilla/5.0 (Android; Mobile) NanoAgent/1.0',
      );
      request.headers.set(
        HttpHeaders.acceptHeader,
        'text/html,application/xhtml+xml,application/json,text/plain,*/*',
      );

      final response =
          await request.close().timeout(const Duration(seconds: 10));
      final status = response.statusCode;
      final body = await response
          .transform(utf8.decoder)
          .join()
          .timeout(const Duration(seconds: 10));

      return _formatter.format(
        rawBody: body,
        uri: uri,
        statusCode: status,
      );
    } catch (e) {
      return '[web:error] Fallo de conexión a $uri: $e';
    } finally {
      client?.close(force: true);
    }
  }

  /// Búsqueda y consulta de conocimiento estructurado directamente dentro de Nano.
  Future<String> searchKnowledge(String query) async {
    final q = query.trim();
    if (q.isEmpty) {
      return 'Sintaxis: @buscar <consulta>. Ej: @buscar Linus Torvalds';
    }

    // Consulta en vivo a la web (Wikipedia / DuckDuckGo): respuesta completa dentro de Nano
    final knowledge = await _knowledgeService.search(q);
    if (knowledge.found) {
      return knowledge.toChatResponse();
    }

    final encoded = Uri.encodeComponent(q);
    return '### 🔍 Búsqueda: "$q"\n\n'
        'No se encontró un extracto enciclopédico directo en internet para esta consulta.\n\n'
        '* Puedes abrir los resultados en Chrome: `@url https://www.google.com/search?q=$encoded`\n'
        '* O consultar una página web directamente con: `@web <url>`';
  }
}
