import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:nanoai/features/browser/domain/browser_tab_model.dart';
import 'package:nanoai/features/browser/presentation/widgets/browser_options_tiles.dart';

/// Hoja modal de opciones del navegador con estética ejecutiva dark glass.
/// 
/// - QUÉ HACE: Despliega menú de opciones, búsqueda en página, favoritos, vista 3D y ajustes.
/// - CÓMO FUNCIONA: Usa [BackdropFilter] y despacha acciones a través de [onAction].
/// - POR QUÉ: Diseño sobrio, profesional y adaptativo sin colores infantiles (<140 líneas).
class BrowserOptionsSheet extends StatelessWidget {
  final BrowserTabModel tab;
  final bool isBookmarked, isDesktopMode, isDarkModeWeb;
  final ValueChanged<String> onAction;

  const BrowserOptionsSheet({
    super.key,
    required this.tab,
    required this.isBookmarked,
    required this.isDesktopMode,
    required this.isDarkModeWeb,
    required this.onAction,
  });

  static Future<void> show({
    required BuildContext context,
    required BrowserTabModel tab,
    required bool isBookmarked,
    required bool isDesktopMode,
    required bool isDarkModeWeb,
    required ValueChanged<String> onAction,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black54,
      builder: (_) => BrowserOptionsSheet(
        tab: tab,
        isBookmarked: isBookmarked,
        isDesktopMode: isDesktopMode,
        isDarkModeWeb: isDarkModeWeb,
        onAction: onAction,
      ),
    );
  }

