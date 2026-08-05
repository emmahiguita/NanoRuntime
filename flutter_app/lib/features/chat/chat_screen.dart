import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../core/theme/design_tokens.dart';
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
    Timer(NanoDurations.normal, () => _scrollCtrl.animateTo(_scrollCtrl.position.maxScrollExtent, duration: NanoDurations.normal, curve: Curves.easeOut));
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(chatProvider);
    final notifier = ref.read(chatProvider.notifier);
    final colors = NanoThemeExtension.of(context).colors;
    final shadow = NanoShadows.card(colors);
    final msgs = state.messages.reversed.toList();
    final suggestions = const ['¿Qué modelos tengo?', 'Explica NanoRuntime', 'Escribe función Kotlin', 'Estado del sistema'];

    return Scaffold(
      appBar: AppBar(title: const Text('Chat'), backgroundColor: colors.surface),
      body: Stack(children: [
        Column(children: [
          _ModelBar(state: state, colors: colors, onToggle: notifier.toggleSelector, onSelect: notifier.selectModel, shadow: shadow),
          const Divider(height: 1),
          if (msgs.isEmpty)
            Expanded(child: _EmptyChat(connection: state.connection, colors: colors, suggestions: suggestions, onTap: (s) { _inputCtrl.text = s; _send(notifier); }))
          else
            Expanded(child: _MessageList(scrollCtrl: _scrollCtrl, msgs: msgs, generating: state.generating, colors: colors)),
          _InputBar(ctrl: _inputCtrl, colors: colors, generating: state.generating, onSend: () => _send(notifier), onStop: notifier.stop, suggestions: suggestions, onSuggestion: (s) { _inputCtrl.text = s; _send(notifier); }, shadow: shadow),
        ]),
        if (_fabVisible) Positioned(right: 16, bottom: 130, child: FloatingActionButton.small(onPressed: () => _scrollCtrl.animateTo(0, duration: NanoDurations.fast, curve: Curves.easeOut), backgroundColor: colors.primaryContainer, elevation: 4, child: Icon(Icons.keyboard_arrow_down, color: colors.onPrimaryContainer))),
      ]),
    );
  }
}

// ── Model Bar ──
class _ModelBar extends StatelessWidget {
  final ChatState state; final NanoColors colors; final VoidCallback onToggle; final Function(String) onSelect; final List<BoxShadow> shadow;
  const _ModelBar({required this.state, required this.colors, required this.onToggle, required this.onSelect, required this.shadow});
  @override Widget build(BuildContext context) {
    final dot = {ModelConnectionState.ready: colors.success, ModelConnectionState.loadingModel: colors.secondary, ModelConnectionState.noModel: colors.onSurfaceVariant, ModelConnectionState.error: colors.error}[state.connection]!;
    final label = {ModelConnectionState.ready: 'Conectado', ModelConnectionState.loadingModel: 'Cargando modelo...', ModelConnectionState.noModel: 'Sin modelo activo', ModelConnectionState.error: 'Error de conexión'}[state.connection]!;
    return Column(children: [
      InkWell(onTap: onToggle, child: Container(padding: const EdgeInsets.symmetric(horizontal: NanoSpacing.lg, vertical: NanoSpacing.md), decoration: BoxDecoration(color: colors.surface, boxShadow: shadow), child: Row(children: [
        Container(width: 8, height: 8, decoration: BoxDecoration(color: dot, shape: BoxShape.circle, boxShadow: [BoxShadow(color: dot.withValues(alpha: 0.4), blurRadius: 4)])),
        const SizedBox(width: NanoSpacing.sm),
        Expanded(child: Text(state.activeModel, style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14, color: colors.onSurface))),
        Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3), decoration: BoxDecoration(color: colors.surfaceVariant, borderRadius: NanoShapes.small), child: Text(label, style: TextStyle(fontSize: 10, color: colors.onSurfaceVariant))),
        const SizedBox(width: NanoSpacing.sm),
        Icon(state.showModelSelector ? Icons.expand_less : Icons.expand_more, size: 18, color: colors.onSurfaceVariant),
      ]))),
      if (state.showModelSelector) ...state.availableModels.map((m) => InkWell(
        onTap: () => onSelect(m),
        child: Container(width: double.infinity, padding: const EdgeInsets.symmetric(horizontal: NanoSpacing.lg, vertical: NanoSpacing.md), color: m == state.activeModel ? colors.primaryContainer.withValues(alpha: 0.5) : colors.surface, child: Row(children: [
          Icon(Icons.psychology, size: 16, color: m == state.activeModel ? colors.primary : colors.onSurfaceVariant),
          const SizedBox(width: NanoSpacing.sm),
          Text(m, style: TextStyle(fontSize: 13, color: colors.onSurface)),
          const Spacer(),
          if (m == state.activeModel) Icon(Icons.check_circle, size: 16, color: colors.primary),
        ])))),
    ]);
  }
}

