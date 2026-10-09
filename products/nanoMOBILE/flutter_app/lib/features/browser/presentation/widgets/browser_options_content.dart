import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../domain/browser_tab_model.dart';

/// Contenido de opciones del navegador agrupado al estilo iOS con tarjetas glassed.
///
/// - QUÉ HACE: Renderiza secciones agrupadas con insignias metálicas y tipografía Apple.
/// - CÓMO FUNCIONA: Agrupa opciones en contenedores redondeados con divisores finos y feedback háptico.
/// - POR QUÉ: Logra el look & feel 100% iOS profesional y fluido sin saturar la GPU (<200 líneas).
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

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _sectionHeader('PÁGINA ACTUAL', isDark),
          _group(isDark, [
            _ItemDef(
              CupertinoIcons.bookmark,
              const Color(0xFFF59E0B),
              isBookmarked ? 'Quitar de favoritos' : 'Guardar en favoritos',
              'toggle_bookmark',
              subtitle: isBookmarked ? 'Guardada' : null,
            ),
            const _ItemDef(CupertinoIcons.search, Color(0xFF3B82F6), 'Buscar en la página', 'find_in_page'),
            const _ItemDef(CupertinoIcons.doc_on_doc, Color(0xFF8B5CF6), 'Copiar enlace', 'copy_url'),
            const _ItemDef(CupertinoIcons.shield_lefthalf_fill, Color(0xFF10B981), 'Información de conexión', 'show_ssl'),
          ]),
          const SizedBox(height: 12),
          _sectionHeader('VISUALIZACIÓN', isDark),
          _group(isDark, [
            _ItemDef(
              CupertinoIcons.textformat_size,
              const Color(0xFF06B6D4),
              'Escala de la página',
              'show_zoom_sheet',
              subtitle: '${(tab.zoomLevel * 100).round()} %',
            ),
            _ItemDef(
              CupertinoIcons.desktopcomputer,
              const Color(0xFF6366F1),
              'Versión de escritorio',
              'toggle_desktop_mode',
              subtitle: isDesktopMode ? 'Activada' : 'Desactivada',
            ),
            _ItemDef(
              CupertinoIcons.moon_stars_fill,
              const Color(0xFFA855F7),
              'Oscurecer páginas web',
              'toggle_dark_web',
              subtitle: isDarkModeWeb ? 'Activado' : 'Desactivado',
            ),
            const _ItemDef(
              CupertinoIcons.play_rectangle_fill,
              Color(0xFFEC4899),
              'Vídeo flotante (PiP)',
              'pip_mode',
              subtitle: 'Compatible con reproductores web',
            ),
            const _ItemDef(
              CupertinoIcons.square_stack_3d_up_fill,
              Color(0xFF14B8A6),
              'Carrusel de pestañas 3D',
              'toggle_carousel',
            ),
          ]),
          const SizedBox(height: 12),
          _sectionHeader('NAVEGACIÓN Y DATOS', isDark),
          _group(isDark, [
            const _ItemDef(CupertinoIcons.plus_square_fill, Color(0xFF3B82F6), 'Nueva pestaña', 'new_tab'),
            const _ItemDef(CupertinoIcons.bookmark_fill, Color(0xFFF59E0B), 'Favoritos', 'show_bookmarks'),
            const _ItemDef(CupertinoIcons.clock_fill, Color(0xFF64748B), 'Historial', 'show_history'),
            const _ItemDef(CupertinoIcons.lock_fill, Color(0xFF0EA5E9), 'Contraseñas guardadas', 'show_credentials'),
            const _ItemDef(
              CupertinoIcons.trash_fill,
              Color(0xFFEF4444),
              'Limpiar caché',
              'clear_cache',
              subtitle: 'Libera almacenamiento',
            ),
          ]),
        ],
      ),
    );
  }

  Widget _sectionHeader(String title, bool isDark) => Padding(
    padding: const EdgeInsets.only(left: 8, bottom: 5, top: 2),
    child: Text(
      title,
      style: TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.8,
        color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
      ),
    ),
  );

  Widget _group(bool isDark, List<_ItemDef> items) => Container(
    decoration: BoxDecoration(
      color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.black.withValues(alpha: 0.03),
      borderRadius: BorderRadius.circular(16),
      border: Border.all(
        color: isDark ? Colors.white.withValues(alpha: 0.08) : Colors.black.withValues(alpha: 0.06),
      ),
    ),
    child: Column(
      children: [
        for (int i = 0; i < items.length; i++) ...[
          _row(items[i], isDark),
          if (i < items.length - 1)
            Divider(
              height: 1,
              thickness: 0.7,
              indent: 48,
              color: isDark ? Colors.white.withValues(alpha: 0.06) : Colors.black.withValues(alpha: 0.05),
            ),
        ],
      ],
    ),
  );

  Widget _row(_ItemDef item, bool isDark) => Material(
    color: Colors.transparent,
    child: InkWell(
      onTap: () { HapticFeedback.lightImpact(); onAction(item.action); },
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9.5),
        child: Row(
          children: [
            Container(
              width: 28, height: 28,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [item.color, item.color.withValues(alpha: 0.8)],
                  begin: Alignment.topLeft, end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(7),
                boxShadow: [BoxShadow(color: item.color.withValues(alpha: 0.28), blurRadius: 5, offset: const Offset(0, 1.5))],
              ),
              child: Icon(item.icon, size: 15, color: Colors.white),
            ),
            const SizedBox(width: 11),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.title,
                    style: TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w500,
                      color: isDark ? Colors.white : const Color(0xFF1E293B),
                    ),
                  ),
                  if (item.subtitle != null) ...[
                    const SizedBox(height: 1),
                    Text(
                      item.subtitle!,
                      style: TextStyle(fontSize: 11, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
                    ),
                  ],
                ],
              ),
            ),
            Icon(CupertinoIcons.chevron_right, size: 13, color: isDark ? Colors.white24 : Colors.black26),
          ],
        ),
      ),
    ),
  );
}

class _ItemDef {
  final IconData icon;
  final Color color;
  final String title, action;
  final String? subtitle;
  const _ItemDef(this.icon, this.color, this.title, this.action, {this.subtitle});
}
