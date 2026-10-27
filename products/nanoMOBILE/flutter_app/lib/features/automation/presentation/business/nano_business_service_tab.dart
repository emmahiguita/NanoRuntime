/// NANO-BUSINESS-SERVICE-TAB — Pestaña "Atención" del Agente Comercial.
///
/// QUÉ HACE:
/// Configura la estrategia de venta (persuasivo vs informativo), el trato al cliente,
/// las políticas de envío, cobertura a domicilio y devoluciones.
///
/// CÓMO FUNCIONA:
/// Sincroniza con [businessToneProfileNotifierProvider] y [DeliveryEditDialog],
/// adaptando las respuestas comerciales de Nano al estilo del negocio.
///
/// POR QUÉ:
/// Centraliza la atención y logística comercial en una interfaz clara
/// cumpliendo con el límite de 200 líneas de código.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../engine/business/business_facts_providers.dart';
import '../../engine/messaging/tone_profile.dart';
import '../../engine/messaging/tone_profile_providers.dart';
import '../automation_visual_theme.dart';
import '../widgets/dialogs/delivery_edit_dialog.dart';
import '../widgets/settings_tile_components.dart';

class NanoBusinessServiceTab extends ConsumerWidget {
  const NanoBusinessServiceTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tone = ref.watch(businessToneProfileNotifierProvider);
    final toneNotifier = ref.read(businessToneProfileNotifierProvider.notifier);
    final facts = ref.watch(businessFactsNotifierProvider);
    final isLandscape =
        MediaQuery.of(context).orientation == Orientation.landscape;

    return ListView(
      padding: EdgeInsets.fromLTRB(16, 6, 16, isLandscape ? 24 : 90),
      children: [
        const AutomationSectionLabel('Estrategia de Venta'),
        SettingsCard(
          children: [
            SettingsRow(
              icon: Icons.trending_up_rounded,
              title: 'Enfoque de venta',
              subtitle: tone.sales == ToneSales.persuasivo
                  ? 'Persuasivo — Resalta beneficios y busca cerrar la venta'
                  : 'Natural — Responde claro sin presionar la compra',
              trailing: ValueBadge(
                label: tone.sales == ToneSales.persuasivo
                    ? 'PERSUASIVO'
                    : 'NATURAL',
              ),
              onTap: () => toneNotifier.update(
                tone.copyWith(
                  enabled: true,
                  sales: tone.sales == ToneSales.persuasivo
                      ? ToneSales.natural
                      : ToneSales.persuasivo,
                ),
              ),
            ),
            SettingsRow(
              icon: Icons.record_voice_over_outlined,
              title: 'Trato al cliente',
              subtitle: tone.warmth == ToneWarmth.cercano
                  ? 'Cercano y amable (tuteo respetuoso)'
                  : 'Formal y respetuoso (usted)',
              trailing: ValueBadge(
                label: tone.warmth == ToneWarmth.cercano ? 'CERCANO' : 'FORMAL',
              ),
              onTap: () => toneNotifier.update(
                tone.copyWith(
                  enabled: true,
                  warmth: tone.warmth == ToneWarmth.cercano
                      ? ToneWarmth.formal
                      : ToneWarmth.cercano,
                ),
              ),
            ),
            SettingsRow(
              icon: Icons.format_align_left_rounded,
              title: 'Extensión de respuesta',
              subtitle: switch (tone.verbosity) {
                ToneVerbosity.breve => 'Breve — Respuestas directas',
                ToneVerbosity.media => 'Media — Contexto equilibrado',
                ToneVerbosity.extensa => 'Amplia — Más detalle cuando aplica',
              },
              trailing: ValueBadge(label: tone.verbosity.name.toUpperCase()),
              onTap: () => toneNotifier.update(
                tone.copyWith(
                  enabled: true,
                  verbosity: switch (tone.verbosity) {
                    ToneVerbosity.breve => ToneVerbosity.media,
                    ToneVerbosity.media => ToneVerbosity.extensa,
                    ToneVerbosity.extensa => ToneVerbosity.breve,
                  },
                ),
              ),
            ),
            SettingsRow(
              icon: Icons.emoji_emotions_outlined,
              title: 'Emojis moderados',
              subtitle: tone.emojis
                  ? 'Activados en saludos y datos destacados'
                  : 'Desactivados para un tono sobrio',
              trailing: Switch.adaptive(
                value: tone.emojis,
                onChanged: (value) => toneNotifier.update(
                  tone.copyWith(enabled: true, emojis: value),
                ),
              ),
              onTap: () => toneNotifier.update(
                tone.copyWith(enabled: true, emojis: !tone.emojis),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        const AutomationSectionLabel('Logística y Envíos'),
        SettingsCard(
          children: [
            SettingsRow(
              icon: Icons.local_shipping_outlined,
              title: 'Envíos y zonas de cobertura',
              subtitle: facts.delivery.trim().isNotEmpty
                  ? facts.delivery.trim()
                  : 'Sin políticas de envío configuradas — Toca para editar',
              onTap: () async {
                final text = await showDialog<String>(
                  context: context,
                  useRootNavigator: true,
                  builder: (_) => DeliveryEditDialog(initial: facts.delivery),
                );
                if (text != null) {
                  ref
                      .read(businessFactsNotifierProvider.notifier)
                      .setDelivery(text);
                }
              },
            ),
          ],
        ),
      ],
    );
  }
}
