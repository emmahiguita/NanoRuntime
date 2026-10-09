// product_depth_controller.dart
//
// QUÉ HACE:
// Controlador del ciclo de vida y decodificación asíncrona de recursos para el efecto 2.5D Parallax.
// Carga el FragmentProgram desde assets y decodifica las imágenes (RGB y Depth Map) a texturas `ui.Image`.
//
// CÓMO FUNCIONA:
// - Carga `FragmentProgram.fromAsset('shaders/product_depth_parallax.frag')` de forma segura.
// - Decodifica archivos o assets de imagen a `ui.Image` nativas para ser consumidas por samplers de GPU.
// - Notifica los cambios de estado (cargando, listo, error) sin bloquear el hilo principal.
// - Provee liberación de recursos (dispose) de texturas GPU para evitar fugas de memoria.
//
// POR QUÉ:
// Aísla la decodificación de texturas y ciclo de vida de GPU del widget visual (Clean Architecture / SRP)
// manteniéndose bajo 160 líneas de código.

library;

import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'depth_asset_cache.dart';

class ProductDepthController extends ChangeNotifier {
  static const String _shaderAssetPath = 'shaders/product_depth_parallax.frag';

  final DepthAssetCache depthCache;

  ui.FragmentShader? _shader;
  ui.Image? _rgbImage;
  ui.Image? _depthImage;
  bool _isLoading = false;
  bool _hasError = false;
  String? _errorMessage;

  ProductDepthController({this.depthCache = const DepthAssetCache()});

  ui.FragmentShader? get shader => _shader;
  ui.Image? get rgbImage => _rgbImage;
  ui.Image? get depthImage => _depthImage;
  bool get isLoading => _isLoading;
  bool get isReady => _shader != null && _rgbImage != null && _depthImage != null;
  bool get hasError => _hasError;
  String? get errorMessage => _errorMessage;

  /// Inicializa los recursos de shader y mapa de profundidad para una imagen de producto dada.
  Future<void> loadResources({
    required String rgbMediaPath,
    String? explicitDepthPath,
  }) async {
    if (_isLoading) return;
    _isLoading = true;
    _hasError = false;
    _errorMessage = null;
    notifyListeners();

    try {
      // 1. Cargar el FragmentProgram compilado
      final program = await ui.FragmentProgram.fromAsset(_shaderAssetPath);
      _shader = program.fragmentShader();

      // 2. Resolver la ruta del mapa de profundidad
      final depthPath = explicitDepthPath ??
          depthCache.getCachedDepthPath(rgbMediaPath) ??
          depthCache.resolveExpectedDepthPath(rgbMediaPath);

      // 3. Decodificar imagen RGB y Depth Map concurrentemente
      final results = await Future.wait([
        _decodeImageFromPath(rgbMediaPath),
        _decodeImageFromPath(depthPath),
      ]);

      _rgbImage = results[0];
      _depthImage = results[1];

      if (_rgbImage == null || _depthImage == null) {
        _hasError = true;
        _errorMessage = 'No fue posible decodificar las texturas de imagen o profundidad';
      }
    } on Object catch (e) {
      _hasError = true;
      _errorMessage = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Decodifica un archivo en disco o un asset del paquete a un objeto `ui.Image`.
  Future<ui.Image?> _decodeImageFromPath(String path) async {
    if (path.isEmpty) return null;
    try {
      Uint8List bytes;
      if (path.startsWith('assets/')) {
        final data = await rootBundle.load(path);
        bytes = data.buffer.asUint8List();
      } else {
        final file = File(path);
        if (!file.existsSync()) return null;
        bytes = await file.readAsBytes();
      }

      final codec = await ui.instantiateImageCodec(bytes);
      final frame = await codec.getNextFrame();
      return frame.image;
    } on Object {
      return null;
    }
  }

  @override
  void dispose() {
    _shader?.dispose();
    _rgbImage?.dispose();
    _depthImage?.dispose();
    super.dispose();
  }
}
