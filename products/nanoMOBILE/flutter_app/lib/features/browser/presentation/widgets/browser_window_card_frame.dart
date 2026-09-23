import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:nanoai/features/browser/presentation/widgets/browser_window_url_editor.dart';

/// QUÉ HACE:
/// Marco visual ergonómico y controles de ventana para el navegador Nano AI.
/// 
/// CÓMO FUNCIONA:
/// 1. Cabecera con editor de URL, navegación directa y profesional Atrás/Adelante,
///    menú contextual de opciones (Recargar, Búho IA) y controles de ventana (minimizar, maximizar, cerrar).
/// 2. Sin botones muertos: elimina botones innecesarios (zoom aA se realiza por pellizco con 2 dedos
///    y se remueve el alternador ambiguo de scroll).
/// 3. Tirador táctil inferior de redimensión ergonómico para ajustar la altura libremente con drag.
/// 
/// POR QUÉ:
/// Cumple con las exigencias del usuario de ergonomía móvil, estética Material Expressive 3
/// sin saturación y código limpio menor a 180 líneas.
class BrowserWindowCardFrame extends StatefulWidget {
  final String title, url;
  final Color siteColor;
  final bool isMaximized, isMinimized, isActive, fillHeight, canGoBack, canGoForward;
  final Widget child;
  final VoidCallback? onReload, onToggleMinimize, onToggleMaximize, onClose, onAskOwl, onBack, onForward;
  final ValueChanged<String>? onNavigate;
  final int? dragIndex;

  const BrowserWindowCardFrame({
    super.key, required this.title, required this.url, required this.siteColor, required this.child,
    this.isMaximized = false, this.isMinimized = false, this.isActive = false, this.fillHeight = false,
    this.canGoBack = true, this.canGoForward = false, this.onReload, this.onToggleMinimize,
    this.onToggleMaximize, this.onClose, this.onAskOwl, this.onBack, this.onForward, this.onNavigate, this.dragIndex,
  });

  @override
  State<BrowserWindowCardFrame> createState() => _BrowserWindowCardFrameState();
}

class _BrowserWindowCardFrameState extends State<BrowserWindowCardFrame> {
  double _userHeight = 280.0;

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    final isLand = mq.orientation == Orientation.landscape;
    final maxLandH = (mq.size.height - 110.0).clamp(160.0, 320.0);
    final rawH = widget.isMaximized
        ? (isLand ? maxLandH : 580.0)
        : (isLand ? _userHeight.clamp(40.0, maxLandH) : _userHeight.clamp(60.0, 820.0));

    return AnimatedContainer(
      duration: mq.disableAnimations ? Duration.zero : const Duration(milliseconds: 200), curve: Curves.easeOutCubic,
      margin: EdgeInsets.only(bottom: isLand ? 4 : 8),
      decoration: BoxDecoration(
        color: const Color(0xEE091322), borderRadius: BorderRadius.circular(isLand ? 12 : 18),
        border: Border.all(color: widget.isActive ? widget.siteColor.withValues(alpha: 0.8) : Colors.white.withValues(alpha: 0.14), width: widget.isActive ? 1.4 : 1.0),
        boxShadow: [
          BoxShadow(color: widget.siteColor.withValues(alpha: widget.isActive ? 0.25 : 0.06), blurRadius: widget.isActive ? 14 : 6, offset: const Offset(0, 3)),
          BoxShadow(color: Colors.black.withValues(alpha: 0.45), blurRadius: 16, offset: const Offset(0, 5)),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(isLand ? 11 : 17),
        child: Column(mainAxisSize: widget.fillHeight ? MainAxisSize.max : MainAxisSize.min, children: [
          _buildTitleBar(isLand),
          if (widget.fillHeight)
            Expanded(child: Visibility(visible: !widget.isMinimized, maintainState: true, child: widget.child))
          else ...[
            Visibility(visible: !widget.isMinimized, maintainState: true, child: SizedBox(height: rawH.roundToDouble(), child: widget.child)),
            if (!widget.isMinimized) _buildResizeHandle(isLand, maxLandH),
          ],
        ]),
      ),
    );
  }

