import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'nano_ai_models.dart';
import 'nano_owl_alive.dart';
import 'nano_owl_orbital_ring.dart';
import 'nano_voice_wave.dart';
import '../../../../core/widgets/effects/nano_voice_beam.dart';

/// Cabecera compacta: una sola indicación animada del trabajo del asistente.
class NanoAssistantHeader extends StatelessWidget {
  const NanoAssistantHeader({
    super.key,
    required this.activity,
    required this.isMedia,
    required this.onClose,
  });
  final NanoActivity activity;
  final bool isMedia;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      NanoOwlOrbitalRing(
        size: 46,
        activity: activity,
        child: NanoOwlAlive(size: 38, activity: activity),
      ),
      const SizedBox(width: 10),
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Búho AI', style: Theme.of(context).textTheme.titleMedium),
            Text(
              isMedia ? 'Archivos multimedia' : 'Asistente Nano',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
      IconButton(
        tooltip: 'Cerrar Búho AI',
        onPressed: onClose,
        icon: const Icon(Icons.close_rounded),
      ),
    ],
  );
}

/// Entrada única para teclado y voz, usando tipografía y contraste del tema.
class NanoAssistantComposer extends StatelessWidget {
  const NanoAssistantComposer({
    super.key,
    required this.input,
    required this.isMedia,
    required this.isListening,
    required this.audioLevel,
    required this.onVoice,
    required this.onSend,
  });
  final TextEditingController input;
  final bool isMedia, isListening;
  final ValueListenable<double> audioLevel;
  final VoidCallback? onVoice;
  final VoidCallback onSend;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      NanoVoiceBeam(
        isListening: isListening,
        audioLevel: audioLevel,
        borderRadius: 16,
        child: TextField(
          controller: input,
          minLines: 1,
          maxLines: 3,
          textInputAction: TextInputAction.send,
          onSubmitted: (_) => onSend(),
          style: Theme.of(context).textTheme.bodyMedium,
          decoration: InputDecoration(
            hintText: isMedia ? 'Pega un enlace multimedia…' : 'Pregúntale a Búho AI…',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
            suffixIcon: onVoice == null
                ? null
                : IconButton(
                    tooltip: 'Dictar por voz',
                    onPressed: onVoice,
                    icon: Icon(
                      isListening ? Icons.mic_rounded : Icons.mic_none_rounded,
                      color: isListening ? const Color(0xFF22D3EE) : null,
                    ),
                  ),
          ),
        ),
      ),
      if (isListening) ...[const SizedBox(height: 4), NanoVoiceWave(audioLevel: audioLevel)],
    ],
  );
}
