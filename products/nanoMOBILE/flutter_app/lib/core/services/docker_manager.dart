import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:http/http.dart' as http;

import 'nano_runtime_api.dart';
import 'proot_manager.dart';
import '../../features/terminal/i_bin_executor.dart';

/// Docker-compatible container runtime sin daemon.
///
/// Como el kernel Android no expone cgroups/iptables/overlayfs a apps de
/// usuario, implementamos un runtime ligero que:
///   1. Descarga imágenes del Docker Hub Registry (API v2)
///   2. Extrae capas en rootfs aislados (files/nano/containers/<id>/rootfs)
///   3. Ejecuta el entrypoint del contenedor vía proot
///   4. Gestiona ciclo de vida: run, ps, stop, rm, images, pull
///
/// Compatible con imágenes ARM64 (aarch64). Las imágenes multi-arch
/// seleccionan automáticamente la variante ARM64.
class DockerManager {
  static const _registryAuth = 'https://auth.docker.io/token';
  static const _registry = 'https://registry-1.docker.io';

  final ProotManager _proot;
  final IBinExecutor _shell;
  final http.Client _http = http.Client();

  String? _containersDir;
  final Map<String, _Container> _containers = {};
  final Map<String, _Image> _images = {};
  final Random _rng = Random();

  final void Function(String msg)? onLog;

  bool _initialized = false;
  /// Whether the manager completed initialization successfully.
  /// Methods that depend on [_containersDir] should check this first.
  bool get isInitialized => _initialized;

  DockerManager({required ProotManager proot, required IBinExecutor shell, this.onLog})
      : _proot = proot, _shell = shell;

  Future<void> init() async {
    try {
      final base = await NanoRuntimeApi.instance.getFilesDir();
      if (base != null && base.isNotEmpty) {
        _containersDir = '$base/containers';
        Directory(_containersDir!).createSync(recursive: true);
        _loadState();
        _initialized = true;
      } else {
        onLog?.call('[docker] init: getFilesDir returned null/empty — containers disabled');
      }
    } catch (e) {
      onLog?.call('[docker] init failed: $e — containers disabled');
    }
  }

  /// Guards methods that require the containers directory to be initialized.
  /// Returns false and calls [onLog] with a diagnostic message when init failed.
  bool _checkInit(String caller) {
    if (!_initialized || _containersDir == null) {
      onLog?.call('[docker] $caller: manager not initialized — call init() first');
      return false;
    }
    return true;
  }

  void _loadState() {
    // Persisted container state: scans _containersDir for previously created
    // containers and restores them in-memory on startup.
    if (_containersDir == null) return;
    try {
      final dir = Directory(_containersDir!);
      if (!dir.existsSync()) return;
      for (final entry in dir.listSync()) {
        if (entry is! Directory || entry.path.endsWith('_layers')) continue;
        final id = entry.path.split('/').last.split('\\').last;
        if (id.isEmpty || id.startsWith('_')) continue;
        final rootfs = '${entry.path}/rootfs';
        if (!Directory(rootfs).existsSync()) continue;
        _containers[id] = _Container(
          id: id, image: 'persisted', rootfs: rootfs,
          cmd: ['/bin/sh'], created: entry.statSync().modified,
        )..status = 'exited'
         ..exitCode = 0;
      }
      log('Loaded ${_containers.length} persisted containers');
    } catch (e) {
      log('_loadState error: $e');
    }
  }

  // ── docker pull <image> ──

  /// Descarga una imagen de Docker Hub. Retorna true si éxito.
  /// Soporta formatos: "alpine", "alpine:latest", "alpine:3.19"
  Future<bool> pull(String image, void Function(String line) onProgress) async {
    final ref = _parseImage(image);
    final token = await _getAuthToken(ref.name);
    if (token == null) {
      onProgress('Error: no se pudo autenticar con Docker Hub');
      return false;
    }

    // 1. Obtener manifiesto para ARM64
    onProgress('Obteniendo manifiesto para $image (linux/arm64)...');
    final manifest = await _getManifest(ref, token);
    if (manifest == null) {
      onProgress('Error: imagen no encontrada o no disponible para ARM64');
      return false;
    }

    // 2. Descargar cada capa
    final layers = manifest['layers'] as List? ?? [];
    onProgress('Capas a descargar: ${layers.length}');
    var i = 0;
    final layerPaths = <String>[];
    for (final layer in layers) {
      i++;
      final digest = layer['digest'] as String;
      final size = layer['size'] as int? ?? 0;
      onProgress('[$i/${layers.length}] $digest (${(size / 1e6).toStringAsFixed(1)} MB)');
      final path = await _downloadLayer(ref.name, digest, token, (pct) {
        if (pct % 25 == 0) onProgress('  descargando... $pct%');
      });
      if (path != null) {
        layerPaths.add(path);
      } else {
        onProgress('Error descargando capa $digest');
        return false;
      }
    }

    // 3. Registrar imagen
    _images[image] = _Image(
      name: ref.name,
      tag: ref.tag,
      layers: layerPaths,
      config: manifest['config']?['digest'] as String?,
    );
    onProgress('Imagen $image descargada correctamente');

    return true;
  }

