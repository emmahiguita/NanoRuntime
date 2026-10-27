// messaging_channel_sheet.dart
//
// QUÉ HACE:
// Ventana flotante estilo iOS Glassed para la gestión de canales (WhatsApp, WA Business) y permisos nativos.
//
// CÓMO FUNCIONA:
// - Despliega showNanoGlassWindow con cristal iOS, esquinas redondeadas y borde translúcido reflectante.
// - Agrupa los conmutadores en una tarjeta con estilo iOS Settings y tipografía nítida.
// - Activa o remueve reglas reales en RuleRegistry y solicita permisos nativos con NotificationExecutor.
//
// POR QUÉ:
// Transforma la sábana modal en una ventana flotante profesional iOS sin código zombi (< 160 líneas).

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nanoai/core/widgets/nano_glass_window.dart';

import '../../application/automation_coordinator_provider.dart'
    show ruleRegistryProvider;
import '../../engine/messaging/messaging_package.dart';
import '../../executors/notification_executor_provider.dart';
import '../widgets/nano_metallic_button.dart';
import 'messaging_center_providers.dart';
import 'messaging_theme_sheet.dart';

part 'messaging_channel_sheet_tile.part.dart';

Future<void> showMessagingChannelSheet(BuildContext context, WidgetRef ref) {
  final isDark = Theme.of(context).brightness == Brightness.dark;

  return showNanoGlassWindow<void>(
    context: context,
    builder: (sheetContext) => Consumer(
      builder: (context, sheetRef, _) {
        final registry = sheetRef.watch(ruleRegistryProvider);
        final access = sheetRef.watch(notificationAccessProvider).valueOrNull;
        final hasAccess = access?.accessGranted == true;

        void setChannel(String packageName, bool enabled) {
          HapticFeedback.lightImpact();
          enabled
              ? registry.seedChannelRule(packageName)
              : registry.removeChannelRule(packageName);
        }

        return SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 18),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Canales y permisos',
                style: TextStyle(
                  color: isDark ? Colors.white : const Color(0xFF0F172A),
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.3,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                Platform.isAndroid
                    ? 'Elige qué canales puede procesar NanoAI automáticamente.'
                    : 'iOS no permite leer mensajes de otras apps mediante notificaciones.',
                style: TextStyle(
                  color: isDark ? Colors.white60 : const Color(0xFF64748B),
                  fontSize: 12,
                ),
              ),
              const SizedBox(height: 12),
              if (Platform.isAndroid) ...[
                _MessagingChannelsCard(
                  registry: registry,
                  setChannel: setChannel,
                  isDark: isDark,
                ),
                const SizedBox(height: 12),
                NanoMetallicButton(
                  isExpanded: true,
                  label: hasAccess
                      ? 'Revisar permiso de notificaciones'
                      : 'Conceder permiso de notificaciones',
                  icon: hasAccess
                      ? Icons.verified_user_rounded
                      : Icons.security_rounded,
                  style: NanoMetallicButtonStyle.primary,
                  onPressed: () async {
                    Navigator.pop(sheetContext);
                    await ref
                        .read(notificationExecutorProvider)
                        .requestAccess();
                    ref.invalidate(notificationAccessProvider);
                  },
                ),
                const SizedBox(height: 8),
                NanoMetallicButton(
                  isExpanded: true,
                  label: 'Tema visual del panel',
                  icon: Icons.palette_outlined,
                  style: NanoMetallicButtonStyle.subtle,
                  onPressed: () {
                    Navigator.pop(sheetContext);
                    showMessagingThemeSheet(context, ref);
                  },
                ),
                const SizedBox(height: 8),
                NanoMetallicButton(
                  isExpanded: true,
                  label: 'Cancelar',
                  icon: Icons.close_rounded,
                  style: NanoMetallicButtonStyle.subtle,
                  onPressed: () => Navigator.pop(sheetContext),
                ),
              ] else ...[
                const SizedBox(height: 8),
                NanoMetallicButton(
                  isExpanded: true,
                  label: 'Cerrar',
                  style: NanoMetallicButtonStyle.subtle,
                  onPressed: () => Navigator.pop(sheetContext),
                ),
              ],
            ],
          ),
        );
      },
    ),
  );
}
