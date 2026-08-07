import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/design_tokens.dart';
import '../../core/theme/nano_type.dart';
import '../../core/providers/app_providers.dart';

/// Ancho mínimo en dp para layout ancho (tablets / landscape).
const _kWideBreakpoint = 600.0;
/// Ancho máximo de burbuja en modo compacto.
const _kMaxBubbleCompact = 300.0;
/// Ancho máximo de burbuja en modo ancho (tablet / landscape).
const _kMaxBubbleWide = 480.0;

class ChatScreen extends ConsumerStatefulWidget {
  const ChatScreen({super.key});
  @override ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen> {
  final _inputCtrl = TextEditingController();
  final _scrollCtrl = ScrollController();
  final _focusNode = FocusNode();
  bool _fabVisible = false;
  bool _autoScroll = true;
  Timer? _scrollTimer;

  @override
  void initState() {
    super.initState();
    _scrollCtrl.addListener(() {
      final v = _scrollCtrl.hasClients && _scrollCtrl.position.pixels > 300;
      if (v != _fabVisible) setState(() => _fabVisible = v);
      // Desactivar auto-scroll si el usuario scrollea hacia arriba.
      if (_scrollCtrl.hasClients && _scrollCtrl.position.pixels < _scrollCtrl.position.maxScrollExtent - 60) {
        _autoScroll = false;
      }
      // Re-enganchar auto-scroll si vuelve al fondo manualmente.
      if (_scrollCtrl.hasClients && _scrollCtrl.position.pixels >= _scrollCtrl.position.maxScrollExtent - 10) {
        _autoScroll = true;
      }
    });
  }
  @override void dispose() { _scrollTimer?.cancel(); _inputCtrl.dispose(); _scrollCtrl.dispose(); _focusNode.dispose(); super.dispose(); }

  /// Scroll al fondo: jumpTo si está cerca, animateTo si está lejos.
  void _scrollToBottom({bool force = false}) {
    if (!_scrollCtrl.hasClients) return;
    if (!_autoScroll && !force) return;
    final dist = _scrollCtrl.position.maxScrollExtent - _scrollCtrl.position.pixels;
    if (dist < 120 && dist > 0) {
      _scrollCtrl.jumpTo(_scrollCtrl.position.maxScrollExtent);
    } else if (dist >= 120) {
      _scrollCtrl.animateTo(_scrollCtrl.position.maxScrollExtent, duration: NanoDurations.fast, curve: Curves.easeOutCubic);
    }
  }

  void _send(ChatNotifier n, [String? text]) {
    final t = (text ?? _inputCtrl.text).trim();
    if (t.isEmpty) return;
    // Guard: solo permitir enviar si el motor está listo (misma condición que ChatNotifier.send).
    final conn = ref.read(chatProvider).connection;
    if (conn != ModelConnectionState.ready) {
      HapticFeedback.heavyImpact();
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(conn == ModelConnectionState.loadingModel ? 'El modelo aún está cargando...' : 'El motor no está conectado. Revisa la conexión en Modelos.', style: NanoType.caption(NanoThemeExtension.of(context).colors.onSurface)),
        duration: const Duration(seconds: 2), behavior: SnackBarBehavior.floating,
      ));
      return;
    }
    HapticFeedback.lightImpact();
    n.send(t);
    // Solo borrar el input si el mensaje fue aceptado (generating pasó a true).
    if (ref.read(chatProvider).generating) {
      _inputCtrl.clear();
      _autoScroll = true;
      _scrollTimer?.cancel();
      _scrollTimer = Timer(NanoDurations.normal, () => _scrollToBottom(force: true));
    }
  }

  void _copyMessage(String id, String text) {
    Clipboard.setData(ClipboardData(text: text));
    HapticFeedback.selectionClick();
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text('Copiado al portapapeles', style: NanoType.caption(NanoThemeExtension.of(context).colors.onSurface)),
      duration: const Duration(seconds: 1), behavior: SnackBarBehavior.floating, width: 200,
    ));
  }

  void _deleteMessage(String id) => ref.read(chatProvider.notifier).delete(id);
  void _retryMessage(String id) { ref.read(chatProvider.notifier).retry(id); _autoScroll = true; }

  Future<void> _confirmClear(ChatNotifier n) async {
    final ok = await showDialog<bool>(context: context, builder: (ctx) => AlertDialog(
      title: Text('Limpiar chat', style: NanoType.title(NanoThemeExtension.of(ctx).colors.onSurface)),
      content: Text('¿Borrar todo el historial de esta conversación?', style: NanoType.body(NanoThemeExtension.of(ctx).colors.onSurfaceVariant)),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text('Cancelar', style: NanoType.label(NanoThemeExtension.of(ctx).colors.onSurfaceVariant))),
        TextButton(onPressed: () => Navigator.pop(ctx, true), child: Text('Borrar', style: NanoType.label(NanoThemeExtension.of(ctx).colors.error))),
      ],
    ));
    if (ok == true) n.clear();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(chatProvider);
    final notifier = ref.read(chatProvider.notifier);
    final colors = NanoThemeExtension.of(context).colors;
    final shadow = NanoShadows.card(colors);

    // Auto-scroll durante streaming: cada token nuevo baja el scroll.
    ref.listen(chatProvider, (prev, next) {
      if (next.generating && next.streamingText.isNotEmpty) _scrollToBottom();
    });

    final msgs = state.messages;
    const suggestions = ['¿Qué modelos tengo?', 'Explica NanoRuntime', 'Escribe función Kotlin', 'Estado del sistema'];
    final bottomInset = MediaQuery.paddingOf(context).bottom;

    return Stack(children: [
      Column(children: [
        _ModelBar(state: state, colors: colors, onToggle: notifier.toggleSelector, onSelect: notifier.selectModel, shadow: shadow, hasMessages: msgs.isNotEmpty, onClear: () => _confirmClear(notifier)),
        const Divider(height: 1),
        if (msgs.isEmpty)
          Expanded(child: _EmptyChat(connection: state.connection, colors: colors, suggestions: suggestions, onTap: (s) => _send(notifier, s)))
        else
          Expanded(child: _MessageList(
            scrollCtrl: _scrollCtrl, msgs: msgs, generating: state.generating, streamingText: state.streamingText, colors: colors,
            onCopy: _copyMessage, onDelete: _deleteMessage, onRetry: _retryMessage,
          )),
        _InputBar(ctrl: _inputCtrl, focusNode: _focusNode, colors: colors, generating: state.generating, onSend: () => _send(notifier), onStop: () { HapticFeedback.lightImpact(); notifier.stop(); }, suggestions: suggestions, onSuggestion: (s) => _send(notifier, s), shadow: shadow, bottomInset: bottomInset),
      ]),
      Positioned(
        right: 16, bottom: bottomInset + 16,
        child: AnimatedScale(
          scale: _fabVisible ? 1.0 : 0.0, duration: NanoDurations.normal, curve: Curves.easeOutBack,
          child: AnimatedOpacity(
            opacity: _fabVisible ? 1.0 : 0.0, duration: NanoDurations.fast,
            child: FloatingActionButton.small(
              onPressed: () { _autoScroll = false; _scrollToBottom(force: true); },
              backgroundColor: colors.primaryContainer, elevation: 4,
              tooltip: 'Ir al final',
              child: Icon(Icons.keyboard_arrow_down, size: NanoIcons.medium, color: colors.onPrimaryContainer),
            ),
          ),
        ),
      ),
    ]);
  }
}

