import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Nombres de canales — espejo Dart de `ChannelNames.kt`.
///
/// Frontera única Flutter↔NanoRuntime. Los servicios de dominio deben llamar
/// a [NanoRuntimeApi] (o usar estas constantes) en vez de repetir strings.
abstract final class NanoRuntimeChannels {
  static const runtime = 'com.nanoai/runtime';
  static const execBin = 'com.nanoai/exec_bin';
  static const pty = 'com.nanoai/pty';
  static const deviceMetrics = 'com.nanoai/device_metrics';
  static const navigation = 'com.nanoai/navigation';
  static const agent = 'com.nanoai/agent';
  static const engine = 'com.nanoai/engine';
  static const modelStorage = 'com.nanoai/model_storage';
  static const notifications = 'com.nanoai/notifications';
  static const devicePermissions = 'com.nanoai/device_permissions';
  static const speech = 'com.nanoai/speech';
  static const system = 'com.nanoai/system';
}

/// Resultado del handshake de runtime.
class RuntimeInfo {
  /// false cuando el runtime no responde (tests, desktop, engine sin nativo).
  final bool available;

  /// Versión reportada por `getRuntimeVersion`. 0 si no disponible.
  final int version;

  /// Capacidades reportadas por `getCapabilities`.
  final Set<String> capabilities;

  /// Warning no fatal cuando las versiones Dart/nativo difieren.
  final String? warning;

  const RuntimeInfo._({
    required this.available,
    required this.version,
    required this.capabilities,
    this.warning,
  });

  const RuntimeInfo.unavailable()
    : available = false,
      version = 0,
      capabilities = const {},
      warning = null;

  bool supports(String capability) => capabilities.contains(capability);
}

/// Fachada única sobre el runtime nativo (worker, rootfs, desktop, PTY).
///
/// Única puerta de entrada de la UI hacia los canales `exec_bin`, `pty` y
/// `device_metrics`. El handshake consulta `com.nanoai/runtime` una sola vez
/// (memoizado) y degrada con warning si las versiones difieren — nunca lanza.
///
/// Contrato del canal en Kotlin:
/// `android/.../channels/RuntimeChannelHandler.kt` (RUNTIME_VERSION).
class NanoRuntimeApi {
  /// Público SOLO para fakes de test (override de los métodos del canal).
  /// Producción usa [instance] — jamás crear instancias nuevas.
  @visibleForTesting
  NanoRuntimeApi();

  static final NanoRuntimeApi instance = NanoRuntimeApi();

  /// Versión de contrato que este Dart conoce. Debe coincidir con
  /// `RuntimeChannelHandler.RUNTIME_VERSION` en Kotlin.
  static const supportedRuntimeVersion = 1;

  static const _runtime = MethodChannel(NanoRuntimeChannels.runtime);
  static const _exec = MethodChannel(NanoRuntimeChannels.execBin);
  static const _pty = MethodChannel(NanoRuntimeChannels.pty);
  static const _metrics = MethodChannel(NanoRuntimeChannels.deviceMetrics);
  static const _agent = MethodChannel(NanoRuntimeChannels.agent);
  static const _engine = MethodChannel(NanoRuntimeChannels.engine);
  static const _notifications = MethodChannel(
    NanoRuntimeChannels.notifications,
  );
  static const _devicePermissions = MethodChannel(
    NanoRuntimeChannels.devicePermissions,
  );
  static const _speech = MethodChannel(NanoRuntimeChannels.speech);

  Future<RuntimeInfo>? _handshake;

  /// Handshake memoizado: se ejecuta una sola vez por proceso.
  Future<RuntimeInfo> handshake() => _handshake ??= _doHandshake();

