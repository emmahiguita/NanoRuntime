import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nanoai/core/providers/settings_provider.dart';
import 'package:nanoai/core/theme/design_tokens.dart';
import 'package:nanoai/features/automation/application/automation_coordinator_provider.dart';
import 'package:nanoai/features/automation/application/rule_creator.dart';
import 'package:nanoai/features/automation/engine/platform/whatsapp_media_share.dart';
import 'package:nanoai/features/automation/engine/scheduling/scheduled_rule.dart';
import 'package:nanoai/features/automation/engine/scheduling/trigger.dart';
import 'package:nanoai/features/automation/engine/scheduling/trigger_parser.dart';

import 'package:nanoai/core/widgets/navigation/nano_navigation_panel.dart';
import 'package:nanoai/core/widgets/navigation/nano_universal_input.dart';

import '../automation_layout.dart';
import '../automation_visual_theme.dart';
import '../widgets/rule_edit_sheet.dart';

/// Gestión de reglas de automatización (listar / activar / desactivar / borrar).
///
/// Solo lee y muta el [RuleRegistry] — la MISMA fuente que consulta el pipeline
/// de notificaciones. La ejecución sigue en el AutomationCoordinator: esta
/// pantalla jamás ejecuta nada. El borrado pide confirmación (irreversible);
/// el switch activa/desactiva directo (reversible).
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

  /// WA-MEDIA-01 — archivo elegido con el picker, pendiente de copiar al
  /// catálogo al crear la regla. Path temporal del picker + nombre legible.
  String? _pendingMediaPath;
  String? _pendingMediaName;

  /// RULES-CREATE-01: verbos de acción del lenguaje natural de la regla.
  /// Se limpian del mensaje (quedan en la acción, no en el texto).
  static final _replyVerbs = RegExp(
    r'^(respóndele|respondele|responde|responder|contéstale|contestale|contesta|contestar)\s*',
    caseSensitive: false,
  );
  static final _notifyVerbs = RegExp(
    r'^(avísame|avisame|avisar|notifícame|notificame|notificar)\s*',
    caseSensitive: false,
  );
  // WA-MEDIA-01 — verbos de envío de archivo: la regla adjunta el archivo
  // elegido y lo manda al remitente del trigger.
  static final _sendVerbs = RegExp(
    r'^(envíale|enviale|envía|envia|enví|mándale|mandale|mandá|manda)\s*',
    caseSensitive: false,
  );

  @override
  void dispose() {
    _createController.dispose();
    super.dispose();
  }

  /// RULES-CREATE-01 — crea una regla desde lenguaje natural con el MISMO
  /// TriggerParser del pipeline. Acción por verbo (responder → reply,
  /// enviar → sendMedia, resto → notify); reply y sendMedia con trigger de
  /// hora se rechazan honestos (un tick no trae remitente) y reply sin
  /// texto queda como respuesta dinámica.
  ///
  /// WA-MEDIA-01 — sendMedia exige archivo elegido con el botón adjuntar:
  /// se copia a la carpeta fija del catálogo (nombre fijo) y la regla
  /// persiste ESA ruta estable, jamás el path temporal del picker.
  Future<void> _createRule() => _createRuleFromText(_createController.text);

  /// Crea una regla desde texto libre. La card de creación y la barra
  /// universal envían aquí su query — misma validación, mismo catálogo,
  /// un solo camino (NAV-BAR-FIX-04).
  Future<void> _createRuleFromText(String raw) async {
    final text = raw.trim();
    if (text.isEmpty) return;
    final parsed = const TriggerParser().parse(text);
    if (parsed == null) {
      setState(
        () => _createError =
            'No entendí el disparo. Prueba «a las 8:30 avísame que es hora» '
            'o «cuando Juan me escriba, respóndele estoy ocupado».',
      );
      return;
    }
    final goal = parsed.goal.trim();
    final String message;
    final RuleAction action;
    var dynamicReply = false;
    if (_replyVerbs.hasMatch(goal)) {
      action = RuleAction.reply;
      message = goal.replaceFirst(_replyVerbs, '').trim();
      dynamicReply = message.isEmpty;
    } else if (_sendVerbs.hasMatch(goal)) {
      action = RuleAction.sendMedia;
      message = goal.replaceFirst(_sendVerbs, '').trim();
    } else {
      action = RuleAction.notify;
      message = goal.replaceFirst(_notifyVerbs, '').trim();
    }
    final needsSender =
        action == RuleAction.reply || action == RuleAction.sendMedia;
    if (parsed.trigger is TimeTrigger && needsSender) {
      setState(
        () => _createError =
            'Responder y enviar archivos necesitan un remitente: usa un '
            'trigger de notificación («cuando Juan me escriba, respóndele '
            'X»). Con hora solo puedo avisarte.',
      );
      return;
    }
    if (action == RuleAction.sendMedia && _pendingMediaPath == null) {
      setState(
        () => _createError =
            'Elige un archivo con el botón adjuntar (📎) antes de crear la '
            'regla de envío. El archivo queda en el catálogo fijo.',
      );
      return;
    }
    // WA-MEDIA-01 — copia al catálogo ANTES de crear: la regla guarda la
    // ruta estable, y sin copia exitosa no hay regla (fail honesto).
    String? mediaPath;
    if (action == RuleAction.sendMedia) {
      mediaPath = await const WhatsAppMediaShare().copyToCatalog(
        _pendingMediaPath!,
      );
      if (mediaPath == null) {
        setState(
          () => _createError =
              'No se pudo copiar el archivo al catálogo. Intenta de nuevo.',
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

  /// WA-MEDIA-01 — abre el picker del sistema y guarda el archivo elegido
  /// como pendiente (path temporal + nombre legible para la card).
  Future<void> _pickMedia() async {
    // Misma API estática del chat (file_picker v11, SAF con ruta cacheada).
    final picked = await FilePicker.pickFiles(type: FileType.any);
    final file = picked?.files.single;
    if (file == null || file.path == null) return;
    setState(() {
      _pendingMediaPath = file.path;
      _pendingMediaName = file.name;
      _createError = null;
    });
  }

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  /// El provider dispara `load()` al crearse; re-leer aquí garantiza que la
  /// lista no se muestre vacía por la carrera de hidratación.
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

  void _toggle(ScheduledRule rule, bool enabled) {
    ref.read(ruleRegistryProvider).setEnabled(rule.id, enabled);
    setState(() => _rules = ref.read(ruleRegistryProvider).rules);
  }

  /// WA-RULES-UI-02 — regla de mensajería (WhatsApp-first): trigger de
  /// notificación con remitente, o paquete WhatsApp explícito.
  static bool _isMessagingRule(ScheduledRule rule) {
    final trigger = rule.trigger;
    if (trigger is! NotificationTrigger) return false;
    final package = trigger.packageName?.toLowerCase() ?? '';
    return trigger.senderMatch != null ||
        trigger.textMatch != null ||
        package.contains('whatsapp');
  }

  /// WA-RULES-UI-02 — secciones: WhatsApp agrupado por contacto, luego
  /// horarios y el resto. Cada sección con su cabecera y sus cards.
  List<Widget> _buildSections(AutomationVisualPalette visual) {
    final whatsapp = _rules.where(_isMessagingRule).toList();
    final timed = _rules
        .where((r) => r.trigger is TimeTrigger && !_isMessagingRule(r))
        .toList();
    final others = _rules
        .where((r) => !_isMessagingRule(r) && r.trigger is! TimeTrigger)
        .toList();

    final sections = <Widget>[];
    if (whatsapp.isNotEmpty) {
      sections.add(const _SectionHeader(title: 'WhatsApp', icon: Icons.chat_rounded));
      // Agrupado por contacto dentro de WhatsApp (null → cualquier contacto).
      final byContact = <String, List<ScheduledRule>>{};
      for (final rule in whatsapp) {
        final trigger = rule.trigger as NotificationTrigger;
        final contact = trigger.senderMatch?.trim() ?? 'Cualquier contacto';
        byContact.putIfAbsent(contact, () => []).add(rule);
      }
      final contacts = byContact.keys.toList()..sort();
      for (final contact in contacts) {
        sections.add(
          _ContactLabel(contact: contact, visual: visual),
        );
        sections.addAll(
          byContact[contact]!.map((rule) => _ruleCard(rule)),
        );
      }
    }
    if (timed.isNotEmpty) {
      sections.add(
        const _SectionHeader(title: 'Horarios', icon: Icons.schedule_rounded),
      );
      sections.addAll(timed.map((rule) => _ruleCard(rule)));
    }
    if (others.isNotEmpty) {
      sections.add(
        const _SectionHeader(title: 'Otras', icon: Icons.apps_rounded),
      );
      sections.addAll(others.map((rule) => _ruleCard(rule)));
    }
    return sections;
  }

  Widget _ruleCard(ScheduledRule rule) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: _RuleCard(
      rule: rule,
      onToggle: (v) => _toggle(rule, v),
      onDelete: () => _confirmDelete(rule),
      // RULES-EDIT-01 — edición profesional desde el detalle de la card.
      onEdit: () => _editRule(rule),
    ),
  );

  Future<void> _confirmDelete(ScheduledRule rule) async {
    final visual = AutomationVisual.of(context);
    final danger = NanoThemeExtension.of(context).colors.danger;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: visual.surface,
        title: const Text('Borrar regla'),
        content: Text(
          'Se eliminará la regla "${rule.id}". Esta acción no se puede deshacer.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: FilledButton.styleFrom(backgroundColor: danger),
            child: const Text('Borrar'),
          ),
        ],
      ),
    );
    if (confirm == true && mounted) {
      ref.read(ruleRegistryProvider).remove(rule.id);
      setState(() => _rules = ref.read(ruleRegistryProvider).rules);
    }
  }

  /// RULES-EDIT-01 — abre el editor estructurado y aplica el resultado al
  /// registro (mismo camino de persistencia que crear y borrar).
  Future<void> _editRule(ScheduledRule rule) async {
    final updated = await showModalBottomSheet<ScheduledRule>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) => RuleEditSheet(rule: rule),
    );
    if (updated == null || !mounted) return;
    ref.read(ruleRegistryProvider).update(rule.id, updated);
    setState(() => _rules = ref.read(ruleRegistryProvider).rules);
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('Regla actualizada: ${rule.id}')));
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
            // UI-REV-03: fondo compartido de Dev.
            backgroundColor: Colors.transparent,
            // NAV-BAR-FIX-03 — barra global también en Reglas.
            body: NanoShellBarScope(
              // NAV-BAR-FIX-04 — la barra CREA reglas aquí (no ejecuta la
              // automatización del dashboard ni salta a otra pantalla).
              child: NanoInputScope(
                scopeId: 'automation',
                hint: 'Crea una regla: «a las 8:30 avísame que es hora»...',
                onSubmit: (query) => _createRuleFromText(query),
                child: Stack(
              fit: StackFit.expand,
              children: [
                const AutomationBackdrop(),
                SafeArea(
                  child: Column(
                    children: [
                      const AutomationBackHeader(),
                      Expanded(
                        child: ListView(
                          padding: const EdgeInsets.fromLTRB(12, 8, 12, 48),
                          children: [
                            Center(
                              child: ConstrainedBox(
                                // UI-REV-13: ancho adaptativo por orientación.
                                constraints: BoxConstraints(
                                  maxWidth: AutomationLayout.contentMaxWidth(
                                    context,
                                  ),
                                ),
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.stretch,
                                  children: [
                                    // UI-REV-02: título 22px — jerarquía Dev, sin la
                                    // losa de 30px que aplastaba la cabecera.
                                    Text(
                                      'Reglas',
                                      style: TextStyle(
                                        color: visual.text,
                                        fontSize: 22,
                                        fontWeight: FontWeight.w700,
                                        letterSpacing: -0.5,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      'Cuándo y cómo Nano responde por ti. Las reglas '
                                      'activas se evalúan con cada notificación.',
                                      style: TextStyle(
                                        color: visual.textMuted,
                                        fontSize: 13,
                                        height: 1.4,
                                      ),
                                    ),
                                    const SizedBox(height: 24),
                                    // RULES-CREATE-01: creación en lenguaje
                                    // natural — el MISMO TriggerParser que
                                    // evalúa el pipeline, sin duplicar lógica.
                                    _RuleCreatorCard(
                                      controller: _createController,
                                      error: _createError,
                                      pendingMediaName: _pendingMediaName,
                                      onCreate: _createRule,
                                      onPickMedia: _pickMedia,
                                    ),
                                    const SizedBox(height: 16),
                                    if (!_loaded)
                                      const Padding(
                                        padding: EdgeInsets.all(24),
                                        child: Center(
                                          child: CircularProgressIndicator(),
                                        ),
                                      )
                                    else if (_rules.isEmpty)
                                      _EmptyState(visual: visual)
                                    else ...[
                                      // WA-RULES-UI-02 — organización
                                      // profesional por destino: WhatsApp
                                      // (por contacto), horarios y el resto.
                                      ..._buildSections(visual),
                                    ],
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    },
  ),
  );
  }
}

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
          Row(
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
              const SizedBox(width: 10),
              Expanded(
                child: Text(
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
class _RuleCard extends StatefulWidget {
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
      final package = trigger.packageName ?? 'cualquier app';
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

  static String _ddmmy(DateTime t) =>
      '${t.day}/${t.month} ${_hhmm(t)}';

  @override
  State<_RuleCard> createState() => _RuleCardState();
}

class _RuleCardState extends State<_RuleCard> {
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
    final actionDetail = rule.action == RuleAction.reply && !rule.dynamicReply
        ? (rule.message.isEmpty
              ? 'sin texto (fail-closed)'
              : '"${rule.message}"')
        : rule.dynamicReply
        ? 'respuesta dinámica (LLM local)'
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
                          children: [
                            Container(
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
                                style: TextStyle(
                                  color: outcomeColor,
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                lastFired == null
                                    ? 'nunca disparó'
                                    : 'última ${_RuleCard._hhmm(lastFired)}',
                                style: TextStyle(
                                  color: visual.textMuted,
                                  fontSize: 11,
                                ),
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
            _DetailRow(
              label: 'Acción',
              value: rule.action.label,
            ),
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
              value: '$outcomeLabel · '
                  '${lastFired == null ? 'nunca disparó' : _RuleCard._ddmmy(lastFired)}',
            ),
            _DetailRow(label: 'Creada', value: _RuleCard._ddmmy(rule.createdAt)),
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
              style: TextStyle(
                color: visual.text,
                fontSize: 12,
                height: 1.35,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title, required this.icon});

  final String title;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final visual = AutomationVisual.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 14, 4, 8),
      child: Row(
        children: [
          Icon(icon, color: visual.accent, size: 16),
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

