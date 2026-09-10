import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:nanoai/core/services/nano_runtime_api.dart';
import 'package:nanoai/core/theme/design_tokens.dart';
import 'package:nanoai/core/theme/nano_type.dart';
import 'package:nanoai/core/widgets/interactive_glass_card.dart';
import 'package:nanoai/core/widgets/nano_screen_shell.dart';
import 'package:nanoai/core/widgets/navigation/nano_navigation_panel.dart';
import 'package:nanoai/features/automation/application/automation_coordinator_provider.dart'
    show ruleRegistryProvider;
import 'package:nanoai/features/automation/engine/agent_dependencies.dart'
    show systemGraphProvider;
import 'package:nanoai/features/automation/engine/messaging/messaging_package.dart';
import 'package:nanoai/features/automation/engine/system/system_capability.dart';
import 'package:nanoai/features/models/application/models_provider.dart';
import 'package:nanoai/features/models/domain/local_model.dart'
    show ModelDownloadState;
import '../automation_layout.dart';
import '../automation_visual_theme.dart';

/// WA-ONBOARDING-01 — Pantalla de activación inicial y verificación de WhatsApp.
///
/// Guía paso a paso al usuario para asegurar todos los permisos y prerrequisitos
/// necesarios antes de habilitar la regla universal de WhatsApp con consentimiento
/// explícito (opt-in).
class WhatsAppOnboardingScreen extends ConsumerStatefulWidget {
  const WhatsAppOnboardingScreen({super.key});

  @override
  ConsumerState<WhatsAppOnboardingScreen> createState() =>
      _WhatsAppOnboardingScreenState();
}

