// QUÉ: Catálogo limpio de opciones reales del navegador Nano Browser estilo iOS Safari.
// CÓMO: Define ítems con iconos Cupertino sobrios, título semántico, subtítulo y acción real.
// POR QUÉ: Elimina colores estridentes y opciones simuladas para estética iOS profesional (< 115 líneas).

import 'package:flutter/cupertino.dart';
import '../../domain/browser_tab_model.dart';

class BrowserOptionItemDef {
  final IconData icon;
  final String title, action;
  final String? subtitle;
  final bool isHighlighted;

  const BrowserOptionItemDef(
    this.icon,
    this.title,
    this.action, {
    this.subtitle,
    this.isHighlighted = false,
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
      isBookmarked ? 'Guardada en favoritos' : 'Añadir a favoritos',
      'toggle_bookmark',
      isHighlighted: isBookmarked,
    ),
    const BrowserOptionItemDef(
      CupertinoIcons.search,
      'Buscar en la página',
      'find_in_page',
    ),
    const BrowserOptionItemDef(
      CupertinoIcons.doc_on_doc,
      'Copiar enlace',
      'copy_url',
    ),
    const BrowserOptionItemDef(
      CupertinoIcons.lock_shield,
      'Seguridad de la conexión',
      'show_ssl',
    ),
  ];

  /// Ajustes reales de visualización, escala, desktop, modo oscuro y PiP.
  static List<BrowserOptionItemDef> displayItems({
    required BrowserTabModel tab,
    required bool isDesktopMode,
    required bool isDarkModeWeb,
  }) => [
    BrowserOptionItemDef(
      CupertinoIcons.textformat_size,
      'Tamaño de texto y zoom',
      'show_zoom_sheet',
      subtitle: '${(tab.zoomLevel * 100).round()} %',
    ),
    BrowserOptionItemDef(
      CupertinoIcons.desktopcomputer,
      'Versión de escritorio',
      'toggle_desktop_mode',
      subtitle: isDesktopMode ? 'Activada' : 'Desactivada',
      isHighlighted: isDesktopMode,
    ),
    BrowserOptionItemDef(
      CupertinoIcons.moon,
      'Oscurecer páginas web',
      'toggle_dark_web',
      subtitle: isDarkModeWeb ? 'Activado' : 'Desactivado',
      isHighlighted: isDarkModeWeb,
    ),
    const BrowserOptionItemDef(
      CupertinoIcons.play_rectangle,
      'Vídeo flotante (PiP)',
      'pip_mode',
      subtitle: 'Reproductor web en miniatura',
    ),
  ];

  /// Datos reales: historial, contraseñas, apertura en apps externas y caché.
  static List<BrowserOptionItemDef> dataItems({
    required String externalAppModeLabel,
  }) => [
    const BrowserOptionItemDef(
      CupertinoIcons.book,
      'Historial y marcadores',
      'show_history',
      subtitle: 'Páginas visitadas y guardadas',
    ),
    const BrowserOptionItemDef(
      CupertinoIcons.lock,
      'Contraseñas guardadas',
      'show_credentials',
      subtitle: 'Bóveda local segura',
    ),
    BrowserOptionItemDef(
      CupertinoIcons.arrow_up_right_square,
      'Apertura en apps externas',
      'cycle_external_app_mode',
      subtitle: externalAppModeLabel,
    ),
    const BrowserOptionItemDef(
      CupertinoIcons.trash,
      'Borrar datos de navegación',
      'clear_cache',
      subtitle: 'Libera caché web y cookies temporales',
    ),
  ];
}
