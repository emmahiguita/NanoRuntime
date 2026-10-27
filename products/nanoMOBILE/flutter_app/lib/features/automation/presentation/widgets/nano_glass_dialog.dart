// nano_glass_dialog.dart
//
// QUÉ HACE:
// Contenedor modal profesional con diseño iOS Frosted Glass, borde metálico reflectante,
// compatibilidad fluida en orientación vertical y horizontal, y tipografía de alta jerarquía.
//
// CÓMO FUNCIONA:
// - Despliega un modal con GlassSurface (desenfoque gaussiano y fondo translúcido iOS).
// - Aplica borde metálico con gradiente especular (luz superior blanca/plata).
// - Calcula límites adaptativos en orientación horizontal para evitar desbordamientos.
//
// POR QUÉ:
// Estandariza la experiencia visual de todos los diálogos y modales de la aplicación bajo SOLID.

import 'package:flutter/material.dart';
import 'package:nanoai/core/widgets/glass_surface.dart';
import '../../../../core/theme/nano_transitions.dart';
import 'nano_glass_dialog_header.dart';

class NanoGlassDialog extends StatelessWidget {
  final String title;
  final String? subtitle;
  final IconData? icon;
  final Color? iconColor;
  final Widget content;
  final List<Widget>? actions;
  final VoidCallback? onClose;

  const NanoGlassDialog({
    super.key,
    required this.title,
    this.subtitle,
    this.icon,
    this.iconColor,
    required this.content,
    this.actions,
    this.onClose,
  });

  /// Método estático de conveniencia para mostrar el diálogo con animación nativa.
  static Future<T?> show<T>({
    required BuildContext context,
    required String title,
    String? subtitle,
    IconData? icon,
    Color? iconColor,
    required Widget content,
    List<Widget>? actions,
    List<Widget> Function(BuildContext dialogContext)? actionsBuilder,
  }) {
    return showNanoModalDialog<T>(
      context: context,
      builder: (ctx) => NanoGlassDialog(
        title: title,
        subtitle: subtitle,
        icon: icon,
        iconColor: iconColor,
        content: content,
        // El contexto pertenece a la ruta modal, no a un Navigator anterior.
        actions: actionsBuilder?.call(ctx) ?? actions,
        onClose: () => Navigator.of(ctx).pop(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final isLandscape = media.orientation == Orientation.landscape;

    final dialogWidth = isLandscape
        ? (media.size.width * 0.60).clamp(320.0, 500.0)
        : (media.size.width * 0.90).clamp(280.0, 420.0);

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
      elevation: 0,
      child: Center(
        // Sin estos factores Center expandía todo el diálogo hasta la ventana.
        widthFactor: 1,
        heightFactor: 1,
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: dialogWidth,
            maxHeight: isLandscape
                ? media.size.height * 0.88
                : media.size.height * 0.80,
          ),
          child: GlassSurface(
            width: dialogWidth,
            radius: 22,
            blur: 24,
            opacity: .68,
            clarity: .88,
            intensity: .72,
            depth: 1.3,
            interactive: false,
            padding: EdgeInsets.zero,
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  NanoGlassDialogHeader(
                    title: title,
                    subtitle: subtitle,
                    icon: icon,
                    iconColor: iconColor,
                    onClose: onClose,
                  ),
                  const SizedBox(height: 16),
                  content,
                  if (actions != null && actions!.isNotEmpty) ...[
                    const SizedBox(height: 20),
                    OverflowBar(
                      alignment: MainAxisAlignment.end,
                      spacing: 10,
                      overflowSpacing: 8,
                      children: actions!,
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
