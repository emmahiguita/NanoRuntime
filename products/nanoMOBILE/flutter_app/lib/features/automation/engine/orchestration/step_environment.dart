/// StepEnvironment — fuentes inyectadas que usan los step handlers.
///
/// Agrupa las dependencias (DI) para que cada TaskStepHandler reciba un único
/// objeto en vez de un constructor de 11 parámetros. Los handlers son puros
/// (env + contexto → resultado), sin estado propio.
library;

import '../perception/search_result_resolver.dart';

class StepEnvironment {
  final Future<List<dynamic>> Function() listNotifications;
  final Future<bool> Function(String url) openUrl;
  final Future<bool> Function(String path, String content) writeFile;
  final Future<bool> Function(String appName)? launchApp;
  final Future<bool> Function(String selector)? tap;
  final Future<bool> Function(String selector, String text)? writeText;
  final Future<String?> Function()? resolveInputSurface;
  final Future<String?> Function(String kind)? resolveActionSurface;
  final Future<String?> Function()? observeInputText;
  final Future<ResultResolution?> Function(ResultTarget target)? resolveResult;
  final Future<String?> Function()? readVisibleText;
  final Future<int?> Function()? detectSearchResults;

  const StepEnvironment({
    required this.listNotifications,
    required this.openUrl,
    required this.writeFile,
    this.launchApp,
    this.tap,
    this.writeText,
    this.resolveInputSurface,
    this.resolveActionSurface,
    this.observeInputText,
    this.resolveResult,
    this.readVisibleText,
    this.detectSearchResults,
  });
}
