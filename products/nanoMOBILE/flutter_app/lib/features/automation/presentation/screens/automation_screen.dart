import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nanoai/core/providers/settings_provider.dart';
import 'package:nanoai/core/theme/design_tokens.dart';
import 'package:nanoai/core/theme/nano_breakpoint.dart';
import 'package:nanoai/core/widgets/nano_ambient_background.dart';
import 'package:nanoai/core/widgets/nano_choice_group.dart';
import 'package:nanoai/core/widgets/nano_components.dart';
import 'package:nanoai/core/widgets/nano_screen_shell.dart';
import 'package:nanoai/core/widgets/nano_section.dart';
import '../agent_console_section.dart';
import '../notification_automation_section.dart';
import '../../domain/automation_policy.dart';

/// Pantalla DEDICADA de Automatización.
///
/// La automatización es un apartado propio del producto — NO vive en Ajustes.
/// Reúne el nivel de automatización (selector), la consola del agente
/// (AgentConsoleSection) y la automatización de notificaciones
/// (NotificationAutomationSection), todas del módulo `features/automation/`.
///
/// Composición responsive (regla "cada rango recompone la interfaz"):
/// - compact/medium (<900): columna única (nivel → consola → notificaciones).
/// - expanded+ (≥900): dos columnas — consola+nivel a la izquierda,
///   notificaciones a la derecha — para no estirar los componentes.
class AutomationScreen extends ConsumerStatefulWidget {
  const AutomationScreen({super.key});

  @override
  ConsumerState<AutomationScreen> createState() => _AutomationScreenState();
}

class _AutomationScreenState extends ConsumerState<AutomationScreen> {
  @override
  Widget build(BuildContext context) {
    final state = ref.watch(settingsProvider);
    final notifier = ref.read(settingsProvider.notifier);
    final colors = NanoThemeExtension.of(context).colors;

    final levelSection = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionHeader(
          'Agente de chat',
          Icons.smart_toy_rounded,
          colors: colors,
        ),
        NanoCard(
          padding: EdgeInsets.zero,
          child: Padding(
            padding: const EdgeInsets.all(NanoSpacing.md),
            child: ChoiceGroup(
              label: 'Nivel de automatización',
              description: state.agentAutomationMode.description,
              options: const [
                ChoiceOption(
                  'manual',
                  'Manual',
                  Icons.pan_tool_alt_rounded,
                ),
                ChoiceOption(
                  'assisted',
                  'Asistido',
                  Icons.assistant_rounded,
                ),
                ChoiceOption(
                  'autonomous',
                  'Autónomo',
                  Icons.auto_awesome_rounded,
                ),
              ],
              selectedValue: state.agentAutomationMode.name,
              onSelected: (value) => notifier.setAgentAutomationMode(
                AgentAutomationMode.fromName(value),
              ),
              colors: colors,
            ),
          ),
        ),
      ],
    );

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        fit: StackFit.expand,
        children: [
          const Positioned.fill(child: NanoAmbientBackground()),
          SafeArea(
            child: NanoScreenShell(
              title: 'Automatización',
              body: LayoutBuilder(
                builder: (context, constraints) {
                  final useColumns =
                      constraints.maxWidth >= NanoBreakpoints.mediumMax;

                  return SingleChildScrollView(
                    keyboardDismissBehavior:
                        ScrollViewKeyboardDismissBehavior.onDrag,
                    padding: const EdgeInsets.fromLTRB(
                      NanoSpacing.md,
                      NanoSpacing.md,
                      NanoSpacing.md,
                      NanoSpacing.xxxl,
                    ),
                    // Cota de contenido: /automation es ruta top-level (fuera
                    // del ScaffoldShell), se autocota aquí.
                    child: Center(
                      child: ConstrainedBox(
                        constraints: NanoBreakpoints.contentBox(
                          constraints.maxWidth,
                        ),
                        child: useColumns
                            ? Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.stretch,
                                      children: [
                                        levelSection,
                                        const SizedBox(height: NanoSpacing.xl),
                                        const AgentConsoleSection(),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: NanoSpacing.xl),
                                  const Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.stretch,
                                      children: [
                                        NotificationAutomationSection(),
                                      ],
                                    ),
                                  ),
                                ],
                              )
                            : Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  levelSection,
                                  const SizedBox(height: NanoSpacing.xl),
                                  const AgentConsoleSection(),
                                  const SizedBox(height: NanoSpacing.xl),
                                  const NotificationAutomationSection(),
                                ],
                              ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}
