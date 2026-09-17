import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:nanoai/features/browser/domain/browser_tab_model.dart';

/// Hoja modal de opciones completas del navegador estilo iOS 26 / Liquid Glass.
/// Diseñada con BackdropFilter real, reflexiones ópticas, bordes especulares y
/// respuesta háptica táctil fluida sin recargas ni pérdida de estado.
class BrowserOptionsSheet extends StatelessWidget {
  final BrowserTabModel tab;
  final bool isBookmarked;
  final bool isDesktopMode;
  final bool isDarkModeWeb;
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
      barrierColor: Colors.black.withValues(alpha: 0.42),
      builder: (_) => BrowserOptionsSheet(
        tab: tab,
        isBookmarked: isBookmarked,
        isDesktopMode: isDesktopMode,
        isDarkModeWeb: isDarkModeWeb,
        onAction: onAction,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final mq = MediaQuery.of(context);
    final isLandscape = mq.orientation == Orientation.landscape;
    final screenHeight = mq.size.height;

    return Center(
      child: Container(
        width: mq.size.width - 24,
        constraints: BoxConstraints(
          maxWidth: isLandscape ? 520 : 410,
          maxHeight: screenHeight * (isLandscape ? 0.96 : 0.90),
        ),
        margin: EdgeInsets.only(bottom: isLandscape ? 6 : 24, top: isLandscape ? 4 : 12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(30),
          // Borde óptico perimetral iridiscente sutil (Liquid Glass)
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: isDark
                ? [
                    const Color(0x6638BDF8),
                    const Color(0x33818CF8),
                    const Color(0x1A0F172A),
                    const Color(0x442DD4BF),
                  ]
                : [
                    Colors.white.withValues(alpha: 0.8),
                    Colors.white.withValues(alpha: 0.4),
                    Colors.white.withValues(alpha: 0.2),
                    Colors.white.withValues(alpha: 0.6),
                  ],
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.45),
              blurRadius: 36,
              spreadRadius: -4,
              offset: const Offset(0, 16),
            ),
            if (isDark)
              BoxShadow(
                color: const Color(0xFF38BDF8).withValues(alpha: 0.12),
                blurRadius: 28,
                spreadRadius: -8,
                offset: const Offset(0, -2),
              ),
          ],
        ),
        padding: const EdgeInsets.all(1.2),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(28.8),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 28, sigmaY: 28),
            child: Container(
              decoration: BoxDecoration(
                color: isDark
                    ? const Color(0xD909101D)
                    : const Color(0xD9FFFFFF),
                borderRadius: BorderRadius.circular(28.8),
                border: Border.all(
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.14)
                      : Colors.white.withValues(alpha: 0.65),
                  width: 0.7,
                ),
              ),
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: isLandscape
                    ? const EdgeInsets.fromLTRB(14, 8, 14, 12)
                    : const EdgeInsets.fromLTRB(18, 12, 18, 18),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Grabber iOS
                    Center(
                      child: Container(
                        width: isLandscape ? 32 : 40,
                        height: isLandscape ? 3.5 : 4.5,
                        decoration: BoxDecoration(
                          color: isDark
                              ? Colors.white.withValues(alpha: 0.28)
                              : Colors.black.withValues(alpha: 0.22),
                          borderRadius: BorderRadius.circular(3),
                        ),
                      ),
                    ),
                    SizedBox(height: isLandscape ? 8 : 14),

                    // Header Glass: [ 🔒 ] [ Título / Dominio ] [ ✕ ]
                    _buildHeader(context, isDark),
                    SizedBox(height: isLandscape ? 10 : 16),

                    // Acciones Rápidas (4 orbes luminosos estilo visionOS / Liquid Glass)
                    _buildQuickActions(context, isDark),
                    SizedBox(height: isLandscape ? 10 : 18),

                    _buildDivider(isDark),
                    const SizedBox(height: 6),

                    // Opciones Principales de Navegación
                    _GlassMenuRow(
                      icon: Icons.view_in_ar_rounded,
                      accent: const Color(0xFF0284C7),
                      title: 'Vista 3D de pestañas',
                      subtitle: 'Previsualiza y cambia sin recargar la página',
                      onTap: () => _trigger(context, 'toggle_carousel'),
                    ),
                    _GlassMenuRow(
                      icon: Icons.open_in_full_rounded,
                      accent: const Color(0xFF10B981),
                      title: 'Tamaño & Zoom de Página (aA)',
                      subtitle: 'Reducir o ampliar escala visual',
                      onTap: () => _trigger(context, 'show_zoom_sheet'),
                    ),
                    _GlassMenuRow(
                      icon: isDesktopMode
                          ? Icons.smartphone_rounded
                          : Icons.desktop_mac_rounded,
                      accent: const Color(0xFF8B5CF6),
                      title: isDesktopMode
                          ? 'Solicitar Sitio Móvil'
                          : 'Solicitar Sitio para Escritorio',
                      subtitle: isDesktopMode
                          ? 'Vista optimizada para teléfonos'
                          : 'Vista completa para ordenadores',
                      trailingBadge: isDesktopMode ? 'ACTIVO' : null,
                      onTap: () => _trigger(context, 'toggle_desktop_mode'),
                    ),
                    _GlassMenuRow(
                      icon: isDarkModeWeb
                          ? Icons.light_mode_rounded
                          : Icons.nightlight_round,
                      accent: const Color(0xFFF59E0B),
                      title: isDarkModeWeb
                          ? 'Desactivar Modo Oscuro Web'
                          : 'Modo Oscuro Web Forzado',
                      subtitle: 'Contraste suave para lectura nocturna',
                      trailingBadge: isDarkModeWeb ? 'ON' : null,
                      onTap: () => _trigger(context, 'toggle_dark_web'),
                    ),
                    _GlassMenuRow(
                      icon: Icons.auto_awesome_rounded,
                      accent: const Color(0xFFD946EF),
                      title: 'Preguntar al Búho IA',
                      subtitle: 'Resumir y analizar contenido con IA',
                      isHighlight: true,
                      onTap: () => _trigger(context, 'ask_owl'),
                    ),

                    const SizedBox(height: 10),
                    _buildDivider(isDark),
                    const SizedBox(height: 12),

                    // Marcadores e Historial (Píldoras secundarias de cristal)
                    Row(
                      children: [
                        Expanded(
                          child: _GlassSecondaryButton(
                            icon: Icons.bookmark_rounded,
                            label: 'Marcadores',
                            accent: const Color(0xFF38BDF8),
                            onTap: () => _trigger(context, 'show_bookmarks'),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _GlassSecondaryButton(
                            icon: Icons.history_rounded,
                            label: 'Historial',
                            accent: const Color(0xFFA78BFA),
                            onTap: () => _trigger(context, 'show_history'),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 12),
                    _buildDivider(isDark),
                    const SizedBox(height: 6),

                    // Utilidades y Seguridad
                    _GlassMenuRow(
                      icon: Icons.copy_rounded,
                      accent: const Color(0xFF64748B),
                      title: 'Copiar Enlace',
                      subtitle: 'Copiar URL al portapapeles',
                      onTap: () => _trigger(context, 'copy_url'),
                    ),
                    _GlassMenuRow(
                      icon: Icons.verified_user_rounded,
                      accent: tab.isSecure
                          ? const Color(0xFF10B981)
                          : const Color(0xFFEF4444),
                      title: 'Seguridad y Certificado SSL',
                      subtitle: tab.isSecure
                          ? 'Conexión HTTPS cifrada'
                          : 'Conexión insegura (HTTP)',
                      onTap: () => _trigger(context, 'show_ssl'),
                    ),
                    _GlassMenuRow(
                      icon: Icons.cleaning_services_rounded,
                      accent: const Color(0xFFF43F5E),
                      title: 'Limpiar Datos y Caché',
                      subtitle: 'Eliminar almacenamiento temporal y cookies',
                      onTap: () => _trigger(context, 'clear_cache'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context, bool isDark) {
    return Row(
      children: [
        // Indicador de seguridad glass circular
        Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: (tab.isSecure
                    ? const Color(0xFF10B981)
                    : const Color(0xFFEF4444))
                .withValues(alpha: 0.15),
            border: Border.all(
              color: (tab.isSecure
                      ? const Color(0xFF10B981)
                      : const Color(0xFFEF4444))
                  .withValues(alpha: 0.45),
              width: 1.2,
            ),
          ),
          alignment: Alignment.center,
          child: Icon(
            tab.isSecure ? Icons.lock_rounded : Icons.lock_open_rounded,
            size: 19,
            color: tab.isSecure
                ? const Color(0xFF34D399)
                : const Color(0xFFF87171),
          ),
        ),
        const SizedBox(width: 12),

        // Título y Dominio
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                tab.title.isNotEmpty ? tab.title : 'Navegador',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: isDark ? const Color(0xFFF8FAFC) : const Color(0xFF0F172A),
                  letterSpacing: -0.2,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                tab.displayHost.isNotEmpty ? tab.displayHost : tab.url,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w400,
                  color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                ),
              ),
            ],
          ),
        ),

        // Botón Cerrar circular glass
        _GlassCircleButton(
          icon: Icons.close_rounded,
          size: 38,
          onTap: () => Navigator.pop(context),
        ),
      ],
    );
  }

  Widget _buildQuickActions(BuildContext context, bool isDark) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        _GlassOrbAction(
          icon: isBookmarked
              ? Icons.bookmark_added_rounded
              : Icons.bookmark_border_rounded,
          label: isBookmarked ? 'Guardado' : 'Favorito',
          accentColor: const Color(0xFF3B82F6),
          isActive: isBookmarked,
          onTap: () => _trigger(context, 'toggle_bookmark'),
        ),
        _GlassOrbAction(
          icon: Icons.search_rounded,
          label: 'Buscar',
          accentColor: const Color(0xFF8B5CF6),
          onTap: () => _trigger(context, 'find_in_page'),
        ),
        _GlassOrbAction(
          icon: Icons.picture_in_picture_alt_rounded,
          label: 'PiP',
          accentColor: const Color(0xFF06B6D4),
          onTap: () => _trigger(context, 'pip_mode'),
        ),
        _GlassOrbAction(
          icon: Icons.share_rounded,
          label: 'Compartir',
          accentColor: const Color(0xFFF97316),
          onTap: () => _trigger(context, 'share'),
        ),
      ],
    );
  }

  Widget _buildDivider(bool isDark) {
    return Container(
      height: 0.6,
      margin: const EdgeInsets.symmetric(vertical: 4),
      color: isDark
          ? Colors.white.withValues(alpha: 0.08)
          : Colors.black.withValues(alpha: 0.07),
    );
  }

  void _trigger(BuildContext context, String action) {
    HapticFeedback.lightImpact();
    Navigator.pop(context);
    onAction(action);
  }
}