// ── Empty Chat ──
class _EmptyChat extends StatelessWidget {
  final ModelConnectionState connection; final NanoColors colors; final List<String> suggestions; final Function(String) onTap;
  const _EmptyChat({required this.connection, required this.colors, required this.suggestions, required this.onTap});
  @override Widget build(BuildContext context) {
    if (connection == ModelConnectionState.noModel) return Center(child: Column(mainAxisSize: MainAxisSize.min, children: [Icon(Icons.psychology, size: 56, color: colors.onSurfaceVariant.withValues(alpha: 0.3)), const SizedBox(height: NanoSpacing.lg), Text('Sin modelo activo', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: colors.onSurface)), const SizedBox(height: 4), Text('Selecciona uno en Modelos para chatear', style: TextStyle(fontSize: 12, color: colors.onSurfaceVariant))]));
    if (connection == ModelConnectionState.loadingModel) return const Center(child: Column(mainAxisSize: MainAxisSize.min, children: [CircularProgressIndicator(), SizedBox(height: NanoSpacing.lg), Text('Cargando modelo en memoria...', style: TextStyle(fontSize: 13))]));
    return Center(child: Padding(padding: const EdgeInsets.all(NanoSpacing.xl), child: Column(mainAxisSize: MainAxisSize.min, children: [
      const SizedBox(height: NanoSpacing.xxl),
      Container(width: 64, height: 64, decoration: BoxDecoration(color: colors.primary.withValues(alpha: 0.1), borderRadius: NanoShapes.large), child: Icon(Icons.chat, size: 32, color: colors.primary)),
      const SizedBox(height: NanoSpacing.lg),
      Text('NanoAI Chat', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w700, color: colors.onSurface, letterSpacing: -0.5)),
      const SizedBox(height: 4),
      Text('100% local · sin internet · privado', style: TextStyle(fontSize: 12, color: colors.onSurfaceVariant)),
      const SizedBox(height: NanoSpacing.xl),
      ...suggestions.map((s) => Padding(padding: const EdgeInsets.only(bottom: NanoSpacing.sm), child: SizedBox(width: double.infinity, child: OutlinedButton(onPressed: () => onTap(s), style: OutlinedButton.styleFrom(shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)), side: BorderSide(color: colors.outlineVariant), padding: const EdgeInsets.symmetric(horizontal: NanoSpacing.lg, vertical: NanoSpacing.md)), child: Align(alignment: Alignment.centerLeft, child: Text(s, style: TextStyle(fontSize: 12, color: colors.onSurface))))))),
    ])));
  }
}

