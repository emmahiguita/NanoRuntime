import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:nanoai/features/browser/presentation/widgets/browser_window_url_editor.dart';

/// Marco visual ergonómico y controles de ventana para las tarjetas del navegador Nano AI.
///
/// - QUÉ HACE: Presenta la tarjeta de pestaña en miniatura con título claro, editor de URL expandido,
///   y controles rápidos de foco/maximizar y cerrar sin sobrecargar la cabecera.
/// - CÓMO FUNCIONA: Usa [AnimatedContainer] con border slate y tirador inferior táctil de redimensión.
/// - POR QUÉ: Diseño profesional, limpio y legible en pantallas de cualquier tamaño (<140 líneas).
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
  final VoidCallback? onReload,
      onToggleMinimize,
      onToggleMaximize,
      onClose,
      onBack,
      onForward;
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
  double _userHeight = 320.0;
  double _userWidthFraction = 1.0;

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    final isLand = mq.orientation == Orientation.landscape;
    final maxLandH = (mq.size.height - 110.0).clamp(160.0, 320.0);
    final rawH = widget.isMaximized
        ? (isLand ? maxLandH : 580.0)
        : (isLand
              ? _userHeight.clamp(40.0, maxLandH)
              : _userHeight.clamp(60.0, 820.0));

    return LayoutBuilder(
      builder: (context, constraints) {
        final availableWidth = constraints.hasBoundedWidth
            ? constraints.maxWidth
            : mq.size.width;
        final targetWidth = widget.fillHeight
            ? availableWidth
            : availableWidth * _userWidthFraction;
        return Align(
          alignment: Alignment.topCenter,
          child: AnimatedContainer(
            width: targetWidth,
            duration: mq.disableAnimations
                ? Duration.zero
                : const Duration(milliseconds: 180),
            curve: Curves.easeOutCubic,
            margin: EdgeInsets.only(bottom: isLand ? 4 : 10),
            decoration: BoxDecoration(
              color: const Color(0xFA091322),
              borderRadius: BorderRadius.circular(isLand ? 12 : 16),
              border: Border.all(
                color: widget.isActive
                    ? const Color(0xFF10B981).withValues(alpha: 0.6)
                    : const Color(0xFF1E293B),
                width: 1.0,
              ),
              boxShadow: const [
                BoxShadow(
                  color: Colors.black54,
                  blurRadius: 16,
                  offset: Offset(0, 6),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(isLand ? 11 : 15),
              child: Column(
                mainAxisSize: widget.fillHeight
                    ? MainAxisSize.max
                    : MainAxisSize.min,
                children: [
                  _buildTitleBar(isLand),
                  if (widget.fillHeight)
                    Expanded(
                      child: Visibility(
                        visible: !widget.isMinimized,
                        maintainState: true,
                        child: widget.child,
                      ),
                    )
                  else ...[
                    Visibility(
                      visible: !widget.isMinimized,
                      maintainState: true,
                      child: SizedBox(
                        height: rawH.roundToDouble(),
                        child: widget.child,
                      ),
                    ),
                    if (!widget.isMinimized)
                      _buildResizeHandle(isLand, maxLandH, availableWidth),
                  ],
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildTitleBar(bool isLand) {
    return Container(
      height: isLand ? 32 : 44,
      padding: EdgeInsets.symmetric(horizontal: isLand ? 6 : 8),
      decoration: const BoxDecoration(
        color: Color(0xFF0C1625),
        border: Border(
          bottom: BorderSide(color: Color(0xFF1E293B), width: 0.8),
        ),
      ),
      child: Row(
        children: [
          if (widget.dragIndex != null && !widget.isMaximized)
            ReorderableDragStartListener(
              index: widget.dragIndex!,
              child: const Padding(
                padding: EdgeInsets.only(right: 6),
                child: Icon(
                  Icons.drag_indicator_rounded,
                  size: 16,
                  color: Color(0xFF64748B),
                ),
              ),
            ),
          Expanded(
            child: BrowserWindowUrlEditor(
              title: widget.title,
              url: widget.url,
              siteColor: widget.siteColor,
              onSubmitted: (u) => widget.onNavigate?.call(u),
            ),
          ),
          const SizedBox(width: 4),
          _FrameBtn(
            icon: widget.isMinimized
                ? Icons.keyboard_arrow_down_rounded
                : Icons.remove_rounded,
            label: widget.isMinimized ? 'Restaurar' : 'Minimizar',
            size: isLand ? 13 : 16,
            color: const Color(0xFFF59E0B),
            onTap: widget.onToggleMinimize,
          ),
          _FrameBtn(
            icon: widget.isMaximized
                ? Icons.fullscreen_exit_rounded
                : Icons.fullscreen_rounded,
            label: widget.isMaximized ? 'Restaurar' : 'Maximizar',
            size: isLand ? 14 : 17,
            color: const Color(0xFF94A3B8),
            onTap: widget.onToggleMaximize,
          ),
          _FrameBtn(
            icon: Icons.close_rounded,
            label: 'Cerrar',
            size: isLand ? 13 : 16,
            color: const Color(0xFF94A3B8),
            onTap: widget.onClose,
          ),
        ],
      ),
    );
  }

  Widget _buildResizeHandle(
    bool isLand,
    double maxLandH,
    double availableWidth,
  ) => GestureDetector(
    behavior: HitTestBehavior.opaque,
    onDoubleTap: () {
      HapticFeedback.mediumImpact();
      setState(() {
        final compact = _userHeight <= 160.0 || _userWidthFraction < 0.75;
        _userHeight = compact ? 460.0 : 140.0;
        _userWidthFraction = compact ? 1.0 : 0.62;
      });
    },
    onPanUpdate: (d) => setState(() {
      final minH = isLand ? 40.0 : 60.0;
      final maxH = isLand ? maxLandH : 820.0;
      final minWidthFraction = isLand ? 0.4 : 0.48;
      _userHeight = (_userHeight + d.delta.dy)
          .clamp(minH, maxH)
          .roundToDouble();
      _userWidthFraction = (_userWidthFraction + d.delta.dx / availableWidth)
          .clamp(minWidthFraction, 1.0)
          .toDouble();
    }),
    child: Container(
      height: isLand ? 14 : 18,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: const Color(0xFF0B1728),
        border: Border(
          top: BorderSide(
            color: widget.siteColor.withValues(alpha: 0.2),
            width: 0.8,
          ),
        ),
      ),
      child: Row(
        children: [
          const Spacer(),
          Container(
            width: isLand ? 36 : 44,
            height: 3.5,
            decoration: BoxDecoration(
              color: widget.siteColor.withValues(alpha: 0.8),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const Spacer(),
          Icon(
            Icons.drag_handle_rounded,
            size: isLand ? 13 : 15,
            color: const Color(0xFF64748B),
          ),
          const SizedBox(width: 5),
        ],
      ),
    ),
  );
}

class _FrameBtn extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  final double size;
  final Color? color;

  const _FrameBtn({
    required this.icon,
    required this.label,
    required this.onTap,
    this.size = 14,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final isLand = MediaQuery.of(context).orientation == Orientation.landscape;
    final isInteractive = onTap != null;
    return Semantics(
      label: label,
      button: true,
      child: InkWell(
        onTap: isInteractive
            ? () {
                HapticFeedback.lightImpact();
                onTap!();
              }
            : null,
        borderRadius: BorderRadius.circular(6),
        child: Container(
          width: isLand ? 24.0 : 28.0,
          height: isLand ? 24.0 : 28.0,
          margin: const EdgeInsets.symmetric(horizontal: 1),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: isInteractive ? 0.06 : 0.02),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Icon(
            icon,
            size: size,
            color: color ?? const Color(0xFFCBD5E1),
          ),
        ),
      ),
    );
  }
}
