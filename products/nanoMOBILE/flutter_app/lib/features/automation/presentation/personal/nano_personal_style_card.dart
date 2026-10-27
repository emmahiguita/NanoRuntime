import 'package:flutter/material.dart';
import '../../engine/messaging/tone_profile.dart';

/// QUÉ: controles de tono conectados al perfil, sin estado duplicado.
/// CÓMO: muestra los valores persistidos y delega cambios al dueño del guardado.
/// POR QUÉ: separar presentación permite adaptar el formulario sin duplicar lógica.
class NanoPersonalStyleCard extends StatelessWidget {
  const NanoPersonalStyleCard({
    super.key,
    required this.tone,
    required this.onChanged,
  });
  final ToneProfile tone;
  final Future<void> Function(ToneProfile) onChanged;
  @override
  Widget build(BuildContext context) => Card(
    child: Column(
      children: [
        SwitchListTile(
          title: const Text('Trato formal'),
          subtitle: const Text('Desactivado: cercano y natural.'),
          value: tone.warmth == ToneWarmth.formal,
          onChanged: (v) => onChanged(
            tone.copyWith(warmth: v ? ToneWarmth.formal : ToneWarmth.cercano),
          ),
        ),
        SwitchListTile(
          title: const Text('Permitir emojis'),
          value: tone.emojis,
          onChanged: (v) => onChanged(tone.copyWith(emojis: v)),
        ),
        Padding(
          padding: const EdgeInsets.all(16),
          child: DropdownButtonFormField<ToneVerbosity>(
            initialValue: tone.verbosity,
            decoration: const InputDecoration(labelText: 'Extensión'),
            items: const [
              DropdownMenuItem(
                value: ToneVerbosity.breve,
                child: Text('Breve'),
              ),
              DropdownMenuItem(
                value: ToneVerbosity.media,
                child: Text('Normal'),
              ),
              DropdownMenuItem(
                value: ToneVerbosity.extensa,
                child: Text('Detallada'),
              ),
            ],
            onChanged: (v) {
              if (v != null) onChanged(tone.copyWith(verbosity: v));
            },
          ),
        ),
      ],
    ),
  );
}
