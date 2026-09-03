import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nanoai/core/providers/settings_provider.dart';
import 'package:nanoai/core/theme/design_tokens.dart';
import 'package:nanoai/core/theme/nano_type.dart';
import 'package:nanoai/core/widgets/nano_screen_shell.dart';
import 'package:nanoai/features/edge/edge_dev_section.dart';

import '../agent_console_section.dart';
import '../automation_visual_theme.dart';
import '../skill_dev_section.dart';
import '../widgets/c14_debug_benchmark_section.dart';
import '../widgets/engine_status_card.dart';

/// Pantalla DEV / Diagnóstico de la automatización.
///
/// Herramientas técnicas (consola del agente, benchmark C14-A, estado real del
/// motor, detalle de notificaciones) agrupadas claramente. NO contamina el
/// dashboard del asistente. Pantalla anidada con botón atrás.
class AutomationDevScreen extends ConsumerWidget {
  const AutomationDevScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final visualMode = AutomationVisual.modeFromSetting(
      ref.watch(settingsProvider.select((settings) => settings.themeMode)),
    );
    return Theme(
      data: AutomationVisual.theme(context, mode: visualMode),
      child: const _AutomationDevBody(),
    );
  }
}

class _AutomationDevBody extends StatelessWidget {
  const _AutomationDevBody();

  @override
  Widget build(BuildContext context) {
    final colors = NanoThemeExtension.of(context).colors;
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // UI-REV-03: fondo compartido del módulo (mismo en todas las
          // pantallas) — antes duplicado aquí inline.
          const AutomationBackdrop(),
          SafeArea(
            child: NanoScreenShell(
              title: 'Dev',
              showBack: true,
              body: SingleChildScrollView(
                keyboardDismissBehavior:
                    ScrollViewKeyboardDismissBehavior.onDrag,
                padding: const EdgeInsets.fromLTRB(
                  NanoSpacing.md,
                  NanoSpacing.md,
                  NanoSpacing.md,
                  NanoSpacing.xxxl,
                ),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 720),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Nota breve (una línea): no es la interfaz del asistente.
                        Padding(
                          padding: const EdgeInsets.fromLTRB(
                            NanoSpacing.sm,
                            0,
                            NanoSpacing.sm,
                            NanoSpacing.md,
                          ),
                          child: Text(
                            'Herramientas de diagnóstico del agente. Solo para '
                            'depurar la percepción y la ejecución.',
                            style: NanoType.caption(colors.onSurfaceVariant),
                          ),
                        ),
                        // 1 · Motor (estado real del runtime + capacidades)
                        const EngineStatusCard(),
                        const SizedBox(height: NanoSpacing.xl),
                        // 2 · Percepción y acciones (snapshot, selector, toque,
                        //    insertar texto, gestos)
                        const AgentConsoleSection(),
                        const SizedBox(height: NanoSpacing.xl),
                        // 3 · Búho y edge (validación física: overlay, probe,
                        //    espejo de conversación)
                        const EdgeDevSection(),
                        const SizedBox(height: NanoSpacing.xl),
                        // 4 · Skills (SKILL-01): drafts + aprobación humana
                        const SkillDevSection(),
                        if (kDebugMode) ...[
                          const SizedBox(height: NanoSpacing.xl),
                          // 5 · Benchmark físico (C14-A)
                          const C14DebugBenchmarkSection(),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
