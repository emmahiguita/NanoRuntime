part of 'personalization_studio_screen.dart';

// personalization_studio_example_dialog.dart
//
// QUÉ HACE:
// Diálogo de edición de frases aprendidas, variantes equivalentes y respuestas múltiples.
//
// CÓMO FUNCIONA:
// - Detecta orientación landscape/portrait para ajustar márgenes y paddings dinámicos.
// - Presenta campos compactos con Material Expressive (fondos translúcidos y acentos cromáticos).
// - Scroll vertical seguro con ConstrainedBox para garantizar cero RenderFlex overflows con teclado.
//
// POR QUÉ:
// Asegura que las intenciones y respuestas sean editables cómodamente en móviles apaisados (< 200 líneas).

class _ExampleEditDialog extends StatefulWidget {
  final PersonaExample? example;
  final bool isTemplate;
  final String initialScope;
  final Map<String, _Scope> scopes;
  final bool busy;

  const _ExampleEditDialog({
    this.example,
    this.isTemplate = false,
    required this.initialScope,
    required this.scopes,
    this.busy = false,
  });

  @override
  State<_ExampleEditDialog> createState() => _ExampleEditDialogState();
}

class _ExampleEditDialogState extends State<_ExampleEditDialog> {
  late final TextEditingController _triggerCtrl;
  late final List<TextEditingController> _inVarCtrls, _respCtrls;
  late final List<String> _respTones;
  late final List<bool> _respActives;
  late String _scope;
  late ConversationSemanticTag _semanticTag;

  @override
  void initState() {
    super.initState();
    final ex = widget.example;
    _scope = widget.initialScope;
    _semanticTag = ex == null
        ? ConversationSemanticTag.conversation
        : ConversationSemanticTag.fromStorageKey(ex.intent);
    _triggerCtrl = TextEditingController(text: ex?.displayTrigger ?? '');
    final inVars = ex?.incomingVariants ?? [];
    _inVarCtrls = inVars.isEmpty ? [TextEditingController(text: ex?.incomingText ?? '')] : inVars.map((v) => TextEditingController(text: v)).toList();
    final opts = ex?.responseOptions ?? [];
    if (opts.isNotEmpty) {
      _respCtrls = opts.map((o) => TextEditingController(text: o.text)).toList();
      _respTones = opts.map((o) => o.tone).toList();
      _respActives = opts.map((o) => o.enabled).toList();
    } else {
      final vars = ex?.variants ?? [];
      final list = vars.isNotEmpty ? vars : [''];
      _respCtrls = list.map((v) => TextEditingController(text: v)).toList();
      _respTones = List.filled(list.length, 'cotidiana');
      _respActives = List.filled(list.length, true);
    }
  }