  Widget _buildTitleBar(bool isLand) {
    final titleContent = Expanded(
      child: BrowserWindowUrlEditor(title: widget.title, url: widget.url, siteColor: widget.siteColor, onSubmitted: (u) => widget.onNavigate?.call(u)),
    );

    // Expanded debe ser hijo directo de Row; el tirador ya gestiona el drag.

    return Container(
      height: isLand ? 30 : 44, padding: EdgeInsets.symmetric(horizontal: isLand ? 6 : 8),
      decoration: BoxDecoration(color: const Color(0x990F172A), border: Border(bottom: BorderSide(color: Colors.white.withValues(alpha: 0.08), width: 0.7))),
      child: Row(children: [
        if (widget.dragIndex != null && !widget.isMaximized)
          ReorderableDragStartListener(
            index: widget.dragIndex!,
            child: Padding(
              padding: const EdgeInsets.only(right: 4),
              child: Icon(Icons.drag_indicator_rounded, size: isLand ? 14 : 16, color: const Color(0xFF64748B)),
            ),
          ),
        titleContent,
        const SizedBox(width: 4),
        // Navegación profesional Atrás y Adelante directamente en la barra
        _FrameBtn(
          icon: Icons.chevron_left_rounded, label: 'Atrás', size: isLand ? 16 : 19,
          color: widget.canGoBack ? const Color(0xFF38BDF8) : const Color(0xFF475569),
          onTap: widget.canGoBack ? widget.onBack : null,
        ),
        _FrameBtn(
          icon: Icons.chevron_right_rounded, label: 'Adelante', size: isLand ? 16 : 19,
          color: widget.canGoForward ? const Color(0xFF38BDF8) : const Color(0xFF475569),
          onTap: widget.canGoForward ? widget.onForward : null,
        ),
        _buildOptionsMenu(isLand),
        _FrameBtn(icon: widget.isMinimized ? Icons.keyboard_arrow_down_rounded : Icons.remove_rounded, label: 'Minimizar', size: isLand ? 11 : 13, onTap: widget.onToggleMinimize),
        _FrameBtn(icon: widget.isMaximized ? Icons.filter_none_rounded : Icons.check_box_outline_blank_rounded, label: 'Maximizar', size: isLand ? 10 : 12, onTap: widget.onToggleMaximize),
        _FrameBtn(icon: Icons.close_rounded, label: 'Cerrar', size: isLand ? 11 : 13, onTap: widget.onClose),
      ]),
    );
  }

  Widget _buildOptionsMenu(bool isLand) => PopupMenuButton<String>(
    tooltip: 'Opciones', icon: Icon(Icons.more_vert_rounded, size: isLand ? 13 : 15, color: const Color(0xFFCBD5E1)),
    color: const Color(0xFF0F172A), elevation: 8, padding: EdgeInsets.zero,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10), side: BorderSide(color: Colors.white.withValues(alpha: 0.12))),
    onSelected: (v) {
      if (v == 'reload') widget.onReload?.call();
      if (v == 'owl') widget.onAskOwl?.call();
    },
    itemBuilder: (_) => [
      const PopupMenuItem(value: 'reload', height: 36, child: Row(children: [Icon(Icons.refresh_rounded, size: 15, color: Color(0xFF94A3B8)), SizedBox(width: 8), Text('Recargar', style: TextStyle(color: Colors.white, fontSize: 12))])),
      if (widget.onAskOwl != null) const PopupMenuItem(value: 'owl', height: 36, child: Row(children: [Icon(Icons.auto_awesome_rounded, size: 15, color: Color(0xFF10B981)), SizedBox(width: 8), Text('Búho IA', style: TextStyle(color: Color(0xFF10B981), fontSize: 12, fontWeight: FontWeight.bold))])),
    ],
  );

  /// Tirador táctil ergonómico para ajustar altura de ventana con drag libre
  Widget _buildResizeHandle(bool isLand, double maxLandH) => GestureDetector(
    behavior: HitTestBehavior.opaque,
    onDoubleTap: () { HapticFeedback.mediumImpact(); setState(() => _userHeight = _userHeight <= 140.0 ? 420.0 : 120.0); },
    onVerticalDragUpdate: (d) => setState(() {
      final minH = isLand ? 40.0 : 60.0, maxH = isLand ? maxLandH : 820.0;
      _userHeight = (_userHeight + d.delta.dy).clamp(minH, maxH).roundToDouble();
    }),
    child: Container(
      height: isLand ? 14 : 20, alignment: Alignment.center,
      decoration: BoxDecoration(
        color: const Color(0xFF0B1728),
        border: Border(top: BorderSide(color: widget.siteColor.withValues(alpha: 0.22), width: 0.8)),
      ),
      child: Container(
        width: isLand ? 36 : 48, height: isLand ? 3 : 4,
        decoration: BoxDecoration(
          color: widget.siteColor.withValues(alpha: 0.9), borderRadius: BorderRadius.circular(2),
          boxShadow: [BoxShadow(color: widget.siteColor.withValues(alpha: 0.4), blurRadius: 4)],
        ),
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
  const _FrameBtn({required this.icon, required this.label, required this.onTap, this.size = 14, this.color});

  @override
  Widget build(BuildContext context) {
    final isLand = MediaQuery.of(context).orientation == Orientation.landscape;
    final isInteractive = onTap != null;
    return Semantics(
      label: label, button: true,
      child: InkWell(
        onTap: isInteractive ? () { HapticFeedback.lightImpact(); onTap!(); } : null,
        borderRadius: BorderRadius.circular(6),
        child: Container(
          width: isLand ? 20.0 : 26.0, height: isLand ? 20.0 : 26.0, margin: const EdgeInsets.symmetric(horizontal: 1),
          decoration: BoxDecoration(color: Colors.white.withValues(alpha: isInteractive ? 0.08 : 0.03), borderRadius: BorderRadius.circular(6)),
          child: Icon(icon, size: size, color: color ?? const Color(0xFFCBD5E1)),
        ),
      ),
    );
  }
}