// ── Model Bar ──
class _ModelBar extends StatelessWidget {
  final ChatState state; final NanoColors colors; final VoidCallback onToggle; final Function(String) onSelect; final List<BoxShadow> shadow; final bool hasMessages; final VoidCallback onClear;
  const _ModelBar({required this.state, required this.colors, required this.onToggle, required this.onSelect, required this.shadow, required this.hasMessages, required this.onClear});
  @override Widget build(BuildContext context) {
    final c = colors;
    final dot = {ModelConnectionState.ready: c.success, ModelConnectionState.loadingModel: c.secondary, ModelConnectionState.noModel: c.onSurfaceVariant, ModelConnectionState.error: c.error}[state.connection]!;
    final label = {ModelConnectionState.ready: 'Conectado', ModelConnectionState.loadingModel: 'Cargando modelo...', ModelConnectionState.noModel: 'Sin modelo activo', ModelConnectionState.error: 'Error de conexión'}[state.connection]!;
    final matches = NeuralCatalog.models.where((m) => m.name == state.activeModel);
    final entry = matches.isNotEmpty ? matches.first : null;
    final sub = entry != null ? '${entry.params} · ${entry.quant}' : null;
    return Column(children: [
      InkWell(onTap: onToggle, child: Container(padding: const EdgeInsets.symmetric(horizontal: NanoSpacing.lg, vertical: NanoSpacing.md), decoration: BoxDecoration(color: c.surface, boxShadow: shadow), child: Row(children: [
        AnimatedContainer(duration: NanoDurations.normal, curve: Curves.easeInOutCubic, width: 8, height: 8, decoration: BoxDecoration(color: dot, shape: BoxShape.circle, boxShadow: [BoxShadow(color: dot.withValues(alpha: 0.4), blurRadius: 4)])),
        const SizedBox(width: NanoSpacing.sm),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
          Text(state.activeModel, style: NanoType.subtitle(c.onSurface), overflow: TextOverflow.ellipsis),
          if (sub != null) Text(sub, style: NanoType.caption(c.onSurfaceVariant)),
        ])),
        Flexible(child: Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3), decoration: BoxDecoration(color: c.surfaceVariant, borderRadius: NanoShapes.small), child: Text(label, style: NanoType.overline(c.onSurfaceVariant), overflow: TextOverflow.ellipsis, maxLines: 1))),
        const SizedBox(width: NanoSpacing.sm),
        if (hasMessages) ...[
          SizedBox(width: 32, height: 32, child: IconButton(onPressed: onClear, icon: Icon(Icons.delete_sweep_outlined, size: NanoIcons.small, color: c.onSurfaceVariant), padding: EdgeInsets.zero, tooltip: 'Limpiar chat')),
          const SizedBox(width: 2),
        ],
        Icon(state.showModelSelector ? Icons.expand_less : Icons.expand_more, size: NanoIcons.small, color: c.onSurfaceVariant),
      ]))),
      AnimatedSize(
        duration: NanoDurations.normal, curve: Curves.easeInOutCubic,
        alignment: Alignment.topCenter,
        child: state.showModelSelector
          ? ConstrainedBox(
              constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * 0.4),
              child: SingleChildScrollView(
                child: Column(children: state.availableModels.map((m) => InkWell(
              onTap: () => onSelect(m),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: NanoSpacing.lg, vertical: NanoSpacing.md),
                color: m == state.activeModel ? c.primaryContainer.withValues(alpha: 0.5) : c.surface,
                child: Row(children: [
                  Icon(Icons.psychology, size: NanoIcons.small, color: m == state.activeModel ? c.primary : c.onSurfaceVariant),
                  const SizedBox(width: NanoSpacing.sm),
                  Expanded(child: Text(m, style: NanoType.body(c.onSurface), overflow: TextOverflow.ellipsis)),
                  if (m == state.activeModel) Icon(Icons.check_circle, size: NanoIcons.small, color: c.primary),
                ]),
              ),
            )).toList()),
              ),
            )
          : const SizedBox.shrink(),
      ),
    ]);
  }
}

