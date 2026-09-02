import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nanoai/core/services/nano_runtime_api.dart';
import 'package:nanoai/core/theme/design_tokens.dart';
import 'package:nanoai/core/theme/nano_type.dart';

import '../../engine/agent_dependencies.dart' show systemGraphProvider;
import '../../engine/system/capability_availability.dart';
import '../../engine/system/device_permission_requester.dart';
import '../../engine/system/system_capability.dart';
import '../automation_visual_theme.dart';

/// Estado de permisos/capacidades del agente — la pantalla "acorde a las
/// funciones": muestra QUÉ puede hacer el agente según los permisos reales del
/// dispositivo (Accesibilidad, Notificaciones, Linux, Shizuku), leídos del
/// SystemGraph factual (nunca del string de un modelo).
///
/// Si falta una capacidad clave muestra una única alerta con acceso directo;
/// cuando todo está disponible, las filas factuales bastan y no se duplica el
/// mismo estado en un banner adicional.
class CapabilityStatusCard extends ConsumerWidget {
  const CapabilityStatusCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = NanoThemeExtension.of(context).colors;
    final visual = AutomationVisual.of(context);
    final graph = ref.watch(systemGraphProvider).valueOrNull;

    final acc = graph?.availabilityOf(SystemCapability.observeAccessibility);
    final notif = graph?.availabilityOf(SystemCapability.readNotifications);
    final linux = graph?.availabilityOf(SystemCapability.linuxExecution);
    final shizuku = graph?.availabilityOf(SystemCapability.shizuku);

    // Los dos permisos clave que desbloquean la automatización UI y de mensajes.
    final keyDone =
        (acc?.isAvailable ?? false) && (notif?.isAvailable ?? false);
    final keyMissing = [
      if (!(acc?.isAvailable ?? false)) 'Accesibilidad',
      if (!(notif?.isAvailable ?? false)) 'Notificaciones',
    ];
    final hasMissing =
        (acc != null && !acc.isAvailable) ||
        (notif != null && !notif.isAvailable) ||
        shizuku?.state == CapabilityAvailabilityKind.requiresUserEnablement;

