part of 'automation_rules_screen.dart';

// automation_rules_actions.dart
//
// QUÉ HACE:
// Acciones de creación y parsing de reglas en lenguaje natural y selección de multimedia.
//
// CÓMO FUNCIONA:
// - Parsea disparadores mediante TriggerParser (notificaciones, horarios, remitentes).
// - Maneja el selector de archivos multimedia con FilePicker y copiado seguro al catálogo.
//
// POR QUÉ:
// Aplica Single Responsibility Principle (SRP) separando la lógica interactiva (< 200 líneas).

extension _AutomationRulesActions on _AutomationRulesScreenState {
  Future<void> _refresh() async {
    final registry = ref.read(ruleRegistryProvider);
    await registry.load();
    if (mounted) {
      setState(() {
        _rules = registry.rules;
        _loaded = true;
      });
    }
  }

  Future<void> _createRule() => _createRuleFromText(_createController.text);

  Future<void> _createRuleFromText(String raw) async {
    final text = raw.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (text.isEmpty) return;
    final parsed = const TriggerParser().parse(text);
    if (parsed == null) {
      setState(
        () => _createError =
            'No entendí el disparo. Prueba «a las 8:30 avísame que es hora», '
            '«cuando Juan me escriba, respóndele...» o «si dice noche, respóndele...».',
      );
      return;
    }
    final goal = parsed.goal.trim();

    final scheduledMessage = parsed.trigger is TimeTrigger
        ? ScheduledMessageCommandParser.parse(goal)
        : null;
    if (scheduledMessage != null) {
      await _scheduleTimeMessage(parsed.trigger, scheduledMessage);
      return;
    }

    if (parsed.trigger is TimeTrigger &&
        _AutomationRulesScreenState._sendVerbs.hasMatch(goal)) {
      setState(
        () => _createError =
            'Indica destinatario y texto. Ejemplo: '
            '«a las 6:45 pm mándale un mensaje a Emm: Hola».',
      );
      return;
    }

    final String message;
    final RuleAction action;
    var dynamicReply = false;
    if (_AutomationRulesScreenState._replyVerbs.hasMatch(goal)) {
      action = RuleAction.reply;
      message = goal
          .replaceFirst(_AutomationRulesScreenState._replyVerbs, '')
          .trim();
      dynamicReply = message.isEmpty;
    } else if (_AutomationRulesScreenState._sendVerbs.hasMatch(goal)) {
      action = RuleAction.sendMedia;
      message = goal
          .replaceFirst(_AutomationRulesScreenState._sendVerbs, '')
          .trim();
    } else {
      action = RuleAction.notify;
      message = goal
          .replaceFirst(_AutomationRulesScreenState._notifyVerbs, '')
          .trim();
    }
    final needsSender =
        action == RuleAction.reply || action == RuleAction.sendMedia;
    if (parsed.trigger is TimeTrigger && needsSender) {
      setState(
        () => _createError =
            'Responder y enviar archivos necesitan un remitente: usa un trigger de notificación. Con hora solo puedo avisarte.',
      );
      return;
    }
    if (action == RuleAction.sendMedia && _pendingMediaPath == null) {
      setState(
        () =>
            _createError = 'Elige un archivo antes de crear la regla de envío.',
      );
      return;
    }

    String? mediaPath;
    if (action == RuleAction.sendMedia) {
      mediaPath = await const WhatsAppMediaShare().copyToCatalog(
        _pendingMediaPath!,
      );
      if (mediaPath == null) {
        if (!mounted) return;
        setState(
          () => _createError = 'No se pudo copiar el archivo al catálogo.',
        );
        return;
      }
    }

    final rule = ref
        .read(ruleCreatorProvider)
        .create(
          trigger: parsed.trigger,
          action: action,
          message: message,
          dynamicReply: dynamicReply,
          mediaPath: mediaPath,
        );
    if (!mounted) return;
    setState(() {
      _rules = ref.read(ruleRegistryProvider).rules;
      _createError = null;
      _pendingMediaPath = null;
      _pendingMediaName = null;
    });
    _createController.clear();
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('Regla creada: ${rule.id}')));
  }

  Future<void> _scheduleTimeMessage(
    Trigger trigger,
    ScheduledMessageCommand scheduledMessage,
  ) async {
    final service = ScheduledWhatsAppMessageService();
    final recipients = await service.resolveRecipients(
      scheduledMessage.recipients,
    );
    if (!mounted) return;
    if (recipients == null ||
        recipients.length != scheduledMessage.recipients.length) {
      setState(
        () => _createError =
            'No pude resolver todos los contactos. Usa nombres completos, '
            'números con indicativo o encierra cada nombre entre paréntesis.',
      );
      return;
    }

    final registry = ref.read(ruleRegistryProvider);
    final previousIds = registry.rules.map((rule) => rule.id).toSet();
    final rule = ref
        .read(ruleCreatorProvider)
        .create(
          trigger: trigger,
          action: RuleAction.sendMessage,
          message: scheduledMessage.message,
          recipients: recipients,
        );
    final scheduled = await service.schedule(rule);
    if (!mounted) return;
    if (!scheduled.scheduled) {
      if (!previousIds.contains(rule.id)) registry.remove(rule.id);
      setState(() => _createError = scheduled.reason);
      return;
    }
    setState(() {
      _rules = registry.rules;
      _createError = null;
    });
    _createController.clear();
    final precision = scheduled.exact ? 'exacta' : 'aproximada por Android';
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Mensaje programado para ${recipients.length} contacto(s) '
          '($precision).',
        ),
        action: scheduled.exact
            ? null
            : SnackBarAction(
                label: 'Permitir exactas',
                onPressed: service.openExactAlarmSettings,
              ),
      ),
    );
  }
}
