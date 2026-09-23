import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:url_launcher/url_launcher.dart';
import 'floating_video_overlay.dart';

/// Modal interactivo para reproducir videos (YouTube, HTML5, clips locales) y previsualizar enlaces web.
abstract final class ConversationInAppPlayer {
  static void showVideoPlayer(
    BuildContext context, {
    required String urlOrPath,
    String? title,
    String? youTubeId,
    bool floating = true,
  }) {
    if (floating) {
      FloatingVideoController.instance.show(
        context,
        videoUrl: urlOrPath,
        title: title,
        youTubeId: youTubeId,
      );
      return;
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _VideoPlayerSheet(
        urlOrPath: urlOrPath,
        title: title,
        youTubeId: youTubeId,
      ),
    );
  }

  static void showWebBrowser(
    BuildContext context, {
    required String url,
    String? title,
  }) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _WebBrowserSheet(
        url: url,
        title: title,
      ),
    );
  }
}

class _VideoPlayerSheet extends StatefulWidget {
  final String urlOrPath;
  final String? title;
  final String? youTubeId;

  const _VideoPlayerSheet({
    required this.urlOrPath,
    this.title,
    this.youTubeId,
  });

  @override
  State<_VideoPlayerSheet> createState() => _VideoPlayerSheetState();
}

class _VideoPlayerSheetState extends State<_VideoPlayerSheet> {
  double _progress = 0;
  bool _isLoading = true;

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isYouTube = widget.youTubeId != null && widget.youTubeId!.isNotEmpty;
    final displayTitle = widget.title ?? (isYouTube ? 'YouTube Video' : 'Reproductor de Video');

