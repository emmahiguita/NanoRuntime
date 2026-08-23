import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nanoai/core/theme/design_tokens.dart';
import 'package:nanoai/core/widgets/nano_ambient_background.dart';
import 'package:nanoai/core/widgets/nano_components.dart';
import 'package:nanoai/core/widgets/nano_screen_shell.dart';
import 'package:nanoai/core/widgets/nano_section.dart';
import 'package:nanoai/features/automation/presentation/widgets/automation_dashboard.dart'
    show engineStatusProvider;

import '../agent_console_section.dart';
import '../notification_automation_section.dart';
import '../widgets/c14_debug_benchmark_section.dart';

/// Pantalla DEV / Diagnóstico de la automatización.
///
/// Herramientas técnicas (consola del agente, benchmark C14-A, estado real del
/// motor, detalle de notificaciones) agrupadas claramente. NO contamina el
/// dashboard del asistente. Pantalla anidada con botón atrás.
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
                        const _EngineDiagnosticsCard(),
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

/// Estado REAL del motor en Dev (runtime / modelo / accesibilidad), ligero.
class _EngineDiagnosticsCard extends ConsumerWidget {
  const _EngineDiagnosticsCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = NanoThemeExtension.of(context).colors;
    final engine = ref.watch(engineStatusProvider);
    return NanoCard(
      padding: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(NanoSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SectionHeader('Motor', Icons.memory_rounded, colors: colors),
            const SizedBox(height: NanoSpacing.sm),
            _row(context, 'Runtime', engine?.isLive ?? false),
            _row(context, 'Modelo', engine?.modelPath?.split('/').last ?? '—'),
            _row(context, 'Estado', engine?.phase.name ?? '—'),
          ],
        ),
      ),
    );
  }

  Widget _row(BuildContext context, String label, dynamic value) {
    final colors = NanoThemeExtension.of(context).colors;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          SizedBox(
            width: 96,
            child: Text(label,
                style: TextStyle(color: colors.onSurfaceVariant, fontSize: 13)),
          ),
          Expanded(
            child: Text(
              value.toString(),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 13, color: colors.textPrimary),
            ),
          ),
        ],
      ),
    );
  }
}
