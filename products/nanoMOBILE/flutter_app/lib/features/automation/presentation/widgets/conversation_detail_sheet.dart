import 'dart:ui';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../application/automation_coordinator_provider.dart';
import '../../engine/agent_dependencies.dart' show conversationMemoryStoreProvider;
import '../../engine/messaging/conversation_hub_providers.dart';
import '../../engine/messaging/conversation_memory.dart';
import '../../executors/notification_executor_provider.dart';
import '../../personal_agent/domain/conversation_owner.dart';
import '../automation_visual_theme.dart';

class ConversationDetailSheet extends ConsumerStatefulWidget {
  final ConversationSummaryItem item;

  static const List<String> _sfFallback = [
    '.SF UI Text',
    '.SF UI Display',
    'SF Pro Text',
    'SF Pro Display',
    'Inter',
    'Roboto',
  ];

  const ConversationDetailSheet({
    super.key,
    required this.item,
  });

  static Future<void> show(
    BuildContext context,
    ConversationSummaryItem item,
  ) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.38),
      builder: (ctx) => ConversationDetailSheet(item: item),
    );
  }

  @override
  ConsumerState<ConversationDetailSheet> createState() =>
      _ConversationDetailSheetState();
}

class _ConversationDetailSheetState
    extends ConsumerState<ConversationDetailSheet> {
  final _inputController = TextEditingController();
  final _scrollController = ScrollController();
  bool _isHumanOwned = false;
  bool _busy = false;
  String? _statusText;

  @override
  void initState() {
    super.initState();
    _isHumanOwned = widget.item.humanOwns;
    if (widget.item.hasPendingReply &&
        widget.item.pendingReplyText != null) {
      _inputController.text = widget.item.pendingReplyText!;
    }
  }

  @override
  void dispose() {
    _inputController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _toggleOwnership(bool human) async {
    setState(() {
      _isHumanOwned = human;
    });
    final store = ref.read(conversationOwnershipStoreProvider);
    await store.load();
    await store.setOwner(
      widget.item.conversationId,
      human ? ConversationOwner.human : ConversationOwner.bot,
    );
    ref.invalidate(conversationHubListProvider);
  }

  Future<void> _generateAiSuggestion() async {
    setState(() {
      _busy = true;
      _statusText = 'Generando respuesta con la IA local...';
    });
    try {
      final executor = ref.read(notificationExecutorProvider);
      final list = await executor.list(limit: 10);
      if (list.isEmpty) {
        setState(() {
          _statusText = 'No hay notificaciones activas para generar borrador';
        });
        return;
      }
      final targetNotif = list.firstWhere(
        (n) => n.text == widget.item.lastMessage || n.sender == widget.item.displayName,
        orElse: () => list.first,
      );
      final draft = await executor.generateLocalDraft(targetNotif);
      if (draft.isNotEmpty) {
        setState(() {
          _inputController.text = draft;
          _statusText = 'Sugerencia generada con el catálogo de datos';
        });
      }
    } catch (e) {
      setState(() {
        _statusText = 'No se pudo generar borrador: $e';
      });
    } finally {
      setState(() {
        _busy = false;
      });
    }
  }

  Future<void> _sendReply() async {
    final text = _inputController.text.trim();
    if (text.isEmpty || _busy) return;
    setState(() {
      _busy = true;
      _statusText = 'Enviando mensaje...';
    });
    try {
      if (widget.item.hasPendingReply && widget.item.pendingReplyId != null) {
        final pendingStore = ref.read(pendingReplyStoreProvider);
        await pendingStore.updateDraftText(widget.item.pendingReplyId!, text);
        await pendingStore.approve(widget.item.pendingReplyId!);
      }

      final executor = ref.read(notificationExecutorProvider);
      final list = await executor.list(limit: 10);
      if (list.isNotEmpty) {
        final targetNotif = list.firstWhere(
          (n) => n.text == widget.item.lastMessage || n.sender == widget.item.displayName,
          orElse: () => list.first,
        );
        await executor.confirmAndReply(targetNotif, text);
      }

      final memoryStore = ref.read(conversationMemoryStoreProvider);
      memoryStore.appendOutbound(
        widget.item.conversationId,
        text,
        kind: ConversationMemoryEntryKind.outboundDispatched,
        atMs: DateTime.now().millisecondsSinceEpoch,
      );

      setState(() {
        _inputController.clear();
        _statusText = 'Mensaje entregado';
      });
      ref.invalidate(conversationHubListProvider);

      await Future<void>.delayed(const Duration(milliseconds: 600));
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      setState(() {
        _statusText = 'Error enviando mensaje: $e';
      });
    } finally {
      if (mounted) {
        setState(() {
          _busy = false;
        });
      }
    }
  }

  String _cleanName(String raw) {
    if (raw.contains('|')) {
      raw = raw.split('|').last;
    }
    if (raw.contains('shortcut:') || raw.contains('@g.us') || raw.contains('@s.whatsapp.net') || raw.startsWith('whatsapp/')) {
      final digits = RegExp(r'\d{8,15}').firstMatch(raw)?.group(0);
      if (digits != null) {
        return 'Contacto WhatsApp ($digits)';
      }
      return 'Chat de WhatsApp';
    }
    return raw;
  }

  @override
  Widget build(BuildContext context) {
    final visual = AutomationVisual.of(context);
    final memoryStore = ref.watch(conversationMemoryStoreProvider);
    final memory = memoryStore.memoryFor(widget.item.conversationId);
    final entries = memory?.entries ?? const <ConversationMemoryEntry>[];

    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 35, sigmaY: 35),
        child: Container(
          height: MediaQuery.of(context).size.height * 0.86,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: visual.isDark
                  ? [
                      const Color(0x731E293B), // ~45% sapphire glass top
                      const Color(0x520F172A), // ~32% obsidian slate bottom
                    ]
                  : [
                      const Color(0xDDFFFFFF), // 86% specular white glass top
                      const Color(0xB3F1F5F9), // 70% glass slate bottom
                    ],
            ),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
            border: Border.all(
              color: visual.isDark
                  ? Colors.white.withValues(alpha: 0.22)
                  : const Color(0x88FFFFFF),
              width: 1.2,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.45),
                blurRadius: 35,
                spreadRadius: -5,
                offset: const Offset(0, -10),
              ),
              BoxShadow(
                color: visual.accent.withValues(alpha: 0.15),
                blurRadius: 25,
                spreadRadius: 0,
              ),
            ],
          ),
          child: Stack(
            children: [
              // Top specular rim highlight
              Positioned(
                top: 0,
                left: 40,
                right: 40,
                child: Container(
                  height: 1.5,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Colors.transparent,
                        Colors.white.withValues(alpha: 0.55),
                        Colors.transparent,
                      ],
                    ),
                  ),
                ),
              ),
              SafeArea(
                top: false,
                child: Column(
                  children: [
                    const SizedBox(height: 8),
                    Center(
                      child: Container(
                        width: 36,
                        height: 5,
                        decoration: BoxDecoration(
                          color: visual.textMuted.withValues(alpha: 0.4),
                          borderRadius: BorderRadius.circular(2.5),
                        ),
                      ),
                    ),
                    _buildHeader(visual),
                    _buildControlBar(visual),
                    if (_statusText != null)
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 16),
                        color: visual.accent.withValues(alpha: 0.15),
                        child: Text(
                          _statusText!,
                          style: TextStyle(
                            color: visual.accent,
                            fontFamily: 'Inter',
                            fontFamilyFallback: ConversationDetailSheet._sfFallback,
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            letterSpacing: -0.2,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    Expanded(
                      child: entries.isEmpty
                          ? _buildFallbackLastMessage(visual)
                          : ListView.builder(
                              controller: _scrollController,
                              padding: const EdgeInsets.all(16),
                              itemCount: entries.length,
                              itemBuilder: (ctx, idx) {
                                final entry = entries[idx];
                                final isInbound = entry.kind == ConversationMemoryEntryKind.inbound;
                                return _buildChatBubble(entry.text, isInbound, visual);
                              },
                            ),
                    ),
                    _buildBottomActionBar(visual),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(AutomationVisualPalette visual) {
    final title = _cleanName(widget.item.displayName);

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.04),
        border: Border(
          bottom: BorderSide(
            color: visual.isDark
                ? Colors.white.withValues(alpha: 0.12)
                : const Color(0x33CBD5E1),
          ),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  visual.accent,
                  visual.accent.withValues(alpha: 0.65),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              shape: BoxShape.circle,
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.4),
                width: 1.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: visual.accent.withValues(alpha: 0.30),
                  blurRadius: 10,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Text(
              title.isNotEmpty ? title[0].toUpperCase() : '?',
              style: const TextStyle(
                color: Colors.white,
                fontFamily: 'Inter',
                fontFamilyFallback: ConversationDetailSheet._sfFallback,
                fontWeight: FontWeight.w700,
                fontSize: 18,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: visual.text,
                    fontFamily: 'Inter',
                    fontFamilyFallback: ConversationDetailSheet._sfFallback,
                    fontSize: 17,
                    fontWeight: FontWeight.w600,
                    letterSpacing: -0.4,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    Container(
                      width: 7,
                      height: 7,
                      decoration: const BoxDecoration(
                        color: Color(0xFF34C759),
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 5),
                    Text(
                      '${widget.item.appLabel} · En línea',
                      style: TextStyle(
                        color: visual.textMuted,
                        fontFamily: 'Inter',
                        fontFamilyFallback: ConversationDetailSheet._sfFallback,
                        fontSize: 12,
                        fontWeight: FontWeight.w400,
                        letterSpacing: -0.2,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ],
            ),
          ),
          InkWell(
            onTap: () => Navigator.of(context).pop(),
            borderRadius: BorderRadius.circular(18),
            child: Container(
              padding: const EdgeInsets.all(7),
              decoration: BoxDecoration(
                color: visual.textMuted.withValues(alpha: 0.15),
                shape: BoxShape.circle,
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.15),
                  width: 0.8,
                ),
              ),
              child: Icon(
                CupertinoIcons.xmark,
                size: 16,
                color: visual.text,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildControlBar(AutomationVisualPalette visual) {
    final activeBg = visual.isDark
        ? Colors.white.withValues(alpha: 0.18)
        : Colors.white;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      padding: const EdgeInsets.all(3.5),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: visual.isDark ? 0.25 : 0.06),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.15),
          width: 0.8,
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: GestureDetector(
              onTap: () => _toggleOwnership(false),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(vertical: 8),
                decoration: BoxDecoration(
                  color: !_isHumanOwned ? activeBg : Colors.transparent,
                  borderRadius: BorderRadius.circular(13),
                  border: !_isHumanOwned
                      ? Border.all(
                          color: Colors.white.withValues(alpha: 0.35),
                          width: 0.8,
                        )
                      : null,
                  boxShadow: !_isHumanOwned
                      ? [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.15),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          )
                        ]
                      : [],
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      CupertinoIcons.sparkles,
                      size: 14,
                      color: !_isHumanOwned
                          ? const Color(0xFF34C759)
                          : visual.textMuted,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'IA Activa (Bot)',
                      style: TextStyle(
                        color: !_isHumanOwned ? visual.text : visual.textMuted,
                        fontFamily: 'Inter',
                        fontFamilyFallback: ConversationDetailSheet._sfFallback,
                        fontSize: 13,
                        fontWeight: !_isHumanOwned
                            ? FontWeight.w600
                            : FontWeight.w400,
                        letterSpacing: -0.3,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Expanded(
            child: GestureDetector(
              onTap: () => _toggleOwnership(true),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(vertical: 8),
                decoration: BoxDecoration(
                  color: _isHumanOwned ? activeBg : Colors.transparent,
                  borderRadius: BorderRadius.circular(13),
                  border: _isHumanOwned
                      ? Border.all(
                          color: Colors.white.withValues(alpha: 0.35),
                          width: 0.8,
                        )
                      : null,
                  boxShadow: _isHumanOwned
                      ? [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.15),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          )
                        ]
                      : [],
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      CupertinoIcons.person_fill,
                      size: 14,
                      color: _isHumanOwned
                          ? const Color(0xFF007AFF)
                          : visual.textMuted,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'Control Humano',
                      style: TextStyle(
                        color: _isHumanOwned ? visual.text : visual.textMuted,
                        fontFamily: 'Inter',
                        fontFamilyFallback: ConversationDetailSheet._sfFallback,
                        fontSize: 13,
                        fontWeight: _isHumanOwned
                            ? FontWeight.w600
                            : FontWeight.w400,
                        letterSpacing: -0.3,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFallbackLastMessage(AutomationVisualPalette visual) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Center(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
            ),
            child: Text(
              'Historial reciente de mensajes',
              style: TextStyle(
                color: visual.textMuted,
                fontFamily: 'Inter',
                fontFamilyFallback: ConversationDetailSheet._sfFallback,
                fontSize: 12,
                letterSpacing: -0.2,
              ),
            ),
          ),
        ),
        const SizedBox(height: 16),
        _buildChatBubble(widget.item.lastMessage, true, visual),
        if (widget.item.hasPendingReply && widget.item.pendingReplyText != null)
          _buildChatBubble(widget.item.pendingReplyText!, false, visual),
      ],
    );
  }

  Widget _buildChatBubble(String text, bool isInbound, AutomationVisualPalette visual) {
    return Align(
      alignment: isInbound ? Alignment.centerLeft : Alignment.centerRight,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.78,
        ),
        decoration: BoxDecoration(
          gradient: isInbound
              ? LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Colors.white.withValues(alpha: visual.isDark ? 0.14 : 0.90),
                    Colors.white.withValues(alpha: visual.isDark ? 0.06 : 0.75),
                  ],
                )
              : const LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Color(0xEB007AFF),
                    Color(0xDB0056C6),
                  ],
                ),
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(20),
            topRight: const Radius.circular(20),
            bottomLeft: Radius.circular(isInbound ? 4 : 20),
            bottomRight: Radius.circular(isInbound ? 20 : 4),
          ),
          border: Border.all(
            color: isInbound
                ? Colors.white.withValues(alpha: visual.isDark ? 0.18 : 0.60)
                : Colors.white.withValues(alpha: 0.35),
            width: 0.9,
          ),
          boxShadow: [
            BoxShadow(
              color: isInbound
                  ? Colors.black.withValues(alpha: 0.08)
                  : const Color(0x44007AFF),
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Text(
          text,
          style: TextStyle(
            color: isInbound ? visual.text : Colors.white,
            fontFamily: 'Inter',
            fontFamilyFallback: ConversationDetailSheet._sfFallback,
            fontSize: 14.5,
            height: 1.35,
            letterSpacing: -0.3,
          ),
        ),
      ),
    );
  }

  Widget _buildBottomActionBar(AutomationVisualPalette visual) {
    return Container(
      padding: EdgeInsets.fromLTRB(
        14,
        10,
        14,
        MediaQuery.of(context).viewInsets.bottom + 14,
      ),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: visual.isDark ? 0.06 : 0.75),
        border: Border(
          top: BorderSide(
            color: visual.isDark
                ? Colors.white.withValues(alpha: 0.12)
                : const Color(0x33CBD5E1),
          ),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              OutlinedButton.icon(
                onPressed: _busy ? null : _generateAiSuggestion,
                icon: const Icon(CupertinoIcons.sparkles, size: 14),
                label: const Text(
                  'Sugerir con IA',
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontFamilyFallback: ConversationDetailSheet._sfFallback,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    letterSpacing: -0.2,
                  ),
                ),
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFF007AFF),
                  side: BorderSide(
                    color: const Color(0xFF007AFF).withValues(alpha: 0.45),
                  ),
                  backgroundColor: const Color(0xFF007AFF).withValues(alpha: 0.10),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _inputController,
                  enabled: !_busy,
                  maxLines: 3,
                  minLines: 1,
                  style: TextStyle(
                    color: visual.text,
                    fontFamily: 'Inter',
                    fontFamilyFallback: ConversationDetailSheet._sfFallback,
                    fontSize: 14.5,
                    letterSpacing: -0.2,
                  ),
                  decoration: InputDecoration(
                    hintText: 'Escribe tu respuesta...',
                    hintStyle: TextStyle(
                      color: visual.textMuted,
                      fontFamily: 'Inter',
                      fontFamilyFallback: ConversationDetailSheet._sfFallback,
                      fontSize: 14,
                      letterSpacing: -0.2,
                    ),
                    filled: true,
                    fillColor: Colors.white.withValues(alpha: visual.isDark ? 0.08 : 0.85),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 11,
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(22),
                      borderSide: BorderSide(
                        color: Colors.white.withValues(alpha: visual.isDark ? 0.18 : 0.50),
                      ),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(22),
                      borderSide: const BorderSide(
                        color: Color(0xFF007AFF),
                        width: 1.5,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              GestureDetector(
                onTap: _busy ? null : _sendReply,
                child: Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Color(0xFF007AFF),
                        Color(0xFF0056C6),
                      ],
                    ),
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF007AFF).withValues(alpha: 0.45),
                        blurRadius: 10,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: Center(
                    child: _busy
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                            ),
                          )
                        : const Icon(
                            CupertinoIcons.arrow_up,
                            color: Colors.white,
                            size: 20,
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


