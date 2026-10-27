// model_floating_dialog_route.dart — Ruta modal para la ventana flotante 3D de modelos.
// QUÉ HACE: Abre la ventana flotante en el centro de la pantalla con oscurecimiento y vuelo 3D Hero.
// CÓMO FUNCIONA: PageRouteBuilder con opaque: false, barrera oscura interactiva y curva de entrada.
// POR QUÉ: Reemplaza la sábana inferior con una ventana flotante cinematográfica (< 110 líneas).
library;

import 'dart:ui';
import 'package:flutter/material.dart';
import 'model_3d_flip_flight.dart';
import 'model_catalog_types.dart';
import 'model_floating_window.dart';

class ModelFloatingDialogRoute {
  static void show(
    BuildContext context, {
    required UnifiedModelItem item,
    required bool isActive,
    bool isFavorite = false,
    VoidCallback? onUse,
    VoidCallback? onDownload,
    VoidCallback? onCancel,
    VoidCallback? onUnload,
    VoidCallback? onDelete,
    VoidCallback? onToggleFavorite,
    VoidCallback? onCompare,
    VoidCallback? onShare,
  }) {
    final capturedThemes = InheritedTheme.capture(
      from: context,
      to: Navigator.of(context, rootNavigator: true).context,
    );

    Navigator.of(context, rootNavigator: true).push(
      PageRouteBuilder<void>(
        opaque: false,
        barrierDismissible: true,
        barrierColor: Colors.transparent,
        transitionDuration: const Duration(milliseconds: 520),
        reverseTransitionDuration: const Duration(milliseconds: 420),
        pageBuilder: (dialogContext, animation, secondaryAnimation) {
          return capturedThemes.wrap(
            Stack(
              fit: StackFit.expand,
              children: [
                // Fondo oscurecido con desenfoque de cristal para máxima profundidad
                GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => Navigator.of(dialogContext).pop(),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
                    child: Container(
                      color: Colors.black.withValues(alpha: 0.68),
                    ),
                  ),
                ),
                // Ventana flotante en el centro con transición Hero 3D Card Flip
                SafeArea(
                  child: Center(
                    child: Hero(
                      tag: 'model-card-${item.name}',
                      createRectTween: (begin, end) {
                        return MaterialRectCenterArcTween(
                          begin: begin,
                          end: end,
                        );
                      },
                      flightShuttleBuilder: model3DCardFlipFlight,
                      child: Material(
                        color: Colors.transparent,
                        child: ModelFloatingWindow(
                          item: item,
                          isActive: isActive,
                          isFavorite: isFavorite,
                          onUse: onUse,
                          onDownload: onDownload,
                          onCancel: onCancel,
                          onUnload: onUnload,
                          onDelete: onDelete,
                          onToggleFavorite: onToggleFavorite,
                          onCompare: onCompare,
                          onShare: onShare,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(
            opacity: CurvedAnimation(
              parent: animation,
              curve: Curves.easeOutCubic,
            ),
            child: child,
          );
        },
      ),
    );
  }
}
