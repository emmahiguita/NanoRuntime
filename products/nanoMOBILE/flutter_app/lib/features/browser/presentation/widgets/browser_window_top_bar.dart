import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:nanoai/features/browser/domain/browser_tab_model.dart';
import 'package:nanoai/features/browser/presentation/widgets/browser_owl_assistant_sheet.dart';
import 'package:nanoai/features/browser/presentation/widgets/browser_site_theme.dart';
import 'package:nanoai/features/browser/presentation/widgets/browser_window_omnibox.dart';
import 'package:nanoai/features/browser/presentation/widgets/browser_zoom_sheet.dart';

/// Barra superior de navegación y controles ergonómicos de la ventana del navegador.
/// 
/// - QUÉ HACE: Presenta la barra de navegación web con Omnibox editable en vivo,
///   botón atrás, contador de pestañas, asistente Búho IA y menú de opciones.
/// - CÓMO FUNCIONA: Dispone botones con [Semantics] táctiles inmunes a errores 'No Overlay',
///   integrando [BrowserWindowOmnibox] para edición directa de URL sin modales invasivos.
/// - POR QUÉ: Aplica SOLID (SRP) y Material Expressive 3 adaptándose a horizontal/vertical (<200 líneas).
class BrowserWindowTopBar extends StatelessWidget {
  final BrowserTabModel activeTab;
  final int tabCount;
  final bool isVerticalStackMode, isCarouselMode;
  final double currentZoom;
  final InAppWebViewController? controller;
  final VoidCallback onBack, onReload, onToggleStackMode, onToggleCarouselMode, onOpenOptionsMenu;
  final ValueChanged<String> onNavigate;
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
    required this.onNavigate,
    required this.onZoomChanged,
    this.onMinimize,
    this.onMaximize,
    this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    final isLand = MediaQuery.of(context).orientation == Orientation.landscape;
    final siteColor = BrowserSiteTheme.getSiteColor(activeTab.url);

    return Container(
      padding: EdgeInsets.symmetric(horizontal: isLand ? 4 : 6, vertical: isLand ? 2 : 4),
      decoration: const BoxDecoration(
        color: Color(0xFF08121E),
        border: Border(bottom: BorderSide(color: Color(0xFF1E293B), width: 1.0)),
      ),
      child: Row(
        children: [
          _ActionBtn(
            icon: Icons.arrow_back_rounded,
            label: 'Página anterior',
            color: const Color(0xFF94A3B8),
            size: isLand ? 15 : 18,
            onTap: onBack,
          ),
          SizedBox(width: isLand ? 3 : 5),
          Expanded(
            child: BrowserWindowOmnibox(
              url: activeTab.url,
              title: activeTab.title,
              siteColor: siteColor,
              isLandscape: isLand,
              onSubmitted: onNavigate,
              onReload: onReload,
              onZoom: () => BrowserZoomSheet.show(
                context: context,
                tab: activeTab,
                currentZoom: currentZoom,
                controller: controller,
                onZoomChanged: onZoomChanged,
              ),
            ),
          ),
          SizedBox(width: isLand ? 3 : 5),
          _buildTabCounter(isLand),
          if (onMinimize != null)
            _ActionBtn(icon: Icons.remove_rounded, label: 'Minimizar ventana', color: const Color(0xFFF59E0B), size: isLand ? 13 : 16, onTap: onMinimize!),
          if (onMaximize != null)
            _ActionBtn(icon: Icons.fullscreen_rounded, label: 'Ampliar ventana', color: const Color(0xFF38BDF8), size: isLand ? 13 : 16, onTap: onMaximize!),
          if (onClose != null)
            _ActionBtn(icon: Icons.close_rounded, label: 'Cerrar ventana', color: const Color(0xFFEF4444), size: isLand ? 13 : 16, onTap: onClose!),
          _ActionBtn(
            icon: Icons.auto_awesome_rounded,
            label: 'Asistente IA',
            color: const Color(0xFF10B981),
            size: isLand ? 15 : 18,
            onTap: () => BrowserOwlAssistantSheet.show(context, tab: activeTab, controller: controller),
          ),
          _ActionBtn(
            icon: Icons.more_vert_rounded,
            label: 'Opciones de navegación',
            color: const Color(0xFF94A3B8),
            size: isLand ? 14 : 17,
            onTap: onOpenOptionsMenu,
          ),
        ],
      ),
    );
  }

  Widget _buildTabCounter(bool isLand) {
    return Semantics(
      label: 'Alternar pestañas, $tabCount activas',
      button: true,
      child: InkWell(
        onTap: onToggleStackMode,
        borderRadius: BorderRadius.circular(isLand ? 5 : 7),
        child: Container(
          width: isLand ? 22 : 28,
          height: isLand ? 22 : 28,
          decoration: BoxDecoration(
            color: isVerticalStackMode ? const Color(0xFF10B981).withValues(alpha: 0.25) : const Color(0xFF1E293B),
            borderRadius: BorderRadius.circular(isLand ? 5 : 7),
            border: Border.all(
              color: isVerticalStackMode ? const Color(0xFF10B981) : const Color(0xFF475569),
              width: 1.0,
            ),
          ),
          alignment: Alignment.center,
          child: Text(
            '$tabCount',
            style: TextStyle(
              color: isVerticalStackMode ? const Color(0xFF10B981) : Colors.white,
              fontSize: isLand ? 9.5 : 11.5,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ),
    );
  }
}

/// Botón táctil ergonómico con Semantics accesible libre de Tooltip para prevenir 'No Overlay'.
class _ActionBtn extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final double size;
  final VoidCallback onTap;

  const _ActionBtn({
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
        borderRadius: BorderRadius.circular(8),
        child: Container(
          width: isLand ? 22 : 28,
          height: isLand ? 22 : 28,
          alignment: Alignment.center,
          margin: const EdgeInsets.symmetric(horizontal: 1),
          child: Icon(icon, size: size, color: color),
        ),
      ),
    );
  }
}
