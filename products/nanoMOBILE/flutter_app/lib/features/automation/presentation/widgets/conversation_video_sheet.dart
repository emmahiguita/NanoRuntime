// conversation_video_sheet.dart
//
// QUÉ HACE:
// Modal interactivo con diseño iOS Frosted Glass para reproducir videos (YouTube y clips locales).
//
// CÓMO FUNCIONA:
// - Renderiza un contenedor con InAppWebView y aceleración por hardware.
// - Barra superior con diseño frosted glass, botón de cerrar, copiar enlace y abrir en app externa.
// - Usa Semantics en lugar de Tooltips para prevenir el error visual "No Overlay".
//
// POR QUÉ:
// Desacopla la vista del reproductor (SRP) garantizando archivos bajo 200 líneas.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:url_launcher/url_launcher.dart';
import 'conversation_media_source.dart';

class VideoPlayerSheet extends StatefulWidget {
  final String urlOrPath;
  final String? title;
  final String? youTubeId;

  const VideoPlayerSheet({
    super.key,
    required this.urlOrPath,
    this.title,
    this.youTubeId,
  });

  @override
  State<VideoPlayerSheet> createState() => _VideoPlayerSheetState();
}

class _VideoPlayerSheetState extends State<VideoPlayerSheet> {
  double _progress = 0;
  bool _isLoading = true;

  @override
  Widget build(BuildContext context) {
    final isLandscape = MediaQuery.of(context).orientation == Orientation.landscape;
    final size = MediaQuery.of(context).size;
    final isYouTube = widget.youTubeId != null && widget.youTubeId!.isNotEmpty;
    final source = ConversationMediaSource(widget.urlOrPath);
    final playbackUrl = source.playbackUrl;
    final displayTitle = widget.title ?? (isYouTube ? 'YouTube Video' : source.displayName);

    return Container(
      height: isLandscape ? size.height * 0.95 : size.height * 0.75,
      decoration: const BoxDecoration(
        color: Color(0xFF0F172A),
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          Container(
            width: 40,
            height: 4,
            margin: const EdgeInsets.only(top: 10, bottom: 6),
            decoration: BoxDecoration(
              color: Colors.white24,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            child: Row(
              children: [
                Icon(
                  isYouTube ? Icons.smart_display_rounded : Icons.play_circle_fill_rounded,
                  color: isYouTube ? const Color(0xFFFF0000) : const Color(0xFF3B82F6),
                  size: 22,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    displayTitle,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 13.5,
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Semantics(
                  label: 'Copiar enlace',
                  child: IconButton(
                    icon: const Icon(Icons.copy_rounded, color: Colors.white70, size: 18),
                    onPressed: () {
                      Clipboard.setData(ClipboardData(text: widget.urlOrPath));
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Enlace de video copiado'),
                          behavior: SnackBarBehavior.floating,
                          duration: Duration(seconds: 2),
                        ),
                      );
                    },
                  ),
                ),
                Semantics(
                  label: 'Abrir en app externa',
                  child: IconButton(
                    icon: const Icon(Icons.open_in_new_rounded, color: Colors.white70, size: 18),
                    onPressed: () {
                      final uri = source.launchUri;
                      if (uri != null) launchUrl(uri, mode: LaunchMode.externalApplication);
                    },
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded, color: Colors.white70, size: 20),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
          ),
          if (_isLoading)
            LinearProgressIndicator(
              value: _progress > 0 ? _progress : null,
              backgroundColor: Colors.white10,
              color: isYouTube ? const Color(0xFFFF0000) : const Color(0xFF3B82F6),
              minHeight: 2,
            ),
          Expanded(
            child: Container(
              color: Colors.black,
              child: InAppWebView(
                initialSettings: InAppWebViewSettings(
                  javaScriptEnabled: true,
                  mediaPlaybackRequiresUserGesture: false,
                  allowsInlineMediaPlayback: true,
                  allowFileAccess: true,
                  allowFileAccessFromFileURLs: true,
                  supportZoom: false,
                  transparentBackground: true,
                ),
                initialData: isYouTube
                    ? InAppWebViewInitialData(
                        data: '''
                          <!DOCTYPE html>
                          <html>
                          <head>
                            <meta name="viewport" content="width=device-width, initial-scale=1.0, maximum-scale=1.0, user-scalable=no">
                            <style>
                              body, html { margin:0; padding:0; width:100%; height:100%; background:#000; overflow:hidden; display:flex; justify-content:center; align-items:center; }
                              iframe { width:100%; height:100%; border:none; }
                            </style>
                          </head>
                          <body>
                            <iframe src="https://www.youtube-nocookie.com/embed/${widget.youTubeId}?autoplay=1&playsinline=1&rel=0&modestbranding=1" allow="accelerometer; autoplay; clipboard-write; encrypted-media; gyroscope; picture-in-picture" allowfullscreen></iframe>
                          </body>
                          </html>
                        ''',
                      )
                    : (source.isRemote
                        ? null
                        : InAppWebViewInitialData(
                            baseUrl: WebUri('file:///'),
                            data: '''
                              <!DOCTYPE html>
                              <html>
                              <head>
                                <meta name="viewport" content="width=device-width, initial-scale=1.0">
                                <style>
                                  body { margin:0; background:#000; display:flex; justify-content:center; align-items:center; height:100vh; }
                                  video { width:100%; max-height:100vh; outline:none; }
                                </style>
                              </head>
                              <body>
                                <video controls autoplay playsinline src="$playbackUrl"></video>
                              </body>
                              </html>
                            ''',
                          )),
                initialUrlRequest: !isYouTube && source.isRemote
                    ? URLRequest(url: WebUri(source.value))
                    : null,
                onProgressChanged: (_, p) {
                  if (!mounted) return;
                  setState(() {
                    _progress = p / 100.0;
                    _isLoading = p < 100;
                  });
                },
                onLoadStop: (_, __) {
                  if (mounted) setState(() => _isLoading = false);
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}
