import 'dart:async';
import 'dart:ui';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/services/execution_budget.dart';
import '../../application/automation_coordinator_provider.dart';
import '../../application/whatsapp_contacts_provider.dart'
    show allWhatsAppContactsProvider;
import '../../engine/agent_dependencies.dart'
    show conversationAssignmentStoreProvider, conversationMemoryStoreProvider;
import '../../engine/business/business_document_library.dart';
import '../../engine/business/business_facts_providers.dart';
import '../../engine/language/conversation_semantic_tag.dart';
import '../../engine/messaging/conversation_agent.dart';
import '../../engine/messaging/conversation_group_resolver.dart';
import '../../engine/messaging/conversation_hub_providers.dart';
import '../../engine/messaging/conversation_key.dart'
    show canonicalConversationId, resolveConversationIdentity;
import '../../engine/messaging/conversation_memory.dart';
import '../../engine/messaging/whatsapp_capability_resolver.dart';
import '../../engine/notifications/notification_object.dart';
import '../../engine/platform/whatsapp_media_share.dart';
import '../../executors/notification_executor.dart' show DeviceNotification;
import '../../executors/notification_executor_provider.dart';
import '../../personal_agent/application/persona_context.dart'
    show personaContextProvider;
import '../../personal_agent/application/personal_reply_learning_service.dart';
import '../../personal_agent/domain/conversation_owner.dart';
import '../automation_visual_theme.dart';
import '../business/business_document_library_dialog.dart';
import '../messaging_center/messaging_center_providers.dart'
    show allHubConversationsProvider, liveNotificationStreamProvider;
import '../messaging_center/whatsapp_web_history_view.dart';
import '../messaging_center/conversation_hub_action_controller.dart';
import '../messaging_center/notification_history_view.dart';
import '../whatsapp_web/whatsapp_web_session_ownership.dart';
import 'conversation_history_resolver.dart';
import 'conversation_media_bubble.dart';
import 'conversation_phone_resolver.dart';
import 'conversation_semantic_badge.dart';
import 'message_event_time.dart';
import 'nano_glass_dialog.dart';
import 'nano_metallic_button.dart';
import 'package:nanoai/core/widgets/nano_glass_window.dart';
import 'package:nanoai/core/widgets/glass_surface.dart';
part 'conversation_detail_header_view.dart';
part 'conversation_detail_control_bar.part.dart';
part 'conversation_detail_state.part.dart';
part 'conversation_detail_sources.part.dart';
part 'conversation_detail_empty_view.dart';
part 'conversation_detail_chat_view.dart';
part 'conversation_detail_bubbles.part.dart';
part 'conversation_detail_input_view.dart';
part 'conversation_detail_suggestions_view.dart';
part 'conversation_detail_composer_view.dart';
part 'conversation_detail_agent_picker.dart';
part 'conversation_detail_dialogs.dart';
part 'conversation_detail_form_picker.dart';
part 'conversation_detail_attachments.dart';
part 'conversation_detail_attachments_share.part.dart';
part 'conversation_detail_library.dart';
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

  static Future<void> show(
    BuildContext context,
    ConversationSummaryItem item,
  ) async {
    final isWeb = {
      item.conversationId,
      ...item.conversationAliases,
    }.any((id) => id.startsWith('waweb:'));
    if (isWeb) WhatsAppWebSessionOwnership.foreground.value = true;
    try {
      await showNanoGlassWindow(
        context: context,
        useRootNavigator: true,
        // La cabecera del chat ya tiene cierre; evita otra X y otra superficie.
        chrome: NanoWindowChrome.contentOwned,

        animationStyle: MediaQuery.disableAnimationsOf(context)
            ? AnimationStyle.noAnimation
            : null,

        barrierColor: Colors.black.withValues(alpha: 0.38),
        builder: (_) => ConversationDetailSheet(item: item),
      );
    } finally {
      if (isWeb) WhatsAppWebSessionOwnership.foreground.value = false;
    }
  }

  @override
  ConsumerState<ConversationDetailSheet> createState() =>
      _ConversationDetailSheetState();
}