  Future<RuntimeInfo> _doHandshake() async {
    try {
      final version = await _runtime.invokeMethod<int>('getRuntimeVersion');
      final caps =
          (await _runtime.invokeListMethod<String>('getCapabilities')) ??
          const <String>[];
      String? warning;
      if (version == null || version == 0) {
        warning = 'runtime no reportó versión';
      } else if (version > supportedRuntimeVersion) {
        warning =
            'runtime nativo v$version más nuevo que Dart '
            'v$supportedRuntimeVersion — actualizar app';
      } else if (version < supportedRuntimeVersion) {
        warning =
            'runtime nativo v$version más viejo que Dart '
            'v$supportedRuntimeVersion — actualizar runtime';
      }
      debugPrint(
        '[runtime] handshake v${version ?? "?"} '
        'caps=${caps.join(",")}${warning != null ? " WARN: $warning" : ""}',
      );
      return RuntimeInfo._(
        available: true,
        version: version ?? 0,
        capabilities: caps.toSet(),
        warning: warning,
      );
    } on MissingPluginException {
      return _unavailable('MissingPluginException');
    } on PlatformException catch (e) {
      return _unavailable(e.code);
    } catch (e) {
      return _unavailable('$e');
    }
  }

  RuntimeInfo _unavailable(String reason) {
    debugPrint('[runtime] handshake no disponible: $reason');
    return const RuntimeInfo.unavailable();
  }

  // ── rootfs ──

  /// Ruta base `files/nano/` del sandbox. Null si el canal no responde.
  Future<String?> getFilesDir() async {
    try {
      return await _exec.invokeMethod<String>('getFilesDir');
    } catch (e) {
      debugPrint('[runtime] getFilesDir error: $e');
      return null;
    }
  }

  Future<bool> downloadBootstrap(String url) async {
    try {
      return await _exec.invokeMethod<bool>('downloadBootstrap', url) == true;
    } catch (e) {
      debugPrint('[runtime] downloadBootstrap error: $e');
      return false;
    }
  }

  /// Extrae un bootstrap zip. Retorna archivos extraídos, -1 en fallo.
  Future<int> extractBootstrap(String zipPath, String destDir) async {
    try {
      final resp = await _exec.invokeMethod<Map<dynamic, dynamic>>(
        'extractBootstrap',
        {'zipPath': zipPath, 'destDir': destDir},
      );
      return (resp?['filesExtracted'] as num?)?.toInt() ?? -1;
    } catch (e) {
      debugPrint('[runtime] extractBootstrap error: $e');
      return -1;
    }
  }

  Future<bool> isBootstrapInstalled(String usrDir) async {
    try {
      return await _exec.invokeMethod<bool>('isBootstrapInstalled', usrDir) ==
          true;
    } catch (e) {
      debugPrint('[runtime] isBootstrapInstalled error: $e');
      return false;
    }
  }

  Future<bool> downloadFile(String url, String destPath) async {
    try {
      return await _exec.invokeMethod<bool>('downloadFile', {
            'url': url,
            'destPath': destPath,
          }) ==
          true;
    } catch (e) {
      debugPrint('[runtime] downloadFile error: $e');
      return false;
    }
  }

  // ── exec ──

  Future<bool> makeExecutable(String path) async {
    try {
      return await _exec.invokeMethod<bool>('makeExecutable', path) == true;
    } catch (e) {
      debugPrint('[runtime] makeExecutable error: $e');
      return false;
    }
  }

  /// Ejecuta un binario y captura salida completa. Map {rc, out, err} o null.
  Future<Map<dynamic, dynamic>?> probeExec(
    String path,
    List<String> args,
  ) async {
    try {
      return await _exec.invokeMethod<Map<dynamic, dynamic>>('probeExec', {
        'path': path,
        'args': args,
      });
    } catch (e) {
      debugPrint('[runtime] probeExec error: $e');
      return null;
    }
  }

  // ── worker ──

  /// Spawnea un binario en el proceso `:nanoshell` (sin GPU). Retorna taskId.
  Future<String?> workerSpawn({
    required String binaryPath,
    required List<String> argv,
    Map<String, String>? envp,
    String? ldPreload,
  }) async {
    try {
      final resp = await _exec
          .invokeMethod<Map<dynamic, dynamic>>('workerSpawn', {
            'binaryPath': binaryPath,
            'argv': argv,
            'envp': envp ?? const {},
            'ldPreload': ldPreload,
          });
      return resp?['taskId'] as String?;
    } catch (e) {
      debugPrint('[runtime] workerSpawn error: $e');
      return null;
    }
  }

