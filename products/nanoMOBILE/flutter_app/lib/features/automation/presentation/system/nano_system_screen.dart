/// NANO-SYSTEM-SCREEN — Pantalla unificada de Sistema y Configuración Avanzada.
///
/// QUÉ HACE:
/// Centraliza todos los aspectos técnicos del motor de automatización:
/// modo de ejecución, modelo de razonamiento local, permisos de Android,
/// herramientas MCP, diagnóstico técnico y Agentes Personalizados (Bot Studio).
///
/// CÓMO FUNCIONA:
/// Agrupa las opciones técnicas en secciones claras, eliminando la saturación
/// del dashboard principal y respetando el principio de Divulgación Progresiva.
///
/// POR QUÉ:
/// Despeja la experiencia cotidiana del usuario y garantiza un acceso rápido
/// a los ajustes avanzados en un archivo estrictamente menor a 200 líneas.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/providers/settings_provider.dart';
import '../../../../core/theme/nano_transitions.dart';
import '../../../../core/widgets/navigation/nano_navigation_panel.dart';
import '../automation_layout.dart';
import '../automation_visual_theme.dart';
import '../bot_studio/bot_studio_screen.dart';
import '../screens/automation_dev_screen.dart';
import '../screens/mcp_skills_hub_screen.dart';
import '../widgets/automation_settings_pickers.dart';
import '../widgets/settings_tile_components.dart';
import '../widgets/whatsapp_integration_cards.dart';

class NanoSystemScreen extends ConsumerWidget {
  const NanoSystemScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final visual = AutomationVisual.of(context);
    final settings = ref.watch(settingsProvider);
    final notifier = ref.read(settingsProvider.notifier);

    return Scaffold(
      resizeToAvoidBottomInset: false,
      backgroundColor: Colors.transparent,
      body: NanoShellBarScope(
        slotId: 'nano_system',
        child: SafeArea(
          top: true,
          bottom: false,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, kNanoBarScrollReserve),
            children: [
              Center(
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    maxWidth: AutomationLayout.contentMaxWidth(context),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const AutomationBackHeader(),
                      const SizedBox(height: 12),
                      _buildHeader(visual),
                      const SizedBox(height: 20),

                      // SECCIÓN 1: MOTOR Y RAZONAMIENTO
                      const AutomationSectionLabel('Motor y Razonamiento'),
                      SettingsCard(
                        children: [
                          SettingsRow(
                            icon: Icons.shield_outlined,
                            title: 'Modo de ejecución',
                            subtitle:
                                'Controla cuándo Nano requiere confirmación para actuar',
                            trailing: ValueBadge(
                              label: settings.agentAutomationMode.label.toUpperCase(),
                            ),
                            onTap: () =>
                                AutomationSettingsPickers.pickMode(context, ref),
                          ),
                          SettingsRow(
                            icon: Icons.psychology_outlined,
                            title: 'Modelo de IA local',
                            subtitle: AutomationSettingsPickers.modelModeLabel(
                              settings.automationModelMode,
                            ),
                            trailing: ValueBadge(
                              label: AutomationSettingsPickers.modelModeLabel(
                                settings.automationModelMode,
                              ).toUpperCase(),
                            ),
                            onTap: () => AutomationSettingsPickers
                                .pickAutomationModelMode(context, ref),
                          ),
                          SettingsRow(
                            icon: settings.voiceEnabled
                                ? Icons.volume_up_outlined
                                : Icons.volume_off_outlined,
                            title: 'Audio y voz de Nano',
                            subtitle: settings.voiceEnabled
                                ? 'Leer respuestas en voz alta'
                                : 'Solo texto en pantalla',
                            trailing: Switch(
                              value: settings.voiceEnabled,
                              onChanged: notifier.setVoiceEnabled,
                            ),
                            showChevron: false,
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),

                      // SECCIÓN 2: HERRAMIENTAS Y EXTENSIONES
                      const AutomationSectionLabel('Herramientas y Extensiones'),
                      SettingsCard(
                        children: [
                          SettingsRow(
                            icon: Icons.hub_outlined,
                            title: 'Hub de MCP & Skills',
                            subtitle:
                                'Plugins, herramientas locales y extensiones activas',
                            onTap: () => Navigator.of(context).push(
                              nanoGlassPageRoute<void>(
                                builder: (_) => const McpSkillsHubScreen(),
                              ),
                            ),
                          ),
                          SettingsRow(
                            icon: Icons.smart_toy_outlined,
                            title: 'Agentes personalizados (Bot Studio)',
                            subtitle:
                                'Crear bots especializados adicionales (Soporte, Tareas)',
                            onTap: () => Navigator.of(context).push(
                              nanoGlassPageRoute<void>(
                                builder: (_) => const BotStudioScreen(),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),

                      // SECCIÓN 3: PERMISOS Y SEGUNDO PLANO
                      const AutomationSectionLabel('Permisos y Sistema'),
                      const BackgroundAutomationCard(),
                      const SizedBox(height: 20),

                      // SECCIÓN 4: DIAGNÓSTICO
                      const AutomationSectionLabel('Diagnóstico y Desarrollo'),
                      SettingsCard(
                        children: [
                          SettingsRow(
                            icon: Icons.terminal_rounded,
                            title: 'Consola de Desarrollador',
                            subtitle:
                                'Inspección de árbol UI, selectores y auditoría técnica',
                            onTap: () => Navigator.of(context).push(
                              nanoGlassPageRoute<void>(
                                builder: (_) => const AutomationDevScreen(),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(AutomationVisualPalette visual) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Sistema y Herramientas',
          style: TextStyle(
            color: visual.text,
            fontSize: 22,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.5,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Configuración avanzada del motor, modelos, permisos y extensiones.',
          style: TextStyle(color: visual.textMuted, fontSize: 13),
        ),
      ],
    );
  }
}
