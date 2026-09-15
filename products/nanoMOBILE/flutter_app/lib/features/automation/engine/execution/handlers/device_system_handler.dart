import '../../../../../core/services/device_metrics.dart';
import '../../../../../core/services/nano_runtime_api.dart';
import '../../system/capabilities_report.dart';
import '../../system/installed_app_catalog.dart';
import '../../system/system_graph.dart' show SystemGraph;
import '../../voice/execution_cancellation.dart';
import '../tool_call.dart';
import '../tool_outcome.dart';
import 'shizuku_tool_handler.dart';
import 'web_tool_handler.dart';

/// Manejador de estado del dispositivo, permisos, voz y apertura de apps.
/// Cumple SRP: telemetría del sistema, diálogo de voz y catálogo de apps.
class DeviceSystemHandler {
  final NanoRuntimeApi _runtime;
  final Future<SystemGraph> Function()? _systemGraphSource;
  final Future<Map<dynamic, dynamic>> Function()? _devicePermissionsSource;
  final Future<Map<dynamic, dynamic>> Function()? _shizukuStatusSource;
  final Future<bool> Function(String kind)? _openPermissionSource;
  final bool Function() _voiceOutputEnabled;
  final InstalledAppCatalog? _installedAppCatalog;
  final WebToolHandler _webHandler;
  final ShizukuToolHandler _shizukuHandler;

  DeviceSystemHandler({
    NanoRuntimeApi? runtime,
    Future<SystemGraph> Function()? systemGraphSource,
    Future<Map<dynamic, dynamic>> Function()? devicePermissionsSource,
    Future<Map<dynamic, dynamic>> Function()? shizukuStatusSource,
    Future<bool> Function(String kind)? openPermissionSource,
    bool Function()? voiceOutputEnabled,
    InstalledAppCatalog? installedAppCatalog,
    WebToolHandler? webHandler,
    ShizukuToolHandler? shizukuHandler,
  })  : _runtime = runtime ?? NanoRuntimeApi.instance,
        _systemGraphSource = systemGraphSource,
        _devicePermissionsSource = devicePermissionsSource,
        _shizukuStatusSource = shizukuStatusSource,
        _openPermissionSource = openPermissionSource,
        _voiceOutputEnabled = voiceOutputEnabled ?? _defaultVoice,
        _installedAppCatalog = installedAppCatalog,
        _webHandler = webHandler ?? WebToolHandler(),
        _shizukuHandler = shizukuHandler ?? ShizukuToolHandler();

  static bool _defaultVoice() => true;

  /// Consulta de estado físico bajo demanda (batería, red, bluetooth, audio, RAM).
  Future<String> deviceState() async {
    try {
      final metrics = await DeviceMetrics.fetch();
      final system = await _runtime.systemState();
      final battery = metrics.batteryPct >= 0
          ? '${metrics.batteryPct.round()}%'
          : 'desconocida';
      final charging = metrics.isCharging ? 'sí' : 'no';

      final wifiConnected = system['wifiConnected'] == true;
      final wifiEnabled = system['wifiEnabled'] == true || wifiConnected;
      final cellularConnected = system['cellularConnected'] == true;
      final isOnline = system['isOnline'] == true;
      final Object? btRaw = system['bluetoothEnabled'];
      final bluetooth = btRaw == true
          ? 'activo'
          : (btRaw == false ? 'inactivo' : 'no consultable');
      final media =
          system['mediaPlaying'] == true ? 'reproduciendo' : 'inactivo';

      final String red;
      if (wifiConnected) {
        red = 'WiFi (conectado)';
      } else if (cellularConnected) {
        red = 'Datos móviles (conectado)';
      } else if (wifiEnabled) {
        red = 'WiFi activo (sin conexión)';
      } else {
        red = 'Desconectada';
      }

      final internet = isOnline ? 'con internet' : 'sin internet';
      final ram = metrics.ramTotalGb > 0
          ? 'RAM: ${(metrics.ramTotalGb - metrics.ramAvailableGb).toStringAsFixed(1)}/${metrics.ramTotalGb.toStringAsFixed(1)} GB'
          : null;

      final parts = [
        'Batería: $battery (cargando: $charging)',
        'Red: $red · $internet',
        'Bluetooth: $bluetooth',
        'Audio: $media',
        if (ram != null) ram,
      ];

      return '[device_state] ${parts.join(', ')}.';
    } catch (e) {
      return '[device_state] Error al consultar hardware: $e';
    }
  }

