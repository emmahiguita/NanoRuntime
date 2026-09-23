/// NANO-PERSONAL-TIMING-TAB — Pestaña "Tiempos y Pausa de Envío".
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../engine/messaging/tone_profile.dart';
import '../../engine/messaging/tone_profile_providers.dart';
import '../automation_visual_theme.dart';
import '../widgets/settings_tile_components.dart';
import '../widgets/whatsapp_reply_delay_card.dart';

class NanoPersonalTimingTab extends ConsumerWidget {
  const NanoPersonalTimingTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final visual = AutomationVisual.of(context);
    final tone = ref.watch(toneProfileNotifierProvider);
    final toneNotifier = ref.read(toneProfileNotifierProvider.notifier);

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
      children: [
        // 1. Tarjeta principal de delay humano
        const WhatsAppReplyDelayCard(),
        const SizedBox(height: 16),

        // 2. Simulación de tipeo humano en WhatsApp
        const AutomationSectionLabel('Simulación de Tipeo Humano'),
        SettingsCard(
          children: [
            SettingsRow(
              icon: Icons.chat_bubble_outline_rounded,
              title: 'Longitud y detalle del mensaje',
              subtitle: 'Afecta la cadencia y tiempo que toma redactar la respuesta.',
              trailing: ValueBadge(
                label: tone.verbosity.name.toUpperCase(),
              ),
              onTap: () {
                final next = switch (tone.verbosity) {
                  ToneVerbosity.breve => ToneVerbosity.media,
                  ToneVerbosity.media => ToneVerbosity.extensa,
                  ToneVerbosity.extensa => ToneVerbosity.breve,
                };
                toneNotifier.update(tone.copyWith(enabled: true, verbosity: next));
              },
            ),
            const SettingsRow(
              icon: Icons.hourglass_bottom_rounded,
              title: 'Pausa de lectura previa',
              subtitle: 'Espera entre 3 y 8 segundos para simular que lees el chat.',
              trailing: ValueBadge(label: 'ACTIVA'),
            ),
          ],
        ),
        const SizedBox(height: 16),

        // 3. Horarios y disponibilidad
        const AutomationSectionLabel('Disponibilidad y Horarios'),
        SettingsCard(
          children: [
            const SettingsRow(
              icon: Icons.access_time_rounded,
              title: 'Atención 24/7',
              subtitle: 'El agente responde en cualquier momento del día o noche.',
              trailing: ValueBadge(label: '24 HORAS'),
            ),
            SettingsRow(
              icon: Icons.nightlight_round,
              title: 'Respetar horario nocturno',
              subtitle: 'Pausa respuestas automáticas entre las 11:00 PM y 6:00 AM.',
              trailing: const ValueBadge(label: 'CONFIGURAR'),
              onTap: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    backgroundColor: visual.surface,
                    content: Text(
                      'Modo nocturno programado en el motor de reglas.',
                      style: TextStyle(color: visual.text, fontSize: 12),
                    ),
                    duration: const Duration(seconds: 2),
                  ),
                );
              },
            ),
          ],
        ),
      ],
    );
  }
}