/// Orbe de acción rápida circular con brillo de cristal líquido
class _GlassOrbAction extends StatefulWidget {
  final IconData icon;
  final String label;
  final Color accentColor;
  final bool isActive;
  final VoidCallback onTap;

  const _GlassOrbAction({
    required this.icon,
    required this.label,
    required this.accentColor,
    this.isActive = false,
    required this.onTap,
  });

  @override
  State<_GlassOrbAction> createState() => _GlassOrbActionState();
}

class _GlassOrbActionState extends State<_GlassOrbAction> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) => setState(() => _pressed = false),
      onTapCancel: () => setState(() => _pressed = false),
      onTap: widget.onTap,
      child: AnimatedScale(
        scale: _pressed ? 0.92 : 1.0,
        duration: const Duration(milliseconds: 140),
        curve: Curves.easeOutCubic,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  center: Alignment.topLeft,
                  radius: 0.9,
                  colors: [
                    widget.accentColor.withValues(alpha: 0.32),
                    widget.accentColor.withValues(alpha: 0.12),
                  ],
                ),
                border: Border.all(
                  color: widget.accentColor.withValues(
                    alpha: widget.isActive ? 0.95 : 0.65,
                  ),
                  width: widget.isActive ? 1.8 : 1.2,
                ),
                boxShadow: [
                  BoxShadow(
                    color: widget.accentColor.withValues(alpha: 0.35),
                    blurRadius: 14,
                    spreadRadius: -2,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              alignment: Alignment.center,
              child: Icon(
                widget.icon,
                size: 21,
                color: widget.isActive
                    ? Colors.white
                    : widget.accentColor.withValues(alpha: 0.95),
              ),
            ),
            const SizedBox(height: 7),
            Text(
              widget.label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: isDark ? const Color(0xFFE2E8F0) : const Color(0xFF334155),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Fila de menú estilo iOS Liquid Glass
class _GlassMenuRow extends StatefulWidget {
  final IconData icon;
  final Color accent;
  final String title;
  final String? subtitle;
  final String? trailingBadge;
  final bool isHighlight;
  final VoidCallback onTap;

  const _GlassMenuRow({
    required this.icon,
    required this.accent,
    required this.title,
    this.subtitle,
    this.trailingBadge,
    this.isHighlight = false,
    required this.onTap,
  });

  @override
  State<_GlassMenuRow> createState() => _GlassMenuRowState();
}

class _GlassMenuRowState extends State<_GlassMenuRow> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isLandscape = MediaQuery.of(context).orientation == Orientation.landscape;

    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) => setState(() => _pressed = false),
      onTapCancel: () => setState(() => _pressed = false),
      onTap: widget.onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 140),
        padding: EdgeInsets.symmetric(horizontal: 8, vertical: isLandscape ? 4 : 9),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          color: _pressed
              ? (isDark
                  ? Colors.white.withValues(alpha: 0.08)
                  : Colors.black.withValues(alpha: 0.05))
              : Colors.transparent,
        ),
        child: Row(
          children: [
            // Icono con contenedor de cristal
            Container(
              width: isLandscape ? 28 : 36,
              height: isLandscape ? 28 : 36,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(isLandscape ? 8 : 10),
                color: widget.accent.withValues(alpha: 0.16),
                border: Border.all(
                  color: widget.accent.withValues(alpha: 0.42),
                  width: 1.0,
                ),
                boxShadow: [
                  BoxShadow(
                    color: widget.accent.withValues(alpha: 0.22),
                    blurRadius: 10,
                    spreadRadius: -2,
                  ),
                ],
              ),
              alignment: Alignment.center,
              child: Icon(widget.icon, size: isLandscape ? 15 : 19, color: widget.accent),
            ),
            SizedBox(width: isLandscape ? 10 : 14),

            // Textos
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.title,
                    style: TextStyle(
                      fontSize: isLandscape ? 12.5 : 14.5,
                      fontWeight: FontWeight.w600,
                      color: widget.isHighlight
                          ? (isDark ? const Color(0xFFF0ABFC) : const Color(0xFFC026D3))
                          : (isDark ? const Color(0xFFF1F5F9) : const Color(0xFF0F172A)),
                      letterSpacing: -0.1,
                    ),
                  ),
                  if (widget.subtitle != null) ...[
                    const SizedBox(height: 1),
                    Text(
                      widget.subtitle!,
                      style: TextStyle(
                        fontSize: isLandscape ? 10.0 : 11.5,
                        color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                      ),
                    ),
                  ],
                ],
              ),
            ),

            // Badge opcional (ej: ACTIVO / ON)
            if (widget.trailingBadge != null) ...[
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: widget.accent.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: widget.accent.withValues(alpha: 0.5),
                    width: 0.8,
                  ),
                ),
                child: Text(
                  widget.trailingBadge!,
                  style: TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.bold,
                    color: widget.accent,
                  ),
                ),
              ),
              const SizedBox(width: 6),
            ],

            // Chevron iOS
            Icon(
              Icons.chevron_right_rounded,
              size: 19,
              color: isDark ? Colors.white.withValues(alpha: 0.28) : Colors.black.withValues(alpha: 0.25),
            ),
          ],
        ),
      ),
    );
  }
}

