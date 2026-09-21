import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:nanoai/features/browser/presentation/widgets/browser_site_theme.dart';

/// Marco visual y controles de ventana para una instancia de navegador.
/// 
/// - ¿Qué hace?: Contenedor de tarjeta flotante con bordes redondeados, sombra luminosa,
///   cabecera con favicon, título, URL con punto, controles [Recargar, —, ▢, ✕] y tirador táctil.
/// - ¿Cómo funciona?: Mantiene `_userHeight` y gestiona arrastre y doble toque para redimensionar.
/// - ¿Por qué?: Separa la responsabilidad visual del marco (SRP) de los motores de `InAppWebView`.
class BrowserWindowCardFrame extends StatefulWidget {
  final String title, url;
  final Color siteColor;
  final bool isMaximized, isMinimized, isActive, fillHeight;
  final Widget child;
  final VoidCallback? onReload, onToggleMinimize, onToggleMaximize, onClose, onTitleTap, onAskOwl, onBack, onForward;

  const BrowserWindowCardFrame({
    super.key, required this.title, required this.url, required this.siteColor, required this.child,
    this.isMaximized = false, this.isMinimized = false, this.isActive = false, this.fillHeight = false,
    this.onReload, this.onToggleMinimize, this.onToggleMaximize, this.onClose, this.onTitleTap, this.onAskOwl,
    this.onBack, this.onForward,
  });

  @override
  State<BrowserWindowCardFrame> createState() => _BrowserWindowCardFrameState();
}