  Future<bool> workerKill() async {
    try {
      return await _exec.invokeMethod<bool>('workerKill') == true;
    } catch (e) {
      debugPrint('[runtime] workerKill error: $e');
      return false;
    }
  }

  // ── packages / desktop ──

  Future<bool> installPackages(List<String> packages) async {
    try {
      final resp = await _exec.invokeMethod<Map<dynamic, dynamic>>(
        'installPackages',
        {'packages': packages},
      );
      return resp?['installed'] == true;
    } catch (e) {
      debugPrint('[runtime] installPackages error: $e');
      return false;
    }
  }

  Future<bool> installGraphical() async {
    try {
      final resp = await _exec.invokeMethod<Map<dynamic, dynamic>>(
        'installGraphical',
        {},
      );
      return resp?['installed'] == true;
    } catch (e) {
      debugPrint('[runtime] installGraphical error: $e');
      return false;
    }
  }

  /// El canal responde Boolean (no Map). Timeout nativo: 60s.
  /// [vncPassword] vacío = Xvnc sin auth (SecurityTypes None); no vacío =
  /// Xvnc con -rfbauth (VNC Auth). Solo se usa la primera vez que arranca el
  /// escritorio; un cambio posterior requiere stopDesktop + startDesktop.
  Future<bool> startDesktop({
    String vncPassword = '',
    int? width,
    int? height,
  }) async {
    try {
      // D-1: width/height = px del viewport lógico (MediaQuery del widget).
      // El framebuffer de Xvnc nace con el aspect del device (cap 1920),
      // no con el 1280x720 landscape fijo que dejaba franjas en portrait.
      return await _exec.invokeMethod<bool>('startDesktop', {
            'vncPassword': vncPassword,
            if (width != null) 'width': width,
            if (height != null) 'height': height,
          }) ==
          true;
    } catch (e) {
      debugPrint('[runtime] startDesktop error: $e');
      return false;
    }
  }

  /// Solicita los permisos de lectura de medios compartidos (Android 13+:
  /// READ_MEDIA_IMAGES/VIDEO/AUDIO; <=32: READ_EXTERNAL_STORAGE). Retorna
  /// true si todos los necesarios están concedidos. No-op en < API 23.
  Future<bool> requestStoragePermission() async {
    try {
      return await _exec.invokeMethod<bool>('requestStoragePermission') == true;
    } catch (e) {
      debugPrint('[runtime] requestStoragePermission error: $e');
      return false;
    }
  }

  Future<void> stopDesktop() async {
    try {
      await _exec.invokeMethod('stopDesktop', {});
    } catch (e) {
      debugPrint('[runtime] stopDesktop error: $e');
    }
  }

  /// Lanza una app gráfica del escritorio (allowlist nativa).
  Future<bool> launchApp(String app) async {
    try {
      return await _exec.invokeMethod<bool>('launchApp', {'app': app}) == true;
    } catch (e) {
      debugPrint('[runtime] launchApp($app) error: $e');
      return false;
    }
  }

  Future<Map<dynamic, dynamic>?> getDesktopStatus() async {
    try {
      return await _exec.invokeMethod<Map<dynamic, dynamic>>(
        'getDesktopStatus',
        {},
      );
    } catch (e) {
      debugPrint('[runtime] getDesktopStatus error: $e');
      return null;
    }
  }

  // ── pty (primitivas; PtySession las consume) ──

  Future<num?> ptySpawn({
    required List<String> argv,
    Map<String, String>? envp,
    String? ldPreload,
    int rows = 24,
    int cols = 80,
  }) async {
    try {
      return await _pty.invokeMethod<num?>('ptySpawn', {
        'argv': argv,
        'envp': envp ?? const {},
        'ldPreload': ldPreload,
        'rows': rows,
        'cols': cols,
      });
    } catch (e) {
      debugPrint('[runtime] ptySpawn error: $e');
      return null;
    }
  }