    return AutomationSurfaceCard(
      padding: const EdgeInsets.all(NanoSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Row(
                  children: [
                    Icon(
                      Icons.verified_user_rounded,
                      size: 18,
                      color: visual.accent,
                    ),
                    const SizedBox(width: NanoSpacing.sm),
                    Expanded(
                      child: Text(
                        'PERMISOS DEL AGENTE',
                        style: TextStyle(
                          color: visual.textMuted,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.55,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: 'Recargar estado',
                visualDensity: VisualDensity.compact,
                onPressed: () => ref.invalidate(systemGraphProvider),
                icon: Icon(
                  Icons.refresh_rounded,
                  size: 18,
                  color: visual.textMuted,
                ),
              ),
            ],
          ),
          const SizedBox(height: NanoSpacing.sm),
          if (graph != null && !keyDone) ...[
            _SummaryBanner(missing: keyMissing, colors: colors),
            const SizedBox(height: NanoSpacing.sm),
          ],
          _CapRow(
            label: 'Accesibilidad',
            description: 'Observar, tocar y escribir en pantalla',
            icon: Icons.accessibility_new_rounded,
            availability: acc,
            onActivate: () => _open(
              context,
              NanoRuntimeApi.instance.openAccessibilitySettings,
            ),
            colors: colors,
          ),
          _CapRow(
            label: 'Notificaciones',
            description: 'Leer y responder mensajes',
            icon: Icons.notifications_active_rounded,
            availability: notif,
            onActivate: () => _open(
              context,
              NanoRuntimeApi.instance.openNotificationAccessSettings,
            ),
            colors: colors,
          ),
          _CapRow(
            label: 'Linux',
            description: 'Ejecutar comandos y archivos locales',
            icon: Icons.terminal_rounded,
            availability: linux,
            colors: colors,
          ),
          _CapRow(
            label: 'Shizuku',
            description: 'Acciones avanzadas de sistema',
            icon: Icons.bolt_rounded,
            availability: shizuku,
            onActivate: () async {
              // Empareja con Shizuku (dispara el diálogo de autorización) y
              // re-lee el estado real al volver.
              await _open(
                context,
                NanoRuntimeApi.instance.shizukuRequestPermission,
              );
              ref.invalidate(systemGraphProvider);
            },
            colors: colors,
          ),
          if (hasMissing) ...[
            const SizedBox(height: NanoSpacing.sm),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: graph == null
                    ? null
                    : () async {
                        await const DevicePermissionRequester()
                            .requestAllMissing(graph);
                        if (context.mounted) {
                          ref.invalidate(systemGraphProvider);
                        }
                      },
                icon: const Icon(Icons.shield_outlined),
                label: const Text('Solicitar todos los permisos'),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _open(
    BuildContext context,
    Future<bool> Function() action,
  ) async {
    try {
      await action();
    } catch (_) {
      // El ajuste no se abrió; no romper la UI.
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No se pudo abrir el ajuste.')),
        );
      }
    }
  }
}

class _SummaryBanner extends StatelessWidget {
  const _SummaryBanner({required this.missing, required this.colors});

  final List<String> missing;
  final NanoColors colors;

  @override
  Widget build(BuildContext context) {
    final color = colors.warning;
    final text = 'Falta activar: ${missing.join(', ')}';
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(
        horizontal: NanoSpacing.md,
        vertical: NanoSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Row(
        children: [
          Icon(Icons.info_outline_rounded, size: 18, color: color),
          const SizedBox(width: NanoSpacing.sm),
          Expanded(
            child: Text(
              text,
              style: NanoType.label(
                color,
              ).copyWith(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}

class _CapRow extends StatelessWidget {
  const _CapRow({
    required this.label,
    required this.description,
    required this.icon,
    required this.availability,
    required this.colors,
    this.onActivate,
  });

  final String label;
  final String description;
  final IconData icon;
  final CapabilityAvailability? availability;
  final NanoColors colors;
  final VoidCallback? onActivate;

  @override
  Widget build(BuildContext context) {
    final visual = AutomationVisual.of(context);
    final avail = availability;
    final (color: chipColor, label: chipLabel, icon: chipIcon) = _chip(
      avail,
      colors,
    );
    final status = onActivate != null && avail != null && _requiresAction(avail)
        ? TextButton.icon(
            onPressed: onActivate,
            style: TextButton.styleFrom(
              visualDensity: VisualDensity.compact,
              padding: const EdgeInsets.symmetric(horizontal: 8),
            ),
            icon: Icon(chipIcon, size: 14, color: chipColor),
            label: Text(chipLabel, style: NanoType.label(chipColor)),
          )
        : Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(chipIcon, size: 14, color: chipColor),
              const SizedBox(width: 4),
              Text(chipLabel, style: NanoType.label(chipColor)),
            ],
          );
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 290;
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 7),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Icon(icon, size: 20, color: visual.textMuted),
              ),
              const SizedBox(width: NanoSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Text(
                            label,
                            style: NanoType.body(
                              visual.text,
                            ).copyWith(fontWeight: FontWeight.w600),
                          ),
                        ),
                        if (!compact) ...[
                          const SizedBox(width: NanoSpacing.sm),
                          status,
                        ],
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      description,
                      softWrap: true,
                      style: NanoType.caption(
                        visual.textMuted,
                      ).copyWith(height: 1.3),
                    ),
                    if (compact) ...[
                      const SizedBox(height: 6),
                      Align(alignment: Alignment.centerRight, child: status),
                    ],
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  ({Color color, String label, IconData icon}) _chip(
    CapabilityAvailability? a,
    NanoColors colors,
  ) {
    if (a == null) {
      return (
        color: colors.onSurfaceVariant,
        label: 'Comprobando…',
        icon: Icons.more_horiz_rounded,
      );
    }
    if (a.isAvailable) {
      return (
        color: colors.success,
        label: 'Activado',
        icon: Icons.check_circle_rounded,
      );
    }
    if (_requiresAction(a)) {
      return (
        color: colors.warning,
        label: 'Activar',
        icon: Icons.add_circle_outline_rounded,
      );
    }
    return (
      color: colors.onSurfaceVariant,
      label: 'No disponible',
      icon: Icons.block_rounded,
    );
  }

  /// Estados que admiten acción del usuario (abrir ajuste / emparejar).
  bool _requiresAction(CapabilityAvailability a) =>
      a.state == CapabilityAvailabilityKind.requiresAccessibility ||
      a.state == CapabilityAvailabilityKind.requiresNotificationAccess ||
      a.state == CapabilityAvailabilityKind.requiresUserEnablement;
}
