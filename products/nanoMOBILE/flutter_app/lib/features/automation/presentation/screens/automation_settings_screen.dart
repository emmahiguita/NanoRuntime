import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nanoai/core/providers/settings_provider.dart';
import 'package:nanoai/core/theme/nano_transitions.dart';
import 'package:nanoai/core/widgets/navigation/nano_navigation_panel.dart';
import 'package:nanoai/features/automation/application/automation_coordinator_provider.dart'
    show ruleRegistryProvider;

import '../automation_layout.dart';
import '../automation_visual_theme.dart';
import '../widgets/automation_settings_pickers.dart';
import '../widgets/capability_status_card.dart';
import '../widgets/personal_agent_cards.dart';
import '../widgets/settings_tile_components.dart';
import '../widgets/whatsapp_integration_cards.dart';
import 'automation_rules_screen.dart';
import '../../personal_agent/presentation/personalization_studio_screen.dart';

// Re-exportamos la enumeración para compatibilidad total con consumidores externos.
export '../widgets/settings_tile_components.dart'
    show AutomationSettingsCategory;

/// Configuración del agente organizada con principios SOLID y Arquitectura Limpia.
/// Pantalla orquestadora desacoplada en secciones temáticas (General, WhatsApp, Cerebro, Sistema).
class AutomationSettingsScreen extends ConsumerStatefulWidget {
  const AutomationSettingsScreen({
    super.key,
    this.onDevTap,
    this.initialCategory = AutomationSettingsCategory.general,
  });

  final VoidCallback? onDevTap;
  final AutomationSettingsCategory initialCategory;

  @override
  ConsumerState<AutomationSettingsScreen> createState() =>
      _AutomationSettingsScreenState();
}