  Future<int> ptyWrite(int id, Uint8List data) async {
    try {
      return await _pty.invokeMethod<int>('ptyWrite', {
            'id': id,
            'data': data,
          }) ??
          0;
    } catch (e) {
      debugPrint('[runtime] ptyWrite error: $e');
      return 0;
    }
  }

  Future<Uint8List?> ptyRead(int id, {int maxBytes = 4096}) async {
    try {
      return await _pty.invokeMethod<Uint8List?>('ptyRead', {
        'id': id,
        'maxBytes': maxBytes,
      });
    } catch (e) {
      debugPrint('[runtime] ptyRead error: $e');
      return null;
    }
  }

  Future<void> ptyResize(int id, int rows, int cols) async {
    try {
      await _pty.invokeMethod('ptyResize', {
        'id': id,
        'rows': rows,
        'cols': cols,
      });
    } catch (e) {
      debugPrint('[runtime] ptyResize error: $e');
    }
  }

  Future<void> ptyKill(int id, {int signal = 2}) async {
    try {
      await _pty.invokeMethod('ptyKill', {'id': id, 'signal': signal});
    } catch (e) {
      debugPrint('[runtime] ptyKill error: $e');
    }
  }

  Future<void> ptyClose(int id) async {
    try {
      await _pty.invokeMethod('ptyClose', {'id': id});
    } catch (e) {
      debugPrint('[runtime] ptyClose error: $e');
    }
  }

  Future<int?> ptyGetPid(int id) async {
    try {
      return await _pty.invokeMethod<int>('ptyGetPid', {'id': id});
    } catch (e) {
      debugPrint('[runtime] ptyGetPid error: $e');
      return null;
    }
  }

  Future<int> ptyIsAlive(int id) async {
    try {
      return await _pty.invokeMethod<int>('ptyIsAlive', {'id': id}) ?? 1;
    } catch (e) {
      debugPrint('[runtime] ptyIsAlive error: $e');
      // Fallo = asumir vivo: el caller sigue haciendo polling en vez de
      // marcar la sesión como terminada por un error de canal.
      return 1;
    }
  }

  // ── device metrics ──

  Future<Map<dynamic, dynamic>?> getMetrics() async {
    try {
      return await _metrics.invokeMethod<Map<dynamic, dynamic>>('getMetrics');
    } catch (e) {
      debugPrint('[runtime] getMetrics error: $e');
      return null;
    }
  }

  Future<Map<dynamic, dynamic>?> getDeviceIdentity() async {
    try {
      return await _metrics.invokeMethod<Map<dynamic, dynamic>>(
        'getDeviceIdentity',
      );
    } catch (e) {
      debugPrint('[runtime] getDeviceIdentity error: $e');
      return null;
    }
  }

  // ── agente (AccessibilityService) ──

  /// true si el AgentAccessibilityService está conectado (activado en
  /// Ajustes → Accesibilidad). false cuando no, o canal ausente.
  Future<Map<dynamic, dynamic>?> agentStatus() async {
    try {
      return await _agent.invokeMethod<Map<dynamic, dynamic>>('getStatus');
    } catch (e) {
      debugPrint('[runtime] agentStatus error: $e');
      return null;
    }
  }

  /// Árbol de accesibilidad de la ventana activa como JSON (list de nodos con
  /// id/type/text/desc/bounds/clickable/...). Empty list si nada activo.
  Future<List<dynamic>> agentDumpScreen() async {
    try {
      return await _agent.invokeListMethod<dynamic>('dumpScreen') ?? const [];
    } catch (e) {
      debugPrint('[runtime] agentDumpScreen error: $e');
      return const [];
    }
  }

