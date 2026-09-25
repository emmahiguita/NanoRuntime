import 'package:flutter/material.dart';
import 'package:nanoai/core/widgets/navigation/nano_navigation_panel.dart';
import '../automation_layout.dart';
import '../automation_visual_theme.dart';
import '../widgets/personal_agent/personal_agent_autonomy_card.dart';
import '../widgets/personal_agent/personal_agent_contacts_card.dart';
import '../widgets/personal_agent/personal_agent_header_banner.dart';
import '../widgets/personal_agent/personal_agent_identity_card.dart';
import '../widgets/personal_agent/personal_agent_learning_card.dart';
import '../widgets/personal_agent/personal_agent_mcp_card.dart';
import '../widgets/personal_agent/personal_agent_tone_card.dart';
import '../widgets/settings_tile_components.dart';
import '../widgets/whatsapp_integration_cards.dart';
import '../widgets/whatsapp_reply_delay_card.dart';
import '../widgets/whatsapp_web_bridge_card.dart';

/// QUÉ HACE:
/// Pantalla principal para configurar el Agente Personal de WhatsApp (EMMA).
///
/// CÓMO FUNCIONA:
/// Despliega una interfaz responsiva adaptada a modo vertical y horizontal
/// compacto, delegando cada sección en componentes especializados (< 200 líneas).
///
/// POR QUÉ:
/// Cumple con Single Responsibility Principle (SOLID) y arquitectura limpia,
/// garantizando legibilidad, mantenimiento y óptima usabilidad en móviles apaisados.
class PersonalAgentScreen extends StatelessWidget {
  const PersonalAgentScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: NanoShellBarScope(
        slotId: 'personal_agent_studio',
        child: SafeArea(
          top: true,
          bottom: false,
          child: LayoutBuilder(
            builder: (context, constraints) {
              final isLandscape =
                  AutomationLayout.isCompactLandscape(context) ||
                  constraints.maxWidth >= 600;

              return ListView(
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
                          const SizedBox(height: 12),
                          const PersonalAgentHeaderBanner(),
                          const SizedBox(height: 16),
                          if (isLandscape)
                            _buildLandscapeContent()
                          else
                            _buildPortraitContent(),
                        ],
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildPortraitContent() {
    return const Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AutomationSectionLabel('Modo de Atención Personal'),
        PersonalAgentAutonomyCard(),
        SizedBox(height: 12),
        PersonalAgentContactsCard(),
        SizedBox(height: 20),
        AutomationSectionLabel('Diagnóstico y Capacidad Operativa'),
        BackgroundAutomationCard(),
        SizedBox(height: 12),
        WhatsAppWebBridgeCard(),
        SizedBox(height: 12),
        PersonalAgentMcpCard(),
        SizedBox(height: 20),
        AutomationSectionLabel('Mi Identidad y Preferencias'),
        PersonalAgentIdentityCard(),
        SizedBox(height: 20),
        AutomationSectionLabel('Trato y Estilo de Expresión'),
        PersonalAgentToneCard(),
        SizedBox(height: 20),
        AutomationSectionLabel('Horarios Personales'),
        _PersonalHoursCard(),
        SizedBox(height: 20),
        AutomationSectionLabel('Diálogos, Memorias y Aprendizaje'),
        PersonalAgentLearningCard(),
        SizedBox(height: 16),
        WhatsAppReplyDelayCard(),
        SizedBox(height: 40),
      ],
    );
  }

  Widget _buildLandscapeContent() {
    return const Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              AutomationSectionLabel('Modo de Atención Personal'),
              PersonalAgentAutonomyCard(),
              SizedBox(height: 12),
              PersonalAgentContactsCard(),
              SizedBox(height: 16),
              AutomationSectionLabel('Mi Identidad y Preferencias'),
              PersonalAgentIdentityCard(),
              SizedBox(height: 16),
              AutomationSectionLabel('Horarios Personales'),
              _PersonalHoursCard(),
            ],
          ),
        ),
        SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              AutomationSectionLabel('Diagnóstico y Conexión'),
              BackgroundAutomationCard(),
              SizedBox(height: 10),
              WhatsAppWebBridgeCard(),
              SizedBox(height: 10),
              PersonalAgentMcpCard(),
              SizedBox(height: 16),
              AutomationSectionLabel('Trato y Estilo de Expresión'),
              PersonalAgentToneCard(),
              SizedBox(height: 16),
              AutomationSectionLabel('Diálogos, Memorias y Aprendizaje'),
              PersonalAgentLearningCard(),
              SizedBox(height: 14),
              WhatsAppReplyDelayCard(),
              SizedBox(height: 40),
            ],
          ),
        ),
      ],
    );
  }
}

class _PersonalHoursCard extends StatelessWidget {
  const _PersonalHoursCard();

  @override
  Widget build(BuildContext context) {
    return const SettingsCard(
      children: [
        SettingsRow(
          imageAsset: 'assets/automation/icons/icon_horarios.png',
          title: 'Disponibilidad personal',
          subtitle:
              'El agente personal atiende las 24 horas respetando tu modo de supervisión.',
          trailing: ValueBadge(label: '24/7 ACTIVO'),
          showChevron: false,
        ),
      ],
    );
  }
}