// ── Empty Chat ──
class _EmptyChat extends StatelessWidget {
  final ModelConnectionState connection; final NanoColors colors; final List<String> suggestions; final Function(String) onTap;
  const _EmptyChat({required this.connection, required this.colors, required this.suggestions, required this.onTap});
  @override Widget build(BuildContext context) {
    final c = colors;
    if (connection == ModelConnectionState.noModel) return Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
      Icon(Icons.psychology, size: NanoIcons.hero, color: c.onSurfaceVariant.withValues(alpha: 0.3)),
      const SizedBox(height: NanoSpacing.lg),
      Text('Sin modelo activo', style: NanoType.title(c.onSurface)),
      const SizedBox(height: 4),
      Text('Selecciona uno en Modelos para chatear', style: NanoType.caption(c.onSurfaceVariant))]));
    if (connection == ModelConnectionState.loadingModel) return Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
      const CircularProgressIndicator(), const SizedBox(height: NanoSpacing.lg),
      Text('Cargando modelo en memoria...', style: NanoType.body(c.onSurfaceVariant))]));
    if (connection == ModelConnectionState.error) return Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
      Icon(Icons.cloud_off, size: NanoIcons.hero, color: c.error.withValues(alpha: 0.4)),
      const SizedBox(height: NanoSpacing.lg),
      Text('Motor no disponible', style: NanoType.title(c.onSurface)),
      const SizedBox(height: 4),
      Text('El servidor llama.cpp no responde.\nRevisa que esté levantado en el dispositivo.', textAlign: TextAlign.center, style: NanoType.caption(c.onSurfaceVariant)),
    ]));
    return Center(child: Padding(padding: const EdgeInsets.all(NanoSpacing.xl), child: Column(mainAxisSize: MainAxisSize.min, children: [
      const SizedBox(height: NanoSpacing.xxl),
      Container(width: 64, height: 64, decoration: BoxDecoration(color: c.primary.withValues(alpha: 0.1), borderRadius: NanoShapes.large), child: Icon(Icons.chat, size: NanoIcons.large, color: c.primary)),
      const SizedBox(height: NanoSpacing.lg),
      Text('NanoAI Chat', style: NanoType.display(c.onSurface)),
      const SizedBox(height: 4),
      Text('100% local · sin internet · privado', style: NanoType.caption(c.onSurfaceVariant)),
      const SizedBox(height: NanoSpacing.xl),
      ...suggestions.map((s) => Padding(padding: const EdgeInsets.only(bottom: NanoSpacing.sm), child: SizedBox(width: double.infinity, child: OutlinedButton(onPressed: () => onTap(s), style: OutlinedButton.styleFrom(shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)), side: BorderSide(color: c.outlineVariant), padding: const EdgeInsets.symmetric(horizontal: NanoSpacing.lg, vertical: NanoSpacing.md)), child: Align(alignment: Alignment.centerLeft, child: Text(s, style: NanoType.body(c.onSurface))))))),
    ])));
  }
}

