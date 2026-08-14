import 'dart:convert';
import 'dart:io';
import 'dart:ui';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nanoai/core/models/chat_models.dart';
import 'package:nanoai/core/providers/chat_provider.dart';
import 'package:nanoai/core/widgets/live_animations.dart';
import 'package:nanoai/core/widgets/nano_screen_shell.dart';
import 'package:speech_to_text/speech_to_text.dart';

/// Pantalla Chat — identidad visual de Inicio (glassmorphism, sin AppBar).
///
/// Los nombres de estado y métodos son los REALES de ChatNotifier:
/// `send(text)`, `stop()`, `refreshEngine()`. El motor nunca se simula:
/// cuando no está disponible, el envío queda desactivado y la UI lo dice.
class ChatScreen extends ConsumerStatefulWidget {
  const ChatScreen({super.key});

  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen> {
  final _inputController = TextEditingController();
  final _scrollController = ScrollController();

  // Dictado por voz real (speech_to_text) y adjunto de archivos real
  // (file_picker → SAF de Android). Ambos fallan a mensaje honesto,
  // nunca a excepción suelta.
  final SpeechToText _speech = SpeechToText();
  bool _speechReady = false;
  bool _listening = false;

  /// Máximo de caracteres de un archivo adjunto que se insertan en el input.
  static const _maxAttachChars = 8000;

  @override
  void dispose() {
    if (_speechReady && _speech.isListening) {
      _speech.stop();
    }
    _inputController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _showHonestError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: const Color(0xFF07192B),
          behavior: SnackBarBehavior.floating,
        ),
      );
  }

  /// Inicializa el motor de voz una sola vez (pide permiso RECORD_AUDIO
  /// en el primer uso) y alterna escucha con resultados al input.
  Future<void> _toggleMic() async {
    if (!_speechReady) {
      try {
        _speechReady = await _speech.initialize(
          onStatus: (status) {
            if (!mounted) return;
            setState(() => _listening = status == 'listening');
          },
          onError: (error) {
            if (!mounted) return;
            setState(() => _listening = false);
            _showHonestError('Micrófono no disponible: $error');
          },
        );
      } catch (e) {
        _speechReady = false;
        if (!mounted) return;
        _showHonestError('Micrófono no disponible: $e');
        return;
      }
      if (!_speechReady) {
        if (!mounted) return;
        _showHonestError(
          'Reconocimiento de voz no disponible en este '
          'dispositivo.',
        );
        return;
      }
    }

    if (_speech.isListening) {
      await _speech.stop();
      return;
    }

    try {
      await _speech.listen(
        onResult: (result) {
          if (!mounted) return;
          _inputController.text = result.recognizedWords;
          _inputController.selection = TextSelection.collapsed(
            offset: _inputController.text.length,
          );
        },
        listenOptions: SpeechListenOptions(
          listenFor: const Duration(seconds: 60),
          pauseFor: const Duration(seconds: 5),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      _showHonestError('No se pudo iniciar el dictado: $e');
    }
  }

  /// Abre el selector de archivos (SAF) e inserta el contenido textual en el
  /// input. Binarios o archivos ilegibles se reportan, no se inventa texto.
  Future<void> _attachFile() async {
    try {
      final result = await FilePicker.pickFiles(
        type: FileType.any,
        withData: true,
      );
      final file = result?.files.single;
      if (file == null || file.path == null) return;

      final bytes = file.bytes ?? await File(file.path!).readAsBytes();
      final text = utf8.decode(bytes, allowMalformed: true);

      // Heurística honesta: si el contenido no es texto imprimible, no sirve.
      if (text.trim().isEmpty || text.contains('�') || _looksBinary(text)) {
        _showHonestError(
          'El archivo no parece texto legible; adjunta '
          'archivos .txt/.md/.log.',
        );
        return;
      }

      final clipped = text.length > _maxAttachChars
          ? '${text.substring(0, _maxAttachChars)}\n…[truncado]'
          : text;
      _inputController.text = clipped;
      _inputController.selection = TextSelection.collapsed(
        offset: _inputController.text.length,
      );
    } catch (e) {
      if (!mounted) return;
      _showHonestError('No se pudo leer el archivo: $e');
    }
  }

  bool _looksBinary(String text) {
    const window = 512;
    final sample = text.length > window ? text.substring(0, window) : text;
    var controlChars = 0;
    for (final codeUnit in sample.codeUnits) {
      if (codeUnit < 9 || (codeUnit > 13 && codeUnit < 32)) {
        controlChars++;
      }
    }
    return controlChars > sample.length / 100; // >1% de control chars
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;
      final target = _scrollController.position.maxScrollExtent;
      if (MediaQuery.disableAnimationsOf(context)) {
        _scrollController.jumpTo(target);
      } else {
        _scrollController.animateTo(
          target,
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(chatProvider);
    final notifier = ref.read(chatProvider.notifier);

    // Auto-scroll al fondo con cada mensaje nuevo y al arrancar generación.
    ref.listen(chatProvider.select((s) => s.messages.length), (_, __) {
      _scrollToBottom();
    });
    ref.listen(chatProvider.select((s) => s.generating), (_, __) {
      _scrollToBottom();
    });

    return NanoScreenShell(
      title: 'Chat',
      trailing: _EngineBadge(online: state.engineOnline),
      body: Column(
        children: [
          Expanded(
            child: state.messages.isEmpty
                ? _EmptyChat(
                    engineOnline: state.engineOnline,
                    onSuggestion: (text) {
                      _inputController.text = text;
                    },
                    onRetry: () => notifier.refreshEngine(),
                  )
                : ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.fromLTRB(18, 8, 18, 18),
                    itemCount:
                        state.messages.length + (state.generating ? 1 : 0),
                    itemBuilder: (context, index) {
                      if (index == state.messages.length) {
                        return _StreamingBubble(
                          text: state.streamingText,
                          model: state.activeModel,
                        );
                      }

                      final message = state.messages[index];

                      return AnimatedMessageEntry(
                        key: ValueKey(message.id),
                        isUser: message.sender == MessageSender.user,
                        child: _MessageBubble(
                          text: message.text,
                          isUser: message.sender == MessageSender.user,
                          model: state.activeModel,
                          timestamp: message.timestamp,
                          isError: message.status == MessageStatus.error,
                        ),
                      );
                    },
                  ),
          ),
          _Composer(
            controller: _inputController,
            enabled: state.engineOnline && !state.generating,
            generating: state.generating,
            listening: _listening,
            onAttach: _attachFile,
            onMic: _toggleMic,
            onSend: () {
              final text = _inputController.text.trim();
              if (text.isEmpty) return;

              notifier.send(text);
              _inputController.clear();
            },
            onStop: notifier.stop,
          ),
        ],
      ),
    );
  }
}

/// Badge de estado del motor con pulso lento cuando está online. Detenido:
/// sin animación (estado quieto, honesto — solo lo vivo respira).
class _EngineBadge extends StatefulWidget {
  const _EngineBadge({required this.online});

  final bool online;

  @override
  State<_EngineBadge> createState() => _EngineBadgeState();
}

class _EngineBadgeState extends State<_EngineBadge>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    );

    if (widget.online) {
      _controller.repeat(reverse: true);
    }
  }

  @override
  void didUpdateWidget(covariant _EngineBadge oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (widget.online) {
      if (!_controller.isAnimating) {
        _controller.repeat(reverse: true);
      }
    } else {
      _controller.stop();
      _controller.value = 0;
    }
  }

  @override
  Widget build(BuildContext context) {
    final online = widget.online;
    final color = online ? const Color(0xFF21F2B2) : const Color(0xFFFFA726);
    final reduceMotion = MediaQuery.disableAnimationsOf(context);

    return Semantics(
      label: online ? 'Motor local conectado' : 'Motor local detenido',
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          final intensity = reduceMotion
              ? 0.10
              : 0.10 + _controller.value * 0.18;

          return Container(
            constraints: const BoxConstraints(minHeight: 44),
            padding: const EdgeInsets.symmetric(horizontal: 13),
            decoration: BoxDecoration(
              color: const Color(0xFF07192B).withValues(alpha: 0.72),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: color.withValues(alpha: 0.45)),
              boxShadow: [
                BoxShadow(
                  color: color.withValues(alpha: intensity),
                  blurRadius: 12,
                ),
              ],
            ),
            child: child,
          );
        },
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 9,
              height: 9,
              decoration: BoxDecoration(
                color: color,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(color: color.withValues(alpha: 0.5), blurRadius: 8),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Text(
              online ? 'LOCAL' : 'DETENIDO',
              style: TextStyle(
                color: color,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }
}

class _MessageBubble extends StatelessWidget {
  const _MessageBubble({
    required this.text,
    required this.isUser,
    required this.model,
    required this.timestamp,
    this.isError = false,
    this.trailing,
  });

  final String text;
  final bool isUser;
  final String model;
  final DateTime timestamp;
  final bool isError;

  /// Widget inline tras el texto (cursor de streaming).
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final time =
        '${timestamp.hour.toString().padLeft(2, '0')}:'
        '${timestamp.minute.toString().padLeft(2, '0')}';

    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Semantics(
        label: isUser ? 'Mensaje del usuario' : 'Respuesta de NanoAI',
        child: RepaintBoundary(
          child: Container(
            constraints: BoxConstraints(
              maxWidth: MediaQuery.sizeOf(context).width * 0.82,
            ),
            margin: const EdgeInsets.only(bottom: 16),
            child: Column(
              crossAxisAlignment: isUser
                  ? CrossAxisAlignment.end
                  : CrossAxisAlignment.start,
              children: [
                if (!isUser) ...[
                  Text(
                    'NanoAI · ${model.isEmpty || model == 'Sin modelo' ? 'modelo local' : model}',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.58),
                      fontSize: 11,
                    ),
                  ),
                  const SizedBox(height: 5),
                ],
                ClipRRect(
                  borderRadius: BorderRadius.circular(18),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                    child: Container(
                      padding: const EdgeInsets.fromLTRB(15, 12, 15, 9),
                      decoration: BoxDecoration(
                        color: isUser
                            ? const Color(0xFF005D72).withValues(alpha: 0.62)
                            : const Color(0xFF072238).withValues(alpha: 0.66),
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(
                          color: isError
                              ? const Color(0xFFFF5C6C).withValues(alpha: 0.55)
                              : isUser
                              ? const Color(0xFF42D9FF).withValues(alpha: 0.42)
                              : const Color(0xFF21F2B2).withValues(alpha: 0.35),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          if (trailing == null)
                            Text(
                              text,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 15,
                                height: 1.42,
                              ),
                            )
                          else
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Flexible(
                                  child: Text(
                                    text,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 15,
                                      height: 1.42,
                                    ),
                                  ),
                                ),
                                trailing!,
                              ],
                            ),
                          const SizedBox(height: 5),
                          Text(
                            time,
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.48),
                              fontSize: 10,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _StreamingBubble extends StatelessWidget {
  const _StreamingBubble({required this.text, required this.model});

  final String text;
  final String model;

  @override
  Widget build(BuildContext context) {
    // Generando sin tokens todavía: onda de tres puntos. Con texto: burbuja
    // real + cursor respirando inline.
    if (text.isEmpty) {
      return const Align(
        alignment: Alignment.centerLeft,
        child: Padding(
          padding: EdgeInsets.only(bottom: 16),
          child: ThinkingIndicator(),
        ),
      );
    }

    return _MessageBubble(
      text: text,
      isUser: false,
      model: model,
      timestamp: DateTime.now(),
      trailing: const StreamingCursor(),
    );
  }
}

class _Composer extends StatelessWidget {
  const _Composer({
    required this.controller,
    required this.enabled,
    required this.generating,
    required this.listening,
    required this.onAttach,
    required this.onMic,
    required this.onSend,
    required this.onStop,
  });

  final TextEditingController controller;
  final bool enabled;
  final bool generating;
  final bool listening;
  final VoidCallback onAttach;
  final VoidCallback onMic;
  final VoidCallback onSend;
  final VoidCallback onStop;

  @override
  Widget build(BuildContext context) {
    final reduceMotion = MediaQuery.disableAnimationsOf(context);

    // El campo crece con suavidad al añadir líneas (AnimatedSize anima el
    // cambio de altura del TextField multi-línea).
    final inputField = TextField(
      controller: controller,
      enabled: enabled,
      minLines: 1,
      maxLines: 5,
      textInputAction: TextInputAction.newline,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        hintText: listening
            ? 'Escuchando…'
            : enabled
            ? 'Escribe un mensaje'
            : 'Motor local no disponible',
        hintStyle: TextStyle(
          color: listening
              ? const Color(0xFF21F2B2)
              : Colors.white.withValues(alpha: 0.42),
        ),
        border: InputBorder.none,
      ),
    );

    final sendButton = IconButton.filled(
      tooltip: generating ? 'Detener' : 'Enviar',
      onPressed: generating ? onStop : (enabled ? onSend : null),
      style: IconButton.styleFrom(
        minimumSize: const Size(48, 48),
        backgroundColor: const Color(0xFF21D991),
        foregroundColor: Colors.white,
      ),
      icon: Icon(generating ? Icons.stop_rounded : Icons.arrow_upward_rounded),
    );

    return Padding(
      padding: EdgeInsets.fromLTRB(
        16,
        8,
        16,
        14 + MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
          child: Container(
            constraints: const BoxConstraints(minHeight: 62),
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
            decoration: BoxDecoration(
              color: const Color(0xFF07192B).withValues(alpha: 0.74),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: const Color(0xFF42D9FF).withValues(alpha: 0.32),
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                IconButton(
                  tooltip: 'Adjuntar archivo',
                  onPressed: enabled ? onAttach : null,
                  icon: const Icon(Icons.attach_file_rounded),
                ),
                Expanded(
                  child: reduceMotion
                      ? inputField
                      : AnimatedSize(
                          duration: const Duration(milliseconds: 200),
                          curve: Curves.easeOut,
                          alignment: Alignment.bottomCenter,
                          child: inputField,
                        ),
                ),
                IconButton(
                  tooltip: listening ? 'Detener dictado' : 'Dictar por voz',
                  onPressed: enabled ? onMic : null,
                  icon: Icon(
                    listening ? Icons.mic_rounded : Icons.mic_none_rounded,
                    color: listening ? const Color(0xFF21F2B2) : null,
                  ),
                ),
                const SizedBox(width: 3),
                PressableScale(
                  child: reduceMotion
                      ? sendButton
                      : AnimatedContainer(
                          duration: const Duration(milliseconds: 300),
                          curve: Curves.easeOut,
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            boxShadow: generating
                                ? [
                                    BoxShadow(
                                      color: const Color(
                                        0xFF21F2B2,
                                      ).withValues(alpha: 0.42),
                                      blurRadius: 14,
                                    ),
                                  ]
                                : null,
                          ),
                          child: sendButton,
                        ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _EmptyChat extends StatelessWidget {
  const _EmptyChat({
    required this.engineOnline,
    required this.onSuggestion,
    required this.onRetry,
  });

  final bool engineOnline;
  final ValueChanged<String> onSuggestion;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              engineOnline
                  ? Icons.auto_awesome_rounded
                  : Icons.cloud_off_rounded,
              color: engineOnline
                  ? const Color(0xFF21F2B2)
                  : const Color(0xFFFFA726),
              size: 48,
            ),
            const SizedBox(height: 16),
            Text(
              engineOnline
                  ? '¿En qué puedo ayudarte?'
                  : 'El motor local está detenido',
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 19,
                fontWeight: FontWeight.w600,
              ),
            ),
            if (engineOnline) ...[
              const SizedBox(height: 18),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                alignment: WrapAlignment.center,
                children: [
                  ActionChip(
                    label: const Text('Explica esta pantalla'),
                    onPressed: () =>
                        onSuggestion('Explica lo que aparece en pantalla'),
                  ),
                  ActionChip(
                    label: const Text('Abrir Linux'),
                    onPressed: () =>
                        onSuggestion('Ayúdame a usar el escritorio Linux'),
                  ),
                ],
              ),
            ] else ...[
              const SizedBox(height: 8),
              Text(
                'Activa un modelo GGUF en la pantalla Modelos y el '
                'motor correrá 100% en el dispositivo.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.58),
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: 14),
              OutlinedButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh_rounded, size: 18),
                label: const Text('Reintentar'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
