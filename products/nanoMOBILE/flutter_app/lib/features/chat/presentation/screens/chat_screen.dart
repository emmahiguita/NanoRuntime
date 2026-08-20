import 'dart:convert';
import 'dart:io';
import 'dart:ui';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:nanoai/core/models/chat_models.dart';
import 'package:nanoai/core/providers/chat_provider.dart';
import 'package:nanoai/core/services/pdf_report_service.dart';
import 'package:nanoai/core/theme/design_tokens.dart';
import 'package:nanoai/core/widgets/live_animations.dart';
import 'package:nanoai/core/widgets/nano_components.dart';
import 'package:nanoai/core/widgets/nano_screen_shell.dart';
import 'package:share_plus/share_plus.dart';
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
  late final SpeechToText _speech;
  bool _speechEnabled = false;
  bool _listening = false;
  bool _isComposerMinimized = false;
  bool _isReadingMode = false;

  /// Máximo de caracteres de un archivo adjunto que se insertan en el input.
  static const _maxAttachChars = 8000;

  @override
  void initState() {
    super.initState();
    _speech = SpeechToText();
  }

  @override
  void dispose() {
    if (_speechEnabled && _speech.isListening) {
      _speech.stop();
    }
    _inputController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _showHonestError(String message) {
    if (!mounted) return;
    final colors = Theme.of(context).extension<NanoThemeExtension>()!.colors;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: colors.surfaceVariant,
          behavior: SnackBarBehavior.floating,
        ),
      );
  }

  /// Inicializa el motor de voz una sola vez (pide permiso RECORD_AUDIO
  /// en el primer uso) y alterna escucha con resultados al input.
  Future<void> _toggleMic() async {
    if (!_speechEnabled) {
      try {
        _speechEnabled = await _speech.initialize(
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
        _speechEnabled = false;
        if (!mounted) return;
        _showHonestError('Micrófono no disponible: $e');
        return;
      }
      if (!_speechEnabled) {
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

  /// Abre el selector de archivos (SAF) y registra el contenido textual como
  /// adjunto real en el estado del chat (chip visible en el composer). El
  /// contenido viaja al prompt del motor SOLO al enviar. Binarios o archivos
  /// ilegibles se reportan, no se inventa texto.
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
      if (text.trim().isEmpty || text.contains('') || _looksBinary(text)) {
        _showHonestError(
          'El archivo no parece texto legible; adjunta '
          'archivos .txt/.md/.log.',
        );
        return;
      }

      final clipped = text.length > _maxAttachChars
          ? '${text.substring(0, _maxAttachChars)}\n…[truncado]'
          : text;
      ref
          .read(chatProvider.notifier)
          .addAttachment(ChatAttachment(name: file.name, content: clipped));
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
      // Guard: el widget puede desmontarse antes de que se ejecute el callback.
      if (!mounted || !_scrollController.hasClients) return;
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
    final colors = Theme.of(context).extension<NanoThemeExtension>()!.colors;
    final state = ref.watch(chatProvider);
    final notifier = ref.read(chatProvider.notifier);
    final screenSize = MediaQuery.sizeOf(context);
    final isCompactLandscape =
        screenSize.width > screenSize.height && screenSize.height < 520;

    // Auto-scroll al fondo con cada mensaje nuevo y al arrancar generación.
    ref.listen(chatProvider.select((s) => s.messages.length), (_, __) {
      _scrollToBottom();
    });
    ref.listen(chatProvider.select((s) => s.generating), (_, __) {
      _scrollToBottom();
    });
    // Política §12: el tool-calling pidió una escritura externa — diálogo de
    // confirmación obligatorio (sin dismiss lateral: decisión del humano).
    ref.listen(chatProvider.select((s) => s.pendingTool), (prev, next) {
      if (next != null && prev != next) {
        _showToolConfirmDialog(next);
      }
    });

    return NanoScreenShell(
      title: 'Chat',
      hideHeader: _isReadingMode,
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (state.messages.isNotEmpty)
            IconButton(
              key: const ValueKey('chat_reading_mode_toggle'),
              tooltip: 'Modo lectura',
              visualDensity: VisualDensity.compact,
              onPressed: () => setState(() => _isReadingMode = true),
              icon: Icon(
                Icons.chrome_reader_mode_rounded,
                color: colors.onSurface.withValues(alpha: 0.72),
                size: 20,
              ),
            ),
          if (state.messages.isNotEmpty)
            IconButton(
              tooltip: 'Limpiar conversación',
              onPressed: state.generating
                  ? null
                  : () => _showClearDialog(notifier),
              icon: Icon(
                Icons.delete_sweep_rounded,
                color: colors.onSurface.withValues(alpha: 0.72),
                size: 22,
              ),
            ),
          const SizedBox(width: 4),
          _EngineBadge(
            online: state.engineOnline,
            loading: state.connection == ModelConnectionState.loadingModel,
          ),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: isCompactLandscape ? 1280 : 1120,
          ),
          child: Stack(
            children: [
              Positioned.fill(
                child: Column(
                  children: [
                    // ── Lista de mensajes ────────────────────────────────────
                    Expanded(
                      child: state.messages.isEmpty
                          ? _EmptyChat(
                              engineOnline: state.engineOnline,
                              hasModel: state.activeModelPath != null,
                              onSuggestion: (text) {
                                notifier.send(text);
                              },
                              onRetry: () => notifier.refreshEngine(),
                              onGoModels: () => context.go('/models'),
                            )
                          : ListView.builder(
                              controller: _scrollController,
                              physics: const BouncingScrollPhysics(),
                              padding: EdgeInsets.fromLTRB(
                                isCompactLandscape ? 10 : 18,
                                _isReadingMode ? 44 : 8,
                                _isReadingMode
                                    ? 52
                                    : (isCompactLandscape ? 10 : 18),
                                _isReadingMode ? 20 : 12,
                              ),
                              itemCount:
                                  state.messages.length +
                                  (state.generating ? 1 : 0),
                              itemBuilder: (context, index) {
                                if (index == state.messages.length) {
                                  return _StreamingBubble(
                                    text: state.streamingText,
                                    model: state.activeModel,
                                  );
                                }

                                final message = state.messages[index];
                                final isUser =
                                    message.sender == MessageSender.user;
                                final isError =
                                    message.status == MessageStatus.error;

                                return AnimatedMessageEntry(
                                  key: ValueKey(message.id),
                                  isUser: isUser,
                                  child: GestureDetector(
                                    onLongPress: state.generating
                                        ? null
                                        : () => _showDeleteDialog(
                                            notifier,
                                            message,
                                          ),
                                    child: _MessageBubble(
                                      text: message.text,
                                      isUser: isUser,
                                      model: state.activeModel,
                                      timestamp: message.timestamp,
                                      isError: isError,
                                      attachmentNames: message.attachmentNames,
                                      tps: message.tps,
                                      onRetry: isError && !state.generating
                                          ? () => notifier.retry(message.id)
                                          : null,
                                      onDelete: state.generating
                                          ? null
                                          : () => _showDeleteDialog(
                                              notifier,
                                              message,
                                            ),
                                    ),
                                  ),
                                );
                              },
                            ),
                    ),

                    // ── Barra de escritura FLOTANTE con Liquid Glass Water Morphing ──────────
                    if (!_isReadingMode)
                      Padding(
                        padding: EdgeInsets.fromLTRB(
                          isCompactLandscape ? 8 : 14,
                          2,
                          isCompactLandscape ? 8 : 14,
                          isCompactLandscape ? 5 : 10,
                        ),
                        child: _ComposerTransition(
                          child: _isComposerMinimized
                              ? Align(
                                  alignment: Alignment.centerRight,
                                  child: _MinimizedComposerBubble(
                                    key: const ValueKey('minimized_bubble'),
                                    onExpand: () => setState(
                                      () => _isComposerMinimized = false,
                                    ),
                                    hasAttachments:
                                        state.attachments.isNotEmpty,
                                    listening: _listening,
                                  ),
                                )
                              : _Composer(
                                  key: const ValueKey('expanded_composer'),
                                  controller: _inputController,
                                  enabled: state.canSend && !state.generating,
                                  generating: state.generating,
                                  listening: _listening,
                                  attachments: state.attachments,
                                  onRemoveAttachment: notifier.removeAttachment,
                                  onAttach: _attachFile,
                                  onMic: _toggleMic,
                                  onMinimize: () => setState(
                                    () => _isComposerMinimized = true,
                                  ),
                                  compact: isCompactLandscape,
                                  onSend: () {
                                    final text = _inputController.text.trim();
                                    if (text.isEmpty) return;

                                    notifier.send(text);
                                    _inputController.clear();
                                  },
                                  onStop: notifier.stop,
                                ),
                        ),
                      ),
                  ],
                ),
              ),
              if (_isReadingMode)
                Positioned(
                  top: 6,
                  right: 8,
                  child: _ReadingModeExit(
                    onExit: () => setState(() => _isReadingMode = false),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  /// Diálogo de confirmación para limpiar todo el historial.
  Future<void> _showClearDialog(ChatNotifier notifier) async {
    final colors = Theme.of(context).extension<NanoThemeExtension>()!.colors;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: colors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: colors.accent.withValues(alpha: 0.3)),
        ),
        title: Text(
          '¿Limpiar conversación?',
          style: TextStyle(color: colors.onSurface),
        ),
        content: Text(
          'Se eliminarán todos los mensajes. Esta acción no se puede deshacer.',
          style: TextStyle(color: colors.onSurface.withValues(alpha: 0.7)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            style: FilledButton.styleFrom(backgroundColor: colors.danger),
            child: const Text('Limpiar'),
          ),
        ],
      ),
    );
    if (confirmed == true && mounted) {
      await notifier.clear();
    }
  }

  /// Diálogo de confirmación para eliminar un mensaje individual.
  Future<void> _showDeleteDialog(
    ChatNotifier notifier,
    ChatMessage message,
  ) async {
    final colors = Theme.of(context).extension<NanoThemeExtension>()!.colors;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: colors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: colors.accent.withValues(alpha: 0.3)),
        ),
        title: Text(
          '¿Eliminar mensaje?',
          style: TextStyle(color: colors.onSurface),
        ),
        content: Text(
          message.text.length > 80
              ? '"${message.text.substring(0, 80)}…"'
              : '"${message.text}"',
          style: TextStyle(color: colors.onSurface.withValues(alpha: 0.7)),
          maxLines: 3,
          overflow: TextOverflow.ellipsis,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            style: FilledButton.styleFrom(backgroundColor: colors.danger),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
    if (confirmed == true && mounted) {
      notifier.delete(message.id);
    }
  }

  /// Diálogo de confirmación de herramienta. Decisión obligatoria del
  /// humano: aprobar ejecuta la acción (confirmed), rechazar la cancela con
  /// evidencia en el trace. Si la pantalla se desmonta sin decisión, el
  /// pendiente queda descartado por el siguiente send().
  Future<void> _showToolConfirmDialog(String tool) async {
    final description = ref.read(chatProvider).pendingToolDescription ?? '';
    final colors = Theme.of(context).extension<NanoThemeExtension>()!.colors;
    final approved = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: colors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: colors.accent.withValues(alpha: 0.3)),
        ),
        title: Text(
          'Confirmar acción "$tool"',
          style: TextStyle(color: colors.onSurface),
        ),
        content: Text(
          description.isEmpty
              ? 'El agente quiere ejecutar "$tool" en el dispositivo.'
              : description,
          style: TextStyle(color: colors.onSurface.withValues(alpha: 0.7)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Permitir'),
          ),
        ],
      ),
    );
    if (approved == null || !mounted) return;
    final notifier = ref.read(chatProvider.notifier);
    if (approved) {
      await notifier.approvePendingTool();
    } else {
      await notifier.rejectPendingTool();
    }
  }
}