class _BrowserWindowCardFrameState extends State<BrowserWindowCardFrame> {
  double _userHeight = 110.0;

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    final isLand = mq.orientation == Orientation.landscape;
    final maxLandH = (mq.size.height - 110.0).clamp(160.0, 300.0);
    final rawH = widget.isMaximized
        ? (isLand ? maxLandH : 560.0)
        : (isLand ? _userHeight.clamp(28.0, maxLandH) : _userHeight.clamp(36.0, 820.0));

    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOutCubic,
      margin: EdgeInsets.only(bottom: isLand ? 4 : 8),
      decoration: BoxDecoration(
        color: const Color(0xCC091322),
        borderRadius: BorderRadius.circular(isLand ? 12 : 18),
        border: Border.all(
          color: widget.isActive ? widget.siteColor.withValues(alpha: 0.8) : Colors.white.withValues(alpha: 0.14),
          width: widget.isActive ? 1.4 : 1.0,
        ),
        boxShadow: [
          BoxShadow(color: widget.siteColor.withValues(alpha: widget.isActive ? 0.28 : 0.08), blurRadius: widget.isActive ? 16 : 8, offset: const Offset(0, 4)),
          BoxShadow(color: Colors.black.withValues(alpha: 0.40), blurRadius: 18, offset: const Offset(0, 6)),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(isLand ? 11 : 17),
        child: Column(
          mainAxisSize: widget.fillHeight ? MainAxisSize.max : MainAxisSize.min,
          children: [
            _buildTitleBar(isLand, mq.size.height),
            if (widget.fillHeight)
              Expanded(child: Visibility(visible: !widget.isMinimized, maintainState: true, maintainAnimation: true, child: widget.child))
            else ...[
              Visibility(visible: !widget.isMinimized, maintainState: true, maintainAnimation: true, child: SizedBox(height: rawH.roundToDouble(), child: widget.child)),
              if (!widget.isMinimized) _buildResizeHandle(isLand, maxLandH),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildTitleBar(bool isLand, double screenH) {
    return Container(
      height: isLand ? 26 : 40,
      padding: EdgeInsets.symmetric(horizontal: isLand ? 6 : 10),
      decoration: BoxDecoration(
        color: const Color(0x660F172A),
        border: Border(bottom: BorderSide(color: Colors.white.withValues(alpha: 0.08), width: 0.7)),
      ),
      child: Row(
        children: [
          Expanded(
            child: InkWell(
              onTap: widget.onTitleTap,
              borderRadius: BorderRadius.circular(8),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 2),
                child: Row(
                  children: [
                    BrowserSiteTheme.buildFavicon(widget.url, siteColor: widget.siteColor, size: isLand ? 16 : 20),
                    SizedBox(width: isLand ? 5 : 8),
                    Expanded(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.title.isNotEmpty ? widget.title : 'Navegador',
                            maxLines: 1, overflow: TextOverflow.ellipsis,
                            style: TextStyle(fontSize: isLand ? 10.5 : 11.5, height: 1.15, fontWeight: FontWeight.bold, color: Colors.white),
                          ),
                          if (!isLand || screenH > 340) ...[
                            const SizedBox(height: 1),
                            Row(children: [
                              Container(width: 3.5, height: 3.5, decoration: BoxDecoration(shape: BoxShape.circle, color: widget.siteColor)),
                              const SizedBox(width: 4),
                              Expanded(
                                child: Text(
                                  widget.url, maxLines: 1, overflow: TextOverflow.ellipsis,
                                  style: TextStyle(fontSize: isLand ? 8.5 : 9.5, height: 1.15, color: const Color(0xFF94A3B8)),
                                ),
                              ),
                            ]),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          if (widget.onBack != null) _FrameBtn(icon: Icons.chevron_left_rounded, size: isLand ? 13 : 16, onTap: widget.onBack),
          if (widget.onForward != null) _FrameBtn(icon: Icons.chevron_right_rounded, size: isLand ? 13 : 16, onTap: widget.onForward),
          _FrameBtn(icon: Icons.refresh_rounded, size: isLand ? 11 : 13, onTap: widget.onReload),
          if (widget.onAskOwl != null)
            _FrameBtn(icon: Icons.auto_awesome_rounded, color: const Color(0xFF10B981), size: isLand ? 11 : 13, onTap: widget.onAskOwl),
          _FrameBtn(icon: widget.isMinimized ? Icons.keyboard_arrow_down_rounded : Icons.remove_rounded, size: isLand ? 11 : 13, onTap: widget.onToggleMinimize),
          _FrameBtn(icon: widget.isMaximized ? Icons.filter_none_rounded : Icons.check_box_outline_blank_rounded, size: isLand ? 10 : 12, onTap: widget.onToggleMaximize),
          _FrameBtn(icon: Icons.close_rounded, size: isLand ? 11 : 13, onTap: widget.onClose),
        ],
      ),
    );
  }

  Widget _buildResizeHandle(bool isLand, double maxLandH) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onDoubleTap: () {
        HapticFeedback.mediumImpact();
        setState(() => _userHeight = _userHeight <= 45.0 ? 150.0 : 36.0);
      },
      onVerticalDragUpdate: (d) => setState(() {
        final minH = isLand ? 28.0 : 36.0;
        final maxH = isLand ? maxLandH : 820.0;
        _userHeight = (_userHeight + d.delta.dy).clamp(minH, maxH).roundToDouble();
      }),
      child: Container(
        height: isLand ? 9 : 14,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: const Color(0xFF0B1728),
          border: Border(top: BorderSide(color: widget.siteColor.withValues(alpha: 0.25), width: 0.8)),
        ),
        child: Container(
          width: isLand ? 24 : 34, height: isLand ? 2 : 3,
          decoration: BoxDecoration(
            color: widget.siteColor.withValues(alpha: 0.8),
            borderRadius: BorderRadius.circular(2),
            boxShadow: [BoxShadow(color: widget.siteColor.withValues(alpha: 0.35), blurRadius: 4)],
          ),
        ),
      ),
    );
  }
}

class _FrameBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onTap;
  final double size;
  final Color? color;
  const _FrameBtn({required this.icon, required this.onTap, this.size = 14, this.color});

  @override
  Widget build(BuildContext context) {
    final isLand = MediaQuery.of(context).orientation == Orientation.landscape;
    return InkWell(
      onTap: onTap != null ? () { HapticFeedback.lightImpact(); onTap!(); } : null,
      borderRadius: BorderRadius.circular(6),
      child: Container(
        width: isLand ? 19.0 : 24.0, height: isLand ? 19.0 : 24.0,
        decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(6)),
        child: Icon(icon, size: size, color: color ?? const Color(0xFFCBD5E1)),
      ),
    );
  }
}