// ── Input Bar ──
class _InputBar extends StatefulWidget {
  final TextEditingController ctrl; final FocusNode focusNode; final NanoColors colors; final bool generating; final VoidCallback onSend; final VoidCallback onStop; final List<String> suggestions; final Function(String) onSuggestion; final List<BoxShadow> shadow; final double bottomInset;
  const _InputBar({required this.ctrl, required this.focusNode, required this.colors, required this.generating, required this.onSend, required this.onStop, required this.suggestions, required this.onSuggestion, required this.shadow, required this.bottomInset});
  @override State<_InputBar> createState() => _InputBarState();
}
class _InputBarState extends State<_InputBar> {
  bool _focused = false;
  @override void initState() { super.initState(); widget.focusNode.addListener(_onFocus); widget.ctrl.addListener(_onTextChanged); }
  @override void dispose() { widget.focusNode.removeListener(_onFocus); widget.ctrl.removeListener(_onTextChanged); super.dispose(); }
  void _onFocus() { if (mounted) setState(() => _focused = widget.focusNode.hasFocus); }
  void _onTextChanged() { if (mounted) setState(() {}); }
  @override Widget build(BuildContext context) {
    final c = widget.colors;
    return AnimatedContainer(
    duration: NanoDurations.normal, curve: Curves.easeInOutCubic,
    decoration: BoxDecoration(color: c.surface, boxShadow: _focused ? [BoxShadow(color: c.primary.withValues(alpha: 0.15), blurRadius: 8, offset: const Offset(0, -2))] : widget.shadow),
    padding: EdgeInsets.fromLTRB(NanoSpacing.sm, NanoSpacing.xs, NanoSpacing.xs, NanoSpacing.sm + widget.bottomInset),
    child: Column(children: [
      AnimatedSize(duration: NanoDurations.fast, alignment: Alignment.topCenter, child: (!widget.generating && widget.ctrl.text.isEmpty)
        ? SingleChildScrollView(scrollDirection: Axis.horizontal, padding: const EdgeInsets.only(bottom: 4), child: Row(children: widget.suggestions.take(3).map((s) => Padding(padding: const EdgeInsets.only(right: 6), child: ActionChip(avatar: Icon(Icons.lightbulb_outline, size: NanoIcons.tiny, color: c.primary), label: Text(s, style: NanoType.caption(c.onSurface)), onPressed: () => widget.onSuggestion(s), backgroundColor: c.surfaceVariant, side: BorderSide(color: c.outlineVariant), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)), padding: const EdgeInsets.symmetric(horizontal: 4)))).toList()))
        : const SizedBox.shrink()),
      Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
        Expanded(child: TextField(controller: widget.ctrl, focusNode: widget.focusNode, maxLines: 4, minLines: 1, decoration: InputDecoration(hintText: 'Escribe un mensaje...', hintStyle: NanoType.caption(c.onSurfaceVariant.withValues(alpha: 0.4)), border: InputBorder.none, contentPadding: const EdgeInsets.symmetric(horizontal: NanoSpacing.sm, vertical: NanoSpacing.sm)), style: NanoType.body(c.onSurface), onSubmitted: (_) { if (!widget.generating && widget.ctrl.text.trim().isNotEmpty) widget.onSend(); })),
        SizedBox(width: 40, height: 40, child: AnimatedSwitcher(
          duration: NanoDurations.fast, switchInCurve: Curves.easeOutBack, switchOutCurve: Curves.easeInCubic,
          transitionBuilder: (child, anim) => ScaleTransition(scale: anim, child: FadeTransition(opacity: anim, child: child)),
          child: IconButton(key: ValueKey(widget.generating), onPressed: widget.generating ? widget.onStop : widget.onSend, icon: Icon(widget.generating ? Icons.stop_rounded : Icons.send_rounded, size: NanoIcons.medium, color: widget.generating ? c.error : c.primary), padding: EdgeInsets.zero),
        )),
      ]),
    ]));
  }
}

