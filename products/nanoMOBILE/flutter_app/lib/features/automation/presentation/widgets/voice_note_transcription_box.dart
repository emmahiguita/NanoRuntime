// voice_note_transcription_box.dart
// 
// QUÉ HACE:
// Muestra el texto resultante de transcribir una nota de voz en tiempo real
// con opción para copiar al portapapeles.
// 
// CÓMO FUNCIONA:
// - Renderiza un contenedor oscuro con borde fino y tipografía clara.
// - Ofrece un botón táctil con Semantics para copiar la transcripción a la memoria del móvil.
// 
// POR QUÉ:
// Separa la visualización del texto transcrito de la lógica de reproducción de audio,
// cumpliendo el principio de Responsabilidad Única (SRP) y manteniendo los archivos bajo 200 líneas.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Caja visual que renderiza el texto transcrito de una nota de voz con acción de copiado.
class VoiceNoteTranscriptionBox extends StatelessWidget {
  final String text;

  const VoiceNoteTranscriptionBox({super.key, required this.text});

  @override
  Widget build(BuildContext context) {
    if (text.isEmpty) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white.withValues(alpha: 0.15), width: 0.6),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Row(
                children: [
                  Icon(Icons.notes_rounded, color: Color(0xFF00FF88), size: 12),
                  SizedBox(width: 4),
                  Text(
                    'Transcripción en tiempo real',
                    style: TextStyle(color: Color(0xFF00FF88), fontSize: 10, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              Semantics(
                label: 'Copiar transcripción',
                child: InkWell(
                  onTap: () {
                    Clipboard.setData(ClipboardData(text: text));
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Transcripción copiada'), duration: Duration(seconds: 1)),
                    );
                  },
                  child: const Padding(
                    padding: EdgeInsets.all(2),
                    child: Icon(Icons.copy_rounded, color: Colors.white60, size: 13),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            text,
            style: const TextStyle(color: Colors.white, fontSize: 12, height: 1.3),
          ),
        ],
      ),
    );
  }
}