class _WhatsAppOnboardingScreenState
    extends ConsumerState<WhatsAppOnboardingScreen>
    with WidgetsBindingObserver {
  Map<dynamic, dynamic>? _automationStatus;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _refreshStatus();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      ref.invalidate(systemGraphProvider);
      _refreshStatus();
    }
  }

  Future<void> _refreshStatus() async {
    try {
      final status = await NanoRuntimeApi.instance.automationBackgroundStatus();
      if (mounted) {
        setState(() {
          _automationStatus = status;
        });
      }
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final colors = NanoThemeExtension.of(context).colors;
    final visual = AutomationVisual.of(context);
    final registry = ref.watch(ruleRegistryProvider);
    final graph = ref.watch(systemGraphProvider).valueOrNull;
    final modelsState = ref.watch(modelsProvider);

    final status = _automationStatus;
    final notifAvailable =
        (graph?.availabilityOf(SystemCapability.readNotifications).isAvailable ??
            false) ||
        (status?['listenerGranted'] == true);

    final isBatteryExempt = status?['batteryIgnored'] == true;
    final bgEnabled = status?['backgroundEnabled'] == true;
    final hasModel =
        modelsState.models.any(
          (m) => m.downloadState == ModelDownloadState.installed || m.active,
        ) ||
        modelsState.detected.isNotEmpty;
    final waActive = registry.isWhatsAppRuleActive(MessagingPackage.whatsapp);

    final allReady =
        notifAvailable && isBatteryExempt && bgEnabled && hasModel;

    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          const AutomationBackdrop(),
          NanoShellBarScope(
            slotId: 'whatsapp_onboarding',
            child: SafeArea(
              child: NanoScreenShell(
                title: 'Activación de WhatsApp',
                showBack: true,
                body: LayoutBuilder(
                  builder: (context, constraints) {
                    final isDeviceLandscape =
                        MediaQuery.orientationOf(context) == Orientation.landscape;
                    final isLandscape =
                        isDeviceLandscape && constraints.maxWidth >= 560;

                    final headerCard = InteractiveGlassCard(
                      child: Padding(
                        padding: const EdgeInsets.all(NanoSpacing.md),
                        child: Row(
                          children: [
                            Container(
                              width: 48,
                              height: 48,
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                color: const Color(
                                  0xFF25D366,
                                ).withValues(alpha: 0.18),
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: const Color(
                                    0xFF25D366,
                                  ).withValues(alpha: 0.35),
                                ),
                              ),
                              child: const Icon(
                                Icons.chat_bubble_outline_rounded,
                                color: Color(0xFF25D366),
                                size: 26,
                              ),
                            ),
                            const SizedBox(width: NanoSpacing.md),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Automatización WhatsApp',
                                    style: NanoType.title(
                                      colors.onSurface,
                                    ).copyWith(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    'Consentimiento explícito y control total de respuestas.',
                                    style: NanoType.caption(
                                      colors.onSurfaceVariant,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    );

                    final statusSummaryCard = InteractiveGlassCard(
                      child: Padding(
                        padding: const EdgeInsets.all(NanoSpacing.md),
                        child: Row(
                          children: [
                            Icon(
                              allReady
                                  ? Icons.check_circle_rounded
                                  : Icons.info_outline_rounded,
                              color: allReady
                                  ? const Color(0xFF25D366)
                                  : colors.primary,
                              size: 20,
                            ),
                            const SizedBox(width: NanoSpacing.sm),
                            Expanded(
                              child: Text(
                                allReady
                                    ? 'Todos los requisitos del sistema están completos.'
                                    : 'Completa los pasos marcados para activar la respuesta automática.',
                                style: NanoType.caption(colors.onSurface),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );

                    final activateButton = SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: FilledButton.icon(
                        icon: Icon(
                          waActive
                              ? Icons.check_circle_rounded
                              : Icons.play_arrow_rounded,
                        ),
                        label: Text(
                          waActive
                              ? 'WhatsApp Activado en Nano'
                              : 'Activar WhatsApp en Nano',
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        style: FilledButton.styleFrom(
                          backgroundColor: waActive
                              ? const Color(0xFF25D366)
                              : (allReady
                                  ? visual.accent
                                  : colors.surfaceVariant),
                          foregroundColor: waActive
                              ? Colors.white
                              : (allReady
                                  ? Colors.white
                                  : colors.onSurfaceVariant),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        onPressed: () async {
                          if (!waActive) {
                            registry.seedWhatsAppRule(
                              MessagingPackage.whatsapp,
                            );
                          }
                          if (!bgEnabled) {
                            await NanoRuntimeApi.instance
                                .setBackgroundAutomation(true);
                            await _refreshStatus();
                          }
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text(
                                  'Automatización de WhatsApp activada con éxito.',
                                ),
                              ),
                            );
                            context.pop();
                          }
                        },
                      ),
                    );

                    final checklistItems = [
                      _ChecklistTile(
                        icon: Icons.notifications_active_rounded,
                        title: '1. Acceso a notificaciones',
                        subtitle:
                            'Permite a Nano leer mensajes entrantes y responder con RemoteInput.',
                        isComplete: notifAvailable,
                        actionLabel: notifAvailable ? 'Listo' : 'Conceder',
                        onAction: () async {
                          await NanoRuntimeApi.instance
                              .requestNotificationAccess();
                          ref.invalidate(systemGraphProvider);
                          await _refreshStatus();
                        },
                      ),
                      const SizedBox(height: NanoSpacing.sm),
                      _ChecklistTile(
                        icon: Icons.battery_charging_full_rounded,
                        title: '2. Exención de batería',
                        subtitle:
                            'Evita que el sistema cierre Nano cuando la pantalla se apaga.',
                        isComplete: isBatteryExempt,
                        actionLabel: isBatteryExempt ? 'Listo' : 'Conceder',
                        onAction: () async {
                          await NanoRuntimeApi.instance
                              .requestBatteryExemption();
                          await Future<void>.delayed(
                            const Duration(milliseconds: 1200),
                          );
                          await _refreshStatus();
                        },
                      ),
                      const SizedBox(height: NanoSpacing.sm),
                      _ChecklistTile(
                        icon: Icons.sync_rounded,
                        title: '3. Segundo plano (Background)',
                        subtitle:
                            'Servicio residente para procesar eventos sin abrir la app.',
                        isComplete: bgEnabled,
                        actionLabel: bgEnabled ? 'Activo' : 'Activar',
                        onAction: () async {
                          await NanoRuntimeApi.instance
                              .setBackgroundAutomation(!bgEnabled);
                          await _refreshStatus();
                        },
                      ),
                      const SizedBox(height: NanoSpacing.sm),
                      _ChecklistTile(
                        icon: Icons.memory_rounded,
                        title: '4. Modelo local configurado',
                        subtitle: hasModel
                            ? 'Modelo local descargado o detectado'
                            : 'Selecciona o descarga un modelo GGUF en la sección Modelos.',
                        isComplete: hasModel,
                        actionLabel: hasModel ? 'Listo' : 'Configurar',
                        onAction: () => context.push('/models'),
                      ),
                      const SizedBox(height: NanoSpacing.sm),
                      _ChecklistTile(
                        icon: Icons.chat_rounded,
                        title: '5. Regla de WhatsApp activa',
                        subtitle: waActive
                            ? 'Regla de respuesta universal habilitada'
                            : 'Opt-in requerido para habilitar respuestas en WhatsApp',
                        isComplete: waActive,
                        actionLabel: waActive ? 'Activo' : 'Activar',
                        onAction: () {
                          if (!waActive) {
                            registry.seedWhatsAppRule(
                              MessagingPackage.whatsapp,
                            );
                          }
                        },
                      ),
                    ];

                    final content = isLandscape
                        ? Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                flex: 4,
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.stretch,
                                  children: [
                                    headerCard,
                                    const SizedBox(height: NanoSpacing.md),
                                    statusSummaryCard,
                                    const SizedBox(height: NanoSpacing.lg),
                                    activateButton,
                                  ],
                                ),
                              ),
                              const SizedBox(width: NanoSpacing.md),
                              Expanded(
                                flex: 5,
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.stretch,
                                  children: [
                                    Text(
                                      'CHECKLIST DE ACTIVACIÓN',
                                      style: NanoType.label(
                                        colors.onSurfaceVariant,
                                      ).copyWith(letterSpacing: 0.8),
                                    ),
                                    const SizedBox(height: NanoSpacing.sm),
                                    ...checklistItems,
                                  ],
                                ),
                              ),
                            ],
                          )
                        : Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              headerCard,
                              const SizedBox(height: NanoSpacing.lg),
                              Text(
                                'CHECKLIST DE ACTIVACIÓN',
                                style: NanoType.label(
                                  colors.onSurfaceVariant,
                                ).copyWith(letterSpacing: 0.8),
                              ),
                              const SizedBox(height: NanoSpacing.sm),
                              ...checklistItems,
                              const SizedBox(height: NanoSpacing.xl),
                              activateButton,
                            ],
                          );

                    return SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(
                        NanoSpacing.md,
                        NanoSpacing.md,
                        NanoSpacing.md,
                        kNanoBarScrollReserve,
                      ),
                      child: Center(
                        child: ConstrainedBox(
                          constraints: BoxConstraints(
                            maxWidth: isLandscape
                                ? 960
                                : AutomationLayout.contentMaxWidth(context),
                          ),
                          child: content,
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ChecklistTile extends StatelessWidget {
  const _ChecklistTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.isComplete,
    required this.actionLabel,
    required this.onAction,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final bool isComplete;
  final String actionLabel;
  final VoidCallback onAction;

  @override
  Widget build(BuildContext context) {
    final colors = NanoThemeExtension.of(context).colors;

    return InteractiveGlassCard(
      child: Padding(
        padding: const EdgeInsets.all(NanoSpacing.md),
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color:
                    isComplete
                        ? const Color(0xFF25D366).withValues(alpha: 0.18)
                        : colors.surfaceVariant.withValues(alpha: 0.4),
                shape: BoxShape.circle,
                border: Border.all(
                  color:
                      isComplete
                          ? const Color(0xFF25D366).withValues(alpha: 0.4)
                          : colors.outline.withValues(alpha: 0.2),
                ),
              ),
              child: Icon(
                isComplete ? Icons.check_rounded : icon,
                color:
                    isComplete
                        ? const Color(0xFF25D366)
                        : colors.onSurfaceVariant,
                size: 20,
              ),
            ),
            const SizedBox(width: NanoSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: NanoType.body(colors.onSurface).copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: NanoType.caption(colors.onSurfaceVariant),
                  ),
                ],
              ),
            ),
            const SizedBox(width: NanoSpacing.sm),
            if (isComplete)
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFF25D366).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: const Color(0xFF25D366).withValues(alpha: 0.3),
                  ),
                ),
                child: const Text(
                  '✓ OK',
                  style: TextStyle(
                    color: Color(0xFF25D366),
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
              )
            else
              OutlinedButton(
                onPressed: onAction,
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                child: Text(actionLabel, style: const TextStyle(fontSize: 12)),
              ),
          ],
        ),
      ),
    );
  }
}
