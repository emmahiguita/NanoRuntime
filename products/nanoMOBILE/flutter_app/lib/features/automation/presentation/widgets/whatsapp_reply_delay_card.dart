/// WA-REPLY-DELAY-CARD-01 — Configuración visual de delay y pausa humana de respuesta.
///
/// **QUÉ HACE:**
/// Permite al usuario configurar el tiempo de espera (delay en segundos) antes de que
/// Nano despache una respuesta automática en WhatsApp, simulando tipeo humano real.
///
/// **CÓMO FUNCIONA:**
/// Se conecta reactivamente a `settingsProvider` para leer y persistir `waReplyDelaySeconds`
/// mediante un slider adaptativo y botones de acceso rápido (0s, 3s, 5s, 10s).
///
/// **POR QUÉ:**
/// Elimina las respuestas robóticas instantáneas que delatan a un bot y previene bloqueos
/// por exceso de velocidad en WhatsApp, brindando una experiencia conversacional natural.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/providers/settings_provider.dart';

class WhatsAppReplyDelayCard extends ConsumerWidget {
  const WhatsAppReplyDelayCard({super.key});

  static const _presets = [0, 3, 5, 10, 15];

  String _formatDelayLabel(int seconds) {
    if (seconds == 0) return 'Inmediato (0 seg)';
    if (seconds <= 3) return '$seconds seg (Humano rápido)';
    if (seconds <= 5) return '$seconds seg (Recomendado)';
    if (seconds <= 10) return '$seconds seg (Pausa reflexiva)';
    return '$seconds seg (Pausa extendida)';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    final delaySeconds = settings.waReplyDelaySeconds;
    final theme = Theme.of(context);

    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      margin: const EdgeInsets.symmetric(vertical: 6),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.green.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.timer_outlined, color: Colors.green, size: 22),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Pausa de Envío (Delay Humano)',
                        style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
                      ),
                      Text(
                        'Tiempo de espera antes de enviar en WhatsApp',
                        style: theme.textTheme.bodySmall?.copyWith(color: theme.hintColor),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.green.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.green.withValues(alpha: 0.3)),
                  ),
                  child: Text(
                    _formatDelayLabel(delaySeconds),
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: Colors.green),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              'Simula el tiempo que tarda una persona en leer y redactar el mensaje antes de enviarlo. Evita respuestas automáticas instantáneas.',
              style: theme.textTheme.bodySmall?.copyWith(fontSize: 11.5, height: 1.35),
            ),
            const SizedBox(height: 10),
            SliderTheme(
              data: SliderTheme.of(context).copyWith(
                activeTrackColor: Colors.green,
                thumbColor: Colors.green,
                overlayColor: Colors.green.withValues(alpha: 0.2),
              ),
              child: Slider(
                value: delaySeconds.toDouble().clamp(0, 30),
                min: 0,
                max: 30,
                divisions: 30,
                label: '$delaySeconds s',
                onChanged: (val) {
                  final sec = val.round();
                  ref.read(settingsProvider.notifier).setWaReplyDelaySeconds(sec);
                },
              ),
            ),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  const Text('Preajustes: ', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
                  const SizedBox(width: 4),
                  for (final p in _presets)
                    Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: ChoiceChip(
                        label: Text(p == 0 ? '0s (Off)' : '${p}s', style: const TextStyle(fontSize: 10)),
                        selected: delaySeconds == p,
                        visualDensity: VisualDensity.compact,
                        onSelected: (selected) {
                          if (selected) {
                            ref.read(settingsProvider.notifier).setWaReplyDelaySeconds(p);
                            ScaffoldMessenger.of(context).hideCurrentSnackBar();
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Pausa configurada en ${p == 0 ? '0s (inmediata)' : '$p segundos'}.'),
                                duration: const Duration(seconds: 2),
                              ),
                            );
                          }
                        },
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
