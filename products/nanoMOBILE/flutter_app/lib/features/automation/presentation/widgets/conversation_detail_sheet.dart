import 'dart:ui';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../application/automation_coordinator_provider.dart';
import '../../engine/agent_dependencies.dart' show conversationAssignmentStoreProvider, conversationMemoryStoreProvider;
import '../../engine/messaging/conversation_hub_providers.dart';
import '../../engine/messaging/conversation_memory.dart';
import '../../engine/messaging/conversation_agent.dart';
import '../../engine/messaging/conversation_key.dart' show canonicalConversationId, resolveConversationIdentity;
import '../../personal_agent/application/persona_context.dart' show personaContextProvider;
import '../../engine/notifications/notification_object.dart';
import '../../engine/platform/whatsapp_media_share.dart';
import '../../executors/notification_executor.dart' show DeviceNotification;
import '../../executors/notification_executor_provider.dart';
import '../../personal_agent/domain/conversation_owner.dart';
import '../../personal_agent/application/personal_reply_learning_service.dart';
import '../../engine/business/business_facts_providers.dart';
import '../../engine/language/dynamic_reply_generator.dart';
import '../../engine/messaging/whatsapp_capability_resolver.dart';
import '../../application/whatsapp_contacts_provider.dart' show allWhatsAppContactsProvider;
import '../messaging_center/messaging_center_providers.dart'
    show allHubConversationsProvider, liveNotificationStreamProvider;
import '../automation_visual_theme.dart';
import 'conversation_history_resolver.dart';
import 'conversation_media_bubble.dart';
import 'conversation_phone_resolver.dart';

part 'conversation_detail_header_view.dart';
part 'conversation_detail_empty_view.dart';
part 'conversation_detail_chat_view.dart';
part 'conversation_detail_input_view.dart';
part 'conversation_detail_suggestions_view.dart';
part 'conversation_detail_composer_view.dart';
part 'conversation_detail_agent_picker.dart';
part 'conversation_detail_dialogs.dart';
part 'conversation_detail_attachments.dart';
part 'conversation_detail_notifications.dart';
part 'conversation_detail_live_history.dart';
part 'conversation_detail_notification_factory.dart';
part 'conversation_detail_controller.dart';
part 'conversation_detail_sender.dart';
part 'conversation_detail_style_learning.dart';
part 'conversation_detail_responsive_body.dart';

class ConversationDetailSheet extends ConsumerStatefulWidget {
  final ConversationSummaryItem item;
  static const List<String> _sfFallback = ['.SF UI Text', 'Inter', 'Roboto'];

  const ConversationDetailSheet({super.key, required this.item});

  static Future<void> show(BuildContext context, ConversationSummaryItem item) => showModalBottomSheet(
    context: context,
    useRootNavigator: true,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    barrierColor: Colors.black.withValues(alpha: 0.38),
    builder: (sheetContext) => AnimatedPadding(
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOutCubic,
      // La hoja completa sube con el teclado; el compositor no infla su
      // altura interna y por eso no aparece el RenderFlex rojo/amarillo.
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(sheetContext).bottom),
      child: ConversationDetailSheet(item: item),
    ),
  );

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
  bool _historyLoadInProgress = false;
  bool _historyReloadRequested = false;

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
    final media = MediaQuery.of(context);
    final isLandscape = media.orientation == Orientation.landscape;

    final entries = ConversationHistoryResolver.resolve(
      item: widget.item,
      store: memoryStore,
      liveEntries: _liveEntries,
    );

    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
      child: Container(
        height: (media.size.height - media.viewInsets.bottom) * (isLandscape ? 0.98 : 0.90),
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
            SafeArea(top: false, child: _buildResponsiveBody(visual, entries)),
          ],
        ),
      ),
    );
  }
}
