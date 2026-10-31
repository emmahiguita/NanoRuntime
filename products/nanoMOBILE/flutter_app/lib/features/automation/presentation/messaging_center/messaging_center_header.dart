// messaging_center_header.dart
// QUÉ HACE: Encabezado del Centro de Mensajería WhatsApp con diseño iOS Glassed minimalista.
// CÓMO FUNCIONA: Reduce iconos secundarios a 2 visibles + menú de opciones, eliminando sobrecarga visual.
// POR QUÉ: Evita superposiciones con el botón del búho, remueve accesos duplicados y temas (< 145 líneas).
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/services/remote_inference_config.dart';
import '../../../../core/theme/design_tokens.dart';
import '../../../../core/widgets/navigation/nano_nav_mode_provider.dart';
import '../../../models/presentation/widgets/remote_inference_dialog.dart';
import 'messaging_center_providers.dart';
import 'messaging_channel_sheet.dart';
import 'messaging_glass_icon_button.dart';
import 'messaging_options_menu.dart';

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

    // Comprobación real de conexión con PC para inferencia neural y modelos
    final remoteConfig = ref.watch(remoteInferenceConfigProvider);
    final isConnectedToPc = remoteConfig.isRemote;

    // Estado del modo drawer para reservar espacio y evitar superposición con el botón del búho
    final navState = ref.watch(nanoNavModeProvider);
    final isDrawerMode = navState.isDrawerMode;

    return Hero(
      tag: 'nano_messaging_hero',
      child: Material(
        type: MaterialType.transparency,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            if (isDrawerMode) const SizedBox(width: 52),
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
                        fontSize: 24,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.5,
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
            // 1. Conexión con Nano PC (Inferencia y modelos) con indicador verificado real
            IosGlassIconButton(
              icon: Icons.devices_rounded,
              tooltip: isConnectedToPc
                  ? 'Conexión PC: Remoto activo'
                  : 'Conexión con Nano PC',
              hasBadge: isConnectedToPc,
              badgeColor: const Color(0xFF10B981),
              onTap: () => showRemoteInferenceSheet(context),
            ),
            const SizedBox(width: 2),
            // 2. Canales y permisos (filtro/gestión de apps de mensajería con icono shield)
            IosGlassIconButton(
              icon: Icons.shield_outlined,
              tooltip: 'Canales y permisos',
              onTap: onConnectApp ?? () => showMessagingChannelSheet(context, ref),
            ),
            const SizedBox(width: 2),
            // 3. Menú secundario para accesos complementarios sin sobrecargar la cabecera
            MessagingOptionsMenu(onOpenLibrary: onOpenLibrary),
          ],
        ),
      ),
    );
  }
}