  /// Snapshot enriquecido para el Selector Engine:
  /// `{package, nodes:[{..., depth}]}`. null si el servicio no responde.
  /// Usa [NanoAgentExecutor] en vez de este método directo — aquí solo el
  /// transporte.
  Future<Map<dynamic, dynamic>?> agentDumpSnapshot() async {
    try {
      return await _agent.invokeMethod<Map<dynamic, dynamic>>('dumpSnapshot');
    } catch (e) {
      debugPrint('[runtime] agentDumpSnapshot error: $e');
      return null;
    }
  }

  /// Nodos cuyo texto/desc contiene [query]. maxResults limita el volcado
  /// (default 10) — el agente LLM solo necesita los mejores candidatos.
  @Deprecated(
    'Usa NanoAgentExecutor / NanoSelectorEngine: resuelve con '
    'puntuación ponderada y aborta en ambigüedad.',
  )
  Future<List<dynamic>> agentFindText(
    String query, {
    int maxResults = 10,
  }) async {
    try {
      return await _agent.invokeListMethod<dynamic>('findText', {
            'query': query,
            'maxResults': maxResults,
          }) ??
          const [];
    } catch (e) {
      debugPrint('[runtime] agentFindText error: $e');
      return const [];
    }
  }

  /// Tap sobre el nodo cuyo texto/desc contiene [text] (bounds reales del
  /// nodo, no coordenadas adivinadas).
  @Deprecated(
    'Peligroso: coge el primer nodo con contains sin unicidad ni '
    'estado. Usa NanoAgentExecutor.tap() con NanoSelector.',
  )
  Future<bool> agentTapOnText(String text) async {
    try {
      return await _agent.invokeMethod<bool>('tapOnText', {'text': text}) ==
          true;
    } catch (e) {
      debugPrint('[runtime] agentTapOnText error: $e');
      return false;
    }
  }

  /// Tap en coordenadas absolutas de pantalla.
  Future<bool> agentTapAt(int x, int y) async {
    try {
      return await _agent.invokeMethod<bool>('tapAt', {'x': x, 'y': y}) == true;
    } catch (e) {
      debugPrint('[runtime] agentTapAt error: $e');
      return false;
    }
  }

  Future<bool> agentLongPressAt(int x, int y, {int durationMs = 600}) async {
    try {
      return await _agent.invokeMethod<bool>('longPressAt', {
            'x': x,
            'y': y,
            'durationMs': durationMs,
          }) ==
          true;
    } catch (e) {
      debugPrint('[runtime] agentLongPressAt error: $e');
      return false;
    }
  }

  Future<bool> agentSwipe(
    int x1,
    int y1,
    int x2,
    int y2, {
    int durationMs = 300,
  }) async {
    try {
      return await _agent.invokeMethod<bool>('swipe', {
            'x1': x1,
            'y1': y1,
            'x2': x2,
            'y2': y2,
            'durationMs': durationMs,
          }) ==
          true;
    } catch (e) {
      debugPrint('[runtime] agentSwipe error: $e');
      return false;
    }
  }

  /// Escribe [text] en el campo enfocado (ACTION_SET_TEXT del nodo editable).
  Future<bool> agentInputText(String text) async {
    try {
      return await _agent.invokeMethod<bool>('inputText', {'text': text}) ==
          true;
    } catch (e) {
      debugPrint('[runtime] agentInputText error: $e');
      return false;
    }
  }

  /// back | home | recents | notifications | quick_settings.
  Future<bool> agentGlobalAction(String action) async {
    try {
      return await _agent.invokeMethod<bool>('globalAction', {
            'action': action,
          }) ==
          true;
    } catch (e) {
      debugPrint('[runtime] agentGlobalAction error: $e');
      return false;
    }
  }

  /// Lanza una app por packageName.
  Future<bool> agentLaunchPackage(String packageName) async {
    try {
      return await _agent.invokeMethod<bool>('launchPackage', {
            'packageName': packageName,
          }) ==
          true;
    } catch (e) {
      debugPrint('[runtime] agentLaunchPackage error: $e');
      return false;
    }
  }

  // ── motor nanortime (EngineSupervisor Kotlin) ──

