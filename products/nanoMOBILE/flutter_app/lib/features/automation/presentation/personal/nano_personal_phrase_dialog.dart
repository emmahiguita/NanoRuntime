// nano_personal_phrase_dialog.dart
// QUÉ HACE: Diálogo para crear/editar diálogos conversacionales con variantes en Nano Personal.
// CÓMO FUNCIONA: Gestiona disparador, variantes sintácticas y opciones de respuesta con selector blindado de tono.
// POR QUÉ: Previene la excepción "DropdownButton: There should be exactly one item with value: tranquilo" asegurando
// que cualquier tono existente esté siempre en el set de opciones sin duplicarse y manteniendo <= 200 líneas.
library;

import 'dart:convert';
import 'package:flutter/material.dart';
import '../../personal_agent/domain/persona_example.dart';
import '../automation_visual_theme.dart';

class NanoPersonalPhraseDialog extends StatefulWidget {
  final PersonaExample? existing;
  const NanoPersonalPhraseDialog({super.key, this.existing});

  static Future<PersonaExample?> show(BuildContext context, [PersonaExample? existing]) =>
      showDialog<PersonaExample>(
        context: context,
        useRootNavigator: true,
        builder: (_) => NanoPersonalPhraseDialog(existing: existing),
      );

  @override
  State<NanoPersonalPhraseDialog> createState() => _NanoPersonalPhraseDialogState();
}

class _NanoPersonalPhraseDialogState extends State<NanoPersonalPhraseDialog> {
  static const _presetTags = ['Saludos', 'Cotidiano', 'Reencuentro', 'Disponibilidad', 'Planes', 'Opinión', 'Despedidas', 'Cierre'];
  late final TextEditingController _triggerCtrl, _inVariantsCtrl;
  late String _selectedTag;
  final List<TextEditingController> _respCtrls = [];
  final List<String> _respTones = [];

  List<String> get _availableTags => <String>{..._presetTags, _selectedTag}.toList();

  @override
  void initState() {
    super.initState();
    final ex = widget.existing;
    _selectedTag = ex?.category.split('·').first.trim() ?? 'Saludos';
    _triggerCtrl = TextEditingController(text: ex?.displayTrigger ?? '');
    final inVars = ex?.incomingVariants.where((v) => v != ex.displayTrigger).toList() ?? [];
    _inVariantsCtrl = TextEditingController(text: inVars.join(', '));
    final opts = ex?.responseOptions ?? [];
    if (opts.isNotEmpty) {
      for (final o in opts) {
        _respCtrls.add(TextEditingController(text: o.text));
        _respTones.add(o.tone.trim().isNotEmpty ? o.tone.trim() : 'cotidiana');
      }
    } else {
      _respCtrls.add(TextEditingController(text: ex?.body ?? ''));
      _respTones.add('cotidiana');
    }
  }

  @override
  void dispose() {
    _triggerCtrl.dispose();
    _inVariantsCtrl.dispose();
    for (final c in _respCtrls) { c.dispose(); }
    super.dispose();
  }

  void _addOption() => setState(() { _respCtrls.add(TextEditingController()); _respTones.add('cotidiana'); });
  void _removeOption(int i) {
    if (_respCtrls.length <= 1) return;
    setState(() { _respCtrls.removeAt(i).dispose(); _respTones.removeAt(i); });
  }

  void _save() {
    final trigger = _triggerCtrl.text.trim();
    final responses = <PersonaResponseOption>[];
    for (int i = 0; i < _respCtrls.length; i++) {
      final t = _respCtrls[i].text.trim();
      if (t.isNotEmpty) responses.add(PersonaResponseOption(text: t, tone: _respTones[i]));
    }
    if (trigger.isEmpty || responses.isEmpty) return;

    final inVars = _inVariantsCtrl.text.split(',').map((s) => s.trim()).where((s) => s.isNotEmpty && s != trigger).toList();
    final tone = {
      ...?widget.existing?.tone,
      'enabled': widget.existing?.tone['enabled'] ?? 'true',
      'kind': 'phrase',
      'category': _selectedTag,
      'incomingVariants': jsonEncode([trigger, ...inVars]),
      'variants': jsonEncode(responses.map((r) => r.text).toList()),
      'responses': jsonEncode(responses.map((r) => r.toMap()).toList()),
    };

    Navigator.of(context).pop(PersonaExample(
      id: widget.existing?.id ?? DateTime.now().millisecondsSinceEpoch % 1000000,
      personaKey: widget.existing?.personaKey ?? 'owner',
      incomingText: trigger,
      body: responses.first.text,
      source: widget.existing?.source ?? 'manual',
      tone: tone,
    ));
  }

