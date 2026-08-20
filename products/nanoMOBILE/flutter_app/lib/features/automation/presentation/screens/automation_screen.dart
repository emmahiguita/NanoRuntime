import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nanoai/core/providers/settings_provider.dart';
import 'package:nanoai/core/theme/design_tokens.dart';
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

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        fit: StackFit.expand,
        children: [
          const Positioned.fill(child: NanoAmbientBackground()),
          SafeArea(
            child: NanoScreenShell(
              title: 'Automatización',
              body: SingleChildScrollView(
                keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
                padding: const EdgeInsets.fromLTRB(
                  NanoSpacing.md,
                  NanoSpacing.md,
                  NanoSpacing.md,
                  NanoSpacing.xxxl,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Nivel de automatización (política) — opciones completas.
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
                          onSelected: (value) => notifier
                              .setAgentAutomationMode(
                                AgentAutomationMode.fromName(value),
                              ),
                          colors: colors,
                        ),
                      ),
                    ),
                    const SizedBox(height: NanoSpacing.xl),
                    const AgentConsoleSection(),
                    const SizedBox(height: NanoSpacing.xl),
                    const NotificationAutomationSection(),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