// ── Typing ──
class _TypingBubble extends StatefulWidget { final NanoColors colors; const _TypingBubble({required this.colors}); @override State<_TypingBubble> createState() => _TypingBubbleState(); }
class _TypingBubbleState extends State<_TypingBubble> with SingleTickerProviderStateMixin {
  late final _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 900))..repeat();
  @override void dispose() { _ctrl.dispose(); super.dispose(); }
  @override Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.only(bottom: NanoSpacing.sm),
    padding: const EdgeInsets.symmetric(horizontal: NanoSpacing.lg, vertical: NanoSpacing.md),
    decoration: BoxDecoration(color: widget.colors.surfaceVariant, borderRadius: NanoShapes.aiBubble),
    child: Row(mainAxisSize: MainAxisSize.min, children: List.generate(3, (i) => AnimatedBuilder(animation: _ctrl, builder: (_, __) {
      final a = (_ctrl.value * 3 - i).clamp(0.0, 1.0);
      return Container(width: 7, height: 7, margin: const EdgeInsets.only(right: 3), decoration: BoxDecoration(color: widget.colors.onSurfaceVariant.withValues(alpha: a * 0.7), shape: BoxShape.circle));
    }))),
  );
}

// -- Message List --
class _MessageList extends StatelessWidget {
  final ScrollController scrollCtrl; final List<ChatMessage> msgs; final bool generating; final String streamingText; final NanoColors colors;
  final void Function(String id, String text) onCopy; final void Function(String id) onDelete; final void Function(String id) onRetry;
  const _MessageList({required this.scrollCtrl, required this.msgs, required this.generating, required this.streamingText, required this.colors, required this.onCopy, required this.onDelete, required this.onRetry});
  @override Widget build(BuildContext context) {
    final c = colors;
    final wide = MediaQuery.sizeOf(context).width > _kWideBreakpoint;
    final maxW = wide ? _kMaxBubbleWide : _kMaxBubbleCompact;
    return ListView.builder(
    controller: scrollCtrl,
    keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
    padding: const EdgeInsets.symmetric(horizontal: NanoSpacing.lg, vertical: NanoSpacing.sm),
    itemCount: msgs.length + (generating ? 1 : 0),
    itemBuilder: (_, i) {
      if (i < msgs.length) {
        final msg = msgs[i];
        final isUser = msg.sender == MessageSender.user;
        final isError = msg.status == MessageStatus.error;
        final isSending = msg.status == MessageStatus.sending;
        final bg = isUser ? c.primaryContainer : isError ? c.error.withValues(alpha: 0.08) : c.surfaceVariant;
        final fg = isUser ? c.onPrimaryContainer : c.onSurface;
        final time = '${msg.timestamp.hour.toString().padLeft(2, '0')}:${msg.timestamp.minute.toString().padLeft(2, '0')}';

        void _showContextMenu() => showModalBottomSheet(context: context, backgroundColor: c.surface, shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))), builder: (_) => SafeArea(child: Padding(padding: const EdgeInsets.all(NanoSpacing.sm), child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(width: 32, height: 4, margin: const EdgeInsets.only(bottom: NanoSpacing.sm), decoration: BoxDecoration(color: c.outlineVariant, borderRadius: BorderRadius.circular(2))),
          ListTile(leading: Icon(Icons.copy, color: c.primary), title: Text('Copiar texto', style: NanoType.body(c.onSurface)), onTap: () { onCopy(msg.id, msg.text); Navigator.pop(context); }),
          ListTile(leading: Icon(Icons.delete_outline, color: c.error), title: Text('Eliminar mensaje', style: NanoType.body(c.onSurface)), onTap: () { onDelete(msg.id); Navigator.pop(context); }),
          if (isError && !isUser) ListTile(leading: Icon(Icons.refresh, color: c.success), title: Text('Reintentar', style: NanoType.body(c.onSurface)), onTap: () { onRetry(msg.id); Navigator.pop(context); }),
        ]))));

        return Align(alignment: isUser ? Alignment.centerRight : Alignment.centerLeft, child: GestureDetector(
          onLongPress: _showContextMenu, onTap: () => onCopy(msg.id, msg.text),
          child: Container(
            constraints: BoxConstraints(maxWidth: maxW), margin: const EdgeInsets.only(bottom: NanoSpacing.sm), padding: const EdgeInsets.all(NanoSpacing.md),
            decoration: BoxDecoration(color: bg, borderRadius: isUser ? NanoShapes.userBubble : NanoShapes.aiBubble, border: isError ? Border.all(color: c.error.withValues(alpha: 0.3), width: 1) : null, boxShadow: [BoxShadow(color: c.onSurface.withValues(alpha: 0.03), blurRadius: 3, offset: const Offset(0, 1))]),
            child: Opacity(opacity: isSending ? 0.6 : 1.0, child: Semantics(label: '${isUser ? "Tú" : "NanoAI"}: ${msg.text.length > 50 ? "${msg.text.substring(0, 50)}..." : msg.text}', child: Column(crossAxisAlignment: isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start, children: [
              if (isError) ...[
                Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(Icons.error_outline, size: NanoIcons.small, color: c.error),
                  const SizedBox(width: 4),
                  Text('Error', style: NanoType.label(c.error)),
                  const Spacer(),
                  InkWell(onTap: () => onRetry(msg.id), borderRadius: NanoShapes.small, child: Padding(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2), child: Row(mainAxisSize: MainAxisSize.min, children: [Icon(Icons.refresh, size: NanoIcons.tiny, color: c.success), const SizedBox(width: 2), Text('Reintentar', style: NanoType.caption(c.success))]))),
                ]),
                const SizedBox(height: 4),
              ],
              Text(msg.text, style: NanoType.body(fg)),
              const SizedBox(height: 6),
              Row(mainAxisSize: MainAxisSize.min, children: [
                if (isSending) ...[Icon(Icons.schedule, size: NanoIcons.tiny, color: fg.withValues(alpha: 0.4)), const SizedBox(width: 4)],
                if (msg.tps != null) Text('${msg.tps!.toStringAsFixed(1)} t/s ·', style: NanoType.caption(fg.withValues(alpha: 0.4))),
                Text(time, style: NanoType.caption(fg.withValues(alpha: 0.4))),
              ]),
            ]))),
          ),
        ));
      }
      if (streamingText.isNotEmpty) return Align(alignment: Alignment.centerLeft, child: _StreamingBubble(text: streamingText, colors: colors));
      return Align(alignment: Alignment.centerLeft, child: _TypingBubble(colors: colors));
    });
  }
}

