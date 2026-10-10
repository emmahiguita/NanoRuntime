// messaging_channel_sheet.dart
//
// QUÉ HACE:
// Menú flotante estilo iOS Glassed para la gestión de canales (WhatsApp, WA Business) y permisos nativos.
//
// CÓMO FUNCIONA:
// - Despliega un menú flotante con BackdropFilter blur (24px), esquinas redondeadas y borde translúcido reflectante.
// - Agrupa los conmutadores en una tarjeta con estilo iOS Settings y tipografía nítida.
// - Activa o remueve reglas reales en RuleRegistry y solicita permisos nativos con NotificationExecutor.
//
// POR QUÉ:
// Transforma la sábana modal en un menú flotante profesional iOS sin código zombi (< 160 líneas).

import 'dart:io';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../application/automation_coordinator_provider.dart' show ruleRegistryProvider;
import '../../engine/messaging/messaging_package.dart';
import '../../executors/notification_executor_provider.dart';
import '../widgets/nano_metallic_button.dart';
import 'messaging_center_providers.dart';

Future<void> showMessagingChannelSheet(BuildContext context, WidgetRef ref) {
  final isDark = Theme.of(context).brightness == Brightness.dark;

  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (sheetContext) => Consumer(
      builder: (context, sheetRef, _) {
        final registry = sheetRef.watch(ruleRegistryProvider);
        final access = sheetRef.watch(notificationAccessProvider).valueOrNull;
        final hasAccess = access?.accessGranted == true;

        void setChannel(String packageName, bool enabled) {
          HapticFeedback.lightImpact();
          enabled ? registry.seedChannelRule(packageName) : registry.removeChannelRule(packageName);
        }

        return Padding(
          padding: EdgeInsets.fromLTRB(16, 0, 16, MediaQuery.of(sheetContext).viewInsets.bottom + 20),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(24),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
              child: Container(
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF0F172A).withValues(alpha: 0.88) : Colors.white.withValues(alpha: 0.92),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: isDark ? Colors.white.withValues(alpha: 0.14) : Colors.white.withValues(alpha: 0.85), width: 1.1),
                  boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: isDark ? 0.35 : 0.08), blurRadius: 20, offset: const Offset(0, 8))],
                ),
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(child: Container(width: 36, height: 4, decoration: BoxDecoration(color: isDark ? Colors.white24 : Colors.black12, borderRadius: BorderRadius.circular(2)))),
                    const SizedBox(height: 12),
                    Text('Canales y permisos', style: TextStyle(color: isDark ? Colors.white : const Color(0xFF0F172A), fontSize: 17, fontWeight: FontWeight.w700, letterSpacing: -0.3)),
                    const SizedBox(height: 3),
                    Text(
                      Platform.isAndroid ? 'Elige qué canales puede procesar NanoAI automáticamente.' : 'iOS no permite leer mensajes de otras apps mediante notificaciones.',
                      style: TextStyle(color: isDark ? Colors.white60 : const Color(0xFF64748B), fontSize: 12),
                    ),
                    const SizedBox(height: 14),
                    if (Platform.isAndroid) ...[
                      Container(
                        decoration: BoxDecoration(
                          color: isDark ? Colors.white.withValues(alpha: 0.05) : const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: isDark ? Colors.white.withValues(alpha: 0.08) : const Color(0xFFE2E8F0), width: 0.8),
                        ),
                        child: Column(
                          children: [
                            _ChannelSwitch(
                              title: 'WhatsApp',
                              subtitle: 'Mensajes personales y contactos',
                              value: registry.isChannelRuleActive(MessagingPackage.whatsapp),
                              onChanged: (val) => setChannel(MessagingPackage.whatsapp, val),
                              isDark: isDark,
                            ),
                            Divider(height: 1, indent: 16, endIndent: 16, color: isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.06)),
                            _ChannelSwitch(
                              title: 'WhatsApp Business',
                              subtitle: 'Mensajes de clientes y comercio',
                              value: registry.isChannelRuleActive(MessagingPackage.whatsappBusiness),
                              onChanged: (val) => setChannel(MessagingPackage.whatsappBusiness, val),
                              isDark: isDark,
                            ),
                            Divider(height: 1, indent: 16, endIndent: 16, color: isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.06)),
                            _ChannelSwitch(
                              title: 'Telegram',
                              subtitle: 'Mensajes directos y grupos',
                              value: registry.isChannelRuleActive(MessagingPackage.telegramOrg) || registry.isChannelRuleActive(MessagingPackage.telegram),
                              onChanged: (val) {
                                setChannel(MessagingPackage.telegramOrg, val);
                                setChannel(MessagingPackage.telegram, val);
                              },
                              isDark: isDark,
                            ),
                            Divider(height: 1, indent: 16, endIndent: 16, color: isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.06)),
                            _ChannelSwitch(
                              title: 'Instagram',
                              subtitle: 'Mensajes directos (DMs)',
                              value: registry.isChannelRuleActive(MessagingPackage.instagram),
                              onChanged: (val) => setChannel(MessagingPackage.instagram, val),
                              isDark: isDark,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),
                      NanoMetallicButton(
                        isExpanded: true,
                        label: hasAccess ? 'Revisar permiso de notificaciones' : 'Conceder permiso de notificaciones',
                        icon: hasAccess ? Icons.verified_user_rounded : Icons.security_rounded,
                        style: NanoMetallicButtonStyle.primary,
                        onPressed: () async {
                          Navigator.pop(sheetContext);
                          await ref.read(notificationExecutorProvider).requestAccess();
                          ref.invalidate(notificationAccessProvider);
                        },
                      ),
                    ] else ...[
                      const SizedBox(height: 8),
                      NanoMetallicButton(
                        isExpanded: true,
                        label: 'Entendido',
                        style: NanoMetallicButtonStyle.subtle,
                        onPressed: () => Navigator.pop(sheetContext),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        );
      },
    ),
  );
}

class _ChannelSwitch extends StatelessWidget {
  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;
  final bool isDark;

  const _ChannelSwitch({
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return SwitchListTile.adaptive(
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
      dense: true,
      title: Text(
        title,
        style: TextStyle(
          color: isDark ? Colors.white : const Color(0xFF0F172A),
          fontSize: 13.5,
          fontWeight: FontWeight.w600,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: TextStyle(
          color: isDark ? Colors.white54 : const Color(0xFF64748B),
          fontSize: 11.5,
        ),
      ),
      value: value,
      onChanged: onChanged,
    );
  }
}