  /// Suscribe al push de estados del motor (evento `engineState` del canal).
  /// Un solo listener — RuntimeEngineNotifier es el dueño.
  void setEngineStateListener(
    void Function(Map<dynamic, dynamic> state) handler,
  ) {
    _engine.setMethodCallHandler((call) async {
      if (call.method == 'engineState') {
        handler(call.arguments as Map<dynamic, dynamic>? ?? const {});
      }
    });
  }

  void clearEngineStateListener() => _engine.setMethodCallHandler(null);

  /// Arranca el motor (spawn + health poll en el supervisor Kotlin).
  /// Devuelve accepted=true si el supervisor aceptó el arranque; los estados
  /// reales llegan por evento engineState y por engineGetState().
  Future<bool> engineStart({int port = 8080, String? modelPath}) async {
    try {
      final r = await _engine.invokeMethod<Map<dynamic, dynamic>>('start', {
        'port': port,
        if (modelPath != null) 'modelPath': modelPath,
      });
      return r?['accepted'] == true;
    } catch (e) {
      debugPrint('[runtime] engineStart error: $e');
      return false;
    }
  }

  /// Snapshot del estado actual del supervisor (sin IO de red).
  Future<Map<dynamic, dynamic>?> engineGetState() async {
    try {
      return await _engine.invokeMethod<Map<dynamic, dynamic>>('state');
    } catch (e) {
      debugPrint('[runtime] engineGetState error: $e');
      return null;
    }
  }

  /// Probe real GET /health desde el lado Kotlin.
  Future<Map<dynamic, dynamic>?> engineHealth() async {
    try {
      return await _engine.invokeMethod<Map<dynamic, dynamic>>('health');
    } catch (e) {
      debugPrint('[runtime] engineHealth error: $e');
      return null;
    }
  }

  /// Kill limpio del motor (SIGTERM → gracia → SIGKILL).
  Future<bool> engineStop() async {
    try {
      return await _engine.invokeMethod<bool>('stop') == true;
    } catch (e) {
      debugPrint('[runtime] engineStop error: $e');
      return false;
    }
  }

  /// DEBUG/TEST: SIGKILL del proceso nanortime para simular un crash real.
  /// Devuelve true si se envió la señal (no espera a que muera).
  Future<bool> debugKillEngine() async {
    try {
      return await _engine.invokeMethod<bool>('debugKill') == true;
    } catch (e) {
      debugPrint('[runtime] debugKillEngine error: $e');
      return false;
    }
  }

  /// Extrae el PIE del APK a files/nano/engine/nanortime (idempotente).
  Future<Map<dynamic, dynamic>?> engineEnsureExtracted() async {
    try {
      return await _engine.invokeMethod<Map<dynamic, dynamic>>(
        'ensureExtracted',
      );
    } catch (e) {
      debugPrint('[runtime] engineEnsureExtracted error: $e');
      return null;
    }
  }

  // ── Permisos del dispositivo ──

  Future<Map<dynamic, dynamic>> devicePermissionStatus() async {
    try {
      return await _devicePermissions.invokeMethod<Map<dynamic, dynamic>>(
            'status',
          ) ??
          const {};
    } catch (e) {
      debugPrint('[runtime] devicePermissionStatus error: $e');
      return const {};
    }
  }

  /// A14.3 — estado FACTUAL de Shizuku (pasivo). El backend Kotlin consulta
  /// instalación (PackageManager), binder vivo (pingBinder) y autorización
  /// (checkSelfPermission) SIN abrir diálogos ni ejecutar acciones. Devuelve
  /// vacío (honesto) si el canal no responde; el mapeo a ShizukuStatus ocurre
  /// en el provider de dominio, nunca aquí.
  Future<Map<dynamic, dynamic>> queryShizukuStatus() async {
    try {
      return await _devicePermissions.invokeMethod<Map<dynamic, dynamic>>(
            'queryShizukuStatus',
          ) ??
          const {};
    } catch (e) {
      debugPrint('[runtime] queryShizukuStatus error: $e');
      return const {};
    }
  }