// ── Streaming Bubble ──
class _StreamingBubble extends StatefulWidget {
  final String text; final NanoColors colors;
  const _StreamingBubble({required this.text, required this.colors});
  @override State<_StreamingBubble> createState() => _StreamingBubbleState();
}
class _StreamingBubbleState extends State<_StreamingBubble> with SingleTickerProviderStateMixin {
  late final _cursorCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 600))..repeat(reverse: true);
  @override void dispose() { _cursorCtrl.dispose(); super.dispose(); }
  @override Widget build(BuildContext context) {
    final c = widget.colors;
    final wide = MediaQuery.sizeOf(context).width > _kWideBreakpoint;
    return Container(
      constraints: BoxConstraints(maxWidth: wide ? _kMaxBubbleWide : _kMaxBubbleCompact), margin: const EdgeInsets.only(bottom: NanoSpacing.sm), padding: const EdgeInsets.all(NanoSpacing.md),
      decoration: BoxDecoration(color: c.surfaceVariant, borderRadius: NanoShapes.aiBubble, boxShadow: [BoxShadow(color: c.onSurface.withValues(alpha: 0.03), blurRadius: 3, offset: const Offset(0, 1))]),
      child: Row(crossAxisAlignment: CrossAxisAlignment.end, mainAxisSize: MainAxisSize.min, children: [
        Flexible(child: Text(widget.text, style: NanoType.body(c.onSurface))),
        const SizedBox(width: 2),
        AnimatedBuilder(animation: _cursorCtrl, builder: (_, __) => Container(width: 2, height: NanoType.body(c.onSurface).fontSize ?? 14, decoration: BoxDecoration(color: c.primary.withValues(alpha: _cursorCtrl.value), borderRadius: BorderRadius.circular(1)))),
      ]),
    );
  }
}