class _AutomationSettingsScreenState
    extends ConsumerState<AutomationSettingsScreen> {
  late AutomationSettingsCategory _category;

  @override
  void initState() {
    super.initState();
    _category = widget.initialCategory;
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(settingsProvider);
    final notifier = ref.read(settingsProvider.notifier);
    final visualMode = AutomationVisual.modeFromSetting(settings.themeMode);

    return AnimatedTheme(
      data: AutomationVisual.theme(context, mode: visualMode),
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeOutCubic,
      child: Builder(
        builder: (context) {
          final visual = AutomationVisual.of(context);
          return Scaffold(
            resizeToAvoidBottomInset: false,
            backgroundColor: Colors.transparent,
            body: NanoShellBarScope(
              slotId: 'automation_settings',
              child: SafeArea(
                top: true,
                bottom: false,
                child: ListView(
                  keyboardDismissBehavior:
                      ScrollViewKeyboardDismissBehavior.onDrag,
                  padding: const EdgeInsets.fromLTRB(
                    12,
                    8,
                    12,
                    kNanoBarScrollReserve,
                  ),
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
                            const SizedBox(height: 16),
                            Text(
                              'Configuración',
                              style: TextStyle(
                                color: visual.text,
                                fontSize: 22,
                                fontWeight: FontWeight.w700,
                                letterSpacing: -0.5,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Personaliza cómo Nano ejecuta tus automatizaciones.',
                              style: TextStyle(
                                color: visual.textMuted,
                                fontSize: 13,
                                height: 1.4,
                              ),
                            ),
                            const SizedBox(height: 16),
                            _buildCategoryPills(visual),
                            const SizedBox(height: 20),
                            AnimatedSwitcher(
                              duration: const Duration(milliseconds: 220),
                              switchInCurve: Curves.easeOutCubic,
                              switchOutCurve: Curves.easeInCubic,
                              child: KeyedSubtree(
                                key: ValueKey(_category),
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.stretch,
                                  children: _buildCategoryContent(
                                    context,
                                    settings,
                                    notifier,
                                    widget.onDevTap,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 24),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.info_outline_rounded,
                                  size: 17,
                                  color: visual.textMuted,
                                ),
                                const SizedBox(width: 7),
                                Flexible(
                                  child: Text(
                                    'Los cambios se guardan automáticamente',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      color: visual.textMuted,
                                      fontSize: 12,
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
        },
      ),
    );
  }

  Widget _buildCategoryPills(AutomationVisualPalette visual) {
    return Container(
      height: 42,
      decoration: BoxDecoration(
        color: visual.isDark
            ? const Color(0x330E182D)
            : const Color(0x180E182D),
        borderRadius: BorderRadius.circular(21),
        border: Border.all(
          color: visual.cardBorder.withValues(alpha: 0.16),
        ),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isCompact = constraints.maxWidth < 340;
          return Row(
            children: AutomationSettingsCategory.values.map((cat) {
              final isSelected = _category == cat;
              return Expanded(
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () {
                    if (_category != cat) {
                      setState(() => _category = cat);
                    }
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    curve: Curves.easeOutCubic,
                    margin: const EdgeInsets.all(2.5),
                    decoration: BoxDecoration(
                      color: isSelected ? visual.accent : Colors.transparent,
                      borderRadius: BorderRadius.circular(18),
                      boxShadow: isSelected
                          ? [
                              BoxShadow(
                                color: visual.accent.withValues(alpha: 0.30),
                                blurRadius: 6,
                                offset: const Offset(0, 1.5),
                              ),
                            ]
                          : null,
                    ),
                    child: Center(
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            cat.icon,
                            size: isCompact ? 14 : 15.5,
                            color: isSelected
                                ? visual.onAccent
                                : visual.textMuted,
                          ),
                          if (!isCompact || isSelected) ...[
                            const SizedBox(width: 4),
                            Flexible(
                              child: Text(
                                cat.label,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: isSelected
                                      ? visual.onAccent
                                      : visual.textMuted,
                                  fontSize: 11.5,
                                  fontWeight: isSelected
                                      ? FontWeight.w600
                                      : FontWeight.w500,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
          );
        },
      ),
    );
  }

  List<Widget> _buildCategoryContent(
    BuildContext context,
    SettingsState settings,
    SettingsNotifier notifier,
    VoidCallback? onDevTap,
  ) {
    switch (_category) {
      case AutomationSettingsCategory.general:
        return _buildGeneralSection(context, settings, notifier);
      case AutomationSettingsCategory.whatsapp:
        return _buildWhatsAppComponent();
      case AutomationSettingsCategory.brain:
        return _buildBrainSection(context);
      case AutomationSettingsCategory.system:
        return _buildSystemSection(context, onDevTap);
    }
  }

  List<Widget> _buildGeneralSection(
    BuildContext context,
    SettingsState settings,
    SettingsNotifier notifier,
  ) {
    return [
      const AutomationSectionLabel('Modo y Razonamiento'),
      SettingsCard(
        children: [
          SettingsRow(
            icon: Icons.bolt_rounded,
            title: 'Modo de automatización',
            subtitle: settings.agentAutomationMode.description,
            trailing: ValueBadge(
              label: settings.agentAutomationMode.label.toUpperCase(),
            ),
            onTap: () => AutomationSettingsPickers.pickMode(context, ref),
          ),
          SettingsRow(
            icon: Icons.psychology_outlined,
            title: 'Motor de razonamiento',
            subtitle: AutomationSettingsPickers.modelModeLabel(
              settings.automationModelMode,
            ),
            trailing: ValueBadge(
              label: AutomationSettingsPickers.modelModeLabel(
                settings.automationModelMode,
              ).toUpperCase(),
            ),
            onTap: () =>
                AutomationSettingsPickers.pickAutomationModelMode(context, ref),
          ),
          SettingsRow(
            icon: settings.voiceEnabled
                ? Icons.volume_up_outlined
                : Icons.volume_off_outlined,
            title: 'Audio de Nano',
            subtitle: settings.voiceEnabled
                ? 'Leer respuestas y resultados en voz alta'
                : 'Responder únicamente con texto',
            trailing: Switch(
              value: settings.voiceEnabled,
              onChanged: notifier.setVoiceEnabled,
            ),
            showChevron: false,
          ),
        ],
      ),
    ];
  }

  List<Widget> _buildWhatsAppComponent() {
    return const [
      AutomationSectionLabel('Autonomía de Respuestas'),
      AutonomyModeCard(),
      SizedBox(height: 24),
      AutomationSectionLabel('Aplicaciones Conectadas'),
      WhatsAppAppsCard(),
      SizedBox(height: 24),
      AutomationSectionLabel('Segundo Plano y Batería'),
      BackgroundAutomationCard(),
    ];
  }

  List<Widget> _buildBrainSection(BuildContext context) {
    return [
      const AutomationSectionLabel('Agente Personal'),
      SettingsCard(
        children: [
          SettingsRow(
            icon: Icons.psychology_outlined,
            title: 'Aprender de mis conversaciones',
            subtitle: 'Importar, revisar y personalizar por contacto',
            onTap: () => Navigator.of(context).push(
              nanoGlassPageRoute<void>(
                builder: (_) => const PersonalizationStudioScreen(),
              ),
            ),
          ),
        ],
      ),
      const SizedBox(height: 16),
      const PersonalAgentCard(),
      const SizedBox(height: 24),
      const AutomationSectionLabel('Tono de respuesta'),
      const ToneCard(),
      const SizedBox(height: 24),
      const AutomationSectionLabel('Datos del negocio'),
      const BusinessDataCard(),
    ];
  }

  List<Widget> _buildSystemSection(BuildContext context, VoidCallback? onDevTap) {
    final rulesCount = ref.watch(ruleRegistryProvider).rules.length;
    return [
      const AutomationSectionLabel('Reglas de Automatización'),
      SettingsCard(
        children: [
          SettingsRow(
            icon: Icons.rule_rounded,
            title: 'Reglas de automatización',
            subtitle: rulesCount == 0
                ? 'Sin reglas activas'
                : '$rulesCount regla${rulesCount == 1 ? '' : 's'} configurada${rulesCount == 1 ? '' : 's'}',
            trailing: ValueBadge(label: '$rulesCount'),
            onTap: () => Navigator.of(context).push(
              nanoGlassPageRoute<void>(
                builder: (_) => const AutomationRulesScreen(),
              ),
            ),
          ),
        ],
      ),
      const SizedBox(height: 24),
      const AutomationSectionLabel('Ejecución protegida'),
      const SettingsCard(
        children: [
          SettingsRow(
            icon: Icons.verified_user_outlined,
            title: 'Acciones críticas protegidas',
            subtitle: 'Confirmación y política activas',
            trailing: ReadonlyStatus(),
            showChevron: false,
          ),
          SettingsRow(
            icon: Icons.fact_check_outlined,
            title: 'Verificación de resultados',
            subtitle: 'Comprobar el estado después de actuar',
            trailing: ReadonlyStatus(),
            showChevron: false,
          ),
        ],
      ),
      const SizedBox(height: 24),
      const AutomationSectionLabel('Seguridad y accesos'),
      const CapabilityStatusCard(),
      if (onDevTap != null) ...[
        const SizedBox(height: 24),
        const AutomationSectionLabel('Diagnóstico'),
        SettingsCard(
          children: [
            SettingsRow(
              icon: Icons.smart_toy_outlined,
              title: 'Herramientas del agente',
              subtitle: 'Percepción, selectores y estado técnico',
              onTap: onDevTap,
            ),
          ],
        ),
      ],
    ];
  }
}
