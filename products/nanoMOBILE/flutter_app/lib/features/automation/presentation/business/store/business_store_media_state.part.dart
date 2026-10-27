part of 'business_store_media_view.dart';

/// El controlador pertenece a esta vista; un servicio de inclinación externo
/// conserva su propietario original. Las tarjetas normales no activan sensores.
class _BusinessStoreMediaViewState extends State<BusinessStoreMediaView> {
  ProductDepthController? _depthController;
  DeviceTiltService? _localTiltService;

  bool get _isVideo {
    final path = Uri.tryParse(widget.mediaPath ?? '')?.path.toLowerCase() ?? '';
    return const ['.mp4', '.mov', '.mkv', '.webm', '.m4v', '.3gp'].any(path.endsWith);
  }

  @override
  void initState() {
    super.initState();
    _initParallaxIfNeeded();
  }

  @override
  void didUpdateWidget(covariant BusinessStoreMediaView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.mediaPath != widget.mediaPath || oldWidget.enableParallax != widget.enableParallax) {
      _initParallaxIfNeeded();
    }
  }

  /// Conserva la integración existente: solo una imagen con efecto solicitado
  /// carga mapas de profundidad. El catálogo estático no necesita ese trabajo.
  void _initParallaxIfNeeded() {
    if (!widget.enableParallax || _isVideo || (widget.mediaPath?.isEmpty ?? true)) {
      _depthController?.dispose();
      _depthController = null;
      return;
    }
    _localTiltService ??= widget.tiltService ?? DeviceTiltService();
    _depthController ??= ProductDepthController();
    _depthController!.loadResources(rgbMediaPath: widget.mediaPath!);
  }

  @override
  void dispose() {
    _depthController?.dispose();
    if (widget.tiltService == null) _localTiltService?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final path = widget.mediaPath?.trim() ?? '';
    Widget content = _StoreMediaImage(
      path: path,
      fit: widget.fit,
      isVideo: _isVideo,
      showVideoLabel: widget.showVideoBadge,
    );
    if (widget.enableParallax && _depthController != null && !_isVideo) {
      final controller = _depthController!;
      final fallback = content;
      content = AnimatedBuilder(
        animation: controller,
        builder: (context, _) {
          if (!controller.isReady) return fallback;
          return BusinessStoreParallaxCard(
            rgbImage: controller.rgbImage,
            depthImage: controller.depthImage,
            shader: controller.shader,
            tiltService: _localTiltService!,
            fallbackWidget: fallback,
            width: widget.width ?? double.infinity,
            height: widget.height ?? double.infinity,
            borderRadius: widget.borderRadius ?? BorderRadius.zero,
          );
        },
      );
    }
    return ClipRRect(
      borderRadius: widget.borderRadius ?? BorderRadius.zero,
      child: SizedBox(height: widget.height, width: widget.width, child: content),
    );
  }
}