    return Container(
      height: size.height * 0.75,
      decoration: const BoxDecoration(
        color: Color(0xFF0F172A),
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          // Drag handle
          Container(
            width: 40,
            height: 4,
            margin: const EdgeInsets.only(top: 10, bottom: 6),
            decoration: BoxDecoration(
              color: Colors.white24,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          // Top bar
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                Icon(
                  isYouTube ? Icons.smart_display_rounded : Icons.play_circle_fill_rounded,
                  color: isYouTube ? const Color(0xFFFF0000) : const Color(0xFF3B82F6),
                  size: 24,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    displayTitle,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                // Semantics en lugar de Tooltip: previene el fallo "No Overlay" (cajas rojas con texto amarillo)
                Semantics(
                  label: 'Copiar enlace',
                  child: IconButton(
                    icon: const Icon(Icons.copy_rounded, color: Colors.white70, size: 20),
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
                // Semantics en lugar de Tooltip: previene el fallo "No Overlay"
                Semantics(
                  label: 'Abrir en app externa',
                  child: IconButton(
                    icon: const Icon(Icons.open_in_new_rounded, color: Colors.white70, size: 20),
                    onPressed: () => launchUrl(
                      Uri.parse(widget.urlOrPath.startsWith('http') ? widget.urlOrPath : 'https://${widget.urlOrPath}'),
                      mode: LaunchMode.externalApplication,
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded, color: Colors.white70, size: 22),
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
          // Player area
          Expanded(
            child: Container(
              color: Colors.black,
              child: InAppWebView(
                initialSettings: InAppWebViewSettings(
                  javaScriptEnabled: true,
                  mediaPlaybackRequiresUserGesture: false,
                  allowsInlineMediaPlayback: true,
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
                    : (widget.urlOrPath.startsWith('http')
                        ? null
                        : InAppWebViewInitialData(
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
                                <video controls autoplay playsinline src="${widget.urlOrPath.startsWith('file://') ? widget.urlOrPath : 'file://${widget.urlOrPath}'}"></video>
                              </body>
                              </html>
                            ''',
                          )),
                initialUrlRequest: !isYouTube && widget.urlOrPath.startsWith('http')
                    ? URLRequest(url: WebUri(widget.urlOrPath))
                    : null,
                onWebViewCreated: (_) {},
                onProgressChanged: (_, p) {
                  setState(() {
                    _progress = p / 100.0;
                    _isLoading = p < 100;
                  });
                },
                onLoadStop: (_, __) => setState(() => _isLoading = false),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _WebBrowserSheet extends StatefulWidget {
  final String url;
  final String? title;

  const _WebBrowserSheet({
    required this.url,
    this.title,
  });

  @override
  State<_WebBrowserSheet> createState() => _WebBrowserSheetState();
}

class _WebBrowserSheetState extends State<_WebBrowserSheet> {
  InAppWebViewController? _controller;
  double _progress = 0;
  bool _isLoading = true;
  String _pageTitle = '';

  @override
  void initState() {
    super.initState();
    _pageTitle = widget.title ?? Uri.tryParse(widget.url)?.host ?? widget.url;
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final validUrl = widget.url.startsWith('http://') || widget.url.startsWith('https://')
        ? widget.url
        : 'https://${widget.url}';

    return Container(
      height: size.height * 0.85,
      decoration: const BoxDecoration(
        color: Color(0xFF0F172A),
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          // Drag handle
          Container(
            width: 40,
            height: 4,
            margin: const EdgeInsets.only(top: 10, bottom: 6),
            decoration: BoxDecoration(
              color: Colors.white24,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          // Top Navigation Bar
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            child: Row(
              children: [
                const Icon(Icons.language_rounded, color: Color(0xFF60A5FA), size: 22),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        _pageTitle,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 13.5,
                          fontWeight: FontWeight.w600,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        Uri.tryParse(validUrl)?.host ?? validUrl,
                        style: const TextStyle(color: Colors.white54, fontSize: 11),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                // Semantics en lugar de Tooltip: previene el fallo "No Overlay"
                Semantics(
                  label: 'Recargar',
                  child: IconButton(
                    icon: const Icon(Icons.refresh_rounded, color: Colors.white70, size: 20),
                    onPressed: () => _controller?.reload(),
                  ),
                ),
                // Semantics en lugar de Tooltip: previene el fallo "No Overlay"
                Semantics(
                  label: 'Copiar enlace',
                  child: IconButton(
                    icon: const Icon(Icons.copy_rounded, color: Colors.white70, size: 20),
                    onPressed: () {
                      Clipboard.setData(ClipboardData(text: validUrl));
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Enlace copiado al portapapeles'),
                          behavior: SnackBarBehavior.floating,
                          duration: Duration(seconds: 2),
                        ),
                      );
                    },
                  ),
                ),
                // Semantics en lugar de Tooltip: previene el fallo "No Overlay"
                Semantics(
                  label: 'Abrir en navegador',
                  child: IconButton(
                    icon: const Icon(Icons.open_in_new_rounded, color: Colors.white70, size: 20),
                    onPressed: () => launchUrl(Uri.parse(validUrl), mode: LaunchMode.externalApplication),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded, color: Colors.white70, size: 22),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
          ),
          if (_isLoading)
            LinearProgressIndicator(
              value: _progress > 0 ? _progress : null,
              backgroundColor: Colors.white10,
              color: const Color(0xFF60A5FA),
              minHeight: 2,
            ),
          // WebView body
          Expanded(
            child: ClipRRect(
              child: InAppWebView(
                initialUrlRequest: URLRequest(url: WebUri(validUrl)),
                initialSettings: InAppWebViewSettings(
                  javaScriptEnabled: true,
                  domStorageEnabled: true,
                  supportZoom: true,
                  builtInZoomControls: true,
                  displayZoomControls: false,
                ),
                onWebViewCreated: (c) => _controller = c,
                onTitleChanged: (_, t) {
                  if (t != null && t.isNotEmpty && mounted) {
                    setState(() => _pageTitle = t);
                  }
                },
                onProgressChanged: (_, p) {
                  setState(() {
                    _progress = p / 100.0;
                    _isLoading = p < 100;
                  });
                },
                onLoadStop: (_, __) => setState(() => _isLoading = false),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
