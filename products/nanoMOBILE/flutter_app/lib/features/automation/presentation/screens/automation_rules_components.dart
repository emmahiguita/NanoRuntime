part of 'automation_rules_screen.dart';

/// RULES-CREATE-01 — campo de creación de reglas en lenguaje natural.
/// Presentación pura: el parseo y el registry viven en la pantalla.
class _RuleCreatorCard extends StatelessWidget {
  const _RuleCreatorCard({
    required this.controller,
    required this.error,
    required this.pendingMediaName,
    required this.onCreate,
    required this.onPickMedia,
  });

  final TextEditingController controller;
  final String? error;

  /// WA-MEDIA-01 — nombre del archivo elegido para la regla de envío.
  final String? pendingMediaName;
  final VoidCallback onCreate;
  final VoidCallback onPickMedia;

  @override
  Widget build(BuildContext context) {
    final visual = AutomationVisual.of(context);
    final colors = NanoThemeExtension.of(context).colors;
    return AutomationSurfaceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            controller: controller,
            minLines: 1,
            maxLines: 3,
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => onCreate(),
            // FIX-VERT-01 — colapsa saltos de línea EN VIVO (pegar, dictado,
            // Enter): el campo ya no pinta texto vertical mientras se
            // escribe. La normalización al guardar sigue como segunda capa.
            inputFormatters: [
              TextInputFormatter.withFunction((oldValue, newValue) {
                if (!newValue.text.contains('\n')) return newValue;
                final collapsed = newValue.text.replaceAll('\n', ' ');
                return newValue.copyWith(
                  text: collapsed,
                  selection: TextSelection.collapsed(offset: collapsed.length),
                );
              }),
            ],
            style: TextStyle(
              color: visual.text,
              fontSize: 14,
              fontFamily: 'Inter',
            ),
            decoration: InputDecoration(
              hintText: 'Nueva regla… p. ej. «a las 8:30 avísame que es hora»',
              hintStyle: TextStyle(
                color: visual.textMuted.withValues(alpha: 0.7),
                fontSize: 13,
                fontFamily: 'Inter',
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              filled: true,
              fillColor: visual.inputFill,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 10,
              ),
            ),
          ),
          const SizedBox(height: 8),
          // WA-MEDIA-01 — adjuntar archivo para reglas de envío (PDF,
          // imagen, catálogo). El archivo elegido se copia a la carpeta
          // fija del catálogo al crear la regla.
          Wrap(
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 8,
            runSpacing: 4,
            children: [
              OutlinedButton.icon(
                onPressed: onPickMedia,
                icon: const Icon(Icons.attach_file_rounded, size: 17),
                label: const Text('Adjuntar archivo'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: visual.accent,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                ),
              ),
              Text(
                pendingMediaName ?? 'Sin archivo (solo para "envíale…")',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: pendingMediaName == null
                      ? visual.textMuted.withValues(alpha: 0.7)
                      : visual.text,
                  fontSize: 12,
                  fontFamily: 'Inter',
                ),
              ),
            ],
          ),
          if (error != null) ...[
            const SizedBox(height: 8),
            Text(
              error!,
              style: TextStyle(
                color: colors.danger,
                fontSize: 12,
                height: 1.35,
                fontFamily: 'Inter',
              ),
            ),
          ],
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // UI-REV-13: Expanded — el hint cede ancho y el botón jamás
              // desborda en pantallas angostas (overflow horizontal).
              Expanded(
                child: Text(
                  'Se evalúa con cada notificación · hora con la app abierta',
                  style: TextStyle(
                    color: visual.textMuted,
                    fontSize: 11,
                    fontFamily: 'Inter',
                  ),
                ),
              ),
              const SizedBox(width: 8),
              FilledButton(
                onPressed: onCreate,
                style: FilledButton.styleFrom(
                  backgroundColor: visual.accent,
                  foregroundColor: colors.onAccent,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                ),
                child: const Text('Crear'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// WA-RULES-UI-02 — card de regla expandible: header con acción+disparo+
/// badge de última ejecución; tap expande el detalle completo (honesto).
typedef RuleCard = _RuleCard;

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
      // WA-UNIV-01 — nombre amable del paquete WhatsApp (punto único de
      // la card y el detalle; el resto queda con el packageName crudo).
      final rawPackage = trigger.packageName;
      final package = rawPackage == MessagingPackage.whatsapp
          ? 'WhatsApp'
          : rawPackage ?? 'cualquier app';
      final sender = trigger.senderMatch;
      final textMatch = trigger.textMatch;
      final base = (sender == null || sender.isEmpty)
          ? package
          : '$package · contacto "$sender"';
      if (textMatch == null || textMatch.isEmpty) return base;
      return '$base · texto "$textMatch"';
    }
    // TRIG-01: la regla de hora ahora dispara (ticker en-app, app viva).
    if (trigger is TimeTrigger) {
      final hh = trigger.hour.toString().padLeft(2, '0');
      final mm = trigger.minute.toString().padLeft(2, '0');
      if (trigger.weekdays.isEmpty) return 'a las $hh:$mm';
      return 'a las $hh:$mm (días ${trigger.weekdays.join(',')})';
    }
    // TRIG-01: honestidad — conectividad/batería no tienen productor de
    // eventos todavía; la regla existe pero jamás disparará. La UI no miente.
    if (trigger is ConnectivityTrigger) {
      return 'wifi (sin soporte aún)';
    }
    if (trigger is BatteryTrigger) {
      return 'batería < ${trigger.belowPercent}% (sin soporte aún)';
    }
    return trigger.runtimeType.toString();
  }

  /// WA-MEDIA-01 — detalle de la regla de archivo: nombre del archivo del
  /// catálogo fijo + caption. Sin ruta: la regla está incompleta (honesto).
  static String _mediaDetail(ScheduledRule rule) {
    final path = rule.mediaPath;
    final name = (path == null || path.isEmpty)
        ? 'sin archivo (regla incompleta)'
        : path.split('/').last;
    final caption = rule.message.trim();
    return caption.isEmpty ? name : '$name · "$caption"';
  }

  static String _hhmm(DateTime t) {
    final h = t.hour.toString().padLeft(2, '0');
    final m = t.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }

  static String _ddmmy(DateTime t) => '${t.day}/${t.month} ${_hhmm(t)}';

  @override
  ConsumerState<_RuleCard> createState() => _RuleCardState();
}

