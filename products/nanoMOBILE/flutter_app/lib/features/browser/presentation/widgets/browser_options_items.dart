// QUÉ: Catálogo de opciones del menú iOS de Nano Browser sin duplicados.
// CÓMO: Define ítems con icono Cupertino único, color semántico, título, subtítulo y acción.
// POR QUÉ: Desacopla datos de la vista (SOLID) y elimina acciones o iconos redundantes (< 130 líneas).

import 'package:flutter/cupertino.dart';
import '../../domain/browser_tab_model.dart';

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

  /// Acciones directas sobre la página web activa.
  static List<BrowserOptionItemDef> pageItems({
    required bool isBookmarked,
  }) => [
    BrowserOptionItemDef(
      isBookmarked ? CupertinoIcons.star_fill : CupertinoIcons.star,
      const Color(0xFFF59E0B),
      isBookmarked ? 'Quitar de favoritos' : 'Añadir a favoritos',
      'toggle_bookmark',
      subtitle: isBookmarked ? 'Guardada en marcadores' : null,
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
      CupertinoIcons.lock_shield_fill,
      Color(0xFF10B981),
      'Seguridad de la conexión',
      'show_ssl',
    ),
  ];

  /// Ajustes de renderizado, escala, modo escritorio, modo oscuro y PiP.
  static List<BrowserOptionItemDef> displayItems({
    required BrowserTabModel tab,
    required bool isDesktopMode,
    required bool isDarkModeWeb,
  }) => [
    BrowserOptionItemDef(
      CupertinoIcons.textformat_size,
      const Color(0xFF06B6D4),
      'Tamaño de texto y zoom',
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
      subtitle: 'Reproductor en ventana',
    ),
  ];

  /// Gestión de historial/marcadores unificados, bóveda de contraseñas, enlaces y caché.
  static List<BrowserOptionItemDef> dataItems({
    required String externalAppModeLabel,
  }) => [
    const BrowserOptionItemDef(
      CupertinoIcons.book_fill,
      Color(0xFFF97316),
      'Historial y favoritos',
      'show_history',
      subtitle: 'Páginas visitadas y guardadas',
    ),
    const BrowserOptionItemDef(
      CupertinoIcons.lock_fill,
      Color(0xFF0EA5E9),
      'Contraseñas guardadas',
      'show_credentials',
    ),
    BrowserOptionItemDef(
      CupertinoIcons.arrow_up_right_square_fill,
      const Color(0xFF14B8A6),
      'Apertura en apps externas',
      'cycle_external_app_mode',
      subtitle: externalAppModeLabel,
    ),
    const BrowserOptionItemDef(
      CupertinoIcons.trash_fill,
      Color(0xFFEF4444),
      'Limpiar caché web',
      'clear_cache',
      subtitle: 'Libera almacenamiento temporal',
    ),
  ];
}
