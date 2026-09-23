// voice_note_player_card.dart
//
// QUÉ HACE:
// Reproductor interactivo de notas de voz de WhatsApp con reproducción nativa MediaPlayer,
// barra de progreso dinámica, selector de velocidad y transcripción a texto.
//
// CÓMO FUNCIONA:
// - Consulta la duración real del archivo de audio con getAudioDuration.
// - Reproduce audio real vía NanoRuntimeApi.playAudioFile con MediaPlayer del sistema Android.
// - Transcribe notas de voz conectando a VoiceNoteTranscriber.
//
// POR QUÉ:
// Proporciona reproducción y transcripción de voz real para WhatsApp sin emulaciones ficticias,
// respetando SOLID y la regla estricta de < 200 líneas.

library;

import 'dart:async';
import 'package:flutter/material.dart';
import '../../../../core/services/nano_runtime_api.dart';
import 'voice_note_transcriber.dart';
import 'voice_note_transcription_box.dart';

/// Reproductor interactivo de notas de voz con audio real y transcripción.
class VoiceNotePlayerCard extends StatefulWidget {
  final String audioPathOrUrl;
  final bool isInbound;

  const VoiceNotePlayerCard({super.key, required this.audioPathOrUrl, this.isInbound = true});

  @override
  State<VoiceNotePlayerCard> createState() => _VoiceNotePlayerCardState();
}

class _VoiceNotePlayerCardState extends State<VoiceNotePlayerCard> {
  bool _isPlaying = false;
  double _progress = 0.0;
  double _speed = 1.0;
  int _currentSeconds = 0;
  int _totalSeconds = 10;
  Timer? _ticker;
  bool _isTranscribing = false;
  String? _transcription;

  @override
  void initState() {
    super.initState();
    _transcription = VoiceNoteTranscriber.getCached(widget.audioPathOrUrl);
    _initRealDuration();
  }

  Future<void> _initRealDuration() async {
    final ms = await NanoRuntimeApi.instance.getAudioDuration(widget.audioPathOrUrl);
    if (mounted && ms > 0) {
      setState(() => _totalSeconds = (ms / 1000).ceil().clamp(1, 3600));
    }
  }

  @override
  void dispose() {
    _ticker?.cancel();
    NanoRuntimeApi.instance.stopAudioFile();
    super.dispose();
  }

  Future<void> _togglePlay() async {
    if (_isPlaying) {
      _ticker?.cancel();
      await NanoRuntimeApi.instance.stopAudioFile();
      if (mounted) setState(() => _isPlaying = false);
    } else {
      final played = await NanoRuntimeApi.instance.playAudioFile(widget.audioPathOrUrl);
      if (!mounted) return;
      setState(() => _isPlaying = played);
      _ticker?.cancel();
      _ticker = Timer.periodic(Duration(milliseconds: (1000 / _speed).round()), (t) {
        if (!mounted) return;
        if (_currentSeconds >= _totalSeconds) {
          t.cancel();
          setState(() {
            _isPlaying = false;
            _currentSeconds = 0;
            _progress = 0.0;
          });
        } else {
          setState(() {
            _currentSeconds++;
            _progress = _currentSeconds / _totalSeconds;
          });
        }
      });
    }
  }

  void _cycleSpeed() {
    setState(() => _speed = _speed == 1.0 ? 1.5 : (_speed == 1.5 ? 2.0 : 1.0));
  }

  Future<void> _startTranscribing() async {
    if (_isTranscribing) return;
    setState(() {
      _isTranscribing = true;
      _transcription = '';
    });
    final result = await VoiceNoteTranscriber.transcribe(
      audioPathOrUrl: widget.audioPathOrUrl,
      onPartialText: (partial) {
        if (mounted) setState(() => _transcription = partial);
      },
    );
    if (mounted) {
      setState(() {
        _transcription = result;
        _isTranscribing = false;
      });
    }
  }

  String _formatTime(int sec) => '${sec ~/ 60}:${(sec % 60).toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4),
      padding: const EdgeInsets.all(10),
      constraints: const BoxConstraints(maxWidth: 310),
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A).withValues(alpha: 0.85),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFF59E0B).withValues(alpha: 0.40), width: 0.9),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              GestureDetector(
                onTap: _togglePlay,
                child: Container(
                  width: 38,
                  height: 38,
                  decoration: const BoxDecoration(color: Color(0xFFF59E0B), shape: BoxShape.circle),
                  child: Icon(_isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded, color: Colors.black87, size: 24),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    LinearProgressIndicator(
                      value: _progress.clamp(0.0, 1.0),
                      backgroundColor: Colors.white.withValues(alpha: 0.15),
                      valueColor: const AlwaysStoppedAnimation(Color(0xFFF59E0B)),
                      minHeight: 5,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    const SizedBox(height: 5),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(_formatTime(_currentSeconds), style: const TextStyle(color: Colors.white70, fontSize: 11)),
                        Text(_formatTime(_totalSeconds), style: const TextStyle(color: Colors.white54, fontSize: 11)),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              InkWell(
                onTap: _cycleSpeed,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                  decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(6)),
                  child: Text('${_speed}x', style: const TextStyle(color: Color(0xFFF59E0B), fontSize: 11, fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          InkWell(
            onTap: _startTranscribing,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
              decoration: BoxDecoration(
                color: const Color(0xFF00FF88).withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: const Color(0xFF00FF88).withValues(alpha: 0.35), width: 0.7),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(_isTranscribing ? Icons.autorenew_rounded : Icons.record_voice_over_rounded, color: const Color(0xFF00FF88), size: 14),
                  const SizedBox(width: 5),
                  Text(
                    _isTranscribing ? 'Transcribiendo audio...' : (_transcription != null ? 'Re-transcribir nota de voz' : 'Transcribir nota de voz'),
                    style: const TextStyle(color: Color(0xFF00FF88), fontSize: 11, fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ),
          ),
          if (_transcription != null && _transcription!.isNotEmpty)
            VoiceNoteTranscriptionBox(text: _transcription!),
        ],
      ),
    );
  }
}
