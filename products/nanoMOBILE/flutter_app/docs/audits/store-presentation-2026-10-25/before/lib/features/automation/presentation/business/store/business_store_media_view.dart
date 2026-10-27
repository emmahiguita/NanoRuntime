// business_store_media_view.dart
//
// QUÉ HACE:
// Componente de presentación multimedia profesional (Foto, Video y 2.5D Parallax) para productos de la tienda.
// Soporta assets integrados, archivos locales, indicadores de video y efecto 2.5D interactivo opcional.
//
// CÓMO FUNCIONA:
// - Detecta si el medio es un asset de Flutter, un archivo local o un formato de video (.mp4/.mov).
// - Si `enableParallax` está activo y no es video, inicializa `ProductDepthController` para renderizado en GPU.
// - Superpone un gradiente tipo viñeta oscura para garantizar legibilidad de textos y badges.
// - Renderiza un badge interactivo con icono de reproducción en caso de ser video.
//
// POR QUÉ:
// Centraliza el renderizado multimedia y la integración de 2.5D en un solo componente reutilizable de < 170 líneas.

library;

import 'dart:io';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'parallax/business_store_parallax_card.dart';
import 'parallax/device_tilt_service.dart';
import 'parallax/product_depth_controller.dart';

class BusinessStoreMediaView extends StatefulWidget {
  final String? mediaPath;
  final double? height;
  final double? width;
  final BorderRadius? borderRadius;
  final BoxFit fit;
  final bool showVideoBadge;
  final bool enableParallax;
  final DeviceTiltService? tiltService;

  const BusinessStoreMediaView({
    super.key,
    required this.mediaPath,
    this.height,
    this.width,
    this.borderRadius,
    this.fit = BoxFit.cover,
    this.showVideoBadge = true,
    this.enableParallax = false,
    this.tiltService,
  });

  @override
  State<BusinessStoreMediaView> createState() => _BusinessStoreMediaViewState();
}

class _BusinessStoreMediaViewState extends State<BusinessStoreMediaView> {
  ProductDepthController? _depthController;
  DeviceTiltService? _localTiltService;

  bool get _isVideo {
    final path = widget.mediaPath;
    if (path == null || path.isEmpty) return false;
    final lower = path.toLowerCase();
    return lower.endsWith('.mp4') ||
        lower.endsWith('.mov') ||
        lower.endsWith('.mkv') ||
        lower.endsWith('.webm') ||
        lower.contains('video') ||
        lower.contains('cinema');
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

  void _initParallaxIfNeeded() {
    if (!widget.enableParallax || _isVideo || widget.mediaPath == null || widget.mediaPath!.isEmpty) {
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
    if (widget.tiltService == null) {
      _localTiltService?.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final path = widget.mediaPath?.trim() ?? '';
    final isAsset = path.startsWith('assets/');
    final isFile = path.isNotEmpty && !isAsset && File(path).existsSync();

    Widget standardMedia;
    if (isAsset) {
      standardMedia = Image.asset(path, fit: widget.fit, errorBuilder: (_, __, ___) => _buildFallback());
    } else if (isFile) {
      standardMedia = Image.file(File(path), fit: widget.fit, errorBuilder: (_, __, ___) => _buildFallback());
    } else {
      standardMedia = _buildFallback();
    }

    Widget content = standardMedia;

    // Renderizado 2.5D Parallax si el controlador está listo
    if (widget.enableParallax && _depthController != null && !_isVideo) {
      final controller = _depthController!;
      final tilt = _localTiltService!;
      content = AnimatedBuilder(
        animation: controller,
        builder: (context, _) {
          if (!controller.isReady) return standardMedia;
          return BusinessStoreParallaxCard(
            rgbImage: controller.rgbImage,
            depthImage: controller.depthImage,
            shader: controller.shader,
            tiltService: tilt,
            fallbackWidget: standardMedia,
            width: widget.width ?? double.infinity,
            height: widget.height ?? double.infinity,
            borderRadius: widget.borderRadius ?? BorderRadius.zero,
          );
        },
      );
    }

    return ClipRRect(
      borderRadius: widget.borderRadius ?? BorderRadius.zero,
      child: SizedBox(
        height: widget.height,
        width: widget.width,
        child: Stack(
          fit: StackFit.expand,
          children: [
            content,
            const DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Colors.transparent, Color(0x990A111C)],
                  stops: [0.55, 1.0],
                ),
              ),
            ),
            if (_isVideo && widget.showVideoBadge)
              Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: const Color(0xB3000000),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: const Color(0x6664B5F6)),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(CupertinoIcons.play_fill, size: 12, color: Color(0xFF38BDF8)),
                      SizedBox(width: 4),
                      Text(
                        'VIDEO 4K',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 9.5,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildFallback() => Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF1E334D), Color(0xFF0C1624)],
          ),
        ),
        child: const Center(
          child: Icon(
            CupertinoIcons.photo_on_rectangle,
            size: 28,
            color: Color(0xFF64B5F6),
          ),
        ),
      );
}
