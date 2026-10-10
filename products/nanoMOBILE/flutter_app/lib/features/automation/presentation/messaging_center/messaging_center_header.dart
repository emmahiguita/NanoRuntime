import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/design_tokens.dart';
import 'messaging_center_providers.dart';
import 'messaging_channel_sheet.dart';
import '../whatsapp_web/whatsapp_web_screen.dart';

/// Encabezado principal del Centro de Mensajería con estilo iOS Glassed,
/// título tipográfico limpio, indicador de cuentas/no leídos y botones de acción translúcidos.
class MessagingCenterHeader extends ConsumerWidget {
  final VoidCallback? onConnectApp;
  final VoidCallback? onOpenLibrary;

  const MessagingCenterHeader({
    super.key,
    this.onConnectApp,
    this.onOpenLibrary,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final colors = NanoThemeExtension.of(context).colors;
    final unreadCount = ref.watch(pendingRepliesCountProvider);
    final canPop = Navigator.of(context).canPop();

    final unreadText = unreadCount > 0 ? '$unreadCount sin leer' : 'Al día';

    return Hero(
      tag: 'nano_messaging_hero',
      child: Material(
        type: MaterialType.transparency,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            if (canPop) ...[
              Semantics(
                label: 'Volver',
                button: true,
                child: _IosGlassIconButton(
                  icon: Icons.arrow_back_ios_new_rounded,
                  size: 38,
                  iconSize: 18,
                  onTap: () => Navigator.of(context).maybePop(),
                ),
              ),
              const SizedBox(width: 8),
            ],
            // Título principal y estado de no leídos estilo iOS
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Mensajes',
                    style: TextStyle(
                      color: isDark ? Colors.white : const Color(0xFF0F172A),
                      fontSize: 27,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.7,
                      height: 1.1,
                    ),
                  ),
                  const SizedBox(height: 1.5),
                  Row(
                    children: [
                      Text(
                        'Todas tus cuentas',
                        style: TextStyle(
                          color: isDark
                              ? Colors.white60
                              : const Color(0xFF64748B),
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(width: 5),
                      Text(
                        '·',
                        style: TextStyle(
                          color: isDark
                              ? Colors.white38
                              : const Color(0xFF94A3B8),
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(width: 5),
                      Container(
                        width: 6,
                        height: 6,
                        decoration: BoxDecoration(
                          color: colors.primary,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: colors.primary.withValues(alpha: 0.45),
                              blurRadius: 3,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 4.5),
                      Text(
                        unreadText,
                        style: TextStyle(
                          color: isDark
                              ? colors.primary
                              : colors.onSurfaceVariant,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            // Botones de acción translúcidos iOS Frosted Glass compactos
            _IosGlassIconButton(
              icon: Icons.public_rounded,
              size: 34,
              iconSize: 18,
              tooltip: 'WhatsApp Web Mobile',
              onTap: () => WhatsAppWebScreen.navigateTo(context),
            ),
            const SizedBox(width: 6),
            if (onOpenLibrary != null) ...[
              _IosGlassIconButton(
                icon: Icons.folder_open_rounded,
                size: 34,
                iconSize: 17,
                tooltip: 'Biblioteca PDF',
                onTap: onOpenLibrary!,
              ),
              const SizedBox(width: 6),
            ],
            _IosGlassIconButton(
              icon: Icons.edit_square,
              size: 34,
              iconSize: 16,
              tooltip: 'Gestionar Canales',
              onTap:
                  onConnectApp ?? () => showMessagingChannelSheet(context, ref),
            ),
          ],
        ),
      ),
    );
  }
}

/// Botón circular con efecto iOS Frosted Glass, borde translúcido y feedback táctil suave.
class _IosGlassIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final String? tooltip;
  final double size;
  final double iconSize;

  const _IosGlassIconButton({
    required this.icon,
    required this.onTap,
    this.tooltip,
    this.size = 34,
    this.iconSize = 17,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final glassBg = isDark
        ? const Color(0xFF1E293B).withValues(alpha: 0.48)
        : Colors.white.withValues(alpha: 0.45);
    final glassBorder = isDark
        ? Colors.white.withValues(alpha: 0.15)
        : Colors.white.withValues(alpha: 0.66);
    final iconColor = isDark ? Colors.white70 : const Color(0xFF334155);

    final button = Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(size / 2),
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            color: glassBg,
            shape: BoxShape.circle,
            border: Border.all(color: glassBorder, width: 1.2),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.25 : 0.05),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Center(
            child: Icon(icon, size: iconSize, color: iconColor),
          ),
        ),
      ),
    );

    if (tooltip != null) {
      return Tooltip(message: tooltip!, child: button);
    }
    return button;
  }
}