/// Mantiene anclado el compositor al borde inferior durante el cambio de
/// estado. La escala y el deslizamiento conservan la continuidad espacial sin
/// convertir la minimización en un simple fundido.
class _ComposerTransition extends StatelessWidget {
  const _ComposerTransition({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final reduceMotion = MediaQuery.disableAnimationsOf(context);

    return AnimatedSwitcher(
      duration: reduceMotion
          ? Duration.zero
          : const Duration(milliseconds: 260),
      switchInCurve: Curves.easeOutCubic,
      switchOutCurve: Curves.easeInCubic,
      layoutBuilder: (currentChild, previousChildren) => Stack(
        alignment: Alignment.bottomRight,
        children: [...previousChildren, if (currentChild != null) currentChild],
      ),
      transitionBuilder: (transitionChild, animation) {
        final movement = Tween<Offset>(
          begin: const Offset(0, 0.10),
          end: Offset.zero,
        ).animate(animation);
        final scale = Tween<double>(begin: 0.97, end: 1.0).animate(animation);

        return FadeTransition(
          opacity: animation,
          child: SlideTransition(
            position: movement,
            child: ScaleTransition(scale: scale, child: transitionChild),
          ),
        );
      },
      child: child,
    );
  }
}

class _ReadingModeExit extends StatelessWidget {
  const _ReadingModeExit({required this.onExit});

