import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:nanoai/features/browser/domain/browser_tab_model.dart';
import 'package:nanoai/features/browser/presentation/widgets/browser_owl_assistant_sheet.dart';
import 'package:nanoai/features/browser/presentation/widgets/browser_zoom_sheet.dart';

/// Barra superior de navegación y controles ergonómicos de la ventana del navegador.
/// 
/// - QUÉ HACE: Presenta la barra de navegación web con controles integrales de ventana:
///   Minimizar a stack/tarjeta, Cargar/Recargar URL, Ampliar a pantalla completa y Cerrar pestaña.
/// - CÓMO FUNCIONA: Dispone botones con [Semantics] táctiles inmunes a errores 'No Overlay',
///   conectados a los métodos de ciclo de vida del WebView y del gestor de pestañas.
/// - POR QUÉ: Aplica SOLID (SRP) centralizando los 4 controles fundamentales de ventana sin
///   inventar lógica ni superar el umbral estricto de 200 líneas.
class BrowserWindowTopBar extends StatelessWidget {
  final BrowserTabModel activeTab;
  final int tabCount;
  final bool isVerticalStackMode, isCarouselMode;
  final double currentZoom;
  final InAppWebViewController? controller;
  final VoidCallback onBack, onReload, onToggleStackMode, onToggleCarouselMode, onOpenOptionsMenu, onUrlTap;
  final VoidCallback? onMinimize, onMaximize, onClose;
  final ValueChanged<double> onZoomChanged;

