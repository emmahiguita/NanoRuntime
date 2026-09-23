import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:nanoai/features/browser/domain/browser_tab_model.dart';
import 'package:nanoai/features/browser/presentation/widgets/browser_options_tiles.dart';

/// Hoja modal de opciones completas del navegador estilo iOS / Liquid Glass.
/// 
/// - QUÉ HACE: Despliega menú de opciones, búsqueda en página, favoritos, vista 3D y ajustes.
/// - CÓMO FUNCIONA: Usa [BackdropFilter] y despacha acciones a través de [onAction].
/// - POR QUÉ: Centraliza controles avanzados con diseño adaptativo en portrait/landscape (<200 líneas).
class BrowserOptionsSheet extends StatelessWidget {
  final BrowserTabModel tab;
  final bool isBookmarked, isDesktopMode, isDarkModeWeb;
  final ValueChanged<String> onAction;

  const BrowserOptionsSheet({
    super.key, required this.tab, required this.isBookmarked,
    required this.isDesktopMode, required this.isDarkModeWeb, required this.onAction,
  });

  static Future<void> show({
    required BuildContext context, required BrowserTabModel tab,
    required bool isBookmarked, required bool isDesktopMode,
    required bool isDarkModeWeb, required ValueChanged<String> onAction,
  }) {
    return showModalBottomSheet(
      context: context, isScrollControlled: true, backgroundColor: Colors.transparent,
      barrierColor: Colors.black45,
      builder: (_) => BrowserOptionsSheet(
        tab: tab, isBookmarked: isBookmarked, isDesktopMode: isDesktopMode,
        isDarkModeWeb: isDarkModeWeb, onAction: onAction,
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
        width: mq.size.width - (isLand ? 60 : 20),
        constraints: BoxConstraints(maxWidth: isLand ? 500 : 400, maxHeight: mq.size.height * (isLand ? 0.95 : 0.88)),
        margin: EdgeInsets.only(bottom: isLand ? 4 : 20, top: isLand ? 4 : 10),
        padding: const EdgeInsets.all(1.0),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(26),
          color: isDark ? const Color(0xD909101D) : const Color(0xD9FFFFFF),
          border: Border.all(color: isDark ? Colors.white12 : Colors.white60),
          boxShadow: const [BoxShadow(color: Colors.black45, blurRadius: 30, offset: Offset(0, 12))],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(25),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              padding: EdgeInsets.fromLTRB(isLand ? 12 : 16, 10, isLand ? 12 : 16, isLand ? 10 : 16),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                Center(child: Container(width: 36, height: 4, decoration: BoxDecoration(color: isDark ? Colors.white24 : Colors.black26, borderRadius: BorderRadius.circular(2)))),
                const SizedBox(height: 10),
                _buildHeader(context, isDark),
                const SizedBox(height: 12),
                _buildQuickActions(context),
                _divider(isDark),
                GlassMenuRow(icon: Icons.view_in_ar_rounded, accent: const Color(0xFF0284C7), title: 'Vista 3D de pestañas', subtitle: 'Navega en carrusel espacial', onTap: () => _trigger(context, 'toggle_carousel')),
                GlassMenuRow(icon: Icons.open_in_full_rounded, accent: const Color(0xFF10B981), title: 'Tamaño & Zoom (aA)', subtitle: 'Ajustar escala visual de página', onTap: () => _trigger(context, 'show_zoom_sheet')),
                GlassMenuRow(
                  icon: isDesktopMode ? Icons.smartphone_rounded : Icons.desktop_mac_rounded, accent: const Color(0xFF8B5CF6),
                  title: isDesktopMode ? 'Sitio Móvil' : 'Sitio para Escritorio', trailingBadge: isDesktopMode ? 'ACTIVO' : null,
                  onTap: () => _trigger(context, 'toggle_desktop_mode'),
                ),
                GlassMenuRow(
                  icon: isDarkModeWeb ? Icons.light_mode_rounded : Icons.nightlight_round, accent: const Color(0xFFF59E0B),
                  title: isDarkModeWeb ? 'Desactivar Modo Oscuro' : 'Modo Oscuro Forzado', trailingBadge: isDarkModeWeb ? 'ON' : null,
                  onTap: () => _trigger(context, 'toggle_dark_web'),
                ),
                GlassMenuRow(icon: Icons.auto_awesome_rounded, accent: const Color(0xFFD946EF), title: 'Preguntar al Búho IA', subtitle: 'Resumir y analizar contenido', isHighlight: true, onTap: () => _trigger(context, 'ask_owl')),
                _divider(isDark),
                Row(children: [
                  Expanded(child: GlassSecondaryButton(icon: Icons.bookmark_rounded, label: 'Marcadores', accent: const Color(0xFF38BDF8), onTap: () => _trigger(context, 'show_bookmarks'))),
                  const SizedBox(width: 8),
                  Expanded(child: GlassSecondaryButton(icon: Icons.history_rounded, label: 'Historial', accent: const Color(0xFFA78BFA), onTap: () => _trigger(context, 'show_history'))),
                ]),
                _divider(isDark),
                GlassMenuRow(icon: Icons.vpn_key_rounded, accent: const Color(0xFF38BDF8), title: 'Contraseñas', subtitle: 'Bóveda cifrada segura', onTap: () => _trigger(context, 'show_credentials')),
                GlassMenuRow(icon: Icons.copy_rounded, accent: const Color(0xFF64748B), title: 'Copiar Enlace', subtitle: 'Copiar URL al portapapeles', onTap: () => _trigger(context, 'copy_url')),
                GlassMenuRow(icon: Icons.verified_user_rounded, accent: tab.isSecure ? const Color(0xFF10B981) : const Color(0xFFEF4444), title: 'Seguridad SSL', subtitle: tab.isSecure ? 'Conexión HTTPS cifrada' : 'Conexión insegura (HTTP)', onTap: () => _trigger(context, 'show_ssl')),
                GlassMenuRow(icon: Icons.cleaning_services_rounded, accent: const Color(0xFFF43F5E), title: 'Limpiar Datos y Caché', subtitle: 'Eliminar almacenamiento temporal', onTap: () => _trigger(context, 'clear_cache')),
              ]),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context, bool isDark) => Row(children: [
    Container(
      width: 36, height: 36,
      decoration: BoxDecoration(shape: BoxShape.circle, color: (tab.isSecure ? const Color(0xFF10B981) : const Color(0xFFEF4444)).withValues(alpha: 0.15)),
      alignment: Alignment.center,
      child: Icon(tab.isSecure ? Icons.lock_rounded : Icons.lock_open_rounded, size: 17, color: tab.isSecure ? const Color(0xFF34D399) : const Color(0xFFF87171)),
    ),
    const SizedBox(width: 10),
    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(tab.title.isNotEmpty ? tab.title : 'Navegador', maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: isDark ? Colors.white : Colors.black87)),
      Text(tab.displayHost.isNotEmpty ? tab.displayHost : tab.url, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 11.5, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B))),
    ])),
    GlassCircleButton(icon: Icons.close_rounded, size: 32, onTap: () => Navigator.pop(context)),
  ]);

  Widget _buildQuickActions(BuildContext context) => Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
    GlassOrbAction(icon: isBookmarked ? Icons.bookmark_added_rounded : Icons.bookmark_border_rounded, label: isBookmarked ? 'Guardado' : 'Favorito', accentColor: const Color(0xFF3B82F6), isActive: isBookmarked, onTap: () => _trigger(context, 'toggle_bookmark')),
    GlassOrbAction(icon: Icons.search_rounded, label: 'Buscar', accentColor: const Color(0xFF8B5CF6), onTap: () => _trigger(context, 'find_in_page')),
    GlassOrbAction(icon: Icons.picture_in_picture_alt_rounded, label: 'PiP', accentColor: const Color(0xFF06B6D4), onTap: () => _trigger(context, 'pip_mode')),
    GlassOrbAction(icon: Icons.share_rounded, label: 'Compartir', accentColor: const Color(0xFFF97316), onTap: () => _trigger(context, 'share')),
  ]);

  Widget _divider(bool isDark) => Container(height: 0.5, margin: const EdgeInsets.symmetric(vertical: 6), color: isDark ? Colors.white10 : Colors.black12);
}