/// Botón circular secundario de vidrio
class _GlassCircleButton extends StatefulWidget {
  final IconData icon;
  final double size;
  final VoidCallback onTap;

  const _GlassCircleButton({
    required this.icon,
    required this.size,
    required this.onTap,
  });

  @override
  State<_GlassCircleButton> createState() => _GlassCircleButtonState();
}

class _GlassCircleButtonState extends State<_GlassCircleButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) => setState(() => _pressed = false),
      onTapCancel: () => setState(() => _pressed = false),
      onTap: widget.onTap,
      child: AnimatedScale(
        scale: _pressed ? 0.90 : 1.0,
        duration: const Duration(milliseconds: 140),
        child: Container(
          width: widget.size,
          height: widget.size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: isDark
                ? Colors.white.withValues(alpha: 0.08)
                : Colors.black.withValues(alpha: 0.06),
            border: Border.all(
              color: isDark
                  ? Colors.white.withValues(alpha: 0.15)
                  : Colors.black.withValues(alpha: 0.1),
              width: 0.8,
            ),
          ),
          alignment: Alignment.center,
          child: Icon(
            widget.icon,
            size: 19,
            color: isDark ? const Color(0xFFCBD5E1) : const Color(0xFF475569),
          ),
        ),
      ),
    );
  }
}