  // ── docker run <image> [cmd] ──

  /// Crea y ejecuta un contenedor a partir de una imagen.
  /// Retorna el container ID o null si falla.
  Future<String?> run(
    String image,
    List<String> cmd, {
    void Function(String line)? onOut,
    void Function(String line)? onErr,
  }) async {
    if (!_checkInit('run')) return null;
    final img = _images[image];
    if (img == null) {
      onErr?.call('Imagen "$image" no encontrada. Usa "docker pull $image" primero.');
      return null;
    }

    final id = _genId();
    final rootfs = '$_containersDir/$id/rootfs';
    Directory(rootfs).createSync(recursive: true);

    log('Creando contenedor $id desde $image...');

    // Extraer capas en orden (de base a top). Las capas son tar archives
    // (posiblemente comprimidos con gzip o zstd). tar -xf auto-detecta.
    for (final layerPath in img.layers) {
      log('  Extrayendo capa: $layerPath');
      final extractResult = await _shell.bash(
        'mkdir -p "$rootfs" && tar -xf "$layerPath" -C "$rootfs"',
        timeout: const Duration(minutes: 2),
      );
      if (extractResult.exitCode != 0) {
        onErr?.call('Error extrayendo capa: ${extractResult.stderr}');
        log('Layer extract failed: ${extractResult.stderr}');
      }
    }

    // Determinar entrypoint/cmd
    final entrypoint = cmd.isNotEmpty ? cmd : ['/bin/sh'];

    // Crear el contenedor
    final container = _Container(
      id: id,
      image: image,
      rootfs: rootfs,
      cmd: entrypoint,
      created: DateTime.now(),
    );
    _containers[id] = container;

    // Ejecutar vía proot (tag registra el proceso para que docker stop
    // pueda matarlo selectivamente — A-29).
    log('Ejecutando contenedor $id...');
    final exitCode = await _proot.exec(
      rootfs: rootfs,
      command: entrypoint.first,
      args: entrypoint.sublist(1),
      onOut: (l) {
        container.output.add(l);
        onOut?.call(l);
      },
      onErr: (l) {
        container.output.add('[stderr] $l');
        onErr?.call(l);
      },
      tag: 'docker:$id',
    );

    // Si docker stop mató el proceso, el exitCode es el del SIGTERM —
    // no pisar el estado "stopped" que dejó el usuario.
    if (container.status == 'stopped') {
      log('Contenedor $id detenido por docker stop');
      return id;
    }
    container.exitCode = exitCode;
    container.status = exitCode == 0 ? 'exited' : 'error';
    log('Contenedor $id terminó con código $exitCode');
    return id;
  }

  // ── docker ps / docker images ──

  List<Map<String, dynamic>> ps() {
    return _containers.values.map((c) => {
      'id': c.id.substring(0, 12),
      'image': c.image,
      'status': c.status,
      'created': c.created.toString().substring(0, 19),
      'exitCode': c.exitCode,
    }).toList();
  }

  List<Map<String, dynamic>> images() {
    return _images.entries.map((e) => {
      'name': e.key,
      'layers': e.value.layers.length,
    }).toList();
  }

  /// Elimina el contenedor [id] y su rootfs. Retorna false si no existe.
  bool rm(String id) {
    final c = _containers.remove(id);
    if (c == null) return false;
    try { Directory(c.rootfs).deleteSync(recursive: true); } catch (_) {}
    return true;
  }

  /// Detiene el contenedor [id]. Retorna false si no existe.
  ///
  /// A-29: antes solo marcaba status='stopped' — el proceso proot seguía
  /// vivo hasta terminar solo. Ahora mata el proceso real (SIGTERM y, a
  /// los 2s, SIGKILL vía ShellExecutor.killTracked) antes de marcar.
  bool stop(String id) {
    final c = _containers[id];
    if (c == null) return false;
    if (c.status != 'stopped') {
      final killed = _proot.killByTag('docker:$id');
      if (killed) {
        log('Contenedor $id: proceso proot detenido');
      } else if (c.status == 'running') {
        // Sin proceso trackeado (run no en vuelo): solo marcar.
        log('Contenedor $id: sin proceso activo, marcando como detenido');
      }
    }
    c.status = 'stopped';
    return true;
  }

  void dispose() {
    _http.close();
  }

  // ── Docker Hub API ──

  Future<String?> _getAuthToken(String repo) async {
    try {
      final url = '$_registryAuth?service=registry.docker.io&scope=repository:library/$repo:pull';
      final r = await _http.get(Uri.parse(url));
      if (r.statusCode == 200) {
        return (jsonDecode(r.body) as Map)['token'] as String?;
      }
    } catch (e) {
      log('Auth error: $e');
    }
    return null;
  }

