import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'nano_ai_models.dart';
import 'nano_owl_alive.dart';
import 'nano_owl_orbital_ring.dart';
import 'nano_voice_wave.dart';
import '../../../../core/widgets/effects/nano_voice_beam.dart';

/// Cabecera compacta Material 3 Expressive del asistente flotante.
/// QUÉ HACE: Muestra el avatar orbital del Búho AI, título y botón de cierre.
/// CÓMO FUNCIONA: Adapta su altura e íconos según `compact` (modo horizontal)
///   y usa `Semantics` en vez de `Tooltip` para no requerir un `Overlay` externo.
/// POR QUÉ: Previene el error "No Overlay widget found" y evita solapamientos en landscape.
class NanoAssistantHeader extends StatelessWidget {
  const NanoAssistantHeader({
    super.key,
    required this.activity,
    required this.isMedia,
    required this.onClose,
    this.compact = false,
  });
  final NanoActivity activity;
  final bool isMedia;
  final VoidCallback onClose;
  final bool compact;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      NanoOwlOrbitalRing(
        size: compact ? 34 : 46,
        activity: activity,
        child: NanoOwlAlive(size: compact ? 28 : 38, activity: activity),
      ),
      SizedBox(width: compact ? 8 : 10),
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Búho AI',
              style: compact
                  ? Theme.of(context).textTheme.labelLarge
                  : Theme.of(context).textTheme.titleMedium,
            ),
            Text(
              isMedia ? 'Archivos multimedia' : 'Asistente Nano M3',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
      Semantics(
        label: 'Cerrar Búho AI',
        button: true,
        child: IconButton(
          visualDensity: compact ? VisualDensity.compact : VisualDensity.standard,
          onPressed: onClose,
          icon: Icon(Icons.close_rounded, size: compact ? 18 : 22),
        ),
      ),
    ],
  );
}

/// Campo de entrada multimodal (texto corto, párrafos largos y voz) con Material 3 Expressive.
/// QUÉ HACE: Captura desde un saludo corto ("Hola") hasta párrafos extensos o dictado por voz.
/// CÓMO FUNCIONA: Ajusta su densidad vertical en modo horizontal (`compact`) y elimina `Tooltip`
///   en el botón de micrófono, reemplazándolo por `Semantics` seguro.
/// POR QUÉ: Evita cajas rojas de error "No Overlay" y mantiene el formulario usable en horizontal.
class NanoAssistantComposer extends StatelessWidget {
  const NanoAssistantComposer({
    super.key,
    required this.input,
    required this.isMedia,
    required this.isListening,
    required this.audioLevel,
    required this.onVoice,
    required this.onSend,
    this.compact = false,
  });
  final TextEditingController input;
  final bool isMedia, isListening, compact;
  final ValueListenable<double> audioLevel;
  final VoidCallback? onVoice;
  final VoidCallback onSend;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    mainAxisSize: MainAxisSize.min,
    children: [
      NanoVoiceBeam(
        isListening: isListening,
        audioLevel: audioLevel,
        borderRadius: compact ? 14 : 16,
        child: TextField(
          controller: input,
          minLines: 1,
          maxLines: compact ? 2 : 4,
          textInputAction: TextInputAction.send,
          onSubmitted: (_) => onSend(),
          style: Theme.of(context).textTheme.bodyMedium,
          decoration: InputDecoration(
            isDense: compact,
            contentPadding: EdgeInsets.symmetric(
              horizontal: compact ? 12 : 16,
              vertical: compact ? 8 : 12,
            ),
            hintText: isMedia
                ? 'Pega un enlace multimedia…'
                : 'Escribe desde un "Hola" hasta un párrafo completo…',
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(compact ? 14 : 16),
            ),
            suffixIcon: onVoice == null
                ? null
                : Semantics(
                    label: 'Dictar por voz',
                    button: true,
                    child: IconButton(
                      visualDensity: compact
                          ? VisualDensity.compact
                          : VisualDensity.standard,
                      onPressed: onVoice,
                      icon: Icon(
                        isListening ? Icons.mic_rounded : Icons.mic_none_rounded,
                        size: compact ? 18 : 22,
                        color: isListening ? const Color(0xFF22D3EE) : null,
                      ),
                    ),
                  ),
          ),
        ),
      ),
      if (isListening) ...[
        const SizedBox(height: 4),
        NanoVoiceWave(audioLevel: audioLevel),
      ],
    ],
  );
}
