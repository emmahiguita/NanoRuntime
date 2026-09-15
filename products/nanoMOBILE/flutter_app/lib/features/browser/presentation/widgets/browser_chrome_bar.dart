import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:nanoai/features/browser/domain/browser_tab_model.dart';

/// Barra de navegación superior del Navegador Web (Chrome Bar).
/// Sigue principios SOLID (Single Responsibility) y estilo Glassmorphism iOS hiperrealista.
class BrowserChromeBar extends StatelessWidget {
  final BrowserTabModel tab;
  final int tabCount;
  final TextEditingController urlCtrl;
  final FocusNode urlFocus;
  final bool isDark;
  final dynamic colors;
  final bool isEmbedded;
  final bool isMinimized;
  final bool showTabBar;
  final VoidCallback onGoBack;
  final VoidCallback onGoForward;
  final VoidCallback onReload;
  final ValueChanged<String> onUrlSubmitted;
  final VoidCallback onSslTap;
  final VoidCallback onToggleTabBar;
  final VoidCallback? onToggleMinimize;
  final VoidCallback? onOpenFullscreen;
  final ValueChanged<String> onMenuAction;

  const BrowserChromeBar({
    super.key,
    required this.tab,
    required this.tabCount,
    required this.urlCtrl,
    required this.urlFocus,
    required this.isDark,
    required this.colors,
    this.isEmbedded = false,
    this.isMinimized = false,
    this.showTabBar = false,
    required this.onGoBack,
    required this.onGoForward,
    required this.onReload,
    required this.onUrlSubmitted,
    required this.onSslTap,
    required this.onToggleTabBar,
    this.onToggleMinimize,
    this.onOpenFullscreen,
    required this.onMenuAction,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 52,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xE80D1E2E) : const Color(0xECE8EEF5),
        border: Border(
          bottom: BorderSide(
            color: isDark
                ? Colors.white.withValues(alpha: 0.10)
                : Colors.black.withValues(alpha: 0.07),
            width: 0.8,
          ),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // 1. Atrás
          _NavButton(
            icon: Icons.arrow_back_rounded,
            size: 20,
            enabled: tab.canGoBack,
            isDark: isDark,
            onTap: onGoBack,
          ),
          const SizedBox(width: 2),

          // 2. Adelante
          _NavButton(
            icon: Icons.arrow_forward_rounded,
            size: 20,
            enabled: tab.canGoForward,
            isDark: isDark,
            onTap: onGoForward,
          ),
          const SizedBox(width: 2),

          // 3. Recargar / Detener
          _NavButton(
            icon: tab.isLoading ? Icons.close_rounded : Icons.refresh_rounded,
            size: 20,
            enabled: true,
            isDark: isDark,
            onTap: onReload,
          ),
          const SizedBox(width: 6),

          // 4. Barra de Dirección (Píldora Glass iOS)
          Expanded(
            child: _UrlBar(
              urlCtrl: urlCtrl,
              urlFocus: urlFocus,
              tab: tab,
              colors: colors,
              isDark: isDark,
              onSubmit: onUrlSubmitted,
              onSslTap: onSslTap,
            ),
          ),
          const SizedBox(width: 6),

          // 5. Contador de Pestañas
          GestureDetector(
            onTap: onToggleTabBar,
            child: _TabBadge(
              count: tabCount,
              isDark: isDark,
            ),
          ),
          const SizedBox(width: 2),

          // 6. Menú desplegable (3 puntos)
          _BrowserMenu(
            showTabBar: showTabBar,
            isDark: isDark,
            isEmbedded: isEmbedded,
            isMinimized: isMinimized,
            onSelected: onMenuAction,
          ),
        ],
      ),
    );
  }
}

// ── Barra de Dirección Estilo Píldora Glass ─────────────────────────────────

class _UrlBar extends StatefulWidget {
  final TextEditingController urlCtrl;
  final FocusNode urlFocus;
  final BrowserTabModel tab;
  final dynamic colors;
  final bool isDark;
  final ValueChanged<String> onSubmit;
  final VoidCallback onSslTap;

