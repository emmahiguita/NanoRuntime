// messaging_channel_sheet.dart
// QUÉ HACE: Ventana flotante estilo iOS Glassed para la gestión de canales y permisos nativos.
// CÓMO FUNCIONA: Despliega showNanoGlassWindow con canales reales (WA, Business, Telegram, IG) y acceso a notificaciones.
// POR QUÉ: Elimina opciones de tema fuera de Ajustes y botones redundantes, manteniendo SRP (< 110 líneas).
library;

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
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
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
              const SizedBox(height: 3),
              Text(
                Platform.isAndroid
                    ? 'Controla qué aplicaciones utiliza Nano para procesar mensajes.'
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
                const SizedBox(height: 14),
                Text(
                  'Permisos del sistema',
                  style: TextStyle(
                    color: isDark ? Colors.white70 : const Color(0xFF475569),
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 6),
                NanoMetallicButton(
                  isExpanded: true,
                  label: hasAccess
                      ? 'Verificar acceso a notificaciones'
                      : 'Conceder acceso a notificaciones',
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
