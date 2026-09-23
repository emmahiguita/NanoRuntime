import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';

/// [FloatingVideoController]
/// Administra el ciclo de vida del reproductor de video en ventana flotante (PiP).
class FloatingVideoController {
  static final FloatingVideoController instance = FloatingVideoController._();
  FloatingVideoController._();

  OverlayEntry? _entry;
  String? _currentUrl;
  String? _currentTitle;
  String? _currentYouTubeId;

  bool get isPlaying => _entry != null;
  String? get currentUrl => _currentUrl;
  String? get currentTitle => _currentTitle;
  String? get currentYouTubeId => _currentYouTubeId;

  /// Abre o actualiza la ventana flotante de video.
  void show(
    BuildContext context, {
    required String videoUrl,
    String? title,
    String? youTubeId,
  }) {
    _currentUrl = videoUrl;
    _currentTitle = title ?? 'Reproduciendo Video';
    _currentYouTubeId = youTubeId;

    if (_entry != null) {
      _entry!.markNeedsBuild();
      return;
    }

    final overlayState = Overlay.maybeOf(context, rootOverlay: true);
    if (overlayState == null) return;

    _entry = OverlayEntry(
      builder: (ctx) => _FloatingVideoOverlayWidget(
        videoUrl: _currentUrl!,
        title: _currentTitle!,
        youTubeId: _currentYouTubeId,
        onClose: hide,
      ),
    );

    overlayState.insert(_entry!);
  }

  /// Cierra la ventana flotante.
  void hide() {
    _entry?.remove();
    _entry = null;
    _currentUrl = null;
    _currentTitle = null;
    _currentYouTubeId = null;
  }
}

class _FloatingVideoOverlayWidget extends StatefulWidget {
  final String videoUrl;
  final String title;
  final String? youTubeId;
  final VoidCallback onClose;

  const _FloatingVideoOverlayWidget({
    required this.videoUrl,
    required this.title,
    this.youTubeId,
    required this.onClose,
  });

  @override
  State<_FloatingVideoOverlayWidget> createState() => _FloatingVideoOverlayWidgetState();
}

class _FloatingVideoOverlayWidgetState extends State<_FloatingVideoOverlayWidget> {
  Offset _pos = const Offset(20, 100);
  bool _isMinimized = false;

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    final width = _isMinimized ? 220.0 : 300.0;
    final height = _isMinimized ? 140.0 : 210.0;

    // Clamping para que no se salga de la pantalla
    final maxLeft = (mediaQuery.size.width - width - 10).clamp(0.0, double.infinity);
    final maxTop = (mediaQuery.size.height - height - mediaQuery.padding.bottom - 10).clamp(0.0, double.infinity);
    final left = _pos.dx.clamp(10.0, maxLeft);
    final top = _pos.dy.clamp(mediaQuery.padding.top + 10.0, maxTop);

    final isYT = widget.youTubeId != null && widget.youTubeId!.isNotEmpty;
    final initialUrl = isYT
        ? WebUri('https://www.youtube-nocookie.com/embed/${widget.youTubeId}?autoplay=1&playsinline=1&rel=0')
        : (widget.videoUrl.startsWith('http') ? WebUri(widget.videoUrl) : null);

    return Positioned(
      left: left,
      top: top,
      child: Material(
        color: Colors.transparent,
        child: Container(
          width: width,
          height: height,
          decoration: BoxDecoration(
            color: const Color(0xFF0F172A),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFF00FF88).withValues(alpha: 0.5), width: 1.2),
            boxShadow: [
              BoxShadow(color: Colors.black.withValues(alpha: 0.65), blurRadius: 16, offset: const Offset(0, 6)),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(13),
            child: Column(
              children: [
                // Barra de arrastre y control superior
                GestureDetector(
                  onPanUpdate: (details) {
                    setState(() {
                      _pos = Offset(_pos.dx + details.delta.dx, _pos.dy + details.delta.dy);
                    });
                  },
                  child: Container(
                    height: 34,
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    color: const Color(0xFF1E293B),
                    child: Row(
                      children: [
                        const Icon(Icons.drag_indicator_rounded, color: Colors.white54, size: 16),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            widget.title,
                            style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        InkWell(
                          onTap: () => setState(() => _isMinimized = !_isMinimized),
                          child: Padding(
                            padding: const EdgeInsets.all(4),
                            child: Icon(
                              _isMinimized ? Icons.aspect_ratio_rounded : Icons.minimize_rounded,
                              color: Colors.white70,
                              size: 15,
                            ),
                          ),
                        ),
                        InkWell(
                          onTap: widget.onClose,
                          child: const Padding(
                            padding: EdgeInsets.all(4),
                            child: Icon(Icons.close_rounded, color: Colors.white70, size: 15),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                // Contenido del video
                Expanded(
                  child: initialUrl != null
                      ? InAppWebView(
                          initialUrlRequest: URLRequest(url: initialUrl),
                          initialSettings: InAppWebViewSettings(
                            allowsInlineMediaPlayback: true,
                            mediaPlaybackRequiresUserGesture: false,
                            useHybridComposition: true,
                            hardwareAcceleration: true,
                            transparentBackground: false,
                          ),
                        )
                      : Container(
                          color: Colors.black,
                          child: const Center(
                            child: Text(
                              'Archivo local de video',
                              style: TextStyle(color: Colors.white70, fontSize: 12),
                            ),
                          ),
                        ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