  /// A14.4 — solicita la conexión con Shizuku (automatiza el emparejamiento).
  /// Si ya está autorizada devuelve true; si no, dispara el diálogo Shizuku
  /// para que el usuario toque Permitir. El consentimiento humano no se salta.
  Future<bool> shizukuRequestPermission() async {
    try {
      return await _devicePermissions.invokeMethod<bool>(
            'shizukuRequestPermission',
          ) ==
          true;
    } catch (e) {
      debugPrint('[runtime] shizukuRequestPermission error: $e');
      return false;
    }
  }

  /// A14.5.4 — estado semántico factual del sistema (media reproduciéndose,
  /// Bluetooth/WiFi on/off). Lectura pasiva; devuelve vacío si el canal falla.
  Future<Map<dynamic, dynamic>> systemState() async {
    try {
      return await _devicePermissions.invokeMethod<Map<dynamic, dynamic>>(
            'systemState',
          ) ??
          const {};
    } catch (e) {
      debugPrint('[runtime] systemState error: $e');
      return const {};
    }
  }

  /// A14.9 — abrir una URL externa (solo http/https) con intent VIEW. El nativo
  /// valida el esquema para evitar intents arbitrarios. Devuelve false si falla.
  Future<bool> openUrl(String url) async {
    try {
      return await _devicePermissions.invokeMethod<bool>('openUrl', {
            'url': url,
          }) ==
          true;
    } catch (e) {
      debugPrint('[runtime] openUrl error: $e');
      return false;
    }
  }

  /// A16 — etiquetado de imagen on-device (ML Kit). Devuelve [{label, confidence,
  /// bounds}] como observación estructurada. El llamador decide (percepción, no
  /// autoridad). Vacío si falla el canal o el nativo.
  Future<List<dynamic>> visionLabel(Uint8List pngBytes) async {
    try {
      return await _agent.invokeListMethod<dynamic>('visionLabel', {
            'png': pngBytes,
          }) ??
          const [];
    } catch (e) {
      debugPrint('[runtime] visionLabel error: $e');
      return const [];
    }
  }

  /// A16 — entrada por voz: reconocimiento de voz del sistema Android. Devuelve
  /// el texto transcrito, o null si falló/canceló. El texto entra al MISMO
  /// motor de ejecución (AutomationCoordinator), no a un motor de voz separado.
  Future<String?> startVoiceRecognition({String language = 'es-ES'}) async {
    try {
      return await _speech.invokeMethod<String>('startListening', {
        'language': language,
      });
    } catch (e) {
      debugPrint('[runtime] startVoiceRecognition error: $e');
      return null;
    }
  }

  /// A16 — salida por voz (TTS): habla el texto. Devuelve false si falló.
  Future<bool> speak(String text) async {
    try {
      return await _speech.invokeMethod<bool>('speak', {'text': text}) == true;
    } catch (e) {
      debugPrint('[runtime] speak error: $e');
      return false;
    }
  }

  /// A16 — detiene la reproducción de voz (barge-in). true si se detuvo.
  Future<bool> stopSpeech() async {
    try {
      await _speech.invokeMethod<void>('stop');
      return true;
    } catch (e) {
      debugPrint('[runtime] stopSpeech error: $e');
      return false;
    }
  }

  /// A14.4 — acción Shizuku TIPADA: detener una app (reversible).
  /// El nativo vincula el UserService Shizuku (corre con privilegios) y valida
  /// el packageName. El estado de autorización lo valida el broker antes.
  Future<bool> shizukuForceStop(String packageName) async {
    try {
      return await _devicePermissions.invokeMethod<bool>('shizukuForceStop', {
            'packageName': packageName,
          }) ==
          true;
    } catch (e) {
      debugPrint('[runtime] shizukuForceStop error: $e');
      return false;
    }
  }

