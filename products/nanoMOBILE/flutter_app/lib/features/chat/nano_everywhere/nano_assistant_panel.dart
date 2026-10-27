library;

import 'dart:async';
import 'package:flutter/foundation.dart';
import '../../../core/router/app_router.dart';
import '../../automation/application/automation_access_controller.dart';
import '../../automation/presentation/widgets/automation_history_panel.dart';
import 'package:flutter/material.dart';
import 'nano_ai_controller.dart';
import 'nano_ai_models.dart';
import 'nano_assistant_composer.dart';
import 'nano_assistant_panel_components.dart';
import 'nano_assistant_panel_sections.dart';
import 'nano_glass.dart';
import 'nano_prepared_attachment.dart';
import 'nano_attachment_commands.dart';
import 'nano_action_input.dart';
import '../../automation/presentation/widgets/automation_attachment_picker.dart';
import '../../automation/presentation/widgets/automation_input_attachment.dart';
import '../../automation/presentation/widgets/automation_input_menu.dart';
import 'nano_assistant_tools.dart';
import 'nano_assistant_tool_selector.dart';
part 'nano_assistant_panel_actions.dart';
part 'nano_assistant_attachments.dart';
part 'nano_assistant_panel_view.dart';

class NanoAssistantPanel extends StatefulWidget {
  const NanoAssistantPanel({
    super.key,
    required this.controller,
    required this.input,
    required this.audioLevel,
    this.onVoice,
    this.onSpeak,
    required this.onCollapse,
  });

  final NanoAiController controller;
  final TextEditingController input;
  final ValueListenable<double> audioLevel;
  final VoidCallback? onVoice;
  final ValueChanged<String>? onSpeak;
  final VoidCallback onCollapse;

  @override
  State<NanoAssistantPanel> createState() => _NanoAssistantPanelState();
}

class _NanoAssistantPanelState extends State<NanoAssistantPanel> {
  late String _activeTool;
  final _access = AutomationAccessController();
  bool _preparing = false;
  bool _pickingAttachment = false;
  bool _preparationCancelled = false;

  // Cancela también la comprobación de permisos anterior al despacho.
  void _cancelAction() {
    _preparationCancelled = true;
    widget.controller.cancel();
  }

  bool get _busy =>
      _preparing ||
      _pickingAttachment ||
      widget.controller.isBusy &&
          widget.controller.activity != NanoActivity.listening ||
      const {
        NanoActivity.thinking,
        NanoActivity.acting,
        NanoActivity.comparing,
        NanoActivity.debating,
      }.contains(widget.controller.activity);
  @override
  void initState() {
    super.initState();
    _activeTool = widget.controller.panelTool;
    _access.addListener(_refreshAccess);
    unawaited(_access.refresh());
  }

  void _setPreparing(bool value) {
    if (mounted) setState(() => _preparing = value);
  }

  void _selectTool(String value) => setState(() => _activeTool = value);
  void _refreshAccess() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _access.removeListener(_refreshAccess);
    _access.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => _buildPanel(context);
}
