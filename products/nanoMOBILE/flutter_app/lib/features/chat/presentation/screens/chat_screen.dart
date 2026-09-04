import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:nanoai/core/models/chat_models.dart';
import 'package:nanoai/core/providers/chat_provider.dart';
import '../widgets/chat_composer.dart';
import '../widgets/chat_messages.dart';
import 'package:nanoai/core/theme/design_tokens.dart';
import 'package:nanoai/core/theme/nano_transitions.dart';
import 'package:nanoai/core/widgets/live_animations.dart';
import 'package:nanoai/core/widgets/nano_components.dart';
import 'package:nanoai/core/widgets/nano_screen_shell.dart';
import 'package:nanoai/core/services/nano_runtime_api.dart';

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

  // Dictado por voz real (canal `com.nanoai/speech`, SpeechChannelHandler →
  // reconocedor Google Search) y adjunto de archivos real (file_picker → SAF de
  // Android). Ambos fallan a mensaje honesto, nunca a excepción suelta.
  bool _listening = false;
  StreamSubscription<String>? _partialSub;
  bool _isComposerMinimized = false;
  bool _isReadingMode = false;
  // UI-REV-14: en horizontal la barra puede OCULTARSE del todo (queda un chip
  // flotante "Escribir" para reabrir) — no solo minimizarse. Solo landscape.
  bool _composerHidden = false;

  /// Máximo de caracteres de un archivo adjunto que se insertan en el input.
  static const _maxAttachChars = 8000;
  static const _maxAttachBytes = 64 * 1024;

  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    _partialSub?.cancel();
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

  /// Dictado por voz REAL con streaming + AUTOENVÍO del resultado final.
  /// Los parciales solo actualizan el input visualmente; el texto final se
  /// envía automáticamente (manos libres): Voz → send → Automation → Linux.
  /// Nunca se envía un partial (evita ejecutar comandos incompletos).
  Future<void> _toggleMic() async {
    if (_listening) {
      setState(() => _listening = false);
      await _partialSub?.cancel();
      _partialSub = null;
      await NanoRuntimeApi.instance.stopSpeech();
      return;
    }
    setState(() => _listening = true);
    _partialSub = NanoRuntimeApi.instance.voicePartialStream.listen((partial) {
      if (!mounted || !_listening) return;
      _inputController.text = partial;
      _inputController.selection = TextSelection.collapsed(
        offset: _inputController.text.length,
      );
    });
    final text = await NanoRuntimeApi.instance.startVoiceRecognition();
    await _partialSub?.cancel();
    _partialSub = null;
    if (!mounted) return;
    setState(() => _listening = false);
    if (text == null || text.trim().isEmpty) {
      // Sin texto final: si el dictado en vivo dejó algo se conserva; si no,
      // aviso honesto.
      if (_inputController.text.trim().isEmpty) {
        _showHonestError('No se pudo reconocer el audio. Inténtalo de nuevo.');
      }
      return;
    }
    final trimmed = text.trim();
    _inputController.text = trimmed;
    _inputController.selection = TextSelection.collapsed(
      offset: _inputController.text.length,
    );
    // T1.7 — autoenvío del resultado FINAL (nunca partial). El partial solo
    // actualiza el input; enviar aquí evita ejecutar comandos incompletos.
    await ref.read(chatProvider.notifier).send(trimmed);
    if (!mounted) return;
    _inputController.clear();
    // Responder a VOZ: hablar la respuesta generada por el MISMO send().
    await ref.read(chatProvider.notifier).speakLastResponse();
  }

  /// Abre el selector de archivos (SAF) y registra el contenido textual como
  /// adjunto real en el estado del chat (chip visible en el composer). El
  /// contenido viaja al prompt del motor SOLO al enviar. Binarios o archivos
  /// ilegibles se reportan, no se inventa texto.
  Future<void> _attachFile() async {
    try {
      final result = await FilePicker.pickFiles(
        type: FileType.any,
        // En Android, `withData:true` carga el archivo completo en RAM antes
        // de poder validarlo. Se usa la ruta cacheada del SAF y se limita antes.
        withData: false,
      );
      final file = result?.files.single;
      if (file == null || file.path == null) return;

      final selected = File(file.path!);
      final byteLength = await selected.length();
      if (byteLength > _maxAttachBytes) {
        _showHonestError(
          'El archivo supera ${_maxAttachBytes ~/ 1024} KB. '
          'Adjunta un fragmento de texto más pequeño.',
        );
        return;
      }
      final bytes = await selected.readAsBytes();
      final text = utf8.decode(bytes, allowMalformed: true);

      // Heurística honesta: si el contenido no es texto imprimible, no sirve.
      if (text.trim().isEmpty ||
          text.contains('\u0000') ||
          _looksBinary(text)) {
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
    final mediaQuery = MediaQuery.of(context);
    // UI-REV-12: con teclado el shell ya oculta el FAB y adjustResize pega
    // la card al teclado; en reposo la card sube sobre la línea del búho
    // para que nunca tape enviar/adjuntar.
    final keyboardOpen = mediaQuery.viewInsets.bottom > 0;
    final screenSize = mediaQuery.size;
    final isNarrow = screenSize.width < 600;
    final isCompactLandscape =
        screenSize.width > screenSize.height && screenSize.height < 520;
    // UI-REV-14: chat horizontal = modo escritorio — mensajes a ancho completo
    // y barra de escritura como panel lateral acotado (no estirada a 2400px).
    final isLandscape = screenSize.width > screenSize.height;
    // El teclado no debe cambiar la variante del compositor: hacerlo causaba
    // un segundo reflow (controles que aparecen/desaparecen) justo al enfocar
    // el campo. Solo el ancho/orientación definen la composición compacta.
    final compactComposer = isNarrow || isCompactLandscape;

    // Auto-scroll al fondo con cada mensaje nuevo y al arrancar generación.
    ref.listen(chatProvider.select((s) => s.messages.length), (_, __) {
      _scrollToBottom();
    });
    ref.listen(chatProvider.select((s) => s.generating), (_, __) {
      _scrollToBottom();
    });
    // Política §12: el tool-calling pidió una escritura externa — diálogo de
    // confirmación obligatorio (sin dismiss lateral: decisión del humano).
    ref.listen(chatProvider.select((s) => s.pendingTool), (prev, next) {
      if (next != null && prev != next) {
        _showToolConfirmDialog(next);
      }
    });

    return NanoScreenShell(
      title: 'Chat',
      // El shell conserva su geometría cuando aparece el teclado. El
      // compositor se mueve de manera independiente sobre el inset para no
      // desplazar lista, encabezado ni contenido ya leído.
      // UI-REV-15: en horizontal NO hay header — la franja del título se
      // regala al contenido y las acciones del chat flotan sobre los
      // mensajes (mismas acciones, otro lugar, cero espacio perdido).
      hideHeader: _isReadingMode || isLandscape,
      resizeToAvoidBottomInset: false,
      trailing: isLandscape ? null : _chatActions(state, notifier, colors),
      body: _isReadingMode
          ? _ReadingMode(
              messages: state.messages,
              model: state.activeModel,
              onExit: () => setState(() => _isReadingMode = false),
            )
          : isLandscape
          ? _buildLandscapeChat(state, notifier, mediaQuery)
          : Center(
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  // Aprovecha el ancho en desktop/ultrawide (antes 1120 dejaba
                  // márgenes muertos); se mantiene una cota por legibilidad.
                  maxWidth: isCompactLandscape ? 1440 : 1400,
                ),
                child: Stack(
                  children: [
                    Positioned.fill(
                      // UI-REV-14: lista de mensajes compartida con el modo
                      // horizontal — un solo builder, solo cambia el despeje
                      // inferior según quién ocupa la franja baja.
                      child: _messageList(
                        state,
                        notifier,
                        bottomPadding: 180 + mediaQuery.padding.bottom,
                        emptyBottomPadding: 162,
                        sidePadding: isCompactLandscape ? 10.0 : 18.0,
                      ),
                    ),

                    // Android ya redimensiona esta Activity con adjustResize.
                    // No sumar viewInsets aquí: era un segundo desplazamiento
                    // que elevaba el compositor completo al abrir el teclado.
                    // UI-REV-12: en reposo (sin teclado) la card reserva la
                    // franja del FAB flotante (56 + gap 12 + respiro 10 = 78):
                    // el búho vive en su línea y nunca tapa la barra de
                    // escritura. Con teclado el FAB está oculto y la card
                    // vuelve pegada al borde inferior visible.
                    if (!_isReadingMode)
                      Positioned(
                        left: isCompactLandscape ? 8 : 14,
                        right: isCompactLandscape ? 8 : 14,
                        bottom: keyboardOpen
                            ? (isCompactLandscape ? 5 : 10)
                            : 78,
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
                              : ChatComposer(
                                  key: const ValueKey('expanded_composer'),
                                  controller: _inputController,
                                  // El compositor no depende del GGUF:
                                  // comandos deterministas (p. ej.
                                  // notificaciones) usan Android nativo
                                  // y deben funcionar con el motor parado.
                                  // Si el texto sí necesita LLM, send()
                                  // devuelve el error de modelo honesto.
                                  enabled: !state.generating,
                                  generating: state.generating,
                                  listening: _listening,
                                  attachments: state.attachments,
                                  onRemoveAttachment: notifier.removeAttachment,
                                  onAttach: _attachFile,
                                  onMic: _toggleMic,
                                  onMinimize: () => setState(
                                    () => _isComposerMinimized = true,
                                  ),
                                  compact: compactComposer,
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
            ),
    );
  }

  /// UI-REV-15 — acciones del chat (modo lectura, limpiar, estado del motor)
  /// en un solo lugar. En vertical viven en el header del shell; en
  /// horizontal flotan sobre los mensajes — mismas acciones, sin duplicar.
  Widget _chatActions(
    ChatState state,
    ChatNotifier notifier,
    NanoColors colors,
  ) {
    return Row(
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
    );
  }

  /// UI-REV-14 — chat horizontal profesional: los mensajes dominan TODO el
  /// ancho y la escritura vive en un panel lateral acotado (400px) con
  /// cabecera propia. La barra puede minimizarse (burbuja) u ocultarse del
  /// todo (chip flotante "Escribir" para reabrir). Nada se estira a 2400px.
  /// UI-REV-15: sin header — las acciones flotan arriba a la derecha sobre
  /// los mensajes (vidrio), la franja del título es contenido.
  Widget _buildLandscapeChat(
    ChatState state,
    ChatNotifier notifier,
    MediaQueryData mediaQuery,
  ) {
    final colors = Theme.of(context).extension<NanoThemeExtension>()!.colors;
    // UI-REV-12: mismo despeje de la línea del FAB que en vertical.
    const fabClearance = 78.0;
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 8, 14, 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: Stack(
              children: [
                Positioned.fill(
                  child: _messageList(
                    state,
                    notifier,
                    bottomPadding: mediaQuery.padding.bottom + 24,
                    emptyBottomPadding: 0,
                    sidePadding: 18,
                    // UI-REV-15: despeje para la toolbar flotante.
                    topPadding: 52,
                  ),
                ),
                // UI-REV-15: toolbar flotante de acciones (lectura, limpiar,
                // estado del motor) — vidrio sobre el contenido.
                Positioned(
                  top: 4,
                  right: 4,
                  child: _FloatingChatActions(
                    child: _chatActions(state, notifier, colors),
                  ),
                ),
                if (_composerHidden)
                  Positioned(
                    right: 4,
                    bottom: fabClearance,
                    child: _WriteAgainChip(
                      onTap: () => setState(() => _composerHidden = false),
                    ),
                  )
                else if (_isComposerMinimized)
                  Positioned(
                    right: 4,
                    bottom: fabClearance,
                    child: _MinimizedComposerBubble(
                      key: const ValueKey('minimized_bubble_landscape'),
                      onExpand: () =>
                          setState(() => _isComposerMinimized = false),
                      hasAttachments: state.attachments.isNotEmpty,
                      listening: _listening,
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          // Panel de escritura acotado — jamás compite con los mensajes.
          SizedBox(
            width: 400,
            child: Padding(
              padding: const EdgeInsets.only(bottom: fabClearance),
              child: _ComposerPanel(
                composer: ChatComposer(
                  key: const ValueKey('landscape_composer'),
                  controller: _inputController,
                  // El compositor no depende del GGUF: comandos
                  // deterministas (p. ej. notificaciones) usan Android
                  // nativo y deben funcionar con el motor parado.
                  enabled: !state.generating,
                  generating: state.generating,
                  listening: _listening,
                  attachments: state.attachments,
                  onRemoveAttachment: notifier.removeAttachment,
                  onAttach: _attachFile,
                  onMic: _toggleMic,
                  onMinimize: () => setState(() => _isComposerMinimized = true),
                  compact: false,
                  onSend: () {
                    final text = _inputController.text.trim();
                    if (text.isEmpty) return;
                    notifier.send(text);
                    _inputController.clear();
                  },
                  onStop: notifier.stop,
                ),
                onMinimize: () => setState(() => _isComposerMinimized = true),
                onHide: () => setState(() => _composerHidden = true),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// UI-REV-14 — lista de mensajes compartida vertical/horizontal. Un solo
  /// builder para las dos orientaciones; solo cambian los despejes (inferior
  /// para la barra en vertical, superior para la toolbar flotante en
  /// horizontal) y el lateral.
  Widget _messageList(
    ChatState state,
    ChatNotifier notifier, {
    required double bottomPadding,
    required double emptyBottomPadding,
    required double sidePadding,
    double topPadding = 8,
  }) {
    if (state.messages.isEmpty) {
      return Padding(
        padding: EdgeInsets.only(bottom: emptyBottomPadding),
        child: EmptyChat(
          engineOnline: state.engineOnline,
          hasModel: state.activeModelPath != null,
          onSuggestion: (text) {
            notifier.send(text);
          },
          onRetry: () => notifier.refreshEngine(),
          onGoModels: () => context.go('/models'),
        ),
      );
    }
    return ListView.builder(
      controller: _scrollController,
      physics: const BouncingScrollPhysics(),
      padding: EdgeInsets.fromLTRB(
        sidePadding,
        topPadding,
        sidePadding,
        bottomPadding,
      ),
      itemCount: state.messages.length + (state.generating ? 1 : 0),
      itemBuilder: (context, index) {
        if (index == state.messages.length) {
          return StreamingBubble(
            text: state.streamingText,
            model: state.activeModel,
          );
        }

        final message = state.messages[index];
        final isUser = message.sender == MessageSender.user;
        final isError = message.status == MessageStatus.error;

        return AnimatedMessageEntry(
          key: ValueKey(message.id),
          isUser: isUser,
          child: GestureDetector(
            onLongPress: state.generating
                ? null
                : () => _showDeleteDialog(notifier, message),
            child: MessageBubble(
              text: message.text,
              isUser: isUser,
              model: state.activeModel,
              timestamp: message.timestamp,
              isError: isError,
              source: message.source,
              attachmentNames: message.attachmentNames,
              tps: message.tps,
              onRetry: isError && !state.generating
                  ? () => notifier.retry(message.id)
                  : null,
              onDelete: state.generating
                  ? null
                  : () => _showDeleteDialog(notifier, message),
            ),
          ),
        );
      },
    );
  }

  /// Diálogo de confirmación para limpiar todo el historial.
  Future<void> _showClearDialog(ChatNotifier notifier) async {
    final colors = Theme.of(context).extension<NanoThemeExtension>()!.colors;
    final confirmed = await showNanoModalDialog<bool>(
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
    final confirmed = await showNanoModalDialog<bool>(
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
    final approved = await showNanoModalDialog<bool>(
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

// ================================================================
// Modo lectura real e inmersivo
// ================================================================

/// Modo lectura REAL: superficie serena de bajo deslumbramiento, columna
/// centrada legible (720px), tipografía amplia (17px/1.75), barra de progreso
/// y salida elegante. Abandona el chrome del chat para enfocarse en el
/// contenido — no es un simple ocultar barra.
class _ReadingMode extends StatefulWidget {
  const _ReadingMode({
    required this.messages,
    required this.model,
    required this.onExit,
  });

  final List<ChatMessage> messages;
  final String model;
  final VoidCallback onExit;

  @override
  State<_ReadingMode> createState() => _ReadingModeState();
}

class _ReadingModeState extends State<_ReadingMode> {
  final ScrollController _scroll = ScrollController();

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<NanoThemeExtension>()!.colors;
    final isDark = colors is NanoDarkColors;
    final reduceMotion = MediaQuery.disableAnimationsOf(context);

    final surface = Stack(
      children: [
        // UI-REV-07: vidrio sutil de lectura — antes el gradiente claro iba
        // al 40/72% de blanco y tapaba el fondo vivo del shell. Ahora asoma
        // el ambient sin sacrificar la legibilidad del texto centrado.
        Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: isDark
                    ? [
                        colors.glass100.withValues(alpha: 0.08),
                        colors.surface.withValues(alpha: 0.72),
                        colors.glass300.withValues(alpha: 0.10),
                      ]
                    : [
                        colors.surface.withValues(alpha: 0.16),
                        Colors.white.withValues(alpha: 0.30),
                        colors.surface.withValues(alpha: 0.18),
                      ],
              ),
            ),
          ),
        ),
        // Contenido centrado legible (foco en el texto, no en las burbujas)
        Positioned.fill(
          child: Center(
            child: ConstrainedBox(
              // 680 dp mantiene 65—œ75 caracteres por línea en texto de 18dp,
              // rango editorial que reduce los saltos oculares en lectura.
              constraints: const BoxConstraints(maxWidth: 680),
              child: ListView.builder(
                controller: _scroll,
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(28, 56, 28, 88),
                itemCount: widget.messages.length,
                itemBuilder: (context, i) => _ReadingParagraph(
                  message: widget.messages[i],
                  model: widget.model,
                ),
              ),
            ),
          ),
        ),
        // Barra de progreso de lectura (delgada, superior)
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          child: _ReadingProgress(scroll: _scroll),
        ),
        // Salida elegante: píldora de vidrio fija, siempre accesible.
        Positioned(
          top: 8,
          right: 12,
          child: _ReadingExitPill(onExit: widget.onExit),
        ),
      ],
    );

    if (reduceMotion) return surface;

    // Entrada inmersiva: fundido + escala suave al abrir el modo lectura
    // (transición glass, respeta reduce-motion).
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeOutCubic,
      builder: (context, t, child) {
        return Opacity(
          opacity: t,
          child: Transform.scale(scale: 0.982 + 0.018 * t, child: child),
        );
      },
      child: surface,
    );
  }
}

/// Barra de progreso de lectura: refleja la fracción de scroll de forma sutil.
class _ReadingProgress extends StatefulWidget {
  const _ReadingProgress({required this.scroll});

  final ScrollController scroll;

  @override
  State<_ReadingProgress> createState() => _ReadingProgressState();
}

class _ReadingProgressState extends State<_ReadingProgress> {
  @override
  void initState() {
    super.initState();
    widget.scroll.addListener(_onChange);
  }

  void _onChange() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    widget.scroll.removeListener(_onChange);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<NanoThemeExtension>()!.colors;
    final pos = widget.scroll.hasClients ? widget.scroll.position : null;
    // hasViewportDimension: antes del layout el viewport no fijó su dimensión
    // y maxScrollExtent es null (acceder a él revienta con un null-check).
    if (pos == null || !pos.hasViewportDimension) {
      return const SizedBox(height: 2.5);
    }
    final max = pos.maxScrollExtent;
    final frac = max <= 0 ? 1.0 : (pos.pixels / max).clamp(0.0, 1.0);

    return Container(
      height: 2.5,
      alignment: Alignment.centerLeft,
      child: FractionallySizedBox(
        alignment: Alignment.centerLeft,
        widthFactor: frac,
        child: DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [colors.accent, colors.accentCyan],
            ),
            borderRadius: BorderRadius.circular(3),
            boxShadow: [
              BoxShadow(
                color: colors.accent.withValues(alpha: 0.45),
                blurRadius: 6,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Píldora de vidrio para salir del modo lectura (con texto, no solo icono).
class _ReadingExitPill extends StatelessWidget {
  const _ReadingExitPill({required this.onExit});

  final VoidCallback onExit;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<NanoThemeExtension>()!.colors;
    return NanoOpticalSurface(
      key: const ValueKey('chat_reading_mode_exit'),
      geometry: NanoSurfaceGeometry.capsule,
      borderRadius: 999,
      blurSigma: 14,
      borderStrength: 0.62,
      reflectionStrength: 0.50,
      accent: colors.accent,
      onTap: onExit,
      padding: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.fullscreen_exit_rounded,
              size: 15,
              color: colors.onSurface.withValues(alpha: 0.75),
            ),
            const SizedBox(width: 5),
            Text(
              'Salir de lectura',
              style: TextStyle(
                color: colors.onSurface.withValues(alpha: 0.80),
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Un párrafo de lectura: autor + hora + contenido amplio, sin burbujas pesadas.
class _ReadingParagraph extends StatelessWidget {
  const _ReadingParagraph({required this.message, required this.model});

  final ChatMessage message;
  final String model;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<NanoThemeExtension>()!.colors;
    final isUser = message.sender == MessageSender.user;
    final isError = message.status == MessageStatus.error;
    final time =
        '${message.timestamp.hour.toString().padLeft(2, '0')}:'
        '${message.timestamp.minute.toString().padLeft(2, '0')}';
    final label = isUser
        ? 'Tú'
        : (message.source == MessageSource.device
              ? 'Nano · Dispositivo'
              : (model.isEmpty ? 'NanoAI' : model));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              isUser
                  ? Icons.person_rounded
                  : (message.source == MessageSource.device
                        ? Icons.phone_android_rounded
                        : Icons.auto_awesome_rounded),
              size: 13,
              color: isUser
                  ? colors.onSurface.withValues(alpha: 0.45)
                  : colors.accent.withValues(alpha: 0.85),
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontFamily: 'Inter',
                color: isUser
                    ? colors.onSurface.withValues(alpha: 0.50)
                    : colors.accent.withValues(alpha: 0.85),
                fontSize: 12,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.3,
              ),
            ),
            const Spacer(),
            Text(
              time,
              style: TextStyle(
                color: colors.onSurface.withValues(alpha: 0.38),
                fontSize: 11,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        if (isError)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              children: [
                Icon(
                  Icons.error_outline_rounded,
                  size: 14,
                  color: colors.danger,
                ),
                const SizedBox(width: 6),
                Text(
                  'Error',
                  style: TextStyle(color: colors.danger, fontSize: 12),
                ),
              ],
            ),
          ),
        if (isUser)
          SelectableText(
            message.text,
            style: _readingBodyStyle(colors, isUser: true),
          )
        else
          _buildReadingAiBody(context, message.text),
        const SizedBox(height: 34),
      ],
    );
  }
}

/// Hoja de estilo Markdown para el modo lectura (tipografía amplia, cómoda).
MarkdownStyleSheet _buildReadingMarkdownStyleSheet(BuildContext context) {
  final colors = Theme.of(context).extension<NanoThemeExtension>()!.colors;
  return MarkdownStyleSheet(
    p: TextStyle(
      color: colors.onSurface.withValues(alpha: 0.96),
      fontFamily: 'Georgia',
      fontFamilyFallback: const ['serif'],
      fontSize: 18,
      height: 1.72,
      letterSpacing: 0.08,
    ),
    h1: TextStyle(
      color: colors.onSurface,
      fontFamily: 'Georgia',
      fontFamilyFallback: const ['serif'],
      fontSize: 29,
      fontWeight: FontWeight.w700,
      height: 1.22,
    ),
    h2: TextStyle(
      color: colors.onSurface,
      fontFamily: 'Georgia',
      fontFamilyFallback: const ['serif'],
      fontSize: 23,
      fontWeight: FontWeight.w700,
      height: 1.4,
    ),
    h3: TextStyle(
      color: colors.onSurface,
      fontFamily: 'Georgia',
      fontFamilyFallback: const ['serif'],
      fontSize: 20,
      fontWeight: FontWeight.w600,
      height: 1.35,
    ),
    strong: TextStyle(color: colors.onSurface, fontWeight: FontWeight.w700),
    em: TextStyle(
      color: colors.onSurface.withValues(alpha: 0.9),
      fontStyle: FontStyle.italic,
    ),
    listBullet: TextStyle(
      color: colors.accent,
      fontFamily: 'Georgia',
      fontFamilyFallback: const ['serif'],
      fontSize: 18,
    ),
    code: TextStyle(
      backgroundColor: colors.success.withValues(alpha: 0x20 / 0xFF),
      color: colors.success,
      fontFamily: 'monospace',
      fontSize: 15,
    ),
    codeblockPadding: const EdgeInsets.all(14),
    codeblockDecoration: BoxDecoration(
      color: colors.codeBlockBg,
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: colors.accent.withValues(alpha: 0.25)),
    ),
    blockquote: TextStyle(
      color: colors.onSurface.withValues(alpha: 0.8),
      fontFamily: 'Georgia',
      fontFamilyFallback: const ['serif'],
      fontSize: 17,
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

/// Estilo del texto plano del usuario en modo lectura.
TextStyle _readingBodyStyle(NanoColors colors, {required bool isUser}) {
  return TextStyle(
    color: isUser ? colors.onSurface : colors.onSurface.withValues(alpha: 0.96),
    fontFamily: 'Georgia',
    fontFamilyFallback: const ['serif'],
    fontSize: 18,
    height: 1.72,
    letterSpacing: 0.08,
  );
}

/// Cuerpo AI en modo lectura: parsea pensamiento + markdown amplio.
Widget _buildReadingAiBody(BuildContext context, String text) {
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
          styleSheet: _buildReadingMarkdownStyleSheet(context),
        )
      else if (thought == null || response.isEmpty)
        MarkdownBody(
          data: text.isEmpty ? '...' : text,
          selectable: true,
          styleSheet: _buildReadingMarkdownStyleSheet(context),
        ),
    ],
  );
}

/// Badge de estado del motor con pulso lento cuando está online. Detenido:
/// sin animación (estado quieto, honesto — solo lo vivo respira).
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

/// UI-REV-15 — cápsula de vidrio para las acciones del chat cuando flotan
/// sobre los mensajes en horizontal (sin header). Legibles sobre cualquier
/// contenido, sin tapar con bloques opacos.
class _FloatingChatActions extends StatelessWidget {
  const _FloatingChatActions({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<NanoThemeExtension>()!.colors;
    final isDark = colors is NanoDarkColors;
    return NanoOpticalSurface(
      geometry: NanoSurfaceGeometry.capsule,
      borderRadius: 999,
      blurSigma: 14,
      borderStrength: 0.70,
      reflectionStrength: 0.40,
      depth: 0.9,
      accent: isDark ? colors.accentCyan : colors.primary,
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      child: child,
    );
  }
}

/// UI-REV-14 — panel lateral de escritura en horizontal: cabecera compacta
/// (título + minimizar + ocultar) y el composer con scroll propio si el texto
/// crece. La barra queda acotada y jamás estira su ancho.
class _ComposerPanel extends StatelessWidget {
  const _ComposerPanel({
    required this.composer,
    required this.onMinimize,
    required this.onHide,
  });

  final Widget composer;
  final VoidCallback onMinimize;
  final VoidCallback onHide;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<NanoThemeExtension>()!.colors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Icon(
              Icons.edit_note_rounded,
              size: 18,
              color: colors.onSurface.withValues(alpha: 0.60),
            ),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                'Componer',
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                  color: colors.onSurface.withValues(alpha: 0.78),
                ),
              ),
            ),
            _PanelIconButton(
              tooltip: 'Minimizar barra',
              icon: Icons.keyboard_arrow_down_rounded,
              onTap: onMinimize,
            ),
            const SizedBox(width: 2),
            _PanelIconButton(
              tooltip: 'Ocultar barra',
              icon: Icons.close_rounded,
              onTap: onHide,
            ),
          ],
        ),
        const SizedBox(height: 8),
        Expanded(
          child: SingleChildScrollView(
            // El composer crece con el texto (hasta 8 líneas); el scroll
            // garantiza que nunca desborde la altura disponible.
            child: composer,
          ),
        ),
      ],
    );
  }
}

/// Botón compacto de la cabecera del panel de escritura.
class _PanelIconButton extends StatelessWidget {
  const _PanelIconButton({
    required this.tooltip,
    required this.icon,
    required this.onTap,
  });

  final String tooltip;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<NanoThemeExtension>()!.colors;
    return Tooltip(
      message: tooltip,
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(99),
        child: InkWell(
          borderRadius: BorderRadius.circular(99),
          onTap: onTap,
          child: SizedBox(
            width: 30,
            height: 26,
            child: Icon(
              icon,
              size: 18,
              color: colors.onSurface.withValues(alpha: 0.50),
            ),
          ),
        ),
      ),
    );
  }
}

/// UI-REV-14 — chip flotante para reabrir la barra cuando está OCULTA en
/// horizontal. Más discreto que la burbuja minimizada: la barra no existe,
/// solo queda la invitación a escribir.
class _WriteAgainChip extends StatelessWidget {
  const _WriteAgainChip({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<NanoThemeExtension>()!.colors;
    final isDark = colors is NanoDarkColors;
    final accent = isDark ? colors.accentCyan : colors.primary;
    return Tooltip(
      message: 'Mostrar barra de escritura',
      child: Semantics(
        button: true,
        label: 'Mostrar barra de escritura',
        child: GestureDetector(
          onTap: onTap,
          child: NanoOpticalSurface(
            geometry: NanoSurfaceGeometry.capsule,
            borderRadius: 999,
            blurSigma: 14,
            borderStrength: 0.70,
            reflectionStrength: 0.55,
            depth: 0.8,
            accent: accent,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.edit_rounded, size: 17, color: accent),
                const SizedBox(width: 7),
                Text(
                  'Escribir',
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: colors.onSurface,
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