  const BrowserWindowTopBar({
    super.key,
    required this.activeTab,
    required this.tabCount,
    required this.isVerticalStackMode,
    required this.isCarouselMode,
    required this.currentZoom,
    required this.controller,
    required this.onBack,
    required this.onReload,
    required this.onToggleStackMode,
    required this.onToggleCarouselMode,
    required this.onOpenOptionsMenu,
    required this.onUrlTap,
    required this.onZoomChanged,
    this.onMinimize,
    this.onMaximize,
    this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    final isLand = MediaQuery.of(context).orientation == Orientation.landscape;
    return Container(
      padding: EdgeInsets.symmetric(horizontal: isLand ? 4 : 6, vertical: isLand ? 1 : 4),
      decoration: const BoxDecoration(
        color: Color(0xFF08121E),
        border: Border(bottom: BorderSide(color: Color(0xFF1E293B), width: 1.0)),
      ),
      child: Row(
        children: [
          IconButton(
            icon: Icon(Icons.arrow_back_rounded, color: const Color(0xFF94A3B8), size: isLand ? 15 : 18),
            padding: EdgeInsets.zero,
            constraints: BoxConstraints(minWidth: isLand ? 22 : 28, minHeight: isLand ? 22 : 28),
            onPressed: onBack,
          ),
          SizedBox(width: isLand ? 2 : 3),
          Expanded(child: _buildUrlBar(context, isLand)),
          SizedBox(width: isLand ? 2 : 4),
          _buildTabCounter(isLand),
          if (onMinimize != null)
            _TopBarActionBtn(icon: Icons.remove_rounded, label: 'Minimizar ventana', color: const Color(0xFFF59E0B), size: isLand ? 14 : 17, onTap: onMinimize!),
          if (onMaximize != null)
            _TopBarActionBtn(icon: Icons.fullscreen_rounded, label: 'Ampliar ventana', color: const Color(0xFF38BDF8), size: isLand ? 14 : 17, onTap: onMaximize!),
          if (onClose != null)
            _TopBarActionBtn(icon: Icons.close_rounded, label: 'Cerrar ventana', color: const Color(0xFFEF4444), size: isLand ? 14 : 17, onTap: onClose!),
          _TopBarActionBtn(icon: Icons.view_in_ar_rounded, label: 'Carrusel 3D', color: isCarouselMode ? const Color(0xFF10B981) : const Color(0xFF94A3B8), size: isLand ? 14 : 17, onTap: onToggleCarouselMode),
          _TopBarActionBtn(icon: Icons.auto_awesome_rounded, label: 'Búho IA', color: const Color(0xFF10B981), size: 18, onTap: () => BrowserOwlAssistantSheet.show(context, tab: activeTab, controller: controller)),
          _TopBarActionBtn(icon: Icons.more_vert_rounded, label: 'Opciones', color: const Color(0xFF94A3B8), size: isLand ? 14 : 17, onTap: onOpenOptionsMenu),
        ],
      ),
    );
  }

  Widget _buildUrlBar(BuildContext context, bool isLand) {
    return Container(
      height: isLand ? 26 : 34,
      padding: EdgeInsets.symmetric(horizontal: isLand ? 6 : 8),
      decoration: BoxDecoration(
        color: const Color(0xFF0F1E24),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFF059669).withValues(alpha: 0.6), width: 1.0),
      ),
      child: Row(
        children: [
          Icon(Icons.lock_rounded, color: const Color(0xFF10B981), size: isLand ? 11 : 14),
          SizedBox(width: isLand ? 3 : 6),
          Expanded(
            child: InkWell(
              onTap: onUrlTap,
              child: Text(
                activeTab.url.isEmpty ? 'Buscar o escribir URL' : activeTab.url,
                maxLines: 1, overflow: TextOverflow.ellipsis,
                style: TextStyle(color: const Color(0xFFE2E8F0), fontSize: isLand ? 10.5 : 12.0, fontWeight: FontWeight.w500),
              ),
            ),
          ),
          GestureDetector(
            onTap: () => BrowserZoomSheet.show(context: context, tab: activeTab, currentZoom: currentZoom, controller: controller, onZoomChanged: onZoomChanged),
            child: Container(
              padding: EdgeInsets.symmetric(horizontal: isLand ? 3 : 5, vertical: 1),
              decoration: BoxDecoration(color: const Color(0xFF1E293B), borderRadius: BorderRadius.circular(8)),
              child: Text('aA', style: TextStyle(color: const Color(0xFFCBD5E1), fontSize: isLand ? 8.5 : 10.5, fontWeight: FontWeight.bold)),
            ),
          ),
          SizedBox(width: isLand ? 2 : 5),
          GestureDetector(
            onTap: onReload,
            child: Icon(Icons.refresh_rounded, color: const Color(0xFF94A3B8), size: isLand ? 13 : 16),
          ),
        ],
      ),
    );
  }

  Widget _buildTabCounter(bool isLand) {
    return GestureDetector(
      onTap: onToggleStackMode,
      child: Container(
        width: isLand ? 22 : 28, height: isLand ? 22 : 28,
        decoration: BoxDecoration(
          color: isVerticalStackMode ? const Color(0xFF10B981).withValues(alpha: 0.25) : const Color(0xFF1E293B),
          borderRadius: BorderRadius.circular(isLand ? 5 : 7),
          border: Border.all(color: isVerticalStackMode ? const Color(0xFF10B981) : const Color(0xFF475569), width: 1.0),
        ),
        alignment: Alignment.center,
        child: Text(
          '$tabCount',
          style: TextStyle(color: isVerticalStackMode ? const Color(0xFF10B981) : Colors.white, fontSize: isLand ? 9.5 : 11.5, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }
}

/// Botón táctil con Semantics accesible libre de Tooltip para erradicar 'No Overlay'.
class _TopBarActionBtn extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final double size;
  final VoidCallback onTap;

  const _TopBarActionBtn({
    required this.icon,
    required this.label,
    required this.color,
    required this.size,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isLand = MediaQuery.of(context).orientation == Orientation.landscape;
    return Semantics(
      label: label,
      button: true,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(6),
        child: Container(
          width: isLand ? 20 : 26, height: isLand ? 20 : 26,
          alignment: Alignment.center,
          margin: const EdgeInsets.symmetric(horizontal: 1),
          child: Icon(icon, size: size, color: color),
        ),
      ),
    );
  }
}
