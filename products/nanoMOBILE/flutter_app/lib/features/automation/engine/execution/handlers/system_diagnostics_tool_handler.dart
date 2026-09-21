import '../../agent_tools/registry/tool_registry.dart' show IToolHandler;
import '../../system/universal_capability_detector.dart';
import '../tool_call.dart';

/// Manejador de diagnósticos factuales de hardware y sistema (Nano Developer).
///
/// Principios SOLID:
/// - SRP: Responsabilidad única de consolidar y reportar la telemetría del dispositivo.
/// - OCP / LSP: Implementa [IToolHandler] para integrarse dinámicamente al motor.
/// - DIP: Depende de [UniversalCapabilityDetector].
class SystemDiagnosticsToolHandler implements IToolHandler {
  final UniversalCapabilityDetector _detector;

  SystemDiagnosticsToolHandler({UniversalCapabilityDetector? detector})
      : _detector = detector ?? UniversalCapabilityDetector();

  @override
  List<String> get supportedTools => const [
        'dev.diagnostics',
        'diagnostico',
        'diagnostics',
      ];

  @override
  bool supports(String toolName) {
    final lower = toolName.toLowerCase();
    return supportedTools.any((t) => t.toLowerCase() == lower);
  }

  @override
  Future<String> execute(ToolCall call) async {
    return runDiagnostics();
  }

  /// Procesa comandos de usuario vía `@diagnostico`.
  Future<String> handleCommand(String _) async {
    return runDiagnostics();
  }

  /// Ejecuta el diagnóstico factual completo y devuelve un reporte legible.
  Future<String> runDiagnostics() async {
    final snapshot = await _detector.detectCapabilities();

    final ramUsed = (snapshot.ramTotalGb - snapshot.ramAvailableGb).toStringAsFixed(1);
    final ramTotal = snapshot.ramTotalGb.toStringAsFixed(1);
    final ramStr = snapshot.ramTotalGb > 0 ? '$ramUsed / $ramTotal GB' : 'Desconocida';

    final accStatus = snapshot.accessibilityActive ? 'Conectado y Activo' : 'Inactivo / No Concedido';
    final shizukuStatus = snapshot.shizukuActive ? 'Activo (UID 2000 Shell)' : 'Inactivo';
    final adbStatus = snapshot.adbActive ? 'Habilitado' : 'No Conectado';

    final captures = snapshot.canCaptureWindow
        ? 'Ventana completa (API 34+)'
        : (snapshot.canCaptureScreenshot ? 'Pantalla estándar (API 30+)' : 'No soportada (<API 30)');

    return '═══ [NANO UNIVERSAL DIAGNOSTICS] ═══\n'
        '• Nivel Operativo: ${snapshot.activeTier.displayName}\n'
        '• Dispositivo: ${snapshot.manufacturer} ${snapshot.model}\n'
        '• Android: v${snapshot.release} (SDK ${snapshot.sdkInt})\n'
        '• Arquitectura ABI: ${snapshot.cpuAbi}\n'
        '• Memoria RAM: $ramStr\n'
        '─────────────────────────────────────\n'
        '• Accesibilidad: $accStatus\n'
        '• Soporte Captura: $captures\n'
        '• Shizuku: $shizukuStatus\n'
        '• Depuración ADB: $adbStatus\n'
        '═════════════════════════════════════';
  }
}
