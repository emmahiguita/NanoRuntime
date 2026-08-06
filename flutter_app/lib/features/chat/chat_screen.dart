import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/design_tokens.dart';
import '../../core/theme/nano_type.dart';
import '../../core/providers/app_providers.dart';

class ChatScreen extends ConsumerStatefulWidget {
  const ChatScreen({super.key});
  @override ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen> {
  final _inputCtrl = TextEditingController();
  final _scrollCtrl = ScrollController();
  bool _fabVisible = false;

  @override
  void initState() {
    super.initState();
    _scrollCtrl.addListener(() { final v = _scrollCtrl.hasClients && _scrollCtrl.position.pixels > 300; if (v != _fabVisible) setState(() => _fabVisible = v); });
  }
  @override void dispose() { _inputCtrl.dispose(); _scrollCtrl.dispose(); super.dispose(); }

  void _send(ChatNotifier n) {
    final t = _inputCtrl.text.trim();
    if (t.isEmpty) return;
    n.setInput(t); n.send(); _inputCtrl.clear();
    Timer(NanoDurations.normal, () {
      // El chat vacío muestra _EmptyChat (sin ListView): el controller no
      // está attachado. hasClients evita el crash al animar scroll.
      if (_scrollCtrl.hasClients) _scrollCtrl.animateTo(_scrollCtrl.position.maxScrollExtent, duration: NanoDurations.normal, curve: Curves.easeOutCubic);
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(chatProvider);
    final notifier = ref.read(chatProvider.notifier);
    final colors = NanoThemeExtension.of(context).colors;
    final shadow = NanoShadows.card(colors);
    // Orden cronológico natural (más viejo arriba, más reciente abajo).
    // Está como en un chat real: al enviar, el auto-scroll a maxScrollExtent
    // (o el FAB a 0) aterriza en el extremo correcto.
    final msgs = state.messages;
    const suggestions = ['¿Qué modelos tengo?', 'Explica NanoRuntime', 'Escribe función Kotlin', 'Estado del sistema'];
    // Inset inferior real de la barra de navegación del sistema
    final bottomInset = MediaQuery.paddingOf(context).bottom;

    return Stack(children: [
      Column(children: [
        _ModelBar(state: state, colors: colors, onToggle: notifier.toggleSelector, onSelect: notifier.selectModel, shadow: shadow),
        const Divider(height: 1),
        if (msgs.isEmpty)
          Expanded(child: _EmptyChat(connection: state.connection, colors: colors, suggestions: suggestions, onTap: (s) { _inputCtrl.text = s; _send(notifier); }))
        else
          Expanded(child: _MessageList(scrollCtrl: _scrollCtrl, msgs: msgs, generating: state.generating, colors: colors)),
        _InputBar(ctrl: _inputCtrl, colors: colors, generating: state.generating, onSend: () => _send(notifier), onStop: notifier.stop, suggestions: suggestions, onSuggestion: (s) { _inputCtrl.text = s; _send(notifier); }, shadow: shadow, bottomInset: bottomInset),
      ]),
      if (_fabVisible) Positioned(right: 16, bottom: bottomInset + 16, child: FloatingActionButton.small(onPressed: () { if (_scrollCtrl.hasClients) _scrollCtrl.animateTo(0, duration: NanoDurations.fast, curve: Curves.easeOutCubic); }, backgroundColor: colors.primaryContainer, elevation: 4, child: Icon(Icons.keyboard_arrow_down, size: NanoIcons.medium, color: colors.onPrimaryContainer))),
    ]);
  }
}

// ── Model Bar ──
class _ModelBar extends StatelessWidget {
  final ChatState state; final NanoColors colors; final VoidCallback onToggle; final Function(String) onSelect; final List<BoxShadow> shadow;
  const _ModelBar({required this.state, required this.colors, required this.onToggle, required this.onSelect, required this.shadow});
  @override Widget build(BuildContext context) {
    final c = colors;
    final dot = {ModelConnectionState.ready: c.success, ModelConnectionState.loadingModel: c.secondary, ModelConnectionState.noModel: c.onSurfaceVariant, ModelConnectionState.error: c.error}[state.connection]!;
    final label = {ModelConnectionState.ready: 'Conectado', ModelConnectionState.loadingModel: 'Cargando modelo...', ModelConnectionState.noModel: 'Sin modelo activo', ModelConnectionState.error: 'Error de conexión'}[state.connection]!;
    return Column(children: [
      InkWell(onTap: onToggle, child: Container(padding: const EdgeInsets.symmetric(horizontal: NanoSpacing.lg, vertical: NanoSpacing.md), decoration: BoxDecoration(color: c.surface, boxShadow: shadow), child: Row(children: [
        Container(width: 8, height: 8, decoration: BoxDecoration(color: dot, shape: BoxShape.circle, boxShadow: [BoxShadow(color: dot.withValues(alpha: 0.4), blurRadius: 4)])),
        const SizedBox(width: NanoSpacing.sm),
        Expanded(child: Text(state.activeModel, style: NanoType.subtitle(c.onSurface), overflow: TextOverflow.ellipsis)),
        Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3), decoration: BoxDecoration(color: c.surfaceVariant, borderRadius: NanoShapes.small), child: Text(label, style: NanoType.overline(c.onSurfaceVariant))),
        const SizedBox(width: NanoSpacing.sm),
        Icon(state.showModelSelector ? Icons.expand_less : Icons.expand_more, size: NanoIcons.small, color: c.onSurfaceVariant),
      ]))),
      if (state.showModelSelector) ...state.availableModels.map((m) => InkWell(
        onTap: () => onSelect(m),
        child: Container(width: double.infinity, padding: const EdgeInsets.symmetric(horizontal: NanoSpacing.lg, vertical: NanoSpacing.md), color: m == state.activeModel ? c.primaryContainer.withValues(alpha: 0.5) : c.surface, child: Row(children: [
          Icon(Icons.psychology, size: NanoIcons.small, color: m == state.activeModel ? c.primary : c.onSurfaceVariant),
          const SizedBox(width: NanoSpacing.sm),
          Expanded(child: Text(m, style: NanoType.body(c.onSurface), overflow: TextOverflow.ellipsis)),
          if (m == state.activeModel) Icon(Icons.check_circle, size: NanoIcons.small, color: c.primary),
        ])))),
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
class _InputBar extends StatelessWidget {
  final TextEditingController ctrl; final NanoColors colors; final bool generating; final VoidCallback onSend; final VoidCallback onStop; final List<String> suggestions; final Function(String) onSuggestion; final List<BoxShadow> shadow; final double bottomInset;
  const _InputBar({required this.ctrl, required this.colors, required this.generating, required this.onSend, required this.onStop, required this.suggestions, required this.onSuggestion, required this.shadow, required this.bottomInset});
  @override Widget build(BuildContext context) {
    final c = colors;
    return Container(
    decoration: BoxDecoration(color: c.surface, boxShadow: shadow),
    // bottomInset eleva el contenido sobre la barra de navegación del sistema
    padding: EdgeInsets.fromLTRB(NanoSpacing.sm, NanoSpacing.xs, NanoSpacing.xs, NanoSpacing.sm + bottomInset),
    child: Column(children: [
      if (!generating && ctrl.text.isEmpty) SingleChildScrollView(scrollDirection: Axis.horizontal, padding: const EdgeInsets.only(bottom: 4), child: Row(children: suggestions.take(3).map((s) => Padding(padding: const EdgeInsets.only(right: 6), child: ActionChip(avatar: Icon(Icons.lightbulb_outline, size: NanoIcons.tiny, color: c.primary), label: Text(s, style: NanoType.caption(c.onSurface)), onPressed: () => onSuggestion(s), backgroundColor: c.surfaceVariant, side: BorderSide(color: c.outlineVariant), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)), padding: const EdgeInsets.symmetric(horizontal: 4)))).toList())),
      Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
        Expanded(child: TextField(controller: ctrl, maxLines: 4, minLines: 1, decoration: InputDecoration(hintText: 'Escribe un mensaje...', hintStyle: NanoType.caption(c.onSurfaceVariant.withValues(alpha: 0.4)), border: InputBorder.none, contentPadding: const EdgeInsets.symmetric(horizontal: NanoSpacing.sm, vertical: NanoSpacing.sm)), style: NanoType.body(c.onSurface), onSubmitted: (_) { if (!generating && ctrl.text.trim().isNotEmpty) onSend(); })),
        SizedBox(width: 40, height: 40, child: IconButton(onPressed: generating ? onStop : onSend, icon: Icon(generating ? Icons.stop_rounded : Icons.send_rounded, size: NanoIcons.medium, color: generating ? c.error : c.primary), padding: EdgeInsets.zero)),
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
  final ScrollController scrollCtrl; final List<ChatMessage> msgs; final bool generating; final NanoColors colors;
  const _MessageList({required this.scrollCtrl, required this.msgs, required this.generating, required this.colors});
  @override Widget build(BuildContext context) {
    final c = colors;
    return ListView.builder(
    controller: scrollCtrl,
    padding: const EdgeInsets.symmetric(horizontal: NanoSpacing.lg, vertical: NanoSpacing.sm),
    itemCount: msgs.length + (generating ? 1 : 0),
    itemBuilder: (_, i) {
      if (i < msgs.length) {
        final msg = msgs[i];
        final isUser = msg.sender == MessageSender.user;
        final bg = isUser ? c.primaryContainer : c.surfaceVariant;
        final fg = isUser ? c.onPrimaryContainer : c.onSurface;
        final time = '${msg.timestamp.hour.toString().padLeft(2, '0')}:${msg.timestamp.minute.toString().padLeft(2, '0')}';
        return Align(
          alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
          child: Container(
            constraints: const BoxConstraints(maxWidth: 300),
            margin: const EdgeInsets.only(bottom: NanoSpacing.sm),
            padding: const EdgeInsets.all(NanoSpacing.md),
            decoration: BoxDecoration(color: bg, borderRadius: isUser ? NanoShapes.userBubble : NanoShapes.aiBubble, boxShadow: [BoxShadow(color: c.onSurface.withValues(alpha: 0.03), blurRadius: 3, offset: const Offset(0, 1))]),
            child: Column(crossAxisAlignment: isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start, children: [
              Text(msg.text, style: NanoType.body(fg)),
              const SizedBox(height: 6),
              Row(mainAxisSize: MainAxisSize.min, children: [
                if (msg.tps != null) Text('${msg.tps} t/s ·', style: NanoType.caption(fg.withValues(alpha: 0.4))),
                Text(time, style: NanoType.caption(fg.withValues(alpha: 0.4))),
              ]),
            ]),
          ),
        );
      }
      return Align(alignment: Alignment.centerLeft, child: _TypingBubble(colors: colors));
    },
  );
  }
}