  void _trigger(BuildContext context, String action) {
    HapticFeedback.lightImpact();
    Navigator.pop(context);
    onAction(action);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final mq = MediaQuery.of(context);
    final isLand = mq.orientation == Orientation.landscape;

    return Center(
      child: Container(
        width: mq.size.width - (isLand ? 60 : 24),
        constraints: BoxConstraints(
          maxWidth: isLand ? 500 : 380,
          maxHeight: mq.size.height * (isLand ? 0.95 : 0.85),
        ),
        margin: EdgeInsets.only(bottom: isLand ? 6 : 24, top: isLand ? 6 : 12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(22),
          color: isDark ? const Color(0xF20A101D) : const Color(0xF2FFFFFF),
          border: Border.all(color: isDark ? Colors.white12 : Colors.black12),
          boxShadow: const [
            BoxShadow(color: Colors.black54, blurRadius: 32, offset: Offset(0, 14)),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(21),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              padding: EdgeInsets.fromLTRB(isLand ? 12 : 16, 12, isLand ? 12 : 16, isLand ? 12 : 16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Center(
                    child: Container(
                      width: 32,
                      height: 4,
                      decoration: BoxDecoration(
                        color: isDark ? Colors.white24 : Colors.black26,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  _buildHeader(context, isDark),
                  const SizedBox(height: 14),
                  _buildQuickActions(context),
                  _divider(isDark),
                  GlassMenuRow(
                    icon: Icons.view_in_ar_rounded,
                    title: 'Vista 3D de pestañas',
                    subtitle: 'Navega en carrusel espacial',
                    onTap: () => _trigger(context, 'toggle_carousel'),
                  ),
                  GlassMenuRow(
                    icon: Icons.text_fields_rounded,
                    title: 'Tamaño & Zoom',
                    subtitle: 'Ajustar escala visual de página',
                    onTap: () => _trigger(context, 'show_zoom_sheet'),
                  ),
                  GlassMenuRow(
                    icon: isDesktopMode ? Icons.smartphone_rounded : Icons.desktop_mac_rounded,
                    title: isDesktopMode ? 'Sitio Móvil' : 'Sitio para Escritorio',
                    trailingBadge: isDesktopMode ? 'ACTIVO' : null,
                    onTap: () => _trigger(context, 'toggle_desktop_mode'),
                  ),
                  GlassMenuRow(
                    icon: isDarkModeWeb ? Icons.light_mode_rounded : Icons.dark_mode_rounded,
                    title: isDarkModeWeb ? 'Desactivar Modo Oscuro' : 'Modo Oscuro Forzado',
                    trailingBadge: isDarkModeWeb ? 'ON' : null,
                    onTap: () => _trigger(context, 'toggle_dark_web'),
                  ),
                  _divider(isDark),
                  Row(
                    children: [
                      Expanded(
                        child: GlassSecondaryButton(
                          icon: Icons.bookmark_border_rounded,
                          label: 'Marcadores',
                          onTap: () => _trigger(context, 'show_bookmarks'),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: GlassSecondaryButton(
                          icon: Icons.history_rounded,
                          label: 'Historial',
                          onTap: () => _trigger(context, 'show_history'),
                        ),
                      ),
                    ],
                  ),
                  _divider(isDark),
                  GlassMenuRow(
                    icon: Icons.lock_outline_rounded,
                    title: 'Contraseñas',
                    subtitle: 'Bóveda cifrada segura',
                    onTap: () => _trigger(context, 'show_credentials'),
                  ),
                  GlassMenuRow(
                    icon: Icons.copy_rounded,
                    title: 'Copiar Enlace',
                    subtitle: 'Copiar URL al portapapeles',
                    onTap: () => _trigger(context, 'copy_url'),
                  ),
                  GlassMenuRow(
                    icon: tab.isSecure ? Icons.verified_user_outlined : Icons.gpp_maybe_outlined,
                    accent: tab.isSecure ? const Color(0xFF10B981) : const Color(0xFFEF4444),
                    title: 'Seguridad SSL',
                    subtitle: tab.isSecure ? 'Conexión HTTPS cifrada' : 'Conexión insegura (HTTP)',
                    onTap: () => _trigger(context, 'show_ssl'),
                  ),
                  GlassMenuRow(
                    icon: Icons.cleaning_services_outlined,
                    accent: const Color(0xFFF43F5E),
                    title: 'Limpiar Datos y Caché',
                    subtitle: 'Eliminar almacenamiento temporal',
                    onTap: () => _trigger(context, 'clear_cache'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context, bool isDark) => Row(
    children: [
      Icon(
        tab.isSecure ? Icons.lock_rounded : Icons.lock_open_rounded,
        size: 16,
        color: tab.isSecure ? const Color(0xFF10B981) : const Color(0xFFF87171),
      ),
      const SizedBox(width: 8),
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              tab.title.isNotEmpty ? tab.title : 'Navegador',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 13.5,
                fontWeight: FontWeight.w600,
                color: isDark ? Colors.white : Colors.black87,
              ),
            ),
            Text(
              tab.displayHost.isNotEmpty ? tab.displayHost : tab.url,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 11.0,
                color: isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8),
              ),
            ),
          ],
        ),
      ),
      GlassCircleButton(
        icon: Icons.close_rounded,
        size: 28,
        onTap: () => Navigator.pop(context),
      ),
    ],
  );

  Widget _buildQuickActions(BuildContext context) => Row(
    children: [
      Expanded(
        child: GlassOrbAction(
          icon: isBookmarked ? Icons.bookmark_added_rounded : Icons.bookmark_border_rounded,
          label: isBookmarked ? 'Guardado' : 'Favorito',
          accentColor: const Color(0xFF10B981),
          isActive: isBookmarked,
          onTap: () => _trigger(context, 'toggle_bookmark'),
        ),
      ),
      const SizedBox(width: 8),
      Expanded(
        child: GlassOrbAction(
          icon: Icons.search_rounded,
          label: 'Buscar',
          accentColor: const Color(0xFF10B981),
          onTap: () => _trigger(context, 'find_in_page'),
        ),
      ),
      const SizedBox(width: 8),
      Expanded(
        child: GlassOrbAction(
          icon: Icons.picture_in_picture_alt_rounded,
          label: 'PiP',
          accentColor: const Color(0xFF10B981),
          onTap: () => _trigger(context, 'pip_mode'),
        ),
      ),
      const SizedBox(width: 8),
      Expanded(
        child: GlassOrbAction(
          icon: Icons.share_rounded,
          label: 'Compartir',
          accentColor: const Color(0xFF10B981),
          onTap: () => _trigger(context, 'share'),
        ),
      ),
    ],
  );

  Widget _divider(bool isDark) => Container(
    height: 0.5,
    margin: const EdgeInsets.symmetric(vertical: 8),
    color: isDark ? Colors.white10 : Colors.black12,
  );
}