class _RuleCardState extends ConsumerState<_RuleCard> {
  bool _expanded = false;

  ScheduledRule get rule => widget.rule;

  /// WA-RULES-UI-02 — etiqueta + color del resultado REAL de la última
  /// ejecución. Sin outcome registrado = "sin ejecutar" (no inventa éxito).
  (String, Color) _outcomeBadge(AutomationVisualPalette visual) {
    final danger = NanoThemeExtension.of(context).colors.danger;
    return switch (rule.lastOutcome) {
      'replyVerified' => ('✓ respuesta verificada', visual.accent),
      'replyDispatchedUnverified' => (
        'respuesta despachada · sin verificar',
        visual.textMuted,
      ),
      'outcomeUnknown' => ('envío sin confirmar', visual.textMuted),
      'mediaLaunched' => ('WhatsApp abierto con el archivo', visual.accent),
      'notified' => ('aviso publicado', visual.accent),
      'drafted' => ('borrador preparado', visual.accent),
      'failed' => ('falló', danger),
      'ignored' => ('ignorada', visual.textMuted),
      _ => ('sin ejecutar', visual.textMuted),
    };
  }

  @override
  Widget build(BuildContext context) {
    final visual = AutomationVisual.of(context);
    final danger = NanoThemeExtension.of(context).colors.danger;

    final settings = ref.watch(settingsProvider);
    final modeName = settings.automationModelMode.name;
    final selectedModelPath = modeName == 'sameAsChat'
        ? settings.chatModelPath
        : modeName == 'specificModel'
            ? settings.automationModelPath
            : '';
    final hasValidModel =
        selectedModelPath.trim().isNotEmpty &&
        File(selectedModelPath).existsSync();

    final dynamicDetail = !hasValidModel
        ? 'respuesta dinámica (⚠️ sin modelo cargado)'
        : 'respuesta dinámica (LLM local)';

    final actionDetail = rule.action == RuleAction.reply && !rule.dynamicReply
        ? (rule.message.isEmpty
              ? 'sin texto (fail-closed)'
              : '"${rule.message}"')
        : rule.dynamicReply
        ? dynamicDetail
        : rule.action == RuleAction.sendMedia
        ? _RuleCard._mediaDetail(rule)
        : null;
    final lastFired = rule.lastFiredAt;
    final (outcomeLabel, outcomeColor) = _outcomeBadge(visual);
    return AutomationSurfaceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header táctil: expande/contrae el detalle.
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
                      color: rule.enabled
                          ? visual.accentSoft
                          : visual.inputFill,
                      borderRadius: BorderRadius.circular(13),
                    ),
                    child: Icon(
                      rule.action == RuleAction.sendMedia
                          ? Icons.attach_file_rounded
                          : Icons.rule_rounded,
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
                          '${rule.action.label} · '
                          '${_RuleCard._triggerLabel(rule.trigger)}',
                          // FIX-VERT-02 — sin espacios entre "días 1,2,3"
                          // (o la hora) la última "palabra" se partía por
                          // caracteres y quedaba apilada vertical. Una línea
                          // con ellipsis: jamás apila.
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: visual.text,
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 4),
                        if (actionDetail != null)
                          Text(
                            actionDetail,
                            maxLines: _expanded ? null : 2,
                            overflow: _expanded
                                ? TextOverflow.visible
                                : TextOverflow.ellipsis,
                            style: TextStyle(
                              color: visual.textMuted,
                              fontSize: 12,
                              height: 1.35,
                            ),
                          ),
                        const SizedBox(height: 4),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Flexible(
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: outcomeColor.withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Text(
                                  outcomeLabel,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: outcomeColor,
                                    fontSize: 10.5,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              lastFired == null
                                  ? 'nunca disparó'
                                  : 'última ${_RuleCard._hhmm(lastFired)}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: visual.textMuted,
                                fontSize: 10.5,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  Switch(value: rule.enabled, onChanged: widget.onToggle),
                  const SizedBox(width: 4),
                  Icon(
                    _expanded
                        ? Icons.expand_less_rounded
                        : Icons.expand_more_rounded,
                    color: visual.textMuted,
                    size: 20,
                  ),
                ],
              ),
            ),
          ),
          // Detalle expandido: información completa de la regla.
          if (_expanded) ...[
            const SizedBox(height: 10),
            Divider(color: visual.inputFill, height: 1),
            const SizedBox(height: 10),
            _DetailRow(
              label: 'Disparo',
              value: _RuleCard._triggerLabel(rule.trigger),
            ),
            _DetailRow(label: 'Acción', value: rule.action.label),
            if (rule.action == RuleAction.sendMedia)
              _DetailRow(
                label: 'Archivo',
                value: rule.mediaPath ?? 'sin archivo (regla incompleta)',
              )
            else if (rule.message.isNotEmpty)
              _DetailRow(label: 'Texto', value: rule.message)
            else if (rule.dynamicReply)
              const _DetailRow(
                label: 'Texto',
                value: 'dinámico (LLM local por conversación)',
              ),
            _DetailRow(
              label: 'Estado',
              value:
                  '$outcomeLabel · '
                  '${lastFired == null ? 'nunca disparó' : _RuleCard._ddmmy(lastFired)}',
            ),
            _DetailRow(
              label: 'Creada',
              value: _RuleCard._ddmmy(rule.createdAt),
            ),
            _DetailRow(label: 'ID', value: rule.id),
            const SizedBox(height: 4),
            Align(
              alignment: Alignment.centerRight,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // RULES-EDIT-01 — editar abre el editor estructurado.
                  TextButton.icon(
                    onPressed: widget.onEdit,
                    icon: const Icon(Icons.edit_outlined, size: 17),
                    label: const Text('Editar'),
                  ),
                  const SizedBox(width: 8),
                  TextButton.icon(
                    onPressed: widget.onDelete,
                    icon: const Icon(Icons.delete_outline_rounded, size: 17),
                    label: const Text('Borrar'),
                    style: TextButton.styleFrom(foregroundColor: danger),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final visual = AutomationVisual.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 68,
            child: Text(
              label,
              style: TextStyle(
                color: visual.textMuted,
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              // FIX-VERT-02 — la hora final de "06/09 05:12" o textos sin
              // espacios no deben partirse por caracteres: truncan con
              // ellipsis, jamás apilan.
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: visual.text, fontSize: 12, height: 1.35),
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title, this.icon, this.imageAsset})
    : assert(icon != null || imageAsset != null);

  final String title;
  final IconData? icon;
  final String? imageAsset;

  @override
  Widget build(BuildContext context) {
    final visual = AutomationVisual.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 14, 4, 8),
      child: Row(
        children: [
          if (imageAsset != null)
            Image.asset(imageAsset!, width: 18, height: 18, fit: BoxFit.contain)
          else
            Icon(icon!, color: visual.accent, size: 16),
          const SizedBox(width: 8),
          Text(
            title,
            style: TextStyle(
              color: visual.text,
              fontSize: 13,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.2,
            ),
          ),
        ],
      ),
    );
  }
}

class _ContactLabel extends StatelessWidget {
  const _ContactLabel({required this.contact, required this.visual});

  final String contact;
  final AutomationVisualPalette visual;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
      child: Text(
        contact,
        style: TextStyle(
          color: visual.textMuted,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.visual});

  final AutomationVisualPalette visual;

  @override
  Widget build(BuildContext context) {
    return AutomationSurfaceCard(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 28),
        child: Column(
          children: [
            Icon(Icons.rule_rounded, color: visual.textMuted, size: 32),
            const SizedBox(height: 10),
            Text(
              'Sin reglas todavía',
              style: TextStyle(
                color: visual.text,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Pídele a Nano en el chat: "responde X a Y" y la regla '
              'aparecerá aquí.',
              textAlign: TextAlign.center,
              style: TextStyle(color: visual.textMuted, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }
}
