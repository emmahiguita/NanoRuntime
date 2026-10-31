import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nanoai/core/providers/settings_provider.dart';
import 'package:nanoai/core/theme/design_tokens.dart';
import 'package:nanoai/core/theme/nano_type.dart';
import 'package:nanoai/core/widgets/nano_glass_window.dart';
import 'package:nanoai/core/widgets/navigation/nano_navigation_panel.dart';
import 'package:nanoai/core/widgets/navigation/nano_universal_input.dart';
import 'package:nanoai/features/automation/application/automation_coordinator_provider.dart';
import 'package:nanoai/features/automation/application/rule_creator.dart';
import 'package:nanoai/features/automation/application/scheduled_whatsapp_message_service.dart';
import 'package:nanoai/features/automation/engine/messaging/messaging_package.dart';
import 'package:nanoai/features/automation/engine/platform/whatsapp_media_share.dart';
import 'package:nanoai/features/automation/engine/scheduling/scheduled_message_command_parser.dart';
import 'package:nanoai/features/automation/engine/scheduling/scheduled_rule.dart';
import 'package:nanoai/features/automation/engine/scheduling/trigger.dart';
import 'package:nanoai/features/automation/engine/scheduling/trigger_parser.dart';

import '../automation_visual_theme.dart';
import '../widgets/rule_edit_sheet.dart';

part 'automation_rules_actions.dart';
part 'automation_rules_dialogs.part.dart';
part 'automation_rules_sections.part.dart';
part 'automation_rules_card.dart';
part 'automation_rules_creator.dart';
part 'automation_rules_widgets.dart';

/// Gestión de reglas de automatización (listar / activar / desactivar / borrar).
class AutomationRulesScreen extends ConsumerStatefulWidget {
  const AutomationRulesScreen({super.key});

  @override
  ConsumerState<AutomationRulesScreen> createState() =>
      _AutomationRulesScreenState();
}

class _AutomationRulesScreenState extends ConsumerState<AutomationRulesScreen> {
  List<ScheduledRule> _rules = const [];
  bool _loaded = false;

  final _createController = TextEditingController();
  String? _createError;
  String? _pendingMediaPath;
  String? _pendingMediaName;

  static final _replyVerbs = RegExp(
    r'^(respóndele|respondele|responde|responder|contéstale|contestale|contesta|contestar)\s*',
    caseSensitive: false,
  );
  static final _notifyVerbs = RegExp(
    r'^(avísame|avisame|avisar|notifícame|notificame|notificar)\s*',
    caseSensitive: false,
  );
  static final _sendVerbs = RegExp(
    r'^(envíale|enviale|envía|envia|enví|mándale|mandale|mandá|manda)\s*',
    caseSensitive: false,
  );

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  @override
  void dispose() {
    _createController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final visualMode = AutomationVisual.modeFromSetting(
      ref.watch(settingsProvider.select((settings) => settings.themeMode)),
    );
    return AnimatedTheme(
      data: AutomationVisual.theme(context, mode: visualMode),
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeOutCubic,
      child: Builder(
        builder: (context) {
          final visual = AutomationVisual.of(context);
          return Scaffold(
            backgroundColor: Colors.transparent,
            body: NanoShellBarScope(
              slotId: 'automation_rules',
              child: NanoInputScope(
                scopeId: 'automation_rules',
                hint: 'Crea una regla: «a las 6:45 pm mándale a Emm: Hola»...',
                onSubmit: _createRuleFromText,
                child: SafeArea(
                  child: Column(
                    children: [
                      const AutomationBackHeader(),
                      Expanded(child: _buildRulesLayout(visual)),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