  /// Escucha voz y devuelve texto transcrito.
  Future<String> listenVoice() async {
    final text = await _runtime.startVoiceRecognition();
    if (text == null || text.trim().isEmpty) {
      return 'No se pudo escuchar: audio no disponible o reconocimiento sin '
          'resultado. Concede el micrófono con @conceder_runtime e inténtalo.';
    }
    return 'Escuchado: "$text".';
  }

  /// Habla texto vía TTS.
  Future<String> speak(String text) async {
    final t = text.trim();
    if (t.isEmpty) return 'Uso: @habla <texto>.';
    if (!_voiceOutputEnabled()) {
      return 'Audio de voz desactivado. Nano responderá solo con texto.';
    }
    final ok = await _runtime.speak(t);
    return ok ? 'Hablado.' : 'No se pudo hablar (TTS no disponible).';
  }

  /// Informe ejecutivo factual de capacidades locales y soberanía de datos.
  Future<String> runCapabilitiesReport() async {
    final graphSource = _systemGraphSource;
    final permsSource = _devicePermissionsSource;
    final shizukuSource = _shizukuStatusSource;
    if (graphSource == null || permsSource == null || shizukuSource == null) {
      return 'Informe de capacidades no configurado en este perfil.';
    }
    final graph = await graphSource();
    final perms = await permsSource();
    final shizuku = await shizukuSource();
    return buildCapabilitiesReport(graph, perms, shizuku);
  }

  /// Abre la pantalla de concesión del permiso indicado.
  Future<String> runGrantPermission(String kind) async {
    if (kind == 'shizuku') {
      return _shizukuHandler.grantShizuku();
    }
    const labels = {
      'accessibility': 'Accesibilidad',
      'notificaciones': 'Notificaciones',
      'archivos': 'Todos los archivos',
      'runtime': 'Permisos de runtime',
    };
    final label = labels[kind] ?? kind;
    final openSource = _openPermissionSource;
    if (openSource == null) {
      return 'Apertura de permisos no configurada en este perfil.';
    }
    final ok = await openSource(kind);
    return ok
        ? 'Abriendo $label... Concede el permiso y vuelve a la app.'
        : 'No se pudo abrir la pantalla de $label.';
  }

  /// Apertura de apps desde el chat / consola.
  Future<String> handleOpenAppCommand(
    String rest, {
    required Future<ToolOutcome> Function(
      ToolCall call, {
      bool humanInitiated,
      String? executionId,
      ExecutionCancellationToken? cancellation,
    }) runGuarded,
    String? executionId,
    ExecutionCancellationToken? cancellation,
  }) async {
    final query = rest.trim();
    if (query.isEmpty) {
      return 'Sintaxis: @abrir <paquete|nombre_app|url>. Ej: @abrir com.android.settings o @abrir chrome o @abrir https://google.com';
    }

    if (query.startsWith('http://') ||
        query.startsWith('https://') ||
        query.startsWith('www.') ||
        query.endsWith('.com') ||
        query.endsWith('.org') ||
        query.endsWith('.net') ||
        query.endsWith('.io') ||
        query.endsWith('.co')) {
      final fullUrl = (query.startsWith('http://') || query.startsWith('https://'))
          ? query
          : 'https://$query';
      return _webHandler.openUrl(fullUrl);
    }

    String targetPackage = query;
    final appCatalog = _installedAppCatalog;
    if (!query.contains('.') && appCatalog != null) {
      final match = await appCatalog.findApp(query);
      switch (match) {
        case AppMatchResolved(:final app):
          targetPackage = app.packageName;
        case AppMatchAmbiguous(:final candidates):
          final options = candidates
              .take(4)
              .map((c) => '${c.label} (${c.packageName})')
              .join(', ');
          return 'Múltiples apps encontradas para "$query": $options. Especifica el nombre completo o paquete.';
        case AppMatchNotFound():
          targetPackage = query;
      }
    }

    final call = ToolCall(
      tool: 'launch_app',
      args: {'packageName': targetPackage},
    );
    return (await runGuarded(
      call,
      humanInitiated: true,
      executionId: executionId,
      cancellation: cancellation,
    )).feedback;
  }
}
