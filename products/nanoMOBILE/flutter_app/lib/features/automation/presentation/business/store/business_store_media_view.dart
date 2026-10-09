// business_store_media_view.dart
//
// QUÉ HACE:
// Componente de presentación multimedia profesional (Foto y Video) para productos de la tienda.
// Soporta assets integrados, archivos locales del dispositivo, indicadores de video y fallbacks elegantes.
//
// CÓMO FUNCIONA:
// - Detecta si el medio es un asset de Flutter, un archivo local o un formato de video (.mp4/.mov).
// - Superpone un gradiente tipo viñeta oscura para garantizar legibilidad de textos y badges.
// - Renderiza un badge interactivo con icono de reproducción en caso de ser video.
//
// POR QUÉ:
// Centraliza el renderizado multimedia en un solo componente reutilizable de < 130 líneas.

import 'dart:io';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

class BusinessStoreMediaView extends StatelessWidget {
  final String? mediaPath;
  final double? height;
  final double? width;
  final BorderRadius? borderRadius;
  final BoxFit fit;
  final bool showVideoBadge;

  const BusinessStoreMediaView({
    super.key,
    required this.mediaPath,
    this.height,
    this.width,
    this.borderRadius,
    this.fit = BoxFit.cover,
    this.showVideoBadge = true,
  });

  bool get _isVideo {
    if (mediaPath == null || mediaPath!.isEmpty) return false;
    final lower = mediaPath!.toLowerCase();
    return lower.endsWith('.mp4') ||
        lower.endsWith('.mov') ||
        lower.endsWith('.mkv') ||
        lower.endsWith('.webm') ||
        lower.contains('video') ||
        lower.contains('cinema');
  }

  @override
  Widget build(BuildContext context) {
    final path = mediaPath?.trim() ?? '';
    final isAsset = path.startsWith('assets/');
    final isFile = path.isNotEmpty && !isAsset && File(path).existsSync();

    Widget mediaWidget;
    if (isAsset) {
      mediaWidget = Image.asset(
        path,
        fit: fit,
        errorBuilder: (_, __, ___) => _buildFallback(),
      );
    } else if (isFile) {
      mediaWidget = Image.file(
        File(path),
        fit: fit,
        errorBuilder: (_, __, ___) => _buildFallback(),
      );
    } else {
      mediaWidget = _buildFallback();
    }

    return ClipRRect(
      borderRadius: borderRadius ?? BorderRadius.zero,
      child: SizedBox(
        height: height,
        width: width,
        child: Stack(
          fit: StackFit.expand,
          children: [
            mediaWidget,
            // Viñeta degradada inferior para contraste nítido estilo Apple
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
            if (_isVideo && showVideoBadge)
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
