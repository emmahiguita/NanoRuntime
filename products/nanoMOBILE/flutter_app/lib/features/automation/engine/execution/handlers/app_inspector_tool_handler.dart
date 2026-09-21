import '../../agent_tools/registry/tool_registry.dart' show IToolHandler;
import '../../perception/current_situation.dart';
import '../../system/installed_app_catalog.dart';
import '../tool_call.dart';

/// Manejador de la herramienta de inspección de aplicaciones (Nano Developer).
///
/// Principios SOLID:
/// - SRP: Responsabilidad única de inspeccionar metadatos y superficie de apps.
/// - OCP / LSP: Implementa [IToolHandler] para integrarse dinámicamente al motor.
/// - DIP: Depende de abstracciones ([InstalledAppCatalog], [CurrentSituationSource]).
class AppInspectorToolHandler implements IToolHandler {
  final InstalledAppCatalog? _catalog;
  final CurrentSituationSource? _situationSource;

  AppInspectorToolHandler({
    InstalledAppCatalog? catalog,
    CurrentSituationSource? situationSource,
  })  : _catalog = catalog,
        _situationSource = situationSource;

  @override
  List<String> get supportedTools => const [
        'dev.inspect_app',
        'inspect_app',
        'inspeccionar',
      ];

  @override
  bool supports(String toolName) {
    final lower = toolName.toLowerCase();
    return supportedTools.any((t) => t.toLowerCase() == lower);
  }

  @override
  Future<String> execute(ToolCall call) async {
    final target = (call.packageNameArg ??
            call.textArg ??
            call.selectorArg ??
            call.args?['target'] ??
            '')
        .toString()
        .trim();
    return inspect(target);
  }

  /// Procesa comandos de usuario vía `@inspeccionar <paquete|nombre>`.
  Future<String> handleCommand(String rawInput) async {
    final input = rawInput.trim();
    return inspect(input);
  }

  /// Ejecuta la inspección de la aplicación indicada o de la ventana actual.
  Future<String> inspect(String target) async {
    // 1. Si no se especificó app, inspeccionar la situación actual de pantalla
    if (target.isEmpty) {
      final situationSource = _situationSource;
      if (situationSource == null) {
        return 'Uso: @inspeccionar <nombre_o_paquete>. Ej: @inspeccionar whatsapp o @inspeccionar com.android.settings';
      }
      final situation = await situationSource();
      if (situation == null) {
        return '[inspector] No se pudo leer la superficie visible actual.';
      }
      return _formatSituationReport(situation);
    }

    // 2. Si se especificó un nombre o paquete, buscar en el catálogo
    final catalog = _catalog;
    if (catalog == null) {
      return '[inspector] Catálogo de aplicaciones no disponible en este perfil.';
    }

    final match = await catalog.findApp(target);
    switch (match) {
      case AppMatchResolved(:final app):
        final systemTag = app.system ? ' (Sistema)' : ' (Terceros)';
        return '[inspector] Aplicación: ${app.label}$systemTag\n'
            '• Paquete: ${app.packageName}\n'
            '• Versión: ${app.versionName} (${app.versionCode})\n'
            '• Habilitada: ${app.enabled ? "Sí" : "No"}\n'
            '• Lanzable: ${app.launchable ? "Sí" : "No"}';
      case AppMatchAmbiguous(:final candidates):
        final list = candidates.take(3).map((c) => '${c.label} (${c.packageName})').join(', ');
        return '[inspector] Múltiples aplicaciones coinciden: $list.';
      case AppMatchNotFound():
        return '[inspector] Aplicación "$target" no encontrada en el dispositivo.';
    }
  }

  String _formatSituationReport(CurrentSituation situation) {
    final pkg = situation.packageName.isNotEmpty ? situation.packageName : 'Desconocido';
    final nodes = situation.structuralEvidence.objects.length;
    final surface = situation.surfaceKind.name;

    return '[inspector_pantalla]\n'
        '• Paquete activo: $pkg\n'
        '• Superficie: $surface\n'
        '• Elementos detectados: $nodes\n'
        '• Evidencia estructural: ${situation.hasStructuralEvidence ? "Confiable" : "Parcial"}';
  }
}
