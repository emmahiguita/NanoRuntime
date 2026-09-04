import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nanoai/core/providers/settings_provider.dart';
import 'package:nanoai/core/theme/design_tokens.dart';
import 'package:nanoai/features/automation/application/automation_coordinator_provider.dart';
import 'package:nanoai/features/automation/application/rule_creator.dart';
import 'package:nanoai/features/automation/engine/scheduling/scheduled_rule.dart';
import 'package:nanoai/features/automation/engine/scheduling/trigger.dart';
import 'package:nanoai/features/automation/engine/scheduling/trigger_parser.dart';

import '../automation_layout.dart';
import '../automation_visual_theme.dart';

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

  /// RULES-CREATE-01: verbos de acción del lenguaje natural de la regla.
  /// Se limpian del mensaje (quedan en la acción, no en el texto).
  static final _replyVerbs = RegExp(
    r'^(respóndele|respondele|responde|responder|contéstale|contestale|contesta|contestar)\s*',
    caseSensitive: false,
  );
  static final _notifyVerbs = RegExp(
    r'^(avísame|avisame|avísar|avisar|notifícame|notificame|notificar)\s*',
    caseSensitive: false,
  );

  @override
  void dispose() {
    _createController.dispose();
    super.dispose();
  }

  /// RULES-CREATE-01 — crea una regla desde lenguaje natural con el MISMO
  /// TriggerParser del pipeline. Acción por verbo (responder → reply,
  /// resto → notify); reply con trigger de hora se rechaza honesto (un tick
  /// no trae remitente) y reply sin texto queda como respuesta dinámica.
  void _createRule() {
    final text = _createController.text.trim();
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
    } else {
      action = RuleAction.notify;
      message = goal.replaceFirst(_notifyVerbs, '').trim();
    }
    if (parsed.trigger is TimeTrigger && action == RuleAction.reply) {
      setState(
        () => _createError =
            'Responder necesita un remitente: usa un trigger de notificación '
            '(«cuando Juan me escriba, respóndele X»). Con hora solo puedo '
            'avisarte.',
      );
      return;
    }
    final rule = ref
        .read(ruleCreatorProvider)
        .create(
          trigger: parsed.trigger,
          action: action,
          message: message,
          dynamicReply: dynamicReply,
        );
    setState(() {
      _rules = ref.read(ruleRegistryProvider).rules;
      _createError = null;
    });
    _createController.clear();
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('Regla creada: ${rule.id}')));
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
            body: Stack(
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
                                      onCreate: _createRule,
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
                                    else
                                      for (final rule in _rules) ...[
                                        _RuleCard(
                                          rule: rule,
                                          onToggle: (v) => _toggle(rule, v),
                                          onDelete: () => _confirmDelete(rule),
                                        ),
                                        const SizedBox(height: 12),
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
    required this.onCreate,
  });

  final TextEditingController controller;
  final String? error;
  final VoidCallback onCreate;

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

class _RuleCard extends StatelessWidget {
  const _RuleCard({
    required this.rule,
    required this.onToggle,
    required this.onDelete,
  });

  final ScheduledRule rule;
  final ValueChanged<bool> onToggle;
  final VoidCallback onDelete;

  static String _actionLabel(RuleAction action) => switch (action) {
    RuleAction.reply => 'Responder',
    RuleAction.notify => 'Avisar',
    RuleAction.draft => 'Borrador',
  };

  static String _triggerLabel(Trigger trigger) {
    if (trigger is NotificationTrigger) {
      final package = trigger.packageName ?? 'cualquier app';
      final sender = trigger.senderMatch;
      if (sender == null || sender.isEmpty) return package;
      return '$package · contacto "$sender"';
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

  static String _hhmm(DateTime t) {
    final h = t.hour.toString().padLeft(2, '0');
    final m = t.minute.toString().padLeft(2, '0');
    return '$h:$m';
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
        : null;
    final lastFired = rule.lastFiredAt;
    return AutomationSurfaceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
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
                  Icons.rule_rounded,
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
                      '${_actionLabel(rule.action)} · ${_triggerLabel(rule.trigger)}',
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
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: visual.textMuted,
                          fontSize: 12,
                          height: 1.35,
                        ),
                      ),
                    const SizedBox(height: 4),
                    Text(
                      [
                        rule.id,
                        'creada ${_hhmm(rule.createdAt)}',
                        if (lastFired != null) 'última ${_hhmm(lastFired)}',
                      ].join(' · '),
                      style: TextStyle(color: visual.textMuted, fontSize: 11),
                    ),
                  ],
                ),
              ),
              Switch(value: rule.enabled, onChanged: onToggle),
            ],
          ),
          const SizedBox(height: 4),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              onPressed: onDelete,
              icon: const Icon(Icons.delete_outline_rounded, size: 17),
              label: const Text('Borrar'),
              style: TextButton.styleFrom(foregroundColor: danger),
            ),
          ),
        ],
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