/// Botón secundario en píldora glass (Marcadores, Historial)
class _GlassSecondaryButton extends StatefulWidget {
  final IconData icon;
  final String label;
  final Color accent;
  final VoidCallback onTap;

  const _GlassSecondaryButton({
    required this.icon,
    required this.label,
    required this.accent,
    required this.onTap,
  });

  @override
  State<_GlassSecondaryButton> createState() => _GlassSecondaryButtonState();
}

class _GlassSecondaryButtonState extends State<_GlassSecondaryButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) => setState(() => _pressed = false),
      onTapCancel: () => setState(() => _pressed = false),
      onTap: widget.onTap,
      child: AnimatedScale(
        scale: _pressed ? 0.96 : 1.0,
        duration: const Duration(milliseconds: 140),
        child: Container(
          height: 46,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(15),
            color: isDark
                ? Colors.white.withValues(alpha: 0.06)
                : Colors.black.withValues(alpha: 0.04),
            border: Border.all(
              color: isDark
                  ? Colors.white.withValues(alpha: 0.12)
                  : Colors.black.withValues(alpha: 0.08),
              width: 0.8,
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(widget.icon, size: 18, color: widget.accent),
              const SizedBox(width: 8),
              Text(
                widget.label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: isDark ? const Color(0xFFF1F5F9) : const Color(0xFF0F172A),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

