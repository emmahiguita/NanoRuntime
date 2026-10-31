import 'dart:convert';
import 'package:flutter/material.dart';
import '../../../../core/widgets/nano_anchored_popover.dart';
import 'automation_input_attachment.dart';
part 'whatsapp_automation_menu_state.dart';
part 'whatsapp_automation_menu_view.dart';

/// Funciones del componente activo. Devuelve un borrador al mismo ejecutor;
/// las fuentes de adjuntos pertenecen al + y no se repiten en este menú.
Future<void> showWhatsAppAutomationMenu(
  BuildContext anchor, {
  required ValueChanged<String> onDraft,
  required VoidCallback onActivate,
  AutomationInputAttachment? attachment,
  Map<String, String> extraActions = const {},
}) async {
  final command = await showNanoAnchoredPopover<String>(
    anchorContext: anchor,
    label: 'Funciones de WhatsApp',
    maxWidth: 280,
    builder: (_) => _WhatsAppActions(attachment: attachment, extraActions: extraActions),
  );
  // El dock puede cambiar al aparecer el teclado. Los callbacks verifican al
  // propietario; la vida del botón usado como ancla no invalida el borrador.
  if (command == null) return;
  onActivate();
  onDraft(command);
}

enum _WhatsAppMenuAction { open, compose, attach }

class _WhatsAppActions extends StatefulWidget {
  const _WhatsAppActions({this.attachment, this.extraActions = const {}});
  final AutomationInputAttachment? attachment;
  final Map<String, String> extraActions;
  @override
  State<_WhatsAppActions> createState() => _WhatsAppActionsState();
}
