part of 'business_profile_edit_dialog.dart';

extension _BusinessProfileEditFields on _BusinessProfileEditDialogState {
  Widget _buildHeader(AutomationVisualPalette visual) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 12, 8, 8),
    child: Row(
      children: [
        Icon(Icons.schema_outlined, color: visual.accent),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Editar plantilla profesional',
                style: TextStyle(
                  color: visual.text,
                  fontWeight: FontWeight.w700,
                  fontSize: 16,
                ),
              ),
              Text(
                '${widget.initial.templateId} · revisión ${widget.initial.revision}',
                style: TextStyle(color: visual.textMuted, fontSize: 11),
              ),
            ],
          ),
        ),
        IconButton(
          tooltip: 'Cerrar',
          onPressed: () => Navigator.of(context).pop(),
          icon: const Icon(Icons.close_rounded),
        ),
      ],
    ),
  );

  Widget _buildFields(AutomationVisualPalette visual) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      _readonly('Sector', widget.initial.sector, visual),
      Row(
        children: [
          Expanded(child: _field('Idioma', _locale)),
          const SizedBox(width: 8),
          Expanded(child: _field('Moneda', _currency)),
        ],
      ),
      _field('Zona horaria', _timezone),
      _field('Intenciones, separadas por coma', _intents, maxLines: 3),
      _field('Herramientas declaradas', _tools, maxLines: 3),
      SwitchListTile.adaptive(
        contentPadding: EdgeInsets.zero,
        value: _autoReply,
        title: const Text('Permitir respuesta automática'),
        subtitle: const Text(
          'Si se desactiva, Nano prepara el borrador y solicita revisión humana.',
        ),
        onChanged: (value) => setState(() => _autoReply = value),
      ),
      _field('Automatizaciones bloqueadas', _blocked, maxLines: 2),
      _field('FAQ: patrones separados por ; => respuesta', _faq, maxLines: 5),
      _field('Flujos: id | INTENT | slots | pasos', _dialogues, maxLines: 5),
      _field(
        'Reglas: id | condición | acción | prioridad',
        _rules,
        maxLines: 4,
      ),
      _field('Mensaje de entrega a humano', _handoff, maxLines: 2),
      Row(
        children: [
          Expanded(
            child: _field('Confianza mínima', _confidence, number: true),
          ),
          const SizedBox(width: 8),
          Expanded(child: _field('Máx. pasos', _maxSteps, number: true)),
        ],
      ),
      _field('Aprobación humana desde monto', _approval, number: true),
      if (_error.isNotEmpty)
        Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Text(
            _error,
            style: TextStyle(
              color: Theme.of(context).colorScheme.error,
              fontSize: 12,
            ),
          ),
        ),
    ],
  );

  Widget _field(
    String label,
    TextEditingController controller, {
    int maxLines = 1,
    bool number = false,
  }) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: TextField(
      controller: controller,
      maxLines: maxLines,
      keyboardType: number
          ? const TextInputType.numberWithOptions(decimal: true)
          : TextInputType.text,
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
        isDense: true,
      ),
    ),
  );

  Widget _readonly(
    String label,
    String value,
    AutomationVisualPalette visual,
  ) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: InputDecorator(
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
        isDense: true,
      ),
      child: Text(value, style: TextStyle(color: visual.text)),
    ),
  );
}