  /// A14.4 — acción Shizuku TIPADA (irreversible): instala un APK desde ruta
  /// local. Gobernada arriba (riesgo install). El nativo valida que la ruta exista.
  Future<bool> shizukuInstall(String apkPath) async {
    try {
      return await _devicePermissions.invokeMethod<bool>('shizukuInstall', {
            'apkPath': apkPath,
          }) ==
          true;
    } catch (e) {
      debugPrint('[runtime] shizukuInstall error: $e');
      return false;
    }
  }

  /// A14.4 — acción Shizuku TIPADA (cambia seguridad): concede un permiso
  /// runtime a un paquete. Gobernada arriba (riesgo grant).
  Future<bool> shizukuGrantPermission(
    String packageName,
    String permission,
  ) async {
    try {
      return await _devicePermissions.invokeMethod<bool>(
            'shizukuGrantPermission',
            {'packageName': packageName, 'permission': permission},
          ) ==
          true;
    } catch (e) {
      debugPrint('[runtime] shizukuGrantPermission error: $e');
      return false;
    }
  }

  /// A14.4 — primera acción Shizuku TIPADA: consulta metadatos de un paquete
  /// con privilegios (read-only, `cmd package dump`). El llamador debe verificar
  /// disponibilidad/autorización ANTES (queryShizukuStatus); el nativo valida el
  /// packageName y no acepta comandos libres. Devuelve vacío si el canal falla.
  Future<Map<dynamic, dynamic>> shizukuQueryPackage(String packageName) async {
    try {
      return await _devicePermissions.invokeMethod<Map<dynamic, dynamic>>(
            'shizukuQueryPackage',
            {'packageName': packageName},
          ) ??
          const {};
    } catch (e) {
      debugPrint('[runtime] shizukuQueryPackage error: $e');
      return const {'ok': false, 'code': 'CHANNEL_ERROR'};
    }
  }

  Future<bool> requestRuntimePermissions() =>
      _invokePermissionAction('requestRuntime');

  Future<bool> openAccessibilitySettings() =>
      _invokePermissionAction('openAccessibility');

  Future<bool> openNotificationAccessSettings() =>
      _invokePermissionAction('openNotificationAccess');

  Future<bool> openAllFilesAccessSettings() =>
      _invokePermissionAction('openAllFilesAccess');

  Future<bool> openAppPermissionSettings() =>
      _invokePermissionAction('openAppDetails');

  Future<bool> _invokePermissionAction(String method) async {
    try {
      return await _devicePermissions.invokeMethod<bool>(method) == true;
    } catch (e) {
      debugPrint('[runtime] $method error: $e');
      return false;
    }
  }

  // ── Automatización local de notificaciones ──

  Future<Map<dynamic, dynamic>> notificationStatus() async {
    try {
      return await _notifications.invokeMethod<Map<dynamic, dynamic>>(
            'status',
          ) ??
          const {};
    } catch (e) {
      debugPrint('[runtime] notificationStatus error: $e');
      return const {};
    }
  }

  Future<bool> requestNotificationAccess() async {
    try {
      return await _notifications.invokeMethod<bool>('requestAccess') == true;
    } catch (e) {
      debugPrint('[runtime] requestNotificationAccess error: $e');
      return false;
    }
  }

  Future<List<dynamic>> listActiveNotifications({int limit = 30}) async {
    try {
      return await _notifications.invokeListMethod<dynamic>('list', {
            'limit': limit.clamp(1, 100),
          }) ??
          const [];
    } catch (e) {
      debugPrint('[runtime] listActiveNotifications error: $e');
      return const [];
    }
  }

  Future<Map<dynamic, dynamic>> replyToNotification({
    required String key,
    required String text,
    required bool confirmed,
  }) async {
    if (!confirmed) {
      return const {'ok': false, 'code': 'CONFIRMATION_REQUIRED'};
    }
    try {
      return await _notifications.invokeMethod<Map<dynamic, dynamic>>('reply', {
            'key': key,
            'text': text,
            'confirmed': true,
          }) ??
          const {'ok': false, 'code': 'EMPTY_RESPONSE'};
    } catch (e) {
      debugPrint('[runtime] replyToNotification error: $e');
      return {'ok': false, 'code': e.toString()};
    }
  }
}
