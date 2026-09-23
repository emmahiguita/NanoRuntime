part of 'automation_rules_screen.dart';

/// QUÉ HACE:
/// Tarjeta interactiva para visualizar, activar/desactivar y expandir una regla.
///
/// CÓMO FUNCIONA:
/// Muestra disparador, acción, resultado de ejecución y permite desplegar el
/// menú de detalles completos (_RuleExpandedDetails) o cambiar su estado enabled.
///
/// POR QUÉ:
/// Ofrece retroalimentación visual clara e inmediata sobre qué reglas están
/// activas, cuándo dispararon por última vez y si fueron exitosas.
class _RuleCard extends ConsumerStatefulWidget {
  const _RuleCard({
    required this.rule,
    required this.onToggle,
    required this.onDelete,
    required this.onEdit,
  });

  final ScheduledRule rule;
  final ValueChanged<bool> onToggle;
  final VoidCallback onDelete;
  final VoidCallback onEdit;

  static String _triggerLabel(Trigger trigger) {
    if (trigger is NotificationTrigger) {
      final raw = trigger.packageName;
      final pkg = raw == MessagingPackage.whatsapp ? 'WhatsApp' : raw ?? 'app';
      final sender = trigger.senderMatch;
      final text = trigger.textMatch;
      final base = (sender == null || sender.isEmpty) ? pkg : '$pkg · "$sender"';
      return (text == null || text.isEmpty) ? base : '$base · "$text"';
    }
    if (trigger is TimeTrigger) {
      final hh = trigger.hour.toString().padLeft(2, '0');
      final mm = trigger.minute.toString().padLeft(2, '0');
      return trigger.weekdays.isEmpty ? 'a las $hh:$mm' : 'a las $hh:$mm (días ${trigger.weekdays.join(",")})';
    }
    if (trigger is ConnectivityTrigger) return 'wifi (sin soporte)';
    if (trigger is BatteryTrigger) return 'batería < ${trigger.belowPercent}%';
    return trigger.runtimeType.toString();
  }

  static String _mediaDetail(ScheduledRule rule) {
    final path = rule.mediaPath;
    final name = (path == null || path.isEmpty) ? 'sin archivo' : path.split('/').last;
    final msg = rule.message.trim();
    return msg.isEmpty ? name : '$name · "$msg"';
  }

  static String _hhmm(DateTime t) => '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
  static String _ddmmy(DateTime t) => '${t.day}/${t.month} ${_hhmm(t)}';

  @override
  ConsumerState<_RuleCard> createState() => _RuleCardState();
}

class _RuleCardState extends ConsumerState<_RuleCard> {
  bool _expanded = false;
  ScheduledRule get rule => widget.rule;

  (String, Color) _outcomeBadge(AutomationVisualPalette visual) {
    final danger = NanoThemeExtension.of(context).colors.danger;
    return switch (rule.lastOutcome) {
      'replyVerified' => ('✓ respuesta verificada', visual.accent),
      'replyDispatchedUnverified' => ('despachada · sin verificar', visual.textMuted),
      'outcomeUnknown' => ('sin confirmar', visual.textMuted),
      'mediaLaunched' => ('WhatsApp abierto con archivo', visual.accent),
      'notified' => ('aviso publicado', visual.accent),
      'drafted' => ('borrador preparado', visual.accent),
      'failed' => ('falló', danger),
      _ => ('sin ejecutar', visual.textMuted),
    };
  }

  @override
  Widget build(BuildContext context) {
    final visual = AutomationVisual.of(context);
    final danger = NanoThemeExtension.of(context).colors.danger;
    final settings = ref.watch(settingsProvider);
    final modeName = settings.automationModelMode.name;
    final modelPath = modeName == 'sameAsChat'
        ? settings.chatModelPath
        : modeName == 'specificModel' ? settings.automationModelPath : '';
    final hasValidModel = modelPath.trim().isNotEmpty && File(modelPath).existsSync();

    final actionDetail = rule.action == RuleAction.reply && !rule.dynamicReply
        ? (rule.message.isEmpty ? 'sin texto' : '"${rule.message}"')
        : rule.dynamicReply
            ? (hasValidModel ? 'dinámica (LLM local)' : 'dinámica (sin modelo)')
            : rule.action == RuleAction.sendMedia ? _RuleCard._mediaDetail(rule) : null;

    final (outcomeLabel, outcomeColor) = _outcomeBadge(visual);

    return AutomationSurfaceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            onTap: () => setState(() => _expanded = !_expanded),
            borderRadius: BorderRadius.circular(14),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: rule.enabled ? visual.accentSoft : visual.inputFill,
                      borderRadius: BorderRadius.circular(13),
                    ),
                    child: Icon(
                      rule.action == RuleAction.sendMedia ? Icons.attach_file_rounded : Icons.rule_rounded,
                      color: rule.enabled ? visual.accent : visual.textMuted,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${rule.action.label} · ${_RuleCard._triggerLabel(rule.trigger)}',
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(color: visual.text, fontSize: 14, fontWeight: FontWeight.w600),
                        ),
                        if (actionDetail != null) ...[
                          const SizedBox(height: 4),
                          Text(
                            actionDetail,
                            maxLines: _expanded ? null : 2,
                            overflow: _expanded ? TextOverflow.visible : TextOverflow.ellipsis,
                            style: TextStyle(color: visual.textMuted, fontSize: 12, height: 1.35),
                          ),
                        ],
                        const SizedBox(height: 4),
                        _buildOutcomeChip(outcomeLabel, outcomeColor),
                      ],
                    ),
                  ),
                  Switch(value: rule.enabled, onChanged: widget.onToggle),
                  const SizedBox(width: 4),
                  Icon(_expanded ? Icons.expand_less_rounded : Icons.expand_more_rounded,
                      color: visual.textMuted, size: 20),
                ],
              ),
            ),
          ),
          if (_expanded)
            _RuleExpandedDetails(
              rule: rule,
              visual: visual,
              outcomeLabel: outcomeLabel,
              lastFired: rule.lastFiredAt,
              onEdit: widget.onEdit,
              onDelete: widget.onDelete,
              dangerColor: danger,
            ),
        ],
      ),
    );
  }

  Widget _buildOutcomeChip(String outcomeLabel, Color outcomeColor) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Flexible(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: outcomeColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              outcomeLabel,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: outcomeColor, fontSize: 10.5, fontWeight: FontWeight.w600),
            ),
          ),
        ),
        const SizedBox(width: 6),
        Text(
          rule.lastFiredAt == null ? 'nunca disparó' : 'última ${_RuleCard._hhmm(rule.lastFiredAt!)}',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(color: AutomationVisual.of(context).textMuted, fontSize: 10.5),
        ),
      ],
    );
  }
}
