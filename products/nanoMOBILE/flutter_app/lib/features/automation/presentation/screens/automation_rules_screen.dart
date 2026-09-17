import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nanoai/core/providers/settings_provider.dart';
import 'package:nanoai/core/theme/design_tokens.dart';
import 'package:nanoai/core/theme/nano_type.dart';
import 'package:nanoai/features/automation/application/automation_coordinator_provider.dart';
import 'package:nanoai/features/automation/application/rule_creator.dart';
import 'package:nanoai/features/automation/engine/messaging/messaging_package.dart';
import 'package:nanoai/features/automation/engine/platform/whatsapp_media_share.dart';
import 'package:nanoai/features/automation/engine/scheduling/scheduled_rule.dart';
import 'package:nanoai/features/automation/engine/scheduling/trigger.dart';
import 'package:nanoai/features/automation/engine/scheduling/trigger_parser.dart';

import 'package:nanoai/core/widgets/navigation/nano_navigation_panel.dart';
import 'package:nanoai/core/widgets/navigation/nano_universal_input.dart';

import '../automation_layout.dart';
import '../automation_visual_theme.dart';
import '../widgets/rule_edit_sheet.dart';

part 'automation_rules_components.dart';

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
  /// FIX-VERT-01 — el texto puede llegar con saltos de línea por palabra
  /// (barra multiline Enter, pegado, dictado): se colapsan a espacios para
  /// que la regla guarde un mensaje de una línea.
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
        // NAV-UI-AUDIT-01 — guard mounted tras el await de la copia.
        if (!mounted) return;
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
      sections.add(
        const _SectionHeader(
          title: 'WhatsApp',
          imageAsset: 'assets/automation/icons/icon_respuestas_wpp.png',
        ),
      );
      // Agrupado por contacto dentro de WhatsApp (null → cualquier contacto).
      final byContact = <String, List<ScheduledRule>>{};
      for (final rule in whatsapp) {
        final trigger = rule.trigger as NotificationTrigger;
        final contact = trigger.senderMatch?.trim() ?? 'Cualquier contacto';
        byContact.putIfAbsent(contact, () => []).add(rule);
      }
      final contacts = byContact.keys.toList()..sort();
      for (final contact in contacts) {
        sections.add(_ContactLabel(contact: contact, visual: visual));
        sections.addAll(byContact[contact]!.map((rule) => _ruleCard(rule)));
      }
    }
    if (timed.isNotEmpty) {
      sections.add(
        const _SectionHeader(
          title: 'Horarios',
          imageAsset: 'assets/automation/icons/icon_horarios.png',
        ),
      );
      sections.addAll(timed.map((rule) => _ruleCard(rule)));
    }
    if (others.isNotEmpty) {
      sections.add(
        const _SectionHeader(
          title: 'Otras automatizaciones',
          imageAsset: 'assets/automation/icons/icon_reglas.png',
        ),
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
            backgroundColor: Colors.transparent,
            body: NanoShellBarScope(
              slotId: 'automation_rules',
              child: NanoInputScope(
                scopeId: 'automation_rules',
                hint: 'Crea una regla: «a las 8:30 avísame que es hora»...',
                onSubmit: (query) => _createRuleFromText(query),
                child: SafeArea(
                  child: Column(
                    children: [
                      const AutomationBackHeader(),
                      Expanded(
                        child: LayoutBuilder(
                          builder: (context, constraints) {
                            final isDeviceLandscape =
                                MediaQuery.orientationOf(context) ==
                                Orientation.landscape;
                            final isLandscape =
                                isDeviceLandscape &&
                                constraints.maxWidth >= 700;

                            final leftColumn = Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
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
                                  'Automatiza acciones cuando ocurran eventos.',
                                  style: TextStyle(
                                    color: visual.textMuted,
                                    fontSize: 13,
                                  ),
                                ),
                                const SizedBox(height: 16),
                                _RuleCreatorCard(
                                  controller: _createController,
                                  error: _createError,
                                  pendingMediaName: _pendingMediaName,
                                  onCreate: _createRule,
                                  onPickMedia: _pickMedia,
                                ),
                              ],
                            );

                            final rightColumn = Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                if (isLandscape) ...[
                                  Text(
                                    'REGLAS ACTIVAS',
                                    style: NanoType.label(
                                      visual.textMuted,
                                    ).copyWith(letterSpacing: 0.8),
                                  ),
                                  const SizedBox(height: 12),
                                ],
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
                            );

                            final content = isLandscape
                                ? Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Expanded(flex: 5, child: leftColumn),
                                      const SizedBox(width: 16),
                                      Expanded(flex: 6, child: rightColumn),
                                    ],
                                  )
                                : Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.stretch,
                                    children: [
                                      leftColumn,
                                      const SizedBox(height: 16),
                                      rightColumn,
                                    ],
                                  );

                            return ListView(
                              // NAV-FLOAT-01 — la barra flota sin reservar
                              // layout: el scroll reserva su propio espacio.
                              padding: const EdgeInsets.fromLTRB(
                                12,
                                8,
                                12,
                                kNanoBarScrollReserve,
                              ),
                              children: [
                                Center(
                                  child: ConstrainedBox(
                                    constraints: BoxConstraints(
                                      maxWidth: isLandscape
                                          ? (AutomationLayout.isCompactLandscape(
                                                  context,
                                                )
                                                ? 960
                                                : 1080)
                                          : AutomationLayout.contentMaxWidth(
                                              context,
                                            ),
                                    ),
                                    child: content,
                                  ),
                                ),
                              ],
                            );
                          },
                        ),
                      ),
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
