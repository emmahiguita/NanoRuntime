import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:nanoai/core/theme/design_tokens.dart';
import 'package:nanoai/core/theme/nano_type.dart';
import 'package:nanoai/core/widgets/liquid_fluid_background.dart';
import 'package:nanoai/core/widgets/nano_screen_shell.dart';

import '../agent_console_section.dart';
import '../notification_automation_section.dart';
import '../widgets/c14_debug_benchmark_section.dart';
import '../widgets/engine_status_card.dart';

/// Pantalla DEV / Diagnóstico de la automatización.
///
/// Herramientas técnicas (consola del agente, benchmark C14-A, estado real del
/// motor, detalle de notificaciones) agrupadas claramente. NO contamina el
/// dashboard del asistente. Pantalla anidada con botón atrás.
class AutomationDevScreen extends StatelessWidget {
  const AutomationDevScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = NanoThemeExtension.of(context).colors;
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        fit: StackFit.expand,
        children: [
          const Positioned.fill(child: LiquidFluidBackground()),
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
                        // Propósito claro del Dev (no es la interfaz del asistente).
                        Padding(
                          padding: const EdgeInsets.fromLTRB(
                              NanoSpacing.sm, 0, NanoSpacing.sm, NanoSpacing.sm),
                          child: Text(
                            'Herramientas del desarrollador para depurar la '
                            'percepción y la ejecución del agente. No es la '
                            'interfaz del asistente; aquí se prueban selectores, '
                            'snapshots, gestos y el benchmark físico.',
                            style: NanoType.body(colors.onSurfaceVariant),
                          ),
                        ),
                        const EngineStatusCard(),
                        const SizedBox(height: NanoSpacing.xl),
                        const AgentConsoleSection(),
                        const SizedBox(height: NanoSpacing.xl),
                        const NotificationAutomationSection(),
                        if (kDebugMode) ...[
                          const SizedBox(height: NanoSpacing.xl),
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
