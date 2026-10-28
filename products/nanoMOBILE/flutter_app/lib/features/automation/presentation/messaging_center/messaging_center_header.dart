import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nanoai/core/providers/settings_provider.dart';
import '../../../../core/theme/design_tokens.dart';
import '../business/meta_inbox_screen.dart';
import '../whatsapp_web/whatsapp_web_screen.dart';
import 'messaging_center_providers.dart';
import 'messaging_channel_sheet.dart';
import 'messaging_glass_icon_button.dart';
import 'messaging_theme_sheet.dart';

/// QUÉ HACE: Encabezado del Centro de Mensajería WhatsApp con diseño iOS Glassed.
/// CÓMO FUNCIONA: Usa FittedBox y Text.rich para eliminar desbordes horizontales (overflow).
/// POR QUÉ: Evita errores de "Right Overflowed" y permite alternar tema visual directamente.
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

    final currentThemeMode =
        ref.watch(settingsProvider.select((s) => s.themeMode));
    final (themeIcon, themeLabel, themeColor) = switch (currentThemeMode) {
      'Claro' => (Icons.wb_sunny_rounded, 'Modo Claro', const Color(0xFFF59E0B)),
      'Grisáceo' || 'Opaco' => (Icons.layers_rounded, 'Modo Grisáceo', const Color(0xFF38BDF8)),
      'Oscuro' => (Icons.dark_mode_rounded, 'Modo Oscuro', const Color(0xFF818CF8)),
      _ => (Icons.brightness_auto_rounded, 'Tema Sistema', const Color(0xFF10B981)),
    };

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
                child: IosGlassIconButton(
                  icon: Icons.arrow_back_ios_new_rounded,
                  size: 34,
                  iconSize: 16,
                  onTap: () => Navigator.of(context).maybePop(),
                ),
              ),
              const SizedBox(width: 6),
            ],
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'WhatsApp',
                      style: TextStyle(
                        color: isDark ? Colors.white : const Color(0xFF0F172A),
                        fontSize: 25,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.6,
                        height: 1.1,
                      ),
                    ),
                  ),
                  const SizedBox(height: 1.5),
                  Text.rich(
                    TextSpan(
                      children: [
                        TextSpan(
                          text: 'Personal y Negocio',
                          style: TextStyle(
                            color: isDark ? Colors.white60 : const Color(0xFF64748B),
                            fontSize: 11.5,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        TextSpan(
                          text: ' · ',
                          style: TextStyle(
                            color: isDark ? Colors.white38 : const Color(0xFF94A3B8),
                            fontSize: 11.5,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        WidgetSpan(
                          alignment: PlaceholderAlignment.middle,
                          child: Padding(
                            padding: const EdgeInsets.only(right: 3.5),
                            child: Container(
                              width: 5.5,
                              height: 5.5,
                              decoration: BoxDecoration(color: colors.primary, shape: BoxShape.circle),
                            ),
                          ),
                        ),
                        TextSpan(
                          text: unreadText,
                          style: TextStyle(
                            color: isDark ? colors.primary : colors.onSurfaceVariant,
                            fontSize: 11.5,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 4),
            IosGlassIconButton(
              icon: themeIcon,
              iconColor: themeColor,
              tooltip: 'Tema ($themeLabel)',
              onTap: () => showMessagingThemeSheet(context, ref),
              onLongPress: () {
                HapticFeedback.heavyImpact();
                final next = switch (currentThemeMode) {
                  'Oscuro' => 'Grisáceo',
                  'Grisáceo' || 'Opaco' => 'Claro',
                  'Claro' => 'Sistema',
                  _ => 'Oscuro',
                };
                ref.read(settingsProvider.notifier).setThemeMode(next);
              },
            ),
            const SizedBox(width: 4),
            IosGlassIconButton(
              icon: Icons.cloud_done_rounded,
              tooltip: 'API Oficial WhatsApp (Meta Cloud)',
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute<void>(builder: (_) => const MetaInboxScreen()),
              ),
            ),
            const SizedBox(width: 4),
            IosGlassIconButton(
              icon: Icons.public_rounded,
              iconSize: 16,
              tooltip: 'WhatsApp Web Mobile',
              onTap: () => WhatsAppWebScreen.navigateTo(context),
            ),
            const SizedBox(width: 4),
            if (onOpenLibrary != null) ...[
              IosGlassIconButton(
                icon: Icons.folder_open_rounded,
                tooltip: 'Biblioteca PDF',
                onTap: onOpenLibrary!,
              ),
              const SizedBox(width: 4),
            ],
            IosGlassIconButton(
              icon: Icons.tune_rounded,
              tooltip: 'Canales y permisos',
              onTap: onConnectApp ?? () => showMessagingChannelSheet(context, ref),
            ),
          ],
        ),
      ),
    );

    if (tooltip != null) {
      return Tooltip(message: tooltip!, child: button);
    }
    return button;
  }
}
