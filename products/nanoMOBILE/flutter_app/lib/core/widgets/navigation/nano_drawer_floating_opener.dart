import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';

/// Control superior único: al tocar abre el drawer y al arrastrar restaura el dock.
class NanoDrawerFloatingOpener extends StatefulWidget {
  const NanoDrawerFloatingOpener({
    super.key,
    required this.onOpen,
    required this.onRestore,
  });
  final VoidCallback onOpen;
  final VoidCallback onRestore;

  /// Conserva el desplazamiento solo durante el gesto, sin crear otro overlay.
  @override
  State<NanoDrawerFloatingOpener> createState() =>
      _NanoDrawerFloatingOpenerState();
}

class _NanoDrawerFloatingOpenerState extends State<NanoDrawerFloatingOpener> {
  Offset _offset = Offset.zero;
  Offset? _lastGlobal;

  /// Suelta el control en el borde inferior para volver a la barra existente.
  @override
  Widget build(BuildContext context) => MergeSemantics(
    child: Semantics(
      customSemanticsActions: {
        const CustomSemanticsAction(label: 'Volver a la barra inferior'):
            widget.onRestore,
      },
      child: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onPanStart: (_) {
          _lastGlobal = null;
        },
        onPanUpdate: (details) => setState(() {
          _offset += details.delta;
          _lastGlobal = details.globalPosition;
        }),
        onPanCancel: () => setState(() {
          _offset = Offset.zero;
          _lastGlobal = null;
        }),
        onPanEnd: (_) {
          final position = _lastGlobal;
          final height = MediaQuery.sizeOf(context).height;
          setState(() {
            _offset = Offset.zero;
            _lastGlobal = null;
          });
          if (position != null &&
              position.dy >= height - (height * .15).clamp(64.0, 120.0)) {
            HapticFeedback.selectionClick();
            widget.onRestore();
          }
        },
        child: Transform.translate(
          offset: _offset,
          child: IconButton(
            tooltip: 'Abrir navegación lateral',
            constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
            icon: const Icon(CupertinoIcons.sidebar_right, size: 20),
            onPressed: () {
              HapticFeedback.lightImpact();
              widget.onOpen();
            },
          ),
        ),
      ),
    ),
  );
}

/// Conserva el acceso existente en rutas fuera del shell que no tienen dock.
class NanoDrawerOutsideShell extends StatelessWidget {
  const NanoDrawerOutsideShell({
    super.key,
    required this.location,
    required this.visible,
    required this.onRight,
    required this.onOpen,
    required this.onRestore,
  });
  final String location;
  final bool visible;
  final bool onRight;
  final VoidCallback onOpen;
  final VoidCallback onRestore;

  /// Las rutas del shell usan su propia franja y no duplican este control.
  @override
  Widget build(BuildContext context) {
    final path = Uri.tryParse(location)?.path ?? location;
    const shellPaths = {'/dashboard', '/automation'};
    if (!visible || shellPaths.contains(path)) return const SizedBox.shrink();
    return Positioned(
      left: onRight ? null : 14,
      right: onRight ? 14 : null,
      top: MediaQuery.paddingOf(context).top + 8,
      child: NanoDrawerFloatingOpener(onOpen: onOpen, onRestore: onRestore),
    );
  }
}
