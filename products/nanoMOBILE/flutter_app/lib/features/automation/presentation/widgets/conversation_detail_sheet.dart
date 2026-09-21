import 'dart:ui';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../application/automation_coordinator_provider.dart';
import '../../engine/agent_dependencies.dart'
    show conversationAssignmentStoreProvider, conversationMemoryStoreProvider;
import '../../engine/messaging/conversation_hub_providers.dart';
import '../../engine/messaging/conversation_memory.dart';
import '../../engine/messaging/conversation_agent.dart';
import '../../engine/messaging/conversation_key.dart' show resolveConversationIdentity;
import '../../personal_agent/application/persona_context.dart' show personaContextProvider;
import '../../engine/notifications/notification_object.dart';
import '../../engine/platform/whatsapp_media_share.dart';
import '../../executors/notification_executor.dart' show DeviceNotification;
import '../../executors/notification_executor_provider.dart';
import '../../personal_agent/domain/conversation_owner.dart';
import '../../personal_agent/domain/personal_memory.dart';
import '../../personal_agent/application/persona_repository.dart';
import '../../engine/business/business_facts_providers.dart';
import '../../engine/language/dynamic_reply_generator.dart';
import '../../engine/messaging/whatsapp_capability_resolver.dart';
import '../../application/whatsapp_contacts_provider.dart'
    show allWhatsAppContactsProvider;
import '../messaging_center/messaging_center_providers.dart'
    show liveNotificationStreamProvider;
import '../automation_visual_theme.dart';
import 'conversation_history_resolver.dart';
import 'conversation_phone_resolver.dart';

part 'conversation_detail_header_view.dart';
part 'conversation_detail_empty_view.dart';
part 'conversation_detail_chat_view.dart';
part 'conversation_detail_input_view.dart';
part 'conversation_detail_agent_picker.dart';
part 'conversation_detail_dialogs.dart';
part 'conversation_detail_attachments.dart';
part 'conversation_detail_notifications.dart';
part 'conversation_detail_controller.dart';
part 'conversation_detail_sender.dart';

/// [ConversationDetailSheet]
/// QUÉ HACE: Despliega la hoja modal para visualizar el historial completo y responder a WhatsApp.
/// CÓMO FUNCIONA: Carga historial con [ConversationHistoryResolver], resuelve teléfono con
/// [ConversationPhoneResolver], gestiona bots y se adapta dinámicamente a landscape.
/// POR QUÉ: Respeta SOLID, Clean Architecture y modularidad estricta (< 200 líneas).
class ConversationDetailSheet extends ConsumerStatefulWidget {
  final ConversationSummaryItem item;
  static const List<String> _sfFallback = ['.SF UI Text', 'Inter', 'Roboto'];

  const ConversationDetailSheet({super.key, required this.item});

  static Future<void> show(BuildContext context, ConversationSummaryItem item) {
    return showModalBottomSheet(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.38),
      builder: (ctx) => ConversationDetailSheet(item: item),
    );
  }

  @override
  ConsumerState<ConversationDetailSheet> createState() => _ConversationDetailSheetState();
}

class _ConversationDetailSheetState extends ConsumerState<ConversationDetailSheet> {
  final _inputController = TextEditingController();
  final _scrollController = ScrollController();
  bool _isHumanOwned = false;
  bool _busy = false;
  String? _statusText;
  List<String> _suggestions = const [];
  late ConversationAgentId _agentId;
  DeviceNotification? _activeNotification;
  List<ConversationMemoryEntry> _liveEntries = const [];

  void _safeSetState(VoidCallback fn) {
    if (mounted) setState(fn);
  }

  @override
  void initState() {
    super.initState();
    _isHumanOwned = widget.item.humanOwns;
    _agentId = widget.item.agentId;
    if (widget.item.hasPendingReply && widget.item.pendingReplyText != null) {
      _inputController.text = widget.item.pendingReplyText!;
    }
    if (widget.item.pendingSuggestions.isNotEmpty) {
      _suggestions = widget.item.pendingSuggestions;
    }
    _loadLiveHistoryAndCapabilities();
  }

  @override
  void dispose() {
    _inputController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(conversationHubVersionProvider);
    ref.listen(liveNotificationStreamProvider, (_, __) => _loadLiveHistoryAndCapabilities());
    ref.listen(conversationHubVersionProvider, (_, __) => _loadLiveHistoryAndCapabilities());

    final visual = AutomationVisual.of(context);
    final memoryStore = ref.watch(conversationMemoryStoreProvider);
    final isLandscape = MediaQuery.of(context).orientation == Orientation.landscape;

    final entries = ConversationHistoryResolver.resolve(
      item: widget.item,
      store: memoryStore,
      liveEntries: _liveEntries,
    );

    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
      child: Container(
        height: MediaQuery.of(context).size.height * (isLandscape ? 0.95 : 0.88),
        decoration: BoxDecoration(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
          border: Border.all(
            color: visual.isDark ? Colors.white.withValues(alpha: 0.22) : Colors.white.withValues(alpha: 0.70),
            width: 1.2,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: visual.isDark ? 0.55 : 0.20),
              blurRadius: 35,
              spreadRadius: -5,
              offset: const Offset(0, -10),
            ),
          ],
        ),
        child: Stack(
          fit: StackFit.expand,
          children: [
            AutomationBackdrop(scrimOpacity: visual.isDark ? 0.20 : 0.32),
            Positioned.fill(
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: visual.isDark
                          ? [const Color(0xD90A0F1D), const Color(0xEB060A14)]
                          : [Colors.white.withValues(alpha: 0.88), Colors.white.withValues(alpha: 0.94)],
                    ),
                  ),
                ),
              ),
            ),
            SafeArea(
              top: false,
              child: Column(
                children: [
                  _buildHeader(visual),
                  _buildControlBar(visual),
                  _buildCapabilityBadge(visual),
                  if (_statusText != null)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
                      child: Text(_statusText!, style: TextStyle(color: visual.accent, fontSize: 11)),
                    ),
                  Expanded(
                    child: entries.isEmpty
                        ? _buildFallbackLastMessage(visual)
                        : ListView.builder(
                            controller: _scrollController,
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            itemCount: entries.length,
                            itemBuilder: (context, index) {
                              final e = entries[index];
                              final isSelf = e.kind == ConversationMemoryEntryKind.outboundDispatched ||
                                  e.kind == ConversationMemoryEntryKind.outboundObservedManual;
                              return _buildChatBubble(e.text, !isSelf, visual);
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
    );
  }
}
