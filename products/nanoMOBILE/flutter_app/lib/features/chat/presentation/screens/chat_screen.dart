import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:nanoai/core/models/chat_models.dart';
import 'package:nanoai/core/providers/chat_provider.dart';
import 'package:nanoai/core/widgets/navigation/nano_attach_sheet.dart';
import 'package:nanoai/core/widgets/navigation/nano_universal_input.dart';
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
  final _scrollController = ScrollController();

  // NAV-BAR-FIX-01 — el campo de escritura del chat ES la barra universal del
  // shell (NanoInputScope). El dictado por voz escribe aquí y viaja a la
  // barra vía `initialText` del scope (antes iba a un TextEditingController
  // huérfano que ningún TextField mostraba: la voz estaba rota).
  String _dictatedText = '';

  // Dictado por voz real (canal `com.nanoai/speech`, SpeechChannelHandler →
  // reconocedor Google Search) y adjunto de archivos real (file_picker → SAF de
  // Android). Ambos fallan a mensaje honesto, nunca a excepción suelta.
  bool _listening = false;
  StreamSubscription<String>? _partialSub;
  // VOICE-NATURAL-01: conversación continua (hablar ↔ responder ↔ volver a
  // escuchar). _voiceState refleja la máquina de estados REAL del manager;
  // el loop vive en ChatNotifier (la voz es I/O del MISMO send()).
  bool _conversationActive = false;
  bool _isReadingMode = false;

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

  /// Dictado por voz REAL con streaming: los parciales llenan el campo en
  /// vivo y el resultado final queda escrito para que el usuario revise y
  /// envíe cuando quiera (patrón de teclado). Nunca se envía un partial ni
  /// el final por sí solo. El modo manos libres vive en la conversación
  /// continua (∞): ahí la voz SÍ se ejecuta directo.
  Future<void> _toggleMic() async {
    // Conversación continua en curso: detenerla antes de dictar (un solo
    // micrófono — dictado y conversación no compiten por el audio).
    if (!_listening && _conversationActive) {
      await _toggleConversation();
    }
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
      setState(() => _dictatedText = partial);
    });
    final text = await NanoRuntimeApi.instance.startVoiceRecognition();
    await _partialSub?.cancel();
    _partialSub = null;
    if (!mounted) return;
    setState(() => _listening = false);
    if (text == null || text.trim().isEmpty) {
      // Sin texto final: si el dictado en vivo dejó algo se conserva; si no,
      // aviso honesto.
      if (_dictatedText.trim().isEmpty) {
        _showHonestError('No se pudo reconocer el audio. Inténtalo de nuevo.');
      }
      return;
    }
    setState(() => _dictatedText = text.trim());
    // VOICE-PRO-04: el dictado LLENA el campo y el usuario decide cuándo
    // enviar. El autoenvío sorprendía: no daba tiempo a revisar lo que el
    // reconocedor había entendido (y un error de transcripción se ejecutaba
    // igual). El envío queda en el botón; el modo manos libres es la
    // conversación continua (∞), que sí ejecuta directo.
  }

  /// VOICE-NATURAL-01 — activa/detiene el modo conversación continua. Tap en ∞
  /// inicia el ciclo (hablar ↔ responder ↔ volver a escuchar); tap en ■ lo
  /// detiene con barge-in. El dictado del mic sigue intacto.
  Future<void> _toggleConversation() async {
    final notifier = ref.read(chatProvider.notifier);
    if (notifier.isVoiceConversationActive) {
      notifier.stopVoiceConversation();
      if (mounted) setState(() => _conversationActive = false);
      return;
    }
    if (_listening) return; // dictado en curso: no pisar el micrófono
    setState(() => _conversationActive = true);
    final completed = await notifier.startVoiceConversation();
    if (mounted) setState(() => _conversationActive = false);
    if (!completed && mounted) {
      // El ciclo terminó sin escuchar nada: fallo del reconocedor o silencio
      // instantáneo. Aviso honesto en vez de "no pasó nada".
      _showHonestError(
        'No se pudo escuchar nada. Verifica el micrófono y la conexión.',
      );
    }
  }


  /// NAV-BAR-FIX-05 — el botón adjuntar abre la hoja flotante de la barra
  /// (Foto / Video / Documento). Documento se inyecta como texto real en el
  /// prompt (igual que antes); foto y video viajan como REFERENCIA honesta:
  /// el contenido describe el archivo y aclara que el modelo local no puede
  /// ver imágenes todavía. Binarios o archivos ilegibles se reportan, no se
  /// inventa texto.
  Future<void> _attachFile() async {
    final picked = await NanoAttachSheet.show(context);
    if (picked == null || !mounted) return;
    final notifier = ref.read(chatProvider.notifier);
    switch (picked.kind) {
      case NanoAttachKind.photo:
      case NanoAttachKind.video:
        final label = picked.kind == NanoAttachKind.photo ? 'imagen' : 'video';
        notifier.addAttachment(
          ChatAttachment(
            name: picked.name,
            content:
                '[Archivo de $label adjuntado: ${picked.name} '
                '(${_formatBytes(picked.sizeBytes)})]\n'
                'El modelo local actual no puede procesar $label todavía; '
                'este adjunto se envía como referencia de que el usuario lo '
                'incluyó en el mensaje.',
            kind: picked.kind == NanoAttachKind.photo
                ? ChatAttachmentKind.photo
                : ChatAttachmentKind.video,
            sizeBytes: picked.sizeBytes,
          ),
        );
      case NanoAttachKind.document:
        await _attachTextDocument(picked, notifier);
    }
  }

  /// Documento → texto real. Ruta cacheada del SAF, límites de peso y
  /// heurística binaria: si no es texto imprimible no se inventa contenido.
  Future<void> _attachTextDocument(
    NanoAttachResult picked,
    ChatNotifier notifier,
  ) async {
    try {
      final selected = File(picked.path);
      if (picked.sizeBytes > _maxAttachBytes) {
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
      notifier.addAttachment(
        ChatAttachment(
          name: picked.name,
          content: clipped,
          kind: ChatAttachmentKind.document,
          sizeBytes: picked.sizeBytes,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      _showHonestError('No se pudo leer el archivo: $e');
    }
  }

  static String _formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
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
    final screenSize = mediaQuery.size;
    final isCompactLandscape =
        screenSize.width > screenSize.height && screenSize.height < 520;
    final isLandscape = screenSize.width > screenSize.height;

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

    return NanoInputScope(
      scopeId: 'chat',
      hint: 'Escribe un mensaje a Nano AI...',
      // NAV-BAR-FIX-01 — el texto dictado llega a la barra universal por aquí.
      initialText: _dictatedText.isEmpty ? null : _dictatedText,
      onSubmit: (text) {
        notifier.send(text);
        // El envío consumió el dictado: la barra se limpia sola (clearOnSubmit).
        setState(() => _dictatedText = '');
      },
      onVoice: _toggleMic,
      onAttach: _attachFile,
      isGenerating: state.generating,
      // NAV-BAR-FIX-05 — el orbe de la barra refleja el estado real del
      // micrófono (stop rojo pulsante mientras escucha).
      isListening: _listening,
      onStop: notifier.stop,
      keepFocusOnSubmit: true,
      child: NanoScreenShell(
        title: 'Chat',
        hideHeader: _isReadingMode || isLandscape,
        resizeToAvoidBottomInset: false,
        trailing: isLandscape
            ? null
            : _chatActions(state, notifier, colors, landscape: false),
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
                    maxWidth: isCompactLandscape ? 1440 : 1400,
                  ),
                  child: Stack(
                    children: [
                      Positioned.fill(
                        child: _messageList(
                          state,
                          notifier,
                          // NAV-BAR-FIX-06 — el frame reserva la altura de la
                          // barra; la lista solo deja su respiro normal.
                          bottomPadding: 24 + mediaQuery.padding.bottom,
                          emptyBottomPadding: 24,
                          sidePadding: isCompactLandscape ? 10.0 : 18.0,
                        ),
                      ),
                      if (state.attachments.isNotEmpty)
                        Positioned(
                          left: isCompactLandscape ? 12 : 24,
                          right: isCompactLandscape ? 12 : 24,
                          bottom: 12,
                          child: _AttachmentPillsStrip(
                            attachments: state.attachments,
                            onRemove: notifier.removeAttachment,
                          ),
                        ),
                    ],
                  ),
                ),
              ),
      ),
    );
  }

  /// UI-REV-16 — un solo botón ⋮ (patrón estándar): modo lectura y limpiar
  /// viven en el menú; el estado del motor es un item informativo (ya no un
  /// badge permanente que roba espacio). En vertical va en el header del
  /// shell; en horizontal flota en cápsula de vidrio. Cero iconos sueltos.
  Widget _chatActions(
    ChatState state,
    ChatNotifier notifier,
    NanoColors colors, {
    required bool landscape,
  }) {
    final loading = state.connection == ModelConnectionState.loadingModel;
    final engineColor = state.engineOnline && !loading
        ? colors.success
        : colors.warning;
    final engineLabel = loading
        ? 'Motor local: cargando…'
        : (state.engineOnline
              ? 'Motor local: activo'
              : 'Motor local: detenido');
    return PopupMenuButton<_ChatMenuAction>(
      key: const ValueKey('chat_overflow_menu'),
      tooltip: 'Más opciones',
      icon: Icon(
        Icons.more_vert_rounded,
        color: colors.onSurface.withValues(alpha: 0.75),
        size: 20,
      ),
      onSelected: (action) {
        switch (action) {
          case _ChatMenuAction.readingMode:
            setState(() => _isReadingMode = true);
          case _ChatMenuAction.clearConversation:
            _showClearDialog(notifier);
        }
      },
      itemBuilder: (context) => [
        if (state.messages.isNotEmpty)
          const PopupMenuItem(
            value: _ChatMenuAction.readingMode,
            child: _ChatMenuItem(
              icon: Icons.chrome_reader_mode_rounded,
              label: 'Modo lectura',
            ),
          ),
        if (state.messages.isNotEmpty)
          PopupMenuItem(
            value: _ChatMenuAction.clearConversation,
            enabled: !state.generating,
            child: const _ChatMenuItem(
              icon: Icons.delete_sweep_rounded,
              label: 'Limpiar conversación',
            ),
          ),
        // Estado del motor: honesto e informativo, dentro del menú —
        // cero espacio permanente en la toolbar.
        PopupMenuItem(
          enabled: false,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 7,
                height: 7,
                decoration: BoxDecoration(
                  color: engineColor,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 9),
              Text(
                engineLabel,
                style: TextStyle(
                  fontSize: 13,
                  color: colors.onSurface.withValues(alpha: 0.75),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// UI-REV-16 — chat horizontal: la lista de mensajes domina TODO el ancho
  /// (sin panel lateral de escritura; la barra universal del shell sigue
  /// siendo el punto de escritura) y las acciones del chat flotan en vidrio
  /// arriba a la derecha. Los adjuntos pendientes se muestran en una franja
  /// inferior. Nada se solapa: la lista reserva sus despejes.
  Widget _buildLandscapeChat(
    ChatState state,
    ChatNotifier notifier,
    MediaQueryData mediaQuery,
  ) {
    final colors = Theme.of(context).extension<NanoThemeExtension>()!.colors;

    return Stack(
      fit: StackFit.expand,
      children: [
        Positioned.fill(
          child: _messageList(
            state,
            notifier,
            topPadding: 52,
            bottomPadding: 24 + mediaQuery.padding.bottom,
            emptyBottomPadding: 24,
            sidePadding: 18,
          ),
        ),
        // UI-REV-15: cápsula de vidrio con el menú ⋮ del chat.
        Positioned(
          top: 4,
          right: 4,
          child: _FloatingChatActions(
            child: _chatActions(state, notifier, colors, landscape: true),
          ),
        ),
        if (state.attachments.isNotEmpty)
          Positioned(
            left: 20,
            right: 20,
            bottom: 12,
            child: _AttachmentPillsStrip(
              attachments: state.attachments,
              onRemove: notifier.removeAttachment,
            ),
          ),
      ],
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

/// UI-REV-16 — acciones del menú ⋮ del chat. Un solo enum: el menú es la
/// única puerta de modo lectura / limpiar / ocultar-mostrar barra.
enum _ChatMenuAction {
  readingMode,
  clearConversation,
}

/// Item del menú ⋮ — icono + etiqueta, presentación pura.
class _ChatMenuItem extends StatelessWidget {
  const _ChatMenuItem({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<NanoThemeExtension>()!.colors;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 18, color: colors.onSurface.withValues(alpha: 0.70)),
        const SizedBox(width: 10),
        Text(label, style: TextStyle(fontSize: 13.5, color: colors.onSurface)),
      ],
    );
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

class _AttachmentPillsStrip extends StatelessWidget {
  const _AttachmentPillsStrip({
    required this.attachments,
    required this.onRemove,
  });

  final List<ChatAttachment> attachments;
  final ValueChanged<String> onRemove;

  @override
  Widget build(BuildContext context) {
    if (attachments.isEmpty) return const SizedBox.shrink();
    final colors = Theme.of(context).extension<NanoThemeExtension>()!.colors;
    final isDark = colors is NanoDarkColors;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xDD0B162E) : const Color(0xF0FFFFFF),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDark ? const Color(0x6642B7FF) : const Color(0x333B82F6),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.35 : 0.08),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: attachments.map((att) {
            return Container(
              margin: const EdgeInsets.only(right: 8),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: isDark ? const Color(0x401D3567) : const Color(0x203B82F6),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isDark ? const Color(0x4D5CE7FF) : const Color(0x403B82F6),
                  width: 0.8,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    // NAV-BAR-FIX-05 — el chip dice el tipo real del adjunto
                    // (foto/video/documento), no un icono genérico.
                    switch (att.kind) {
                      ChatAttachmentKind.photo => Icons.image_rounded,
                      ChatAttachmentKind.video => Icons.videocam_rounded,
                      ChatAttachmentKind.document ||
                      ChatAttachmentKind.text => Icons.description_rounded,
                    },
                    size: 14,
                    color: colors.accent,
                  ),
                  const SizedBox(width: 5),
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 140),
                    child: Text(
                      att.name,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontFamily: 'Inter',
                        color: colors.onSurface,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const SizedBox(width: 5),
                  GestureDetector(
                    onTap: () => onRemove(att.name),
                    behavior: HitTestBehavior.opaque,
                    child: Padding(
                      padding: const EdgeInsets.all(2),
                      child: Icon(
                        Icons.close_rounded,
                        size: 14,
                        color: colors.onSurface.withValues(alpha: 0.7),
                      ),
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
        ),
      ),
    );
  }
}