  Future<Map<String, dynamic>?> _getManifest(_ImageRef ref, String token) async {
    try {
      final url = '$_registry/v2/library/${ref.name}/manifests/${ref.tag}';
      final headers = {
        'Authorization': 'Bearer $token',
        // Aceptar tanto manifest lists (multi-arch) como image manifests (single-arch).
        // Docker Hub devuelve manifest list para imágenes multi-arch como alpine, ubuntu...
        'Accept': 'application/vnd.docker.distribution.manifest.list.v2+json, '
            'application/vnd.docker.distribution.manifest.v2+json, '
            'application/vnd.oci.image.index.v1+json, '
            'application/vnd.oci.image.manifest.v1+json',
      };
      final r = await _http.get(Uri.parse(url), headers: headers);
      if (r.statusCode != 200) {
        log('Manifest error: HTTP ${r.statusCode}');
        return null;
      }

      final raw = jsonDecode(r.body) as Map<String, dynamic>;
      final mediaType = raw['mediaType'] as String? ?? '';

      // Caso 1: manifest list (multi-arch) — buscar entrada ARM64
      if (mediaType.contains('manifest.list') || mediaType.contains('index') || raw.containsKey('manifests')) {
        final manifests = raw['manifests'] as List? ?? [];
        log('Manifest list con ${manifests.length} arquitecturas');

        // Buscar linux/arm64 o linux/arm64/v8
        Map<String, dynamic>? armManifest;
        for (final m in manifests) {
          final platform = m['platform'] as Map<String, dynamic>? ?? {};
          final arch = platform['architecture'] as String? ?? '';
          final os = platform['os'] as String? ?? '';
          if (os == 'linux' && (arch == 'arm64' || arch == 'aarch64')) {
            armManifest = m as Map<String, dynamic>;
            log('  Seleccionada: $os/$arch');
            break;
          }
        }

        if (armManifest == null) {
          log('Error: no hay variante ARM64 para esta imagen');
          return null;
        }

        // Obtener el manifest real de la arquitectura ARM64
        final armDigest = armManifest['digest'] as String?;
        if (armDigest == null) {
          log('Error: entrada ARM64 sin digest');
          return null;
        }

        final armUrl = '$_registry/v2/library/${ref.name}/manifests/$armDigest';
        final armHeaders = {
          'Authorization': 'Bearer $token',
          'Accept': 'application/vnd.docker.distribution.manifest.v2+json, '
              'application/vnd.oci.image.manifest.v1+json',
        };
        final armR = await _http.get(Uri.parse(armUrl), headers: armHeaders);
        if (armR.statusCode != 200) {
          log('ARM64 manifest error: HTTP ${armR.statusCode}');
          return null;
        }
        return jsonDecode(armR.body) as Map<String, dynamic>;
      }

      // Caso 2: image manifest directo (single-arch)
      return raw;
    } catch (e) {
      log('Manifest error: $e');
    }
    return null;
  }

  Future<String?> _downloadLayer(
    String repo,
    String digest,
    String token,
    void Function(int pct) onProgress,
  ) async {
    if (!_checkInit('_downloadLayer')) return null;
    try {
      final url = '$_registry/v2/library/$repo/blobs/$digest';
      final request = http.Request('GET', Uri.parse(url));
      request.headers['Authorization'] = 'Bearer $token';
      final response = await _http.send(request);

      if (response.statusCode != 200) {
        log('Layer error: HTTP ${response.statusCode}');
        return null;
      }

      // Guardar el blob sin asumir compresión. El digest identifica el
      // contenido; la extensión .blob evita falsas suposiciones sobre gzip.
      final safeDigest = digest.replaceAll(':', '_');
      final destPath = '$_containersDir/_layers/$safeDigest.blob';
      final dest = File(destPath);
      dest.parent.createSync(recursive: true);

      final total = response.contentLength ?? 0;
      var downloaded = 0;
      final output = dest.openWrite();
      await for (final chunk in response.stream) {
        output.add(chunk);
        downloaded += chunk.length;
        if (total > 0) {
          final pct = (downloaded * 100 ~/ total);
          if (pct % 20 == 0) onProgress(pct);
        }
      }
      await output.flush();
      await output.close();
      onProgress(100);
      return destPath;
    } catch (e) {
      log('Layer error: $e');
    }
    return null;
  }

  // ── Helpers ──

  _ImageRef _parseImage(String image) {
    final parts = image.split(':');
    return _ImageRef(name: parts[0], tag: parts.length > 1 ? parts[1] : 'latest');
  }

  String _genId() {
    final bytes = List<int>.generate(32, (_) => _rng.nextInt(256));
    return bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  }

  void log(String msg) => onLog?.call(msg);
}

class _ImageRef {
  final String name;
  final String tag;
  _ImageRef({required this.name, required this.tag});
}

class _Image {
  final String name;
  final String tag;
  final List<String> layers;
  final String? config;
  _Image({required this.name, required this.tag, required this.layers, this.config});
}

class _Container {
  final String id;
  final String image;
  final String rootfs;
  final List<String> cmd;
  final DateTime created;
  String status = 'running';
  int? exitCode;
  final List<String> output = [];
  _Container({
    required this.id,
    required this.image,
    required this.rootfs,
    required this.cmd,
    required this.created,
  });
}
