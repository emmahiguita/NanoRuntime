import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:nanoai/core/theme/design_tokens.dart';
import 'package:nanoai/core/widgets/nano_ambient_background.dart';
import 'package:nanoai/core/widgets/nano_screen_shell.dart';

import '../agent_console_section.dart';
import '../notification_automation_section.dart';
import '../widgets/c14_debug_benchmark_section.dart';

/// Pantalla DEV / Diagnóstico de la automatización.
///
/// Aquí viven TODAS las herramientas técnicas del desarrollador (consola del
/// agente, snapshot, selector mini-DSL, benchmark C14-A, detalle de
/// notificaciones). NO contamina el dashboard del asistente. Es una pantalla
/// anidada con botón atrás (NanoScreenShell).
class AutomationDevScreen extends StatelessWidget {
  const AutomationDevScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        fit: StackFit.expand,
        children: [
          const Positioned.fill(child: NanoAmbientBackground()),
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