  @override
  void dispose() {
    _triggerCtrl.dispose();
    for (final c in _inVarCtrls) { c.dispose(); }
    for (final c in _respCtrls) { c.dispose(); }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final isLandscape = size.width > size.height;
    final title = widget.example != null ? widget.example!.displayTrigger : 'Nueva Frase / Intención';

    return AlertDialog(
      insetPadding: EdgeInsets.symmetric(horizontal: 14, vertical: isLandscape ? 6 : 16),
      titlePadding: EdgeInsets.fromLTRB(16, isLandscape ? 8 : 12, 16, isLandscape ? 4 : 6),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16),
      actionsPadding: EdgeInsets.symmetric(horizontal: 12, vertical: isLandscape ? 4 : 8),
      title: Row(
        children: [
          const Icon(Icons.forum_outlined, size: 15, color: Color(0xFF00E676)),
          const SizedBox(width: 8),
          Expanded(child: Text(title, style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold), overflow: TextOverflow.ellipsis)),
        ],
      ),
      content: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: size.height * (isLandscape ? 0.76 : 0.70), maxWidth: isLandscape ? 520 : 460),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              _label('TEXTO / INTENCIÓN RECIBIDA'),
              TextField(controller: _triggerCtrl, style: const TextStyle(fontSize: 11), decoration: _dec('Ej: ¿Qué haces?, ¿Cómo estás?')),
              const SizedBox(height: 6),
              DropdownButtonFormField<ConversationSemanticTag>(
                initialValue: _semanticTag,
                isExpanded: true,
                decoration: _dec('Etiqueta del diálogo'),
                dropdownColor: const Color(0xFF162036),
                style: const TextStyle(fontSize: 10.5, color: Colors.white),
                items: [
                  for (final tag in ConversationSemanticTag.values)
                    DropdownMenuItem(value: tag, child: Text(tag.label)),
                ],
                onChanged: (tag) {
                  if (tag != null) setState(() => _semanticTag = tag);
                },
              ),
              const SizedBox(height: 7),
              Row(
                children: [
                  _label('VARIANTES EQUIVALENTES'),
                  const Spacer(),
                  InkWell(onTap: () => setState(() => _inVarCtrls.add(TextEditingController())), child: const Text('+ Variante', style: TextStyle(fontSize: 9.5, color: Color(0xFF00D2FF), fontWeight: FontWeight.bold))),
                ],
              ),
              for (int i = 0; i < _inVarCtrls.length; i++)
                Padding(
                  padding: const EdgeInsets.only(bottom: 2.5),
                  child: Row(
                    children: [
                      Expanded(child: TextField(controller: _inVarCtrls[i], style: const TextStyle(fontSize: 10), decoration: _dec('Variante #${i + 1}'))),
                      if (_inVarCtrls.length > 1)
                        IconButton(icon: const Icon(Icons.close, size: 12, color: Colors.white54), onPressed: () => setState(() => _inVarCtrls.removeAt(i).dispose()), padding: EdgeInsets.zero, constraints: const BoxConstraints(minWidth: 18, minHeight: 18)),
                    ],
                  ),
                ),
              const SizedBox(height: 8),
              Row(
                children: [
                  _label('RESPUESTAS POSIBLES'),
                  const Spacer(),
                  InkWell(onTap: () => setState(() { _respCtrls.add(TextEditingController()); _respTones.add('cotidiana'); _respActives.add(true); }), child: const Text('+ Respuesta', style: TextStyle(fontSize: 9.5, color: Color(0xFF00E676), fontWeight: FontWeight.bold))),
                ],
              ),
              for (int i = 0; i < _respCtrls.length; i++) _respItem(i),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar', style: TextStyle(fontSize: 11))),
        FilledButton(
          onPressed: widget.busy ? null : _save,
          style: FilledButton.styleFrom(backgroundColor: const Color(0xFF00E676), foregroundColor: Colors.black, padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6)),
          child: const Text('Guardar frase', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
        ),
      ],
    );
  }

  void _save() {
    final trigger = _triggerCtrl.text.trim();
    final inVars = _inVarCtrls.map((c) => c.text.trim()).where((t) => t.isNotEmpty).toList();
    final responses = <PersonaResponseOption>[];
    for (int i = 0; i < _respCtrls.length; i++) {
      final t = _respCtrls[i].text.trim();
      if (t.isNotEmpty) responses.add(PersonaResponseOption(text: t, enabled: _respActives[i], tone: _respTones[i]));
    }
    if (responses.isEmpty) return;

    final semantic = _semanticTag == ConversationSemanticTag.conversation
        ? ConversationSemanticClassifier.classify(trigger)
        : _semanticTag;

    Navigator.pop(context, _ExampleResult(
      scope: _scope,
      input: trigger.isNotEmpty ? trigger : (inVars.isNotEmpty ? inVars.first : ''),
      body: responses.first.text,
      verified: true,
      enabled: true,
      isTemplate: widget.isTemplate,
      title: semantic.label,
      category: semantic.label,
      intent: semantic.storageKey,
      incomingVariants: inVars,
      variants: responses.map((r) => r.text).toList(),
      responses: responses,
    ));
  }
}