  @override
  Widget build(BuildContext context) {
    final visual = AutomationVisual.of(context);
    final isEdit = widget.existing != null;

    return AlertDialog(
      backgroundColor: const Color(0xFF131B2E),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18), side: BorderSide(color: visual.accent.withValues(alpha: 0.3))),
      titlePadding: const EdgeInsets.fromLTRB(18, 14, 18, 6),
      contentPadding: const EdgeInsets.symmetric(horizontal: 18),
      actionsPadding: const EdgeInsets.fromLTRB(14, 6, 14, 12),
      title: Row(children: [
        Icon(Icons.auto_awesome_rounded, color: visual.accent, size: 18),
        const SizedBox(width: 8),
        Expanded(child: Text(isEdit ? 'Editar Diálogo' : 'Nuevo Diálogo Conversacional', style: TextStyle(color: visual.text, fontSize: 14, fontWeight: FontWeight.bold))),
      ]),
      content: SizedBox(
        width: 460,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              _label('TEMA / ETIQUETA'),
              Wrap(spacing: 5, children: _availableTags.map((t) => ChoiceChip(
                label: Text(t, style: TextStyle(fontSize: 9.5, fontWeight: _selectedTag == t ? FontWeight.bold : FontWeight.normal)),
                selected: _selectedTag == t,
                selectedColor: visual.accent.withValues(alpha: 0.25),
                onSelected: (v) => setState(() => _selectedTag = t),
              )).toList()),
              const SizedBox(height: 8),
              _label('MENSAJE ENTRANTE (¿QUÉ TE ESCRIBEN?)'),
              TextField(controller: _triggerCtrl, style: TextStyle(color: visual.text, fontSize: 12), decoration: _dec('Ej: ¿Cómo estás? / Hola bro')),
              const SizedBox(height: 4),
              TextField(controller: _inVariantsCtrl, style: TextStyle(color: visual.text, fontSize: 10.5), decoration: _dec('Variantes parecidas (separadas por coma)')),
              const SizedBox(height: 10),
              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                _label('RESPUESTAS POSIBLES (${_respCtrls.length})'),
                InkWell(onTap: _addOption, child: Text('+ Opción', style: TextStyle(color: visual.accent, fontSize: 10.5, fontWeight: FontWeight.bold))),
              ]),
              for (int i = 0; i < _respCtrls.length; i++)
                Container(
                  margin: const EdgeInsets.only(bottom: 6),
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.04), borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.white12)),
                  child: Column(children: [
                    Row(children: [
                      Text('Opción #${i + 1}', style: TextStyle(color: visual.accent, fontSize: 9.5, fontWeight: FontWeight.bold)),
                      const Spacer(),
                      _toneSelector(i),
                      if (_respCtrls.length > 1)
                        InkWell(onTap: () => _removeOption(i), child: const Padding(padding: EdgeInsets.only(left: 6), child: Icon(Icons.close_rounded, size: 14, color: Colors.redAccent))),
                    ]),
                    const SizedBox(height: 2),
                    TextField(controller: _respCtrls[i], maxLines: 2, minLines: 1, style: TextStyle(color: visual.text, fontSize: 11), decoration: _dec('Cómo responderías tú...')),
                  ]),
                ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
        FilledButton.icon(
          onPressed: _save,
          icon: const Icon(Icons.check_rounded, size: 15),
          label: const Text('Guardar'),
          style: FilledButton.styleFrom(backgroundColor: visual.accent, foregroundColor: Colors.black),
        ),
      ],
    );
  }

  /// Selector de tono blindado contra fallos de aserción en DropdownButton
  Widget _toneSelector(int i) {
    final current = (_respTones.length > i && _respTones[i].trim().isNotEmpty) ? _respTones[i].trim() : 'cotidiana';
    final allTones = <String>{
      'cotidiana', 'amigable', 'cercano', 'tranquilo', 'ocupado',
      'relajado', 'profesional', 'servicial', 'cálido', 'directo',
      'precavido', 'prudente', current,
    }.toList();

    return DropdownButton<String>(
      value: current,
      isDense: true,
      dropdownColor: const Color(0xFF1E293B),
      underline: const SizedBox.shrink(),
      style: const TextStyle(fontSize: 9.5, color: Colors.white70),
      items: allTones.map((t) => DropdownMenuItem(value: t, child: Text(t, style: const TextStyle(fontSize: 9.5)))).toList(),
      onChanged: (v) { if (v != null) setState(() => _respTones[i] = v); },
    );
  }

  Widget _label(String t) => Padding(padding: const EdgeInsets.only(bottom: 2), child: Text(t, style: const TextStyle(fontSize: 8, fontWeight: FontWeight.bold, letterSpacing: 0.3, color: Colors.white60)));

  InputDecoration _dec(String h) => InputDecoration(hintText: h, hintStyle: const TextStyle(fontSize: 10, color: Colors.white30), filled: true, fillColor: Colors.white.withValues(alpha: 0.05), isDense: true, contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5), border: OutlineInputBorder(borderRadius: BorderRadius.circular(7), borderSide: const BorderSide(color: Colors.white12)), enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(7), borderSide: const BorderSide(color: Colors.white12)));
}
