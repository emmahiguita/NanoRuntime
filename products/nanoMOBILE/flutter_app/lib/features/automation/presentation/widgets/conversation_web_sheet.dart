// conversation_web_sheet.dart
//
// QUÉ HACE:
// Modal interactivo para navegación web in-app con diseño iOS Frosted Glass.
//
// CÓMO FUNCIONA:
// - Renderiza InAppWebView con barra de herramientas superior (recargar, copiar enlace, abrir en navegador externo).
// - Proporciona indicador de progreso lineal y extracción reactiva del título de página.
// - Utiliza Semantics en botones de acción para prevenir fallos visuales de "No Overlay".
//
// POR QUÉ:
// Mantiene el código desacoplado y respeta la regla de < 200 líneas por archivo.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:url_launcher/url_launcher.dart';

class WebBrowserSheet extends StatefulWidget {
  final String url;
  final String? title;

  const WebBrowserSheet({super.key, required this.url, this.title});

  @override
  State<WebBrowserSheet> createState() => _WebBrowserSheetState();
}

class _WebBrowserSheetState extends State<WebBrowserSheet> {
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
    final isLandscape = MediaQuery.of(context).orientation == Orientation.landscape;
    final size = MediaQuery.of(context).size;
    final validUrl = widget.url.startsWith('http://') || widget.url.startsWith('https://')
        ? widget.url
        : 'https://${widget.url}';

    return Container(
      height: isLandscape ? size.height * 0.96 : size.height * 0.85,
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
                const Icon(Icons.language_rounded, color: Color(0xFF60A5FA), size: 20),
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
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        Uri.tryParse(validUrl)?.host ?? validUrl,
                        style: const TextStyle(color: Colors.white54, fontSize: 10.5),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                Semantics(
                  label: 'Recargar',
                  child: IconButton(
                    icon: const Icon(Icons.refresh_rounded, color: Colors.white70, size: 18),
                    onPressed: () => _controller?.reload(),
                  ),
                ),
                Semantics(
                  label: 'Copiar enlace',
                  child: IconButton(
                    icon: const Icon(Icons.copy_rounded, color: Colors.white70, size: 18),
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
                Semantics(
                  label: 'Abrir en navegador',
                  child: IconButton(
                    icon: const Icon(Icons.open_in_new_rounded, color: Colors.white70, size: 18),
                    onPressed: () => launchUrl(Uri.parse(validUrl), mode: LaunchMode.externalApplication),
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
              color: const Color(0xFF60A5FA),
              minHeight: 2,
            ),
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
