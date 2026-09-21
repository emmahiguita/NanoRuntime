part of 'personalization_studio_screen.dart';

/// PERSONALIZATION-STUDIO-EXAMPLE-DIALOG — Editor de Frase Aprendida con Variantes.
///
/// **QUÉ HACE:**
/// Permite editar o crear una frase recibida con sus variantes equivalentes de entrada
/// y su conjunto de respuestas posibles con selector de estado y tono.
///
/// **CÓMO FUNCIONA:**
/// Presenta listas dinámicas de variantes y respuestas en scroll responsivo,
/// validando que al menos exista una respuesta antes de guardar en SQLite.
///
/// **POR QUÉ:**
/// Materializa la visión de aprendizaje por intenciones y múltiples respuestas humanas (< 200 líneas).
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

  @override
  void initState() {
    super.initState();
    final ex = widget.example;
    _scope = widget.initialScope;
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
    final title = widget.example != null ? widget.example!.displayTrigger : 'Nueva Frase / Intención';

    return AlertDialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 18),
      titlePadding: const EdgeInsets.fromLTRB(16, 12, 16, 6),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16),
      actionsPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      title: Row(
        children: [
          const Icon(Icons.forum_outlined, size: 15, color: Color(0xFF00E676)),
          const SizedBox(width: 8),
          Expanded(child: Text(title, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold), overflow: TextOverflow.ellipsis)),
        ],
      ),
      content: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: size.height * 0.72, maxWidth: 480),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              _label('TEXTO / INTENCIÓN RECIBIDA'),
              TextField(controller: _triggerCtrl, style: const TextStyle(fontSize: 11.5), decoration: _dec('Ej: ¿Qué haces?, ¿Cómo estás?')),
              const SizedBox(height: 8),
              Row(
                children: [
                  _label('VARIANTES EQUIVALENTES'),
                  const Spacer(),
                  InkWell(onTap: () => setState(() => _inVarCtrls.add(TextEditingController())), child: const Text('+ Variante', style: TextStyle(fontSize: 10, color: Color(0xFF00D2FF), fontWeight: FontWeight.bold))),
                ],
              ),
              for (int i = 0; i < _inVarCtrls.length; i++)
                Padding(
                  padding: const EdgeInsets.only(bottom: 3),
                  child: Row(
                    children: [
                      Expanded(child: TextField(controller: _inVarCtrls[i], style: const TextStyle(fontSize: 10.5), decoration: _dec('Variante #${i + 1}'))),
                      if (_inVarCtrls.length > 1)
                        IconButton(icon: const Icon(Icons.close, size: 13, color: Colors.white54), onPressed: () => setState(() => _inVarCtrls.removeAt(i).dispose()), padding: EdgeInsets.zero, constraints: const BoxConstraints(minWidth: 20, minHeight: 20)),
                    ],
                  ),
                ),
              const SizedBox(height: 10),
              Row(
                children: [
                  _label('RESPUESTAS POSIBLES'),
                  const Spacer(),
                  InkWell(onTap: () => setState(() { _respCtrls.add(TextEditingController()); _respTones.add('cotidiana'); _respActives.add(true); }), child: const Text('+ Respuesta', style: TextStyle(fontSize: 10, color: Color(0xFF00E676), fontWeight: FontWeight.bold))),
                ],
              ),
              for (int i = 0; i < _respCtrls.length; i++) _respItem(i),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar', style: TextStyle(fontSize: 11.5))),
        FilledButton(
          onPressed: widget.busy ? null : _save,
          style: FilledButton.styleFrom(backgroundColor: const Color(0xFF00E676), foregroundColor: Colors.black),
          child: const Text('Guardar frase', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold)),
        ),
      ],
    );
  }

  Widget _respItem(int i) {
    return Container(
      margin: const EdgeInsets.only(bottom: 4),
      padding: const EdgeInsets.all(5),
      decoration: BoxDecoration(color: const Color(0x0EFFFFFF), borderRadius: BorderRadius.circular(7), border: Border.all(color: const Color(0x22FFFFFF), width: 0.6)),
      child: Column(
        children: [
          Row(
            children: [
              Text('#${i + 1}', style: const TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Color(0xFF00E676))),
              const Spacer(),
              InkWell(onTap: () => setState(() => _respActives[i] = !_respActives[i]), child: Text(_respActives[i] ? 'Activo ✓' : 'Inactivo', style: TextStyle(fontSize: 8.5, fontWeight: FontWeight.bold, color: _respActives[i] ? const Color(0xFF00E676) : Colors.white38))),
              if (_respCtrls.length > 1) ...[
                const SizedBox(width: 5),
                InkWell(onTap: () => setState(() { _respCtrls.removeAt(i).dispose(); _respTones.removeAt(i); _respActives.removeAt(i); }), child: const Icon(Icons.delete_outline, size: 12, color: Colors.redAccent)),
              ],
            ],
          ),
          const SizedBox(height: 2),
          TextField(controller: _respCtrls[i], maxLines: 2, minLines: 1, style: const TextStyle(fontSize: 10.5), decoration: _dec('Respuesta posible #${i + 1}')),
        ],
      ),
    );
  }

  Widget _label(String t) => Text(t, style: const TextStyle(fontSize: 8.5, fontWeight: FontWeight.bold, letterSpacing: 0.3, color: Colors.white70));

  InputDecoration _dec(String h) => InputDecoration(
    hintText: h,
    hintStyle: const TextStyle(fontSize: 9.5, color: Colors.white24),
    filled: true,
    fillColor: const Color(0x0BFFFFFF),
    isDense: true,
    contentPadding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
    border: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: const BorderSide(color: Color(0x22FFFFFF), width: 0.7)),
    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: const BorderSide(color: Color(0x22FFFFFF), width: 0.7)),
    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: const BorderSide(color: Color(0x8000E676), width: 0.7)),
  );

  void _save() {
    final trigger = _triggerCtrl.text.trim();
    final inVars = _inVarCtrls.map((c) => c.text.trim()).where((t) => t.isNotEmpty).toList();
    final responses = <PersonaResponseOption>[];
    for (int i = 0; i < _respCtrls.length; i++) {
      final t = _respCtrls[i].text.trim();
      if (t.isNotEmpty) responses.add(PersonaResponseOption(text: t, enabled: _respActives[i], tone: _respTones[i]));
    }
    if (responses.isEmpty) return;

    Navigator.pop(context, _ExampleResult(
      scope: _scope,
      input: trigger.isNotEmpty ? trigger : (inVars.isNotEmpty ? inVars.first : ''),
      body: responses.first.text,
      verified: true,
      enabled: true,
      isTemplate: widget.isTemplate,
      title: widget.example?.categoryTitle ?? 'Cotidiano · conversación',
      category: widget.example?.category ?? 'Cotidiano · conversación',
      intent: widget.example?.intent ?? 'custom_intent',
      incomingVariants: inVars,
      variants: responses.map((r) => r.text).toList(),
      responses: responses,
    ));
  }
}