// ── Input Bar ──
class _InputBar extends StatelessWidget {
  final TextEditingController ctrl; final NanoColors colors; final bool generating; final VoidCallback onSend; final VoidCallback onStop; final List<String> suggestions; final Function(String) onSuggestion; final List<BoxShadow> shadow;
  const _InputBar({required this.ctrl, required this.colors, required this.generating, required this.onSend, required this.onStop, required this.suggestions, required this.onSuggestion, required this.shadow});
  @override Widget build(BuildContext context) => Container(
    decoration: BoxDecoration(color: colors.surface, boxShadow: shadow),
    padding: const EdgeInsets.fromLTRB(NanoSpacing.sm, NanoSpacing.xs, NanoSpacing.xs, NanoSpacing.sm),
    child: Column(children: [
      if (!generating && ctrl.text.isEmpty) SingleChildScrollView(scrollDirection: Axis.horizontal, padding: const EdgeInsets.only(bottom: 4), child: Row(children: suggestions.take(3).map((s) => Padding(padding: const EdgeInsets.only(right: 6), child: ActionChip(avatar: Icon(Icons.lightbulb_outline, size: 14, color: colors.primary), label: Text(s, style: TextStyle(fontSize: 11, color: colors.onSurface)), onPressed: () => onSuggestion(s), backgroundColor: colors.surfaceVariant, side: BorderSide(color: colors.outlineVariant), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)), padding: const EdgeInsets.symmetric(horizontal: 4)))).toList())),
      Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
        Expanded(child: TextField(controller: ctrl, maxLines: 4, minLines: 1, decoration: InputDecoration(hintText: 'Escribe un mensaje...', hintStyle: TextStyle(color: colors.onSurfaceVariant.withValues(alpha: 0.4), fontSize: 13), border: InputBorder.none, contentPadding: const EdgeInsets.symmetric(horizontal: NanoSpacing.sm, vertical: NanoSpacing.sm)), style: TextStyle(color: colors.onSurface, fontSize: 14), onSubmitted: (_) { if (!generating && ctrl.text.trim().isNotEmpty) onSend(); })),
        SizedBox(width: 40, height: 40, child: IconButton(onPressed: () {}, icon: Icon(Icons.mic_outlined, size: 20, color: colors.onSurfaceVariant), padding: EdgeInsets.zero)),
        SizedBox(width: 40, height: 40, child: IconButton(onPressed: generating ? onStop : onSend, icon: Icon(generating ? Icons.stop_rounded : Icons.send_rounded, size: 20, color: generating ? colors.error : colors.primary), padding: EdgeInsets.zero)),
      ]),
    ]),
  );
}

// ── Typing ──
class _TypingBubble extends StatefulWidget { final NanoColors colors; const _TypingBubble({required this.colors}); @override State<_TypingBubble> createState() => _TypingBubbleState(); }
class _TypingBubbleState extends State<_TypingBubble> with SingleTickerProviderStateMixin {
  late final _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 1200))..repeat();
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
  @override Widget build(BuildContext context) => ListView.builder(
    controller: scrollCtrl,
    padding: const EdgeInsets.symmetric(horizontal: NanoSpacing.lg, vertical: NanoSpacing.sm),
    itemCount: msgs.length + (generating ? 1 : 0),
    itemBuilder: (_, i) {
      if (i < msgs.length) {
        final msg = msgs[i];
        final isUser = msg.sender == MessageSender.user;
        final bg = isUser ? colors.primaryContainer : colors.surfaceVariant;
        final fg = isUser ? colors.onPrimaryContainer : colors.onSurface;
        final time = '${msg.timestamp.hour.toString().padLeft(2, '0')}:${msg.timestamp.minute.toString().padLeft(2, '0')}';
        return Align(
          alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
          child: Container(
            constraints: const BoxConstraints(maxWidth: 300),
            margin: const EdgeInsets.only(bottom: NanoSpacing.sm),
            padding: const EdgeInsets.all(NanoSpacing.md),
            decoration: BoxDecoration(color: bg, borderRadius: isUser ? NanoShapes.userBubble : NanoShapes.aiBubble, boxShadow: [BoxShadow(color: colors.onSurface.withValues(alpha: 0.03), blurRadius: 3, offset: const Offset(0, 1))]),
            child: Column(crossAxisAlignment: isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start, children: [
              Text(msg.text, style: TextStyle(fontSize: 14, color: fg, height: 1.4)),
              const SizedBox(height: 6),
              Row(mainAxisSize: MainAxisSize.min, children: [
                if (msg.tps != null) Text('${msg.tps} t/s � ', style: TextStyle(fontSize: 10, color: fg.withValues(alpha: 0.4))),
                Text(time, style: TextStyle(fontSize: 10, color: fg.withValues(alpha: 0.4))),
              ]),
            ]),
          ),
        );
      }
      return Align(alignment: Alignment.centerLeft, child: _TypingBubble(colors: colors));
    },
  );
}