  final VoidCallback onExit;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<NanoThemeExtension>()!.colors;

    return NanoOpticalSurface(
      geometry: NanoSurfaceGeometry.capsule,
      borderRadius: 999,
      blurSigma: 14,
      borderStrength: 0.58,
      reflectionStrength: 0.42,
      padding: EdgeInsets.zero,
      child: IconButton(
        key: const ValueKey('chat_reading_mode_exit'),
        tooltip: 'Salir del modo lectura',
        visualDensity: VisualDensity.compact,
        constraints: const BoxConstraints.tightFor(width: 38, height: 38),
        padding: EdgeInsets.zero,
        onPressed: onExit,
        icon: Icon(
          Icons.fullscreen_exit_rounded,
          size: 19,
          color: colors.onSurface.withValues(alpha: 0.78),
        ),
      ),
    );
  }
}

/// Badge de estado del motor con pulso lento cuando está online. Detenido:
/// sin animación (estado quieto, honesto — solo lo vivo respira).
class _EngineBadge extends StatefulWidget {
  const _EngineBadge({required this.online, this.loading = false});

  final bool online;
  final bool loading;

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
    final colors = Theme.of(context).extension<NanoThemeExtension>()!.colors;
    final online = widget.online;
    final loading = widget.loading;
    final color = online && !loading ? colors.success : colors.warning;
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
            key: const ValueKey('chat_engine_status_badge'),
            constraints: const BoxConstraints(minHeight: 28, maxWidth: 86),
            padding: const EdgeInsets.symmetric(horizontal: 6),
            decoration: BoxDecoration(
              color: colors.surfaceVariant.withValues(alpha: 0.72),
              borderRadius: BorderRadius.circular(9),
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
          mainAxisSize: MainAxisSize.max,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 6,
              height: 6,
              decoration: BoxDecoration(
                color: color,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(color: color.withValues(alpha: 0.5), blurRadius: 8),
                ],
              ),
            ),
            const SizedBox(width: 5),
            Flexible(
              child: Text(
                loading ? 'CARGANDO' : (online ? 'LOCAL' : 'DETENIDO'),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: color,
                  fontSize: 9.5,
                  fontWeight: FontWeight.w700,
                ),
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

MarkdownStyleSheet _buildChatMarkdownStyleSheet(
  BuildContext context, {
  required bool isUser,
}) {
  final colors = Theme.of(context).extension<NanoThemeExtension>()!.colors;
  return MarkdownStyleSheet(
    p: TextStyle(
      color: isUser
          ? colors.onSurface
          : colors.onSurface.withValues(alpha: 0.95),
      fontSize: 15,
      height: 1.55,
      letterSpacing: 0.15,
    ),
    h1: TextStyle(
      color: colors.accent,
      fontSize: 20,
      fontWeight: FontWeight.bold,
      height: 1.4,
    ),
    h2: TextStyle(
      color: colors.accent,
      fontSize: 18,
      fontWeight: FontWeight.w700,
      height: 1.4,
    ),
    h3: TextStyle(
      color: colors.success,
      fontSize: 16,
      fontWeight: FontWeight.w600,
      height: 1.35,
    ),
    strong: TextStyle(color: colors.onSurface, fontWeight: FontWeight.w700),
    em: TextStyle(
      color: colors.onSurface.withValues(alpha: 0.9),
      fontStyle: FontStyle.italic,
    ),
    listBullet: TextStyle(color: colors.accent, fontSize: 15),
    code: TextStyle(
      backgroundColor: colors.success.withValues(alpha: 0x20 / 0xFF),
      color: colors.success,
      fontFamily: 'monospace',
      fontSize: 13.5,
    ),
    codeblockPadding: const EdgeInsets.all(12),
    codeblockDecoration: BoxDecoration(
      color: colors.codeBlockBg,
      borderRadius: BorderRadius.circular(10),
      border: Border.all(color: colors.accent.withValues(alpha: 0.25)),
    ),
    blockquote: TextStyle(
      color: colors.onSurface.withValues(alpha: 0.8),
      fontSize: 14.5,
      fontStyle: FontStyle.italic,
    ),
    blockquoteDecoration: BoxDecoration(
      color: colors.quoteBg.withValues(alpha: 0.3),
      borderRadius: BorderRadius.circular(8),
      border: Border(left: BorderSide(color: colors.accent, width: 3)),
    ),
    tableBorder: TableBorder.all(
      color: colors.onSurface.withValues(alpha: 0.18),
      borderRadius: BorderRadius.circular(6),
    ),
    tableHead: TextStyle(color: colors.accent, fontWeight: FontWeight.w700),
    tableBody: TextStyle(color: colors.onSurface.withValues(alpha: 0.9)),
    tableCellsPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
  );
}

class _MessageBubble extends StatelessWidget {
  const _MessageBubble({
    required this.text,
    required this.isUser,
    required this.model,
    required this.timestamp,
    this.isError = false,
    this.attachmentNames = const [],
    this.tps,
    this.onRetry,
    this.onDelete,
  });

  final String text;
  final bool isUser;
  final String model;
  final DateTime timestamp;
  final bool isError;

  /// Tokens por segundo de la generación (solo respuestas AI completadas).
  final double? tps;

  /// Callback para reintentar el envío tras un error.
  final VoidCallback? onRetry;

  /// Callback para eliminar el mensaje.
  final VoidCallback? onDelete;

  /// Nombres de los adjuntos que viajaron con este mensaje (solo chips;
  /// el contenido se inyectó al prompt y no se persiste).
  final List<String> attachmentNames;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<NanoThemeExtension>()!.colors;
    final time =
        '${timestamp.hour.toString().padLeft(2, '0')}:'
        '${timestamp.minute.toString().padLeft(2, '0')}';

    // Pie del mensaje: hora + TPS (si hay)
    final footerParts = <Widget>[
      Text(
        time,
        style: TextStyle(
          color: colors.onSurface.withValues(alpha: 0.48),
          fontSize: 10,
        ),
      ),
    ];

    if (tps != null && !isUser) {
      footerParts.addAll([
        const SizedBox(width: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
          decoration: BoxDecoration(
            color: colors.success.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: colors.success.withValues(alpha: 0.30)),
          ),
          child: Text(
            '${tps!.toStringAsFixed(1)} tok/s',
            style: TextStyle(
              color: colors.success,
              fontSize: 10,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ]);
    }

    final isDark = colors is NanoDarkColors;
    final reduceMotion = MediaQuery.disableAnimationsOf(context);

    final bubbleBorderRadius = isUser
        ? NanoShapes.userBubble
        : NanoShapes.aiBubble;

    final bubbleDecoration = isUser
        ? BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: isDark
                  ? [
                      colors.primary.withValues(alpha: 0.35),
                      colors.accentCyan.withValues(alpha: 0.20),
                    ]
                  : [
                      colors.primary.withValues(alpha: 0.18),
                      colors.accentSky.withValues(alpha: 0.10),
                    ],
            ),
            borderRadius: bubbleBorderRadius,
            border: Border.all(
              color: isDark
                  ? colors.accentCyan.withValues(alpha: 0.50)
                  : colors.primary.withValues(alpha: 0.35),
              width: 1.0,
            ),
            boxShadow: [
              BoxShadow(
                color: (isDark ? colors.accentCyan : colors.primary).withValues(
                  alpha: isDark ? 0.20 : 0.08,
                ),
                blurRadius: 12,
                offset: const Offset(0, 3),
              ),
            ],
          )
        : BoxDecoration(
            gradient: NanoGlass.substrate(
              colors,
              opacity: isDark ? 0.78 : 0.88,
            ),
            borderRadius: bubbleBorderRadius,
          );

    Widget bubbleWidget = Container(
      constraints: BoxConstraints(maxWidth: isUser ? 680 : double.infinity),
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: bubbleDecoration,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (attachmentNames.isNotEmpty) ...[
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: attachmentNames
                  .map(
                    (name) => Chip(
                      label: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.attach_file_rounded,
                            size: 14,
                            color: colors.onSurface.withValues(alpha: 0.72),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            name,
                            style: TextStyle(
                              color: colors.onSurface.withValues(alpha: 0.72),
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                      backgroundColor: colors.onSurface.withValues(alpha: 0.08),
                      visualDensity: VisualDensity.compact,
                    ),
                  )
                  .toList(),
            ),
            const SizedBox(height: 8),
          ],
          if (!isUser) ...[
            Row(
              children: [
                Icon(
                  Icons.auto_awesome_rounded,
                  size: 14,
                  color: colors.accent.withValues(alpha: isDark ? 0.92 : 0.78),
                ),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    model.isEmpty ? 'NanoAI' : model,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: colors.onSurface.withValues(alpha: 0.60),
                      fontFamily: 'Inter',
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.2,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
          ],
          if (isUser)
            MarkdownBody(
              data: text,
              selectable: true,
              styleSheet: _buildChatMarkdownStyleSheet(context, isUser: isUser),
            )
          else
            _buildAiBody(context, text),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(children: footerParts),
              if (!isUser && !isError)
                _MessageActions(
                  text: text,
                  model: model,
                  timestamp: timestamp,
                  onDelete: onDelete,
                ),
              if (onRetry != null)
                Semantics(
                  button: true,
                  label: 'Reintentar mensaje',
                  child: Material(
                    color: Colors.transparent,
                    borderRadius: BorderRadius.circular(10),
                    child: InkWell(
                      onTap: onRetry,
                      borderRadius: BorderRadius.circular(10),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 5,
                          vertical: 4,
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.refresh_rounded,
                              size: 14,
                              color: colors.accent,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              'Reintentar',
                              style: TextStyle(
                                color: colors.accent,
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );

    if (!isUser) {
      bubbleWidget = Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          borderRadius: bubbleBorderRadius,
          boxShadow: NanoShadows.ambient(colors, depth: 0.6),
        ),
        child: Container(
          padding: const EdgeInsets.all(1.0),
          decoration: BoxDecoration(
            borderRadius: bubbleBorderRadius,
            gradient: NanoBorders.specularChamfer(colors),
          ),
          child: ClipRRect(
            borderRadius: bubbleBorderRadius,
            child: BackdropFilter(
              filter: ImageFilter.blur(
                sigmaX: reduceMotion ? 0.0 : 12.0,
                sigmaY: reduceMotion ? 0.0 : 12.0,
              ),
              child: bubbleWidget,
            ),
          ),
        ),
      );
    }

    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: bubbleWidget,
    );
  }
}

Widget _buildAiBody(BuildContext context, String text) {
  final parsed = parseThought(text);
  final thought = parsed.thought;
  final response = parsed.response;
  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      if (thought != null && thought.trim().isNotEmpty)
        ModelReasoningBlock(thought: thought),
      if (response.trim().isNotEmpty)
        MarkdownBody(
          data: response,
          selectable: true,
          styleSheet: _buildChatMarkdownStyleSheet(context, isUser: false),
        )
      else if (thought != null && response.isEmpty)
        const SizedBox.shrink()
      else
        MarkdownBody(
          data: text.isEmpty ? '...' : text,
          selectable: true,
          styleSheet: _buildChatMarkdownStyleSheet(context, isUser: false),
        ),
    ],
  );
}

// ================================================================
// Menú de acciones de mensaje (3 puntos)
// ================================================================

/// Menú profesional de 3 puntos para cada burbuja AI completada.
/// Organizado en 3 acciones: Copiar · Compartir · Exportar (PDF | Markdown).
class _MessageActions extends StatelessWidget {
  const _MessageActions({
    required this.text,
    required this.model,
    required this.timestamp,
    this.onDelete,
  });

  final String text;
  final String model;
  final DateTime timestamp;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<NanoThemeExtension>()!.colors;
    return PopupMenuButton<String>(
      icon: Icon(
        Icons.more_horiz_rounded,
        size: 18,
        color: colors.onSurface.withValues(alpha: 0.48),
      ),
      tooltip: 'Acciones',
      color: colors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: colors.accent.withValues(alpha: 0.25)),
      ),
      elevation: 8,
      position: PopupMenuPosition.under,
      onSelected: (value) async {
        switch (value) {
          case 'copy':
            await Clipboard.setData(ClipboardData(text: text));
            if (!context.mounted) return;
            ScaffoldMessenger.of(context)
              ..hideCurrentSnackBar()
              ..showSnackBar(
                const SnackBar(
                  content: Text('Texto copiado al portapapeles'),
                  duration: Duration(seconds: 2),
                  behavior: SnackBarBehavior.floating,
                ),
              );
            break;

          case 'share':
            await SharePlus.instance.share(
              ShareParams(text: text, subject: 'Respuesta NanoAI — $model'),
            );
            break;

          case 'delete':
            if (onDelete != null) onDelete!();
            break;

          case 'export_pdf':
            await PdfReportService.exportReport(
              title: 'Informe de Análisis NanoAI',
              content: text,
              modelName: model,
              timestamp: timestamp,
            );
            break;

          case 'export_md':
            await PdfReportService.exportMarkdown(
              title: 'Informe de Análisis NanoAI',
              content: text,
              modelName: model,
              timestamp: timestamp,
            );
            break;
        }
      },
      itemBuilder: (context) => [
        // ── 1. Copiar ──────────────────────────────────────────
        PopupMenuItem<String>(
          value: 'copy',
          child: Row(
            children: [
              Icon(
                Icons.copy_rounded,
                size: 18,
                color: colors.onSurface.withValues(alpha: 0.72),
              ),
              const SizedBox(width: 12),
              Text(
                'Copiar',
                style: TextStyle(
                  color: colors.onSurface.withValues(alpha: 0.9),
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),
        // ── 2. Compartir ───────────────────────────────────────
        PopupMenuItem<String>(
          value: 'share',
          child: Row(
            children: [
              Icon(
                Icons.share_rounded,
                size: 18,
                color: colors.onSurface.withValues(alpha: 0.72),
              ),
              const SizedBox(width: 12),
              Text(
                'Compartir',
                style: TextStyle(
                  color: colors.onSurface.withValues(alpha: 0.9),
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),
        if (onDelete != null)
          PopupMenuItem<String>(
            value: 'delete',
            child: Row(
              children: [
                Icon(
                  Icons.delete_outline_rounded,
                  size: 18,
                  color: colors.danger,
                ),
                const SizedBox(width: 12),
                Text(
                  'Eliminar',
                  style: TextStyle(color: colors.danger, fontSize: 14),
                ),
              ],
            ),
          ),
        // ── Divisor ────────────────────────────────────────────
        const PopupMenuDivider(height: 1),
        // ── 3a. Exportar → PDF ─────────────────────────────────
        PopupMenuItem<String>(
          value: 'export_pdf',
          child: Row(
            children: [
              Icon(
                Icons.picture_as_pdf_rounded,
                size: 18,
                color: colors.accent,
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Exportar como PDF',
                    style: TextStyle(
                      color: colors.onSurface.withValues(alpha: 0.9),
                      fontSize: 14,
                    ),
                  ),
                  Text(
                    'Informe técnico estructurado',
                    style: TextStyle(
                      color: colors.onSurface.withValues(alpha: 0.45),
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        // ── 3b. Exportar → Markdown ────────────────────────────
        PopupMenuItem<String>(
          value: 'export_md',
          child: Row(
            children: [
              Icon(Icons.description_rounded, size: 18, color: colors.success),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Exportar como Markdown',
                    style: TextStyle(
                      color: colors.onSurface.withValues(alpha: 0.9),
                      fontSize: 14,
                    ),
                  ),
                  Text(
                    'Archivo .md para Obsidian, Notion…',
                    style: TextStyle(
                      color: colors.onSurface.withValues(alpha: 0.45),
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _StreamingBubble extends StatelessWidget {
  const _StreamingBubble({required this.text, required this.model});

  final String text;
  final String model;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<NanoThemeExtension>()!.colors;
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: colors.surface.withValues(alpha: 0.72),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: colors.onSurface.withValues(alpha: 0.12)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.25),
              blurRadius: 10,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            () {
              final parsed = parseThought(text);
              final thought = parsed.thought;
              final response = parsed.response;
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (thought != null && thought.trim().isNotEmpty)
                    ModelReasoningBlock(
                      thought: thought,
                      initiallyExpanded: true,
                    ),
                  if (response.trim().isNotEmpty)
                    MarkdownBody(
                      data: response,
                      styleSheet: _buildChatMarkdownStyleSheet(
                        context,
                        isUser: false,
                      ),
                    )
                  else if (text.isEmpty ||
                      (thought != null && response.isEmpty))
                    // Si el pensamiento está activo pero la respuesta principal está vacía, no mostrar body vacío
                    const SizedBox.shrink()
                  else
                    MarkdownBody(
                      data: text.isEmpty ? '...' : text,
                      styleSheet: _buildChatMarkdownStyleSheet(
                        context,
                        isUser: false,
                      ),
                    ),
                ],
              );
            }(),
            const SizedBox(height: 8),
            Row(
              children: [
                Container(
                  width: 6,
                  height: 6,
                  decoration: BoxDecoration(
                    color: colors.success,
                    shape: BoxShape.circle,
                  ),
                ),
                Expanded(
                  child: Text(
                    'Generando con $model...',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: colors.onSurface.withValues(alpha: 0.48),
                      fontSize: 11,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyChat extends StatelessWidget {
  const _EmptyChat({
    required this.engineOnline,
    required this.hasModel,
    required this.onSuggestion,
    required this.onRetry,
    required this.onGoModels,
  });

  final bool engineOnline;
  final bool hasModel;
  final void Function(String) onSuggestion;
  final VoidCallback onRetry;
  final VoidCallback onGoModels;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<NanoThemeExtension>()!.colors;
    return Center(
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.chat_bubble_outline_rounded,
                size: 64,
                color: colors.onSurface.withValues(alpha: 0.3),
              ),
              const SizedBox(height: 16),
              Text(
                'Chat local',
                style: TextStyle(
                  color: colors.onSurface.withValues(alpha: 0.72),
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              if (!engineOnline)
                Column(
                  children: [
                    Text(
                      'Motor local detenido',
                      style: TextStyle(
                        color: colors.onSurface.withValues(alpha: 0.48),
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 12),
                    OutlinedButton.icon(
                      key: const ValueKey('chat_retry_button'),
                      onPressed: onRetry,
                      icon: const Icon(Icons.refresh_rounded, size: 18),
                      label: const Text('Reintentar'),
                      style: OutlinedButton.styleFrom(
                        backgroundColor: Colors.transparent,
                        foregroundColor: colors.onSurface.withValues(
                          alpha: 0.88,
                        ),
                        side: BorderSide(
                          color: colors.onSurface.withValues(alpha: 0.24),
                        ),
                        elevation: 0,
                      ),
                    ),
                  ],
                )
              else if (!hasModel)
                Column(
                  children: [
                    Text(
                      'No hay modelos cargados',
                      style: TextStyle(
                        color: colors.onSurface.withValues(alpha: 0.48),
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 12),
                    ElevatedButton.icon(
                      onPressed: onGoModels,
                      icon: const Icon(Icons.extension_rounded, size: 18),
                      label: const Text('Ir a Modelos'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: colors.accent,
                        foregroundColor: colors.onSurface,
                      ),
                    ),
                  ],
                )
              else
                Column(
                  children: [
                    Text(
                      'Escribe un mensaje para comenzar',
                      style: TextStyle(
                        color: colors.onSurface.withValues(alpha: 0.48),
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      alignment: WrapAlignment.center,
                      children: [
                        _SuggestionChip(
                          label: 'Prueba de estrés y rendimiento',
                          onTap: () => onSuggestion(
                            'Realiza una prueba de estrés y análisis de rendimiento de inferencia en este dispositivo. '
                            'Mide la capacidad de respuesta y organiza los resultados en una tabla comparativa con métricas de RAM, CPU y TPS estimado.',
                          ),
                        ),
                        _SuggestionChip(
                          label: 'Informe técnico del sistema',
                          onTap: () => onSuggestion(
                            'Genera un informe técnico completo y estructurado sobre el estado actual del dispositivo, '
                            'con tablas detalladas de hardware, arquitectura y almacenamiento, listo para exportar a PDF.',
                          ),
                        ),
                        _SuggestionChip(
                          label: 'Diagrama de arquitectura',
                          onTap: () => onSuggestion(
                            'Explica la arquitectura del runtime de NanoAI (Flutter, Binder/SAF, nanortime, llama.cpp) '
                            'e incluye un diagrama en bloque de código ```mermaid.',
                          ),
                        ),
                        _SuggestionChip(
                          label: 'Resumen ejecutivo',
                          onTap: () => onSuggestion(
                            'Genera un resumen ejecutivo de tus capacidades locales, estado de soberanía de datos '
                            'y directivas de seguridad.',
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }
}

// ================================================================
// Soporte de Razonamiento (DeepSeek <thought>)
// ================================================================

class ParsedThoughtText {
  final String? thought;
  final String response;
  const ParsedThoughtText({this.thought, required this.response});
}

ParsedThoughtText parseThought(String text) {
  final thoughtStart = text.indexOf('<thought>');
  if (thoughtStart == -1) {
    return ParsedThoughtText(response: text);
  }

  final thoughtEnd = text.indexOf('</thought>', thoughtStart);
  if (thoughtEnd == -1) {
    final thought = text.substring(thoughtStart + 9);
    return ParsedThoughtText(thought: thought, response: '');
  }

  final thought = text.substring(thoughtStart + 9, thoughtEnd);
  final response = text.substring(thoughtEnd + 10).trim();
  return ParsedThoughtText(thought: thought, response: response);
}

class ModelReasoningBlock extends StatefulWidget {
  const ModelReasoningBlock({
    super.key,
    required this.thought,
    this.initiallyExpanded = false,
  });

  final String thought;
  final bool initiallyExpanded;

  @override
  State<ModelReasoningBlock> createState() => _ModelReasoningBlockState();
}

class _ModelReasoningBlockState extends State<ModelReasoningBlock> {
  late bool _expanded;

  @override
  void initState() {
    super.initState();
    _expanded = widget.initiallyExpanded;
  }

  @override
  void didUpdateWidget(covariant ModelReasoningBlock oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Si cambia el estado de inicialmente expandido (por ejemplo, en streaming)
    if (oldWidget.initiallyExpanded != widget.initiallyExpanded) {
      _expanded = widget.initiallyExpanded;
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<NanoThemeExtension>()!.colors;
    if (widget.thought.trim().isEmpty) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: colors.codeBlockBg.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colors.success.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            onTap: () => setState(() => _expanded = !_expanded),
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Row(
                children: [
                  Icon(
                    Icons.psychology_outlined,
                    size: 16,
                    color: colors.success.withValues(alpha: 0.8),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Razonamiento del modelo',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: colors.success.withValues(alpha: 0.8),
                        letterSpacing: 0.1,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Icon(
                    _expanded
                        ? Icons.keyboard_arrow_up_rounded
                        : Icons.keyboard_arrow_down_rounded,
                    size: 16,
                    color: colors.onSurface.withValues(alpha: 0.48),
                  ),
                ],
              ),
            ),
          ),
          if (_expanded)
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: colors.codeBlockBg.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  widget.thought.trim(),
                  style: TextStyle(
                    fontFamily: 'JetBrainsMono',
                    fontSize: 12,
                    height: 1.5,
                    color: colors.onSurface.withValues(alpha: 0.65),
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _SuggestionChip extends StatelessWidget {
  const _SuggestionChip({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<NanoThemeExtension>()!.colors;
    return ActionChip(
      label: Text(label),
      onPressed: onTap,
      backgroundColor: colors.onSurface.withValues(alpha: 0.08),
      labelStyle: TextStyle(
        color: colors.onSurface.withValues(alpha: 0.72),
        fontSize: 13,
      ),
      side: BorderSide(color: colors.onSurface.withValues(alpha: 0.12)),
    );
  }
}

class _Composer extends StatefulWidget {
  const _Composer({
    super.key,
    required this.controller,
    required this.enabled,
    required this.generating,
    required this.listening,
    required this.attachments,
    required this.onRemoveAttachment,
    required this.onAttach,
    required this.onMic,
    required this.onMinimize,
    required this.compact,
    required this.onSend,
    required this.onStop,
  });

  final TextEditingController controller;
  final bool enabled;
  final bool generating;
  final bool listening;
  final List<ChatAttachment> attachments;
  final void Function(String) onRemoveAttachment;
  final VoidCallback onAttach;
  final VoidCallback onMic;
  final VoidCallback onMinimize;
  final bool compact;
  final VoidCallback onSend;
  final VoidCallback onStop;

  @override
  State<_Composer> createState() => _ComposerState();
}

class _ComposerState extends State<_Composer> {
  late final FocusNode _focusNode;
  bool _isFocused = false;
  bool _hasText = false;

  @override
  void initState() {
    super.initState();
    _focusNode = FocusNode();
    _focusNode.addListener(_onFocusChange);
    _hasText = widget.controller.text.trim().isNotEmpty;
    widget.controller.addListener(_onTextChange);
  }

  void _onFocusChange() {
    if (mounted) {
      setState(() => _isFocused = _focusNode.hasFocus);
    }
  }

  void _onTextChange() {
    final has = widget.controller.text.trim().isNotEmpty;
    if (has != _hasText && mounted) {
      setState(() => _hasText = has);
    }
  }

  @override
  void dispose() {
    _focusNode.removeListener(_onFocusChange);
    _focusNode.dispose();
    widget.controller.removeListener(_onTextChange);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<NanoThemeExtension>()!.colors;
    final isDark = colors is NanoDarkColors;

    return NanoOpticalSurface(
      geometry: NanoSurfaceGeometry.roundedRectangle,
      borderRadius: 24,
      blurSigma: 24.0,
      borderStrength: _isFocused ? 1.0 : 0.80,
      reflectionStrength: _isFocused ? 0.90 : 0.65,
      depth: 1.15,
      accent: _isFocused
          ? (isDark ? colors.accent : colors.accentCyan)
          : (isDark ? colors.accent.withValues(alpha: 0.7) : colors.accentSky),
      padding: const EdgeInsets.fromLTRB(8, 6, 8, 6),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (widget.attachments.isNotEmpty) ...[
            Padding(
              padding: const EdgeInsets.only(
                left: 4,
                right: 4,
                bottom: 6,
                top: 2,
              ),
              child: SizedBox(
                height: 30,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  physics: const BouncingScrollPhysics(),
                  itemCount: widget.attachments.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 6),
                  itemBuilder: (context, index) {
                    final attachment = widget.attachments[index];
                    return Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: colors.accent.withValues(
                          alpha: isDark ? 0.18 : 0.10,
                        ),
                        borderRadius: BorderRadius.circular(99),
                        border: Border.all(
                          color: colors.accent.withValues(alpha: 0.35),
                          width: 0.8,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.insert_drive_file_rounded,
                            size: 13,
                            color: colors.accent,
                          ),
                          const SizedBox(width: 5),
                          ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 130),
                            child: Text(
                              attachment.name,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontFamily: 'Inter',
                                color: colors.onSurface.withValues(alpha: 0.90),
                                fontSize: 11.5,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          const SizedBox(width: 4),
                          GestureDetector(
                            onTap: () =>
                                widget.onRemoveAttachment(attachment.name),
                            behavior: HitTestBehavior.opaque,
                            child: Padding(
                              padding: const EdgeInsets.all(2),
                              child: Icon(
                                Icons.close_rounded,
                                size: 13,
                                color: colors.onSurface.withValues(alpha: 0.65),
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ),
          ],
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Botón Minimizar con efecto suave
              Tooltip(
                message: 'Minimizar barra',
                child: Material(
                  color: Colors.transparent,
                  borderRadius: BorderRadius.circular(99),
                  child: InkWell(
                    key: const ValueKey('chat_composer_minimize'),
                    borderRadius: BorderRadius.circular(99),
                    onTap: widget.onMinimize,
                    child: SizedBox(
                      width: 30,
                      height: 36,
                      child: Icon(
                        Icons.keyboard_arrow_down_rounded,
                        color: colors.onSurface.withValues(alpha: 0.52),
                        size: 22,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 2),

              // Botón Mic / Dictado
              Tooltip(
                message: 'Dictado por voz',
                child: Material(
                  color: Colors.transparent,
                  borderRadius: BorderRadius.circular(99),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(99),
                    onTap: widget.onMic,
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: widget.listening
                            ? colors.success.withValues(alpha: 0.22)
                            : Colors.transparent,
                        border: widget.listening
                            ? Border.all(
                                color: colors.success.withValues(alpha: 0.65),
                                width: 1.2,
                              )
                            : null,
                      ),
                      child: Icon(
                        widget.listening
                            ? Icons.mic_rounded
                            : Icons.mic_none_rounded,
                        color: widget.listening
                            ? colors.success
                            : colors.onSurface.withValues(alpha: 0.58),
                        size: 20,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 2),

              // Botón Adjuntar Archivo
              Tooltip(
                message: 'Adjuntar archivo',
                child: Material(
                  color: Colors.transparent,
                  borderRadius: BorderRadius.circular(99),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(99),
                    onTap: widget.onAttach,
                    child: SizedBox(
                      width: 36,
                      height: 36,
                      child: Icon(
                        Icons.attach_file_rounded,
                        color: colors.onSurface.withValues(alpha: 0.58),
                        size: 20,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 4),

              // Campo de texto expandible con tipografía y padding uniforme
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: TextField(
                    controller: widget.controller,
                    focusNode: _focusNode,
                    enabled: widget.enabled,
                    maxLines: widget.compact ? 3 : 5,
                    minLines: 1,
                    style: TextStyle(
                      color: colors.onSurface,
                      fontSize: 14.5,
                      fontWeight: FontWeight.w400,
                      fontFamily: 'Inter',
                      height: 1.35,
                    ),
                    decoration: InputDecoration(
                      hintText: widget.listening
                          ? 'Escuchando voz...'
                          : 'Escribe un mensaje...',
                      hintStyle: TextStyle(
                        color: colors.onSurfaceVariant.withValues(alpha: 0.52),
                        fontFamily: 'Inter',
                        fontSize: 14.0,
                        fontWeight: FontWeight.w400,
                      ),
                      border: InputBorder.none,
                      filled: false,
                      fillColor: Colors.transparent,
                      isDense: true,
                      contentPadding: EdgeInsets.symmetric(
                        vertical: widget.compact ? 5 : 8,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 6),

              // Botón Enviar / Detener con acabado de vidrio y gradiente dinámico
              Tooltip(
                message: widget.generating ? 'Detener generación' : 'Enviar',
                child: Material(
                  color: Colors.transparent,
                  borderRadius: BorderRadius.circular(99),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(99),
                    onTap: widget.generating
                        ? widget.onStop
                        : (_hasText && widget.enabled ? widget.onSend : null),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 220),
                      curve: Curves.easeOutCubic,
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: widget.generating
                            ? null
                            : (_hasText && widget.enabled
                                  ? LinearGradient(
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                      colors: isDark
                                          ? [colors.accent, colors.accentMint]
                                          : [colors.primary, colors.accentSky],
                                    )
                                  : null),
                        color: widget.generating
                            ? colors.danger.withValues(alpha: 0.18)
                            : (_hasText && widget.enabled
                                  ? null
                                  : colors.onSurface.withValues(alpha: 0.08)),
                        border: Border.all(
                          color: widget.generating
                              ? colors.danger.withValues(alpha: 0.65)
                              : (_hasText && widget.enabled
                                    ? Colors.white.withValues(alpha: 0.45)
                                    : colors.onSurface.withValues(alpha: 0.12)),
                          width: 0.9,
                        ),
                        boxShadow: _hasText && widget.enabled
                            ? [
                                BoxShadow(
                                  color:
                                      (isDark ? colors.accent : colors.primary)
                                          .withValues(
                                            alpha: isDark ? 0.35 : 0.22,
                                          ),
                                  blurRadius: 10,
                                  offset: const Offset(0, 2),
                                ),
                              ]
                            : null,
                      ),
                      child: Center(
                        child: Icon(
                          widget.generating
                              ? Icons.stop_rounded
                              : Icons.arrow_upward_rounded,
                          size: 20,
                          color: widget.generating
                              ? colors.danger
                              : (_hasText && widget.enabled
                                    ? (isDark
                                          ? const Color(0xFF000000)
                                          : Colors.white)
                                    : colors.onSurface.withValues(alpha: 0.30)),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Cápsula líquida flotante que se muestra cuando la barra de chat está encogida/minimizada.
class _MinimizedComposerBubble extends StatelessWidget {
  const _MinimizedComposerBubble({
    super.key,
    required this.onExpand,
    required this.hasAttachments,
    required this.listening,
  });

  final VoidCallback onExpand;
  final bool hasAttachments;
  final bool listening;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<NanoThemeExtension>()!.colors;
    final isDark = colors is NanoDarkColors;

    return Tooltip(
      message: 'Mostrar barra de escritura',
      child: Semantics(
        button: true,
        label: 'Mostrar barra de escritura',
        child: GestureDetector(
          onTap: onExpand,
          child: NanoOpticalSurface(
            geometry: NanoSurfaceGeometry.capsule,
            borderRadius: 999,
            blurSigma: 14,
            borderStrength: 0.70,
            reflectionStrength: 0.55,
            depth: 0.8,
            accent: isDark ? colors.accentCyan : colors.primary,
            padding: EdgeInsets.zero,
            child: SizedBox.square(
              dimension: 42,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Icon(
                    listening ? Icons.mic_rounded : Icons.edit_rounded,
                    size: 19,
                    color: isDark ? colors.accentCyan : colors.primary,
                  ),
                  if (hasAttachments)
                    Positioned(
                      top: 8,
                      right: 8,
                      child: Container(
                        width: 6,
                        height: 6,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: colors.accentLavender,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
