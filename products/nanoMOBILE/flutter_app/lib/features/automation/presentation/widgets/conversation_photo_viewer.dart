// conversation_photo_viewer.dart
//
// QUÉ HACE:
// Despliega el visor de fotos en pantalla completa con zoom interactivo, paneo y compartir.
//
// CÓMO FUNCIONA:
// - Despliega un diálogo con fondo desenfocado (BackdropFilter) y InteractiveViewer.
// - Soporta Hero animations para transiciones suaves desde las miniaturas del chat.
// - Evita Tooltips para prevenir el error "No Overlay" usando Semantics.
//
// POR QUÉ:
// Responsabilidad única (SRP) para el visor de imágenes, manteniendo archivos < 200 líneas.

library;

import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import 'conversation_media_source.dart';

/// Visor interactivo a pantalla completa para imágenes locales o remotas.
abstract final class ConversationPhotoViewer {
  static void show(
    BuildContext context, {
    required String pathOrUrl,
    String? caption,
    Object? heroTag,
  }) {
    final source = ConversationMediaSource(pathOrUrl);
    final file = source.localFile;
    final fileName = source.displayName;
    final tag = heroTag ?? 'media_photo_$pathOrUrl';

    showDialog(
      context: context,
      useRootNavigator: true,
      barrierColor: Colors.black.withValues(alpha: 0.90),
      builder: (dialogCtx) {
        return Scaffold(
          backgroundColor: Colors.transparent,
          body: Stack(
            fit: StackFit.expand,
            children: [
              Positioned.fill(
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
                  child: Container(color: Colors.black.withValues(alpha: 0.5)),
                ),
              ),
              Center(
                child: InteractiveViewer(
                  minScale: 0.7,
                  maxScale: 4.5,
                  child: Hero(
                    tag: tag,
                    child: source.isLocal
                        ? file != null && file.existsSync()
                            ? Image.file(
                                file,
                                fit: BoxFit.contain,
                                errorBuilder: (_, __, ___) => _buildErrorWidget('No se pudo cargar la imagen'),
                              )
                            : _buildErrorWidget('La imagen ya no está disponible')
                        : Image.network(
                            source.value,
                            fit: BoxFit.contain,
                            loadingBuilder: (ctx, child, progress) {
                              if (progress == null) return child;
                              return const Center(child: CircularProgressIndicator(color: Color(0xFF00FF88)));
                            },
                            errorBuilder: (_, __, ___) => _buildErrorWidget('No se pudo cargar la imagen'),
                          ),
                  ),
                ),
              ),
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    child: Row(
                      children: [
                        Semantics(
                          label: 'Cerrar',
                          child: IconButton(
                            icon: const Icon(Icons.close_rounded, color: Colors.white, size: 28),
                            onPressed: () => Navigator.of(dialogCtx).pop(),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            caption?.isNotEmpty == true ? caption! : fileName,
                            style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w600),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Semantics(
                          label: 'Compartir imagen',
                          child: IconButton(
                            icon: const Icon(Icons.share_rounded, color: Colors.white, size: 24),
                            onPressed: () async {
                              if (source.isLocal && file != null && file.existsSync()) {
                                await SharePlus.instance.share(
                                  ShareParams(files: [XFile(file.path)], subject: caption ?? fileName),
                                );
                              } else {
                                await SharePlus.instance.share(
                                  ShareParams(text: pathOrUrl, subject: caption ?? fileName),
                                );
                              }
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  static Widget _buildErrorWidget(String msg) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.6), borderRadius: BorderRadius.circular(16)),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.broken_image_rounded, color: Colors.amber, size: 48),
          const SizedBox(height: 12),
          Text(msg, style: const TextStyle(color: Colors.white, fontSize: 14)),
        ],
      ),
    );
  }
}
