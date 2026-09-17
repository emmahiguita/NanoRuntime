import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/design_tokens.dart';
import '../../application/browser_pip_notifier.dart';
import '../../domain/browser_pip_model.dart';
import '../../domain/browser_url_resolver.dart';
import '../../infrastructure/browser_scripts.dart';
import '../../infrastructure/browser_security_firewall.dart';

/// Superficie multimedia global. Vive por encima del router para continuar
/// visible en Chat, Modelos, Terminal, Ajustes y rutas globales.
class BrowserPipOverlay extends ConsumerStatefulWidget {
  const BrowserPipOverlay({super.key});

  @override
  ConsumerState<BrowserPipOverlay> createState() => _BrowserPipOverlayState();
}

class _BrowserPipOverlayState extends ConsumerState<BrowserPipOverlay> {
  Offset? _dragOrigin;
  Size? _resizeOrigin;
  Offset? _dragStartGlobal;
  Offset? _resizeStartGlobal;

  @override
  Widget build(BuildContext context) {
    final pip = ref.watch(browserPipProvider);
    if (!pip.isActive) return const SizedBox.shrink();

    final notifier = ref.read(browserPipProvider.notifier);
    final screen = MediaQuery.sizeOf(context);
    if (pip.isSystemPip) {
      return Positioned.fill(
        child: ColoredBox(
          color: Colors.black,
          child: _PipWebView(pip: pip, notifier: notifier),
        ),
      );
    }

    if (pip.isMaximized) {
      return Positioned.fill(
        child: Material(
          color: const Color(0xFF020711),
          child: SafeArea(
            child: _PipSurface(
              pip: pip,
              notifier: notifier,
              maximized: true,
              onDragStart: null,
              onDragUpdate: null,
              onResizeStart: null,
              onResizeUpdate: null,
            ),
          ),
        ),
      );
    }

    final size = Size(
      pip.size.width.clamp(240, screen.width - 16),
      pip.size.height.clamp(250, screen.height - 80),
    );
    final left = pip.position.dx
        .clamp(8, screen.width - size.width - 8)
        .toDouble();
    final top = pip.position.dy
        .clamp(40, screen.height - size.height - 40)
        .toDouble();

    return Positioned(
      left: left,
      top: top,
      width: size.width,
      height: size.height,
      child: _PipSurface(
        pip: pip,
        notifier: notifier,
        maximized: false,
        onDragStart: (details) {
          _dragOrigin = pip.position;
          _dragStartGlobal = details.globalPosition;
        },
        onDragUpdate: (details) {
          final origin = _dragOrigin ?? pip.position;
          final start = _dragStartGlobal ?? details.globalPosition;
          notifier.updatePosition(
            origin + (details.globalPosition - start),
            screen,
          );
        },
        onResizeStart: (details) {
          _resizeOrigin = pip.size;
          _resizeStartGlobal = details.globalPosition;
        },
        onResizeUpdate: (details) {
          final origin = _resizeOrigin ?? pip.size;
          final start = _resizeStartGlobal ?? details.globalPosition;
          final delta = details.globalPosition - start;
          notifier.resizePip(
            Size(origin.width + delta.dx, origin.height + delta.dy),
            screen,
          );
        },
      ),
    );
  }
}

class _PipSurface extends StatelessWidget {
  const _PipSurface({
    required this.pip,
    required this.notifier,
    required this.maximized,
    required this.onDragStart,
    required this.onDragUpdate,
    required this.onResizeStart,
    required this.onResizeUpdate,
  });

  final BrowserPipState pip;
  final BrowserPipNotifier notifier;
  final bool maximized;
  final GestureDragStartCallback? onDragStart;
  final GestureDragUpdateCallback? onDragUpdate;
  final GestureDragStartCallback? onResizeStart;
  final GestureDragUpdateCallback? onResizeUpdate;

