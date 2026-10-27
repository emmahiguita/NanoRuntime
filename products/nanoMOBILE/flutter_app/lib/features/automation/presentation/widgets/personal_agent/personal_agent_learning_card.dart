import 'package:flutter/material.dart';
import 'package:nanoai/core/theme/nano_transitions.dart';
import 'package:nanoai/features/automation/personal_agent/presentation/personalization_studio_screen.dart';
import '../settings_tile_components.dart';

/// QUÉ HACE:
/// Tarjeta de accesos directos al estudio de personalización, frases y memoria.
///
/// CÓMO FUNCIONA:
/// Permite navegar a la pantalla de frases aprendidas, memoria factual FTS4
/// o importador de chats de WhatsApp con transiciones de navegación fluidas.
///
/// POR QUÉ:
/// Ofrece al usuario un punto de entrada centralizado para expandir el
/// conocimiento del agente personal sin saturar la pantalla principal.
class PersonalAgentLearningCard extends StatelessWidget {
  const PersonalAgentLearningCard({super.key});

  @override
  Widget build(BuildContext context) {
    return SettingsCard(
      children: [
        SettingsRow(
          imageAsset: 'assets/automation/icons/icon_respuestas_wpp.png',
          title: 'Mis frases y respuestas aprendidas',
          subtitle:
              'Intenciones con múltiples respuestas: qué te dicen y qué responder.',
          trailing: const ValueBadge(label: 'FRASES'),
          onTap: () => Navigator.of(context).push(
            nanoGlassPageRoute<void>(
              builder: (_) =>
                  const PersonalizationStudioScreen(initialIndex: 0),
            ),
          ),
        ),
        SettingsRow(
          icon: Icons.psychology_outlined,
          title: 'Memorias y datos sobre mí',
          subtitle:
              'Tus horarios, gustos y actividades para que el agente responda con la verdad.',
          trailing: const ValueBadge(label: 'MEMORIAS'),
          onTap: () => Navigator.of(context).push(
            nanoGlassPageRoute<void>(
              builder: (_) =>
                  const PersonalizationStudioScreen(initialIndex: 2),
            ),
          ),
        ),
        SettingsRow(
          imageAsset: 'assets/automation/icons/icon_reglas.png',
          title: 'Importar chat de WhatsApp',
          subtitle:
              'Carga un chat exportado (.txt) para extraer vocabulario y expresiones reales.',
          trailing: const ValueBadge(label: 'IMPORTAR'),
          onTap: () => Navigator.of(context).push(
            nanoGlassPageRoute<void>(
              builder: (_) =>
                  const PersonalizationStudioScreen(initialIndex: 3),
            ),
          ),
        ),
      ],
    );
  }
}
