import 'dart:async';
import 'dart:typed_data';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nanoai/features/browser/application/browser_tab_notifier.dart';
import 'package:nanoai/features/browser/application/browser_webview_registry.dart';
import 'package:nanoai/features/browser/domain/browser_url_resolver.dart';
import 'package:nanoai/features/browser/infrastructure/browser_security_firewall.dart';

/// Tipo de acción automatizada en el navegador
enum BrowserAutomationActionType {
  navigate,
  click,
  fillInput,
  scroll,
  wait,
  extractText,
  screenshot,
}

/// Paso ejecutable de automatización web
class BrowserAutomationStep {
  final BrowserAutomationActionType type;
  final String? url;
  final String? selector;
  final String? value;
  final int? scrollY;
  final Duration? delay;
  final String description;

  const BrowserAutomationStep({
    required this.type,
    this.url,
    this.selector,
    this.value,
    this.scrollY,
    this.delay,
    required this.description,
  });
}

/// Resultado de una ejecución de automatización
class BrowserAutomationResult {
  final bool success;
  final String? extractedContent;
  final Uint8List? screenshot;
  final String? error;
  final Duration elapsed;

  const BrowserAutomationResult({
    required this.success,
    this.extractedContent,
    this.screenshot,
    this.error,
    required this.elapsed,
  });
}

/// Motor de automatización desatendida y guiada por IA para el Navegador Nano AI.
/// Permite abrir sitios, interactuar con elementos, llenar formularios, hacer scraping
/// y ejecutar flujos completos de navegación sin intervención manual.
class BrowserAutomationEngine {
  final Ref _ref;

  BrowserAutomationEngine(this._ref);

  InAppWebViewController? _resolveController([String? tabId]) {
    final registry = _ref.read(browserWebViewRegistryProvider);
    final targetId = tabId ?? _ref.read(browserTabProvider).activeTabId;
    return registry.controllerFor(targetId);
  }

  /// Navega de forma automatizada hacia una URL específica
  Future<bool> navigateTo(String inputUrl, {String? tabId}) async {
    final resolvedUrl = BrowserUrlResolver.resolveUrl(inputUrl);
    final targetId = tabId ?? _ref.read(browserTabProvider).activeTabId;
    _ref.read(browserTabProvider.notifier).updateTabById(targetId, url: resolvedUrl);

    final ctrl = _resolveController(targetId);
    if (ctrl == null) return false;

    await ctrl.loadUrl(urlRequest: URLRequest(url: WebUri(resolvedUrl)));
    return true;
  }

  /// Hace clic automatizado sobre un elemento mediante selector CSS
  Future<bool> clickElement(String selector, {String? tabId}) async {
    final ctrl = _resolveController(tabId);
    if (ctrl == null) return false;

    final js = """
      (function() {
        const el = document.querySelector('$selector');
        if (!el) return false;
        el.scrollIntoView({ behavior: 'smooth', block: 'center' });
        el.click();
        return true;
      })();
    """;
    final result = await ctrl.evaluateJavascript(source: js);
    return result == true;
  }

  /// Rellena un campo de texto/input/textarea disparando eventos de framework
  Future<bool> fillInput(String selector, String value, {String? tabId}) async {
    final ctrl = _resolveController(tabId);
    if (ctrl == null) return false;

    final escaped = value.replaceAll("'", "\\'").replaceAll("\n", "\\n");
    final js = """
      (function() {
        const el = document.querySelector('$selector');
        if (!el) return false;
        el.focus();
        el.value = '$escaped';
        el.dispatchEvent(new Event('input', { bubbles: true }));
        el.dispatchEvent(new Event('change', { bubbles: true }));
        return true;
      })();
    """;
    final result = await ctrl.evaluateJavascript(source: js);
    return result == true;
  }

  /// Extrae el texto legible y sanitizado de la página web actual
  Future<String> extractContent({String? tabId}) async {
    final ctrl = _resolveController(tabId);
    if (ctrl == null) return '';

    const js = """
      (function() {
        return document.body ? (document.body.innerText || '') : '';
      })();
    """;
    final raw = await ctrl.evaluateJavascript(source: js);
    final rawString = raw?.toString() ?? '';
    final currentUrl = (await ctrl.getUrl())?.toString() ?? '';
    final title = await ctrl.getTitle() ?? '';

    return BrowserSecurityFirewall.sanitizeWebContentForLLM(
      rawContent: rawString,
      sourceUrl: currentUrl,
      pageTitle: title,
    );
  }

  /// Desplaza la página verticalmente de forma suave
  Future<void> scrollBy(int deltaY, {String? tabId}) async {
    final ctrl = _resolveController(tabId);
    if (ctrl == null) return;
    await ctrl.evaluateJavascript(
      source: "window.scrollBy({ top: $deltaY, behavior: 'smooth' });",
    );
  }

  /// Captura un screenshot nativo de la página web renderizada
  Future<Uint8List?> captureScreenshot({String? tabId}) async {
    final ctrl = _resolveController(tabId);
    if (ctrl == null) return null;
    return await ctrl.takeScreenshot();
  }

  /// Ejecuta un flujo secuencial completo de pasos de automatización
  Future<BrowserAutomationResult> runWorkflow(
    List<BrowserAutomationStep> steps, {
    String? tabId,
  }) async {
    final stopwatch = Stopwatch()..start();
    String? lastExtracted;
    Uint8List? lastScreenshot;

    try {
      for (final step in steps) {
        if (step.delay != null) {
          await Future.delayed(step.delay!);
        }
        switch (step.type) {
          case BrowserAutomationActionType.navigate:
            if (step.url != null) {
              await navigateTo(step.url!, tabId: tabId);
              await Future.delayed(const Duration(milliseconds: 800));
            }
            break;
          case BrowserAutomationActionType.click:
            if (step.selector != null) {
              await clickElement(step.selector!, tabId: tabId);
            }
            break;
          case BrowserAutomationActionType.fillInput:
            if (step.selector != null && step.value != null) {
              await fillInput(step.selector!, step.value!, tabId: tabId);
            }
            break;
          case BrowserAutomationActionType.scroll:
            if (step.scrollY != null) {
              await scrollBy(step.scrollY!, tabId: tabId);
            }
            break;
          case BrowserAutomationActionType.wait:
            break;
          case BrowserAutomationActionType.extractText:
            lastExtracted = await extractContent(tabId: tabId);
            break;
          case BrowserAutomationActionType.screenshot:
            lastScreenshot = await captureScreenshot(tabId: tabId);
            break;
        }
      }
      stopwatch.stop();
      return BrowserAutomationResult(
        success: true,
        extractedContent: lastExtracted,
        screenshot: lastScreenshot,
        elapsed: stopwatch.elapsed,
      );
    } catch (e) {
      stopwatch.stop();
      return BrowserAutomationResult(
        success: false,
        error: e.toString(),
        elapsed: stopwatch.elapsed,
      );
    }
  }
}

final browserAutomationEngineProvider = Provider<BrowserAutomationEngine>((ref) {
  return BrowserAutomationEngine(ref);
});