  @override
  Widget build(BuildContext context) {
    final colors = NanoThemeExtension.of(context).colors;
    final isDark = colors is NanoDarkColors;
    final radius = maximized ? 0.0 : 20.0;

    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: isDark ? const Color(0xF5081422) : const Color(0xF8F8FAFC),
            borderRadius: BorderRadius.circular(radius),
            border: maximized
                ? null
                : Border.all(
                    color: const Color(0xFF10B981).withValues(alpha: 0.7),
                    width: 1.2,
                  ),
            boxShadow: maximized
                ? null
                : [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.48),
                      blurRadius: 32,
                      offset: const Offset(0, 12),
                    ),
                    BoxShadow(
                      color: const Color(0xFF10B981).withValues(alpha: 0.18),
                      blurRadius: 22,
                      spreadRadius: -4,
                    ),
                  ],
          ),
          child: Stack(
            children: [
              Column(
                children: [
                  _PipHeader(
                    pip: pip,
                    notifier: notifier,
                    isDark: isDark,
                    maximized: maximized,
                    onDragStart: onDragStart,
                    onDragUpdate: onDragUpdate,
                  ),
                  Expanded(
                    child: _PipWebView(pip: pip, notifier: notifier),
                  ),
                ],
              ),
              if (!maximized)
                Positioned(
                  right: 0,
                  bottom: 0,
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onPanStart: onResizeStart,
                    onPanUpdate: onResizeUpdate,
                    child: const SizedBox(
                      width: 30,
                      height: 30,
                      child: Icon(
                        Icons.drag_handle_rounded,
                        size: 17,
                        color: Colors.white54,
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

class _PipHeader extends StatelessWidget {
  const _PipHeader({
    required this.pip,
    required this.notifier,
    required this.isDark,
    required this.maximized,
    required this.onDragStart,
    required this.onDragUpdate,
  });

  final BrowserPipState pip;
  final BrowserPipNotifier notifier;
  final bool isDark;
  final bool maximized;
  final GestureDragStartCallback? onDragStart;
  final GestureDragUpdateCallback? onDragUpdate;

  @override
  Widget build(BuildContext context) {
    final host = BrowserUrlResolver.extractHost(pip.url ?? '');
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onPanStart: onDragStart,
      onPanUpdate: onDragUpdate,
      child: Container(
        height: 44,
        padding: const EdgeInsets.only(left: 12, right: 4),
        color: isDark ? const Color(0xEE071522) : const Color(0xF2E8EEF5),
        child: Row(
          children: [
            Container(
              width: 9,
              height: 9,
              decoration: const BoxDecoration(
                color: Color(0xFF34D399),
                shape: BoxShape.circle,
                boxShadow: [BoxShadow(color: Color(0x8834D399), blurRadius: 8)],
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    pip.title?.trim().isNotEmpty == true
                        ? pip.title!
                        : 'Reproductor visible',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w700,
                      color: isDark ? Colors.white : Colors.black87,
                    ),
                  ),
                  Text(
                    host,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 9.5,
                      color: Color(0xFF34D399),
                    ),
                  ),
                ],
              ),
            ),
            if (pip.transferPending)
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 7),
                child: SizedBox.square(
                  dimension: 15,
                  child: CircularProgressIndicator(strokeWidth: 1.5),
                ),
              ),
            _HeaderButton(
              tooltip: pip.isPlaying ? 'Pausar' : 'Reproducir',
              icon: pip.isPlaying
                  ? Icons.pause_rounded
                  : Icons.play_arrow_rounded,
              accent: true,
              onTap: notifier.togglePlayPause,
            ),
            _HeaderButton(
              tooltip: 'Picture-in-Picture del sistema',
              icon: Icons.picture_in_picture_alt_rounded,
              onTap: () async {
                HapticFeedback.mediumImpact();
                final opened = await notifier.enterSystemPictureInPicture();
                if (!opened && context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text(
                        'Este dispositivo no admite PiP del sistema.',
                      ),
                    ),
                  );
                }
              },
            ),
            _HeaderButton(
              tooltip: maximized ? 'Restaurar' : 'Maximizar',
              icon: maximized
                  ? Icons.fullscreen_exit_rounded
                  : Icons.fullscreen_rounded,
              onTap: notifier.toggleMaximized,
            ),
            _HeaderButton(
              tooltip: 'Cerrar reproductor',
              icon: Icons.close_rounded,
              onTap: notifier.deactivatePip,
            ),
          ],
        ),
      ),
    );
  }
}

class _PipWebView extends StatelessWidget {
  const _PipWebView({required this.pip, required this.notifier});

  final BrowserPipState pip;
  final BrowserPipNotifier notifier;

  @override
  Widget build(BuildContext context) {
    final url = pip.url;
    if (url == null || url.isEmpty) {
      return const ColoredBox(
        color: Colors.black,
        child: Center(child: Text('Sin contenido multimedia')),
      );
    }

    return InAppWebView(
      key: ValueKey('pip_webview_${pip.activeTabId}'),
      initialUrlRequest: URLRequest(url: WebUri(url)),
      initialSettings: BrowserSecurityFirewall.defaultWebViewSettings,
      onWebViewCreated: notifier.attachPipController,
      onLoadStop: (controller, _) async {
        try {
          await controller.evaluateJavascript(
            source: BrowserScripts.mobileViewportAdapterScript,
          );
        } catch (_) {}
        await notifier.synchronizePipPlayback();
      },
      shouldOverrideUrlLoading: (controller, action) async {
        final target = action.request.url?.toString();
        if (target == null || !BrowserSecurityFirewall.isAllowedUrl(target)) {
          return NavigationActionPolicy.CANCEL;
        }
        return NavigationActionPolicy.ALLOW;
      },
      onPermissionRequest: (controller, request) async => PermissionResponse(
        resources: request.resources,
        action: PermissionResponseAction.DENY,
      ),
    );
  }
}

class _HeaderButton extends StatelessWidget {
  const _HeaderButton({
    required this.tooltip,
    required this.icon,
    required this.onTap,
    this.accent = false,
  });

  final String tooltip;
  final IconData icon;
  final VoidCallback onTap;
  final bool accent;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: tooltip,
      visualDensity: VisualDensity.compact,
      constraints: const BoxConstraints.tightFor(width: 34, height: 34),
      padding: EdgeInsets.zero,
      icon: Icon(
        icon,
        size: 18,
        color: accent ? const Color(0xFF34D399) : Colors.white70,
      ),
      onPressed: () {
        HapticFeedback.selectionClick();
        onTap();
      },
    );
  }
}
