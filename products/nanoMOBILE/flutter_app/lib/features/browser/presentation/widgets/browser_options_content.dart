import 'package:flutter/material.dart';
import '../../domain/browser_tab_model.dart';

/// Opciones conectadas al despachador existente; textos describen efectos reales.
class BrowserOptionsContent extends StatelessWidget {
  final BrowserTabModel tab;
  final bool isBookmarked, isDesktopMode, isDarkModeWeb;
  final ValueChanged<String> onAction;
  const BrowserOptionsContent({
    super.key,
    required this.tab,
    required this.isBookmarked,
    required this.isDesktopMode,
    required this.isDarkModeWeb,
    required this.onAction,
  });

  /// Las categorías sustituyen filas decorativas y controles de copia duplicados.
  @override
  Widget build(BuildContext context) => Column(
    mainAxisSize: MainAxisSize.min,
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      _section(context, 'Página actual'),
      _item(
        Icons.bookmark_outline_rounded,
        isBookmarked ? 'Quitar de favoritos' : 'Guardar en favoritos',
        'toggle_bookmark',
      ),
      _item(Icons.search_rounded, 'Buscar en la página', 'find_in_page'),
      _item(Icons.copy_rounded, 'Copiar enlace', 'copy_url'),
      _item(Icons.info_outline_rounded, 'Información de conexión', 'show_ssl'),
      const Divider(),
      _section(context, 'Visualización'),
      _item(
        Icons.text_fields_rounded,
        'Escala de la página',
        'show_zoom_sheet',
        subtitle: '${(tab.zoomLevel * 100).round()} %',
      ),
      _item(
        Icons.desktop_windows_outlined,
        'Versión de escritorio',
        'toggle_desktop_mode',
        subtitle: isDesktopMode ? 'Activada' : 'Desactivada',
      ),
      _item(
        Icons.dark_mode_outlined,
        'Oscurecer páginas web',
        'toggle_dark_web',
        subtitle: isDarkModeWeb ? 'Activado' : 'Desactivado',
      ),
      _item(
        Icons.picture_in_picture_alt_rounded,
        'Vídeo flotante',
        'pip_mode',
        subtitle: 'Disponible si la página contiene vídeo compatible',
      ),
      _item(
        Icons.view_carousel_outlined,
        'Carrusel de pestañas',
        'toggle_carousel',
      ),
      const Divider(),
      _section(context, 'Navegación'),
      _item(Icons.add_rounded, 'Nueva pestaña', 'new_tab'),
      _item(Icons.bookmarks_outlined, 'Favoritos', 'show_bookmarks'),
      _item(Icons.history_rounded, 'Historial', 'show_history'),
      _item(
        Icons.password_rounded,
        'Contraseñas guardadas',
        'show_credentials',
      ),
      _item(
        Icons.cleaning_services_outlined,
        'Limpiar caché',
        'clear_cache',
        subtitle: 'No elimina tus cuentas ni favoritos',
      ),
    ],
  );

  /// ListTile nativo permite envolver textos y mantiene un área táctil legible.
  Widget _item(
    IconData icon,
    String title,
    String action, {
    String? subtitle,
  }) => ListTile(
    leading: Icon(icon, size: 20),
    title: Text(title),
    subtitle: subtitle == null ? null : Text(subtitle),
    onTap: () => onAction(action),
  );

  Widget _section(BuildContext context, String title) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
    child: Text(title, style: Theme.of(context).textTheme.titleSmall),
  );
}
