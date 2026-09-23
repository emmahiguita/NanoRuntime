import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nanoai/features/automation/engine/messaging/tone_profile.dart';
import 'package:nanoai/features/automation/engine/messaging/tone_profile_providers.dart';
import '../settings_tile_components.dart';

/// QUÉ HACE:
/// Tarjeta para ajustar el estilo, calidez, extensión y emojis del bot.
///
/// CÓMO FUNCIONA:
/// Modifica reactivamente el [ToneProfileNotifier] para que los compositores
/// de respuestas inyecten directivas estilísticas al modelo o motor determinista.
///
/// POR QUÉ:
/// Evita que el agente suene artificial, robótico o impersonal, asegurando
/// que su vocabulario coincida exactamente con las preferencias del usuario.
class PersonalAgentToneCard extends ConsumerWidget {
  const PersonalAgentToneCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tone = ref.watch(toneProfileNotifierProvider);
    final toneNotifier = ref.read(toneProfileNotifierProvider.notifier);

    return SettingsCard(
      children: [
        SettingsRow(
          imageAsset: 'assets/automation/icons/icon_respuestas_wpp.png',
          title: 'Estilo automático de respuestas',
          subtitle: tone.enabled
              ? 'Activo: guía la calidez, extensión y emojis'
              : 'Inactivo: respuestas estándar',
          trailing: Switch(
            value: tone.enabled,
            onChanged: (v) => toneNotifier.update(tone.copyWith(enabled: v)),
          ),
          showChevron: false,
        ),
        if (tone.enabled) ...[
          SettingsRow(
            imageAsset: 'assets/automation/icons/icon_trato_cliente.png',
            title: 'Trato y calidez',
            subtitle: tone.warmth == ToneWarmth.cercano
                ? 'Cercano: tuteo amistoso y cercano'
                : 'Formal: trato respetuoso de usted',
            trailing: ValueBadge(
              label: tone.warmth == ToneWarmth.cercano ? 'CERCANO' : 'FORMAL',
            ),
            onTap: () => toneNotifier.update(
              tone.copyWith(
                warmth: tone.warmth == ToneWarmth.cercano
                    ? ToneWarmth.formal
                    : ToneWarmth.cercano,
              ),
            ),
          ),
          SettingsRow(
            imageAsset: 'assets/automation/icons/icon_extension.png',
            title: 'Extensión de mensajes',
            subtitle: switch (tone.verbosity) {
              ToneVerbosity.breve => 'Breve: respuestas directas y al grano',
              ToneVerbosity.media => 'Media: balance de detalle y concisión',
              ToneVerbosity.extensa => 'Extensa: explicaciones completas',
            },
            trailing: ValueBadge(label: tone.verbosity.name.toUpperCase()),
            onTap: () {
              final next = ToneVerbosity.values[
                  (tone.verbosity.index + 1) % ToneVerbosity.values.length];
              toneNotifier.update(tone.copyWith(verbosity: next));
            },
          ),
          SettingsRow(
            imageAsset: 'assets/automation/icons/icon_emoji.png',
            title: 'Uso de emojis',
            subtitle: tone.emojis
                ? 'Con moderación en mensajes casuales'
                : 'Sin emojis, puramente textual',
            trailing: Switch(
              value: tone.emojis,
              onChanged: (v) => toneNotifier.update(tone.copyWith(emojis: v)),
            ),
            showChevron: false,
          ),
        ],
      ],
    );
  }
}
