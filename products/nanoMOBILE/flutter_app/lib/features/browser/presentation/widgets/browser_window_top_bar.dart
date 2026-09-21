import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:nanoai/features/browser/domain/browser_tab_model.dart';
import 'package:nanoai/features/browser/presentation/widgets/browser_owl_assistant_sheet.dart';
import 'package:nanoai/features/browser/presentation/widgets/browser_zoom_sheet.dart';

/// Barra superior de navegación y controles de la ventana activa del navegador.
/// 
/// - ¿Qué hace?: Presenta el botón atrás, la caja de dirección URL con candado SSL,
///   botón 'aA' de zoom, botón de recarga, contador de pestañas, carrusel 3D, asistente IA y menú.
/// - ¿Cómo funciona?: Responde a toques para abrir diálogos de edición de URL, zoom táctil
///   y ejecución de comandos de navegación en el controlador WebView activo.
/// - ¿Por qué?: Separa la presentación de la barra de navegación del orquestador multi-ventana (SRP).
class BrowserWindowTopBar extends StatelessWidget {
  final BrowserTabModel activeTab;
  final int tabCount;
  final bool isVerticalStackMode;
  final bool isCarouselMode;
  final double currentZoom;
  final InAppWebViewController? controller;
  final VoidCallback onBack;
  final VoidCallback onReload;
  final VoidCallback onToggleStackMode;
  final VoidCallback onToggleCarouselMode;
  final VoidCallback onOpenOptionsMenu;
  final VoidCallback onUrlTap;
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
  });

  @override
  Widget build(BuildContext context) {
    final isLandscape = MediaQuery.of(context).orientation == Orientation.landscape;
    return Container(
      padding: EdgeInsets.symmetric(horizontal: isLandscape ? 4 : 6, vertical: isLandscape ? 1 : 4),
      decoration: const BoxDecoration(
        color: Color(0xFF08121E),
        border: Border(bottom: BorderSide(color: Color(0xFF1E293B), width: 1.0)),
      ),
      child: Row(
        children: [
          IconButton(
            icon: Icon(Icons.arrow_back_rounded, color: const Color(0xFF94A3B8), size: isLandscape ? 15 : 18),
            padding: EdgeInsets.zero,
            constraints: BoxConstraints(minWidth: isLandscape ? 22 : 28, minHeight: isLandscape ? 22 : 28),
            onPressed: onBack,
          ),
          SizedBox(width: isLandscape ? 2 : 3),
          Expanded(
            child: Container(
              height: isLandscape ? 26 : 34,
              padding: EdgeInsets.symmetric(horizontal: isLandscape ? 6 : 8),
              decoration: BoxDecoration(
                color: const Color(0xFF0F1E24),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: const Color(0xFF059669).withValues(alpha: 0.6), width: 1.0),
              ),
              child: Row(
                children: [
                  Icon(Icons.lock_rounded, color: const Color(0xFF10B981), size: isLandscape ? 11 : 14),
                  SizedBox(width: isLandscape ? 3 : 6),
                  Expanded(
                    child: InkWell(
                      onTap: onUrlTap,
                      child: Text(
                        activeTab.url.isEmpty ? 'Buscar o escribir URL' : activeTab.url,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: const Color(0xFFE2E8F0),
                          fontSize: isLandscape ? 10.5 : 12.0,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ),
                  GestureDetector(
                    onTap: () => BrowserZoomSheet.show(
                      context: context,
                      tab: activeTab,
                      currentZoom: currentZoom,
                      controller: controller,
                      onZoomChanged: onZoomChanged,
                    ),
                    child: Container(
                      padding: EdgeInsets.symmetric(horizontal: isLandscape ? 3 : 5, vertical: 1),
                      decoration: BoxDecoration(color: const Color(0xFF1E293B), borderRadius: BorderRadius.circular(8)),
                      child: Text('aA', style: TextStyle(color: const Color(0xFFCBD5E1), fontSize: isLandscape ? 8.5 : 10.5, fontWeight: FontWeight.bold)),
                    ),
                  ),
                  SizedBox(width: isLandscape ? 2 : 5),
                  GestureDetector(
                    onTap: onReload,
                    child: Icon(Icons.refresh_rounded, color: const Color(0xFF94A3B8), size: isLandscape ? 13 : 16),
                  ),
                ],
              ),
            ),
          ),
          SizedBox(width: isLandscape ? 2 : 5),
          GestureDetector(
            onTap: onToggleStackMode,
            child: Container(
              width: isLandscape ? 22 : 28,
              height: isLandscape ? 22 : 28,
              decoration: BoxDecoration(
                color: isVerticalStackMode ? const Color(0xFF10B981).withValues(alpha: 0.25) : const Color(0xFF1E293B),
                borderRadius: BorderRadius.circular(isLandscape ? 5 : 7),
                border: Border.all(color: isVerticalStackMode ? const Color(0xFF10B981) : const Color(0xFF475569), width: 1.0),
              ),
              alignment: Alignment.center,
              child: Text(
                '$tabCount',
                style: TextStyle(
                  color: isVerticalStackMode ? const Color(0xFF10B981) : Colors.white,
                  fontSize: isLandscape ? 9.5 : 11.5,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          IconButton(
            icon: Icon(Icons.view_in_ar_rounded, color: isCarouselMode ? const Color(0xFF10B981) : const Color(0xFF94A3B8), size: isLandscape ? 14 : 17),
            tooltip: 'Visor Carrusel 3D',
            padding: EdgeInsets.zero,
            constraints: BoxConstraints(minWidth: isLandscape ? 22 : 26, minHeight: isLandscape ? 22 : 26),
            onPressed: onToggleCarouselMode,
          ),
          IconButton(
            icon: const Icon(Icons.auto_awesome_rounded, color: Color(0xFF10B981), size: 18),
            tooltip: 'Búho IA — Consultar Web AI',
            padding: EdgeInsets.zero,
            constraints: BoxConstraints(minWidth: isLandscape ? 22 : 28, minHeight: isLandscape ? 22 : 28),
            onPressed: () => BrowserOwlAssistantSheet.show(context, tab: activeTab, controller: controller),
          ),
          IconButton(
            icon: Icon(Icons.more_vert_rounded, color: const Color(0xFF94A3B8), size: isLandscape ? 14 : 17),
            padding: EdgeInsets.zero,
            constraints: BoxConstraints(minWidth: isLandscape ? 20 : 24, minHeight: isLandscape ? 20 : 24),
            onPressed: onOpenOptionsMenu,
          ),
        ],
      ),
    );
  }
}