  const _UrlBar({
    required this.urlCtrl,
    required this.urlFocus,
    required this.tab,
    required this.colors,
    required this.isDark,
    required this.onSubmit,
    required this.onSslTap,
  });

  @override
  State<_UrlBar> createState() => _UrlBarState();
}

class _UrlBarState extends State<_UrlBar> {
  @override
  void initState() {
    super.initState();
    widget.urlFocus.addListener(_onFocusChange);
  }

  @override
  void dispose() {
    widget.urlFocus.removeListener(_onFocusChange);
    super.dispose();
  }

  void _onFocusChange() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final isSecure = widget.tab.isSecure;
    final hasFocus = widget.urlFocus.hasFocus;

    return ClipRRect(
      borderRadius: BorderRadius.circular(19),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOutCubic,
          height: 38,
          decoration: BoxDecoration(
            color: widget.isDark
                ? (hasFocus
                    ? const Color(0xFF0F1E2E)
                    : const Color(0xFF081420).withValues(alpha: 0.85))
                : (hasFocus
                    ? Colors.white
                    : Colors.white.withValues(alpha: 0.75)),
            borderRadius: BorderRadius.circular(19),
            border: Border.all(
              color: widget.isDark
                  ? (hasFocus
                      ? const Color(0xFF10B981)
                      : const Color(0xFF10B981).withValues(alpha: 0.40))
                  : (hasFocus
                      ? const Color(0xFF1D6FE8)
                      : const Color(0xFF1D6FE8).withValues(alpha: 0.35)),
              width: hasFocus ? 1.2 : 0.9,
            ),
            boxShadow: hasFocus
                ? [
                    BoxShadow(
                      color: const Color(0xFF10B981).withValues(alpha: 0.25),
                      blurRadius: 10,
                      spreadRadius: -1,
                    )
                  ]
                : null,
          ),
          padding: const EdgeInsets.symmetric(horizontal: 10),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Candado SSL
              GestureDetector(
                onTap: widget.onSslTap,
                child: Icon(
                  isSecure ? Icons.lock_rounded : Icons.lock_open_rounded,
                  size: 14,
                  color: isSecure
                      ? const Color(0xFF00E676)
                      : const Color(0xFFEF4444),
                ),
              ),
              const SizedBox(width: 8),

              // Campo de texto de URL
              Expanded(
                child: TextField(
                  controller: widget.urlCtrl,
                  focusNode: widget.urlFocus,
                  keyboardType: TextInputType.url,
                  textInputAction: TextInputAction.go,
                  onSubmitted: widget.onSubmit,
                  textAlignVertical: TextAlignVertical.center,
                  maxLines: 1,
                  cursorColor: const Color(0xFF10B981),
                  cursorWidth: 1.8,
                  cursorRadius: const Radius.circular(1),
                  style: TextStyle(
                    fontSize: 13,
                    color: widget.isDark ? Colors.white : Colors.black87,
                    fontFamily: 'Inter',
                    fontWeight: FontWeight.w400,
                    letterSpacing: 0.1,
                  ),
                  onTap: () {
                    if (widget.urlCtrl.text.isNotEmpty) {
                      widget.urlCtrl.selection = TextSelection(
                        baseOffset: 0,
                        extentOffset: widget.urlCtrl.text.length,
                      );
                    }
                  },
                  decoration: InputDecoration(
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    disabledBorder: InputBorder.none,
                    errorBorder: InputBorder.none,
                    focusedErrorBorder: InputBorder.none,
                    filled: false,
                    fillColor: Colors.transparent,
                    isCollapsed: true,
                    contentPadding: EdgeInsets.zero,
                    hintText: 'Buscar o ingresar dirección web',
                    hintStyle: TextStyle(
                      fontSize: 12,
                      color: widget.isDark ? Colors.white38 : Colors.black38,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Botón de Navegación ─────────────────────────────────────────────────────

class _NavButton extends StatelessWidget {
  final IconData icon;
  final double size;
  final bool enabled;
  final bool isDark;
  final VoidCallback onTap;

  const _NavButton({
    required this.icon,
    required this.size,
    required this.enabled,
    required this.isDark,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: enabled ? onTap : null,
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.all(6),
        child: Icon(
          icon,
          size: size,
          color: enabled
              ? (isDark ? Colors.white.withValues(alpha: 0.85) : Colors.black87)
              : (isDark ? Colors.white.withValues(alpha: 0.25) : Colors.black26),
        ),
      ),
    );
  }
}

// ── Badge de Contador de Pestañas ───────────────────────────────────────────

class _TabBadge extends StatelessWidget {
  final int count;
  final bool isDark;

  const _TabBadge({
    required this.count,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 22,
      height: 22,
      decoration: BoxDecoration(
        color: isDark
            ? Colors.white.withValues(alpha: 0.05)
            : Colors.black.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.38)
              : Colors.black.withValues(alpha: 0.38),
          width: 1.1,
        ),
      ),
      alignment: Alignment.center,
      child: Text(
        '$count',
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: isDark ? Colors.white.withValues(alpha: 0.85) : Colors.black87,
        ),
      ),
    );
  }
}

// ── Menú de 3 Puntos ────────────────────────────────────────────────────────

class _BrowserMenu extends StatelessWidget {
  final bool showTabBar;
  final bool isDark;
  final bool isEmbedded;
  final bool isMinimized;
  final ValueChanged<String> onSelected;

  const _BrowserMenu({
    required this.showTabBar,
    required this.isDark,
    required this.isEmbedded,
    required this.isMinimized,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<String>(
      onSelected: onSelected,
      icon: Icon(
        Icons.more_vert_rounded,
        size: 20,
        color: isDark ? Colors.white.withValues(alpha: 0.85) : Colors.black87,
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      itemBuilder: (_) => [
        const PopupMenuItem(
          value: 'ask_owl',
          child: Row(children: [
            Icon(Icons.auto_awesome, size: 16, color: Color(0xFF10B981)),
            SizedBox(width: 8),
            Text('Preguntar al Búho IA', style: TextStyle(fontSize: 13)),
          ]),
        ),
        const PopupMenuItem(
          value: 'new_tab',
          child: Row(children: [
            Icon(Icons.add_rounded, size: 16),
            SizedBox(width: 8),
            Text('Nueva pestaña', style: TextStyle(fontSize: 13)),
          ]),
        ),
        PopupMenuItem(
          value: 'toggle_tabs',
          child: Row(children: [
            const Icon(Icons.tab_rounded, size: 16),
            const SizedBox(width: 8),
            Text(showTabBar ? 'Ocultar pestañas' : 'Ver pestañas',
                style: const TextStyle(fontSize: 13)),
          ]),
        ),
        if (isEmbedded) ...[
          const PopupMenuDivider(),
          PopupMenuItem(
            value: 'toggle_minimize',
            child: Row(children: [
              Icon(
                isMinimized
                    ? Icons.unfold_more_rounded
                    : Icons.unfold_less_rounded,
                size: 16,
              ),
              const SizedBox(width: 8),
              Text(isMinimized ? 'Expandir ventana' : 'Minimizar ventana',
                  style: const TextStyle(fontSize: 13)),
            ]),
          ),
          const PopupMenuItem(
            value: 'fullscreen',
            child: Row(children: [
              Icon(Icons.open_in_full_rounded, size: 16),
              SizedBox(width: 8),
              Text('Pantalla completa', style: TextStyle(fontSize: 13)),
            ]),
          ),
        ],
        const PopupMenuDivider(),
        const PopupMenuItem(
          value: 'copy_url',
          child: Row(children: [
            Icon(Icons.copy_rounded, size: 16),
            SizedBox(width: 8),
            Text('Copiar enlace', style: TextStyle(fontSize: 13)),
          ]),
        ),
        const PopupMenuItem(
          value: 'share',
          child: Row(children: [
            Icon(Icons.share_rounded, size: 16),
            SizedBox(width: 8),
            Text('Compartir página', style: TextStyle(fontSize: 13)),
          ]),
        ),
        const PopupMenuItem(
          value: 'clear_cache',
          child: Row(children: [
            Icon(Icons.cleaning_services_rounded, size: 16),
            SizedBox(width: 8),
            Text('Limpiar caché', style: TextStyle(fontSize: 13)),
          ]),
        ),
      ],
    );
  }
}
