import 'package:flutter/cupertino.dart';
import '../../domain/browser_tab_model.dart';

/// QUÉ HACE:
/// Definición de elementos y secciones de configuración para el menú de opciones del navegador.
///
/// CÓMO FUNCIONA:
/// Modela cada fila del menú con su icono Cupertino, gradiente de color, título semántico,
/// subtítulo dinámico y acción asociada.
///
/// POR QUÉ:
/// Desacopla los datos del menú del renderizado visual para mantener archivos < 120 líneas (SOLID).
class BrowserOptionItemDef {
  final IconData icon;
  final Color color;
  final String title, action;
  final String? subtitle;

  const BrowserOptionItemDef(
    this.icon,
    this.color,
    this.title,
    this.action, {
    this.subtitle,
  });
}

class BrowserOptionsCatalog {
  const BrowserOptionsCatalog._();

  static List<BrowserOptionItemDef> pageItems({
    required bool isBookmarked,
  }) => [
    BrowserOptionItemDef(
      CupertinoIcons.bookmark,
      const Color(0xFFF59E0B),
      isBookmarked ? 'Quitar de favoritos' : 'Guardar en favoritos',
      'toggle_bookmark',
      subtitle: isBookmarked ? 'Guardada' : null,
    ),
    const BrowserOptionItemDef(
      CupertinoIcons.search,
      Color(0xFF3B82F6),
      'Buscar en la página',
      'find_in_page',
    ),
    const BrowserOptionItemDef(
      CupertinoIcons.doc_on_doc,
      Color(0xFF8B5CF6),
      'Copiar enlace',
      'copy_url',
    ),
    const BrowserOptionItemDef(
      CupertinoIcons.shield_lefthalf_fill,
      Color(0xFF10B981),
      'Información de conexión',
      'show_ssl',
    ),
  ];

  static List<BrowserOptionItemDef> displayItems({
    required BrowserTabModel tab,
    required bool isDesktopMode,
    required bool isDarkModeWeb,
  }) => [
    BrowserOptionItemDef(
      CupertinoIcons.textformat_size,
      const Color(0xFF06B6D4),
      'Escala de la página',
      'show_zoom_sheet',
      subtitle: '${(tab.zoomLevel * 100).round()} %',
    ),
    BrowserOptionItemDef(
      CupertinoIcons.desktopcomputer,
      const Color(0xFF6366F1),
      'Versión de escritorio',
      'toggle_desktop_mode',
      subtitle: isDesktopMode ? 'Activada' : 'Desactivada',
    ),
    BrowserOptionItemDef(
      CupertinoIcons.moon_stars_fill,
      const Color(0xFFA855F7),
      'Oscurecer páginas web',
      'toggle_dark_web',
      subtitle: isDarkModeWeb ? 'Activado' : 'Desactivado',
    ),
    const BrowserOptionItemDef(
      CupertinoIcons.play_rectangle_fill,
      Color(0xFFEC4899),
      'Vídeo flotante (PiP)',
      'pip_mode',
      subtitle: 'Compatible con reproductores web',
    ),
    const BrowserOptionItemDef(
      CupertinoIcons.square_stack_3d_up_fill,
      Color(0xFF14B8A6),
      'Carrusel de pestañas 3D',
      'toggle_carousel',
    ),
  ];

  static List<BrowserOptionItemDef> dataItems({
    required String externalAppModeLabel,
  }) => [
    BrowserOptionItemDef(
      CupertinoIcons.link,
      const Color(0xFFF97316),
      'Enlaces a apps externas',
      'cycle_external_app_mode',
      subtitle: externalAppModeLabel,
    ),
    const BrowserOptionItemDef(
      CupertinoIcons.plus_square_fill,
      Color(0xFF3B82F6),
      'Nueva pestaña',
      'new_tab',
    ),
    const BrowserOptionItemDef(
      CupertinoIcons.bookmark_fill,
      Color(0xFFF59E0B),
      'Favoritos',
      'show_bookmarks',
    ),
    const BrowserOptionItemDef(
      CupertinoIcons.clock_fill,
      Color(0xFF64748B),
      'Historial',
      'show_history',
    ),
    const BrowserOptionItemDef(
      CupertinoIcons.lock_fill,
      Color(0xFF0EA5E9),
      'Contraseñas guardadas',
      'show_credentials',
    ),
    const BrowserOptionItemDef(
      CupertinoIcons.trash_fill,
      Color(0xFFEF4444),
      'Limpiar caché',
      'clear_cache',
      subtitle: 'Libera almacenamiento',
    ),
  ];
}
