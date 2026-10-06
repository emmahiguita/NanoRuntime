import 'package:flutter/material.dart';
import 'browser_window_card_header.dart';
import 'browser_window_controls.dart';
import 'browser_window_resize_handle.dart';

/// Marco Material de ventana. Conserva el hijo nativo al minimizarlo.
/// Separa cabecera y redimensión; no aplica sombras o desenfoques a cada WebView.
class BrowserWindowCardFrame extends StatefulWidget {
  final String title, url;
  final Color siteColor;
  final bool isMaximized,
      isMinimized,
      isActive,
      fillHeight,
      canGoBack,
      canGoForward;
  final Widget child;
  final VoidCallback? onReload, onToggleMinimize, onToggleMaximize, onClose;
  final VoidCallback? onBack, onForward;
  final ValueChanged<String>? onNavigate;
  final int? dragIndex;
  const BrowserWindowCardFrame({
    super.key,
    required this.title,
    required this.url,
    required this.siteColor,
    required this.child,
    this.isMaximized = false,
    this.isMinimized = false,
    this.isActive = false,
    this.fillHeight = false,
    this.canGoBack = true,
    this.canGoForward = false,
    this.onReload,
    this.onToggleMinimize,
    this.onToggleMaximize,
    this.onClose,
    this.onBack,
    this.onForward,
    this.onNavigate,
    this.dragIndex,
  });

  @override
  State<BrowserWindowCardFrame> createState() => _BrowserWindowCardFrameState();
}

class _BrowserWindowCardFrameState extends State<BrowserWindowCardFrame> {
  double _height = 320, _widthFraction = 1;
  bool _dragging = false;

  /// Un ancho mínimo útil evita que la URL y las acciones queden inutilizables.
  /// Durante el arrastre no acumula animaciones detrás del dedo.
  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final size = MediaQuery.sizeOf(context);
    final landscape = size.width > size.height;
    final maxHeight = landscape
        ? (size.height - 110).clamp(120.0, 320.0)
        : 820.0;
    final height = widget.isMaximized
        ? (landscape ? maxHeight : 580.0)
        : _height.clamp(120.0, maxHeight).toDouble();
    return LayoutBuilder(
      builder: (context, constraints) {
        final available = constraints.hasBoundedWidth
            ? constraints.maxWidth
            : size.width;
        if (available <= 0) return const SizedBox.shrink();
        final minWidth = 320.0.clamp(0.0, available);
        final width = widget.fillHeight
            ? available
            : (available * _widthFraction).clamp(minWidth, available);
        final content = Visibility(
          visible: !widget.isMinimized,
          maintainState: true,
          child: widget.child,
        );
        return Align(
          alignment: Alignment.topCenter,
          child: AnimatedContainer(
            width: width,
            margin: const EdgeInsets.only(bottom: 8),
            duration: _dragging || MediaQuery.disableAnimationsOf(context)
                ? Duration.zero
                : const Duration(milliseconds: 120),
            decoration: BoxDecoration(
              color: colors.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: widget.isActive ? colors.primary : colors.outlineVariant,
              ),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(11),
              child: Material(
                color: colors.surface,
                child: Column(
                  mainAxisSize: widget.fillHeight
                      ? MainAxisSize.max
                      : MainAxisSize.min,
                  children: [
                    BrowserWindowCardHeader(
                      title: widget.title,
                      url: widget.url,
                      onNavigate: widget.onNavigate,
                      dragIndex: widget.dragIndex,
                      maximized: widget.isMaximized,
                      controls: BrowserWindowControls(
                        onBack: widget.onBack,
                        onForward: widget.onForward,
                        onReload: widget.onReload,
                        canGoBack: widget.canGoBack,
                        canGoForward: widget.canGoForward,
                        onMinimize: widget.onToggleMinimize,
                        minimized: widget.isMinimized,
                        onMaximize: widget.onToggleMaximize,
                        maximized: widget.isMaximized,
                        onClose: widget.onClose,
                      ),
                    ),
                    if (widget.fillHeight)
                      Expanded(child: content)
                    else ...[
                      SizedBox(
                        height: widget.isMinimized ? 0 : height.toDouble(),
                        child: content,
                      ),
                      if (!widget.isMinimized)
                        BrowserWindowResizeHandle(
                          onDragging: (value) =>
                              setState(() => _dragging = value),
                          onToggleSize: () => setState(() {
                            final compact =
                                _height <= 160 || _widthFraction < 0.75;
                            _height = compact ? 460 : 140;
                            _widthFraction = compact ? 1 : 0.62;
                          }),
                          onDelta: (delta) => setState(() {
                            _height = (_height + delta.dy).clamp(
                              120.0,
                              maxHeight,
                            );
                            _widthFraction =
                                (_widthFraction + delta.dx / available)
                                    .clamp(minWidth / available, 1.0)
                                    .toDouble();
                          }),
                        ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
