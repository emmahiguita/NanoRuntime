// nano_drawer_modal_overlay.dart — Capa modal animada con scrim para el Navigation Drawer.
// QUÉ HACE: Presenta el Navigation Drawer como un modal lateral deslizante con telón scrim oscuro.
// CÓMO FUNCIONA: Aloja un AnimationController para la entrada deslizante y fade del scrim.
// POR QUÉ: Mantiene desacoplada la presentación modal del contenido del drawer (< 150 líneas).
library;

import 'package:flutter/material.dart';
import '../../router/app_router.dart';
import 'nano_destination.dart';
import 'nano_m3_navigation_drawer.dart';

class NanoDrawerModalOverlay extends StatefulWidget {
  const NanoDrawerModalOverlay({
    super.key,
    required this.isOpen,
    required this.selected,
    required this.onClose,
    required this.onDestinationSelected,
    required this.onConvertToBottomBar,
    required this.onOpenSearch,
    this.onOpenBrowser,
    this.onOpenVoice,
  });

  final bool isOpen;
  final NanoDestination selected;
  final VoidCallback onClose;
  final ValueChanged<NanoDestination> onDestinationSelected;
  final VoidCallback onConvertToBottomBar;
  final VoidCallback onOpenSearch;
  final VoidCallback? onOpenBrowser;
  final VoidCallback? onOpenVoice;

  @override
  State<NanoDrawerModalOverlay> createState() => _NanoDrawerModalOverlayState();
}

class _NanoDrawerModalOverlayState extends State<NanoDrawerModalOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _slideAnimation;
  late final Animation<double> _scrimAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 260),
    );
    _slideAnimation = Tween<double>(
      begin: -1.0,
      end: 0.0,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic));
    _scrimAnimation = Tween<double>(
      begin: 0.0,
      end: 0.45,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.linear));

    if (widget.isOpen) {
      _controller.value = 1.0;
    }
  }

  @override
  void didUpdateWidget(covariant NanoDrawerModalOverlay oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isOpen != oldWidget.isOpen) {
      if (widget.isOpen) {
        _controller.forward();
      } else {
        _controller.reverse();
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final disableAnimations = MediaQuery.disableAnimationsOf(context);
    if (disableAnimations) {
      _controller.value = widget.isOpen ? 1.0 : 0.0;
    }

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        if (_controller.value == 0.0 && !widget.isOpen) {
          return const SizedBox.shrink();
        }

        return Positioned.fill(
          child: Stack(
            children: [
              // Telón scrim semitransparente con tap para cerrar
              Positioned.fill(
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: widget.onClose,
                  child: Container(
                    color: Colors.black.withValues(
                      alpha: _scrimAnimation.value,
                    ),
                  ),
                ),
              ),
              // Panel Drawer lateral deslizante desde la izquierda
              Positioned(
                left: 0,
                top: 0,
                bottom: 0,
                child: FractionalTranslation(
                  translation: Offset(_slideAnimation.value, 0.0),
                  child: NanoM3NavigationDrawer(
                    selected: widget.selected,
                    onDestinationSelected: widget.onDestinationSelected,
                    onCloseDrawer: widget.onClose,
                    onConvertToBottomBar: widget.onConvertToBottomBar,
                    onOpenSearch: widget.onOpenSearch,
                    onOpenChat: () => AppRouter.router.push('/chat'),
                    onOpenBrowser: widget.onOpenBrowser ??
                        () => AppRouter.router.push('/browser'),
                    onOpenWhatsApp: () =>
                        AppRouter.router.push('/automation/messages'),
                    onOpenMcp: () =>
                        AppRouter.router.push('/automation/skills-mcp'),
                    onOpenAiWeb: null,
                    onOpenDesktop: () =>
                        AppRouter.router.push('/desktop'),
                    onOpenDatabase: () =>
                        AppRouter.router.push('/database'),
                    onOpenAccount: () =>
                        AppRouter.router.push('/account'),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
