part of 'business_import_wizard_dialog.dart';

// Construye el flujo visible; el desplazamiento evita overflow en horizontal.
extension _BusinessImportWizardContent on _BusinessImportWizardDialogState {
  Widget _buildContent(BuildContext context) {
    final visual = AutomationVisual.of(context);
    final columns = widget.table.columns;
    return DialogContainerShell(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(18),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildHeader(visual),
            const SizedBox(height: 12),
            if (_currentStep == 0)
              ..._buildMappingStep(visual, columns)
            else if (_report != null)
              ..._buildImportStep(visual),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(AutomationVisualPalette visual) => Row(
    children: [
      Icon(Icons.auto_fix_high_rounded, color: visual.accent, size: 22),
      const SizedBox(width: 8),
      Expanded(
        child: Text(
          _currentStep == 0
              ? 'Paso 1 de 2: Asignar columnas'
              : 'Paso 2 de 2: Validar e importar',
          style: TextStyle(
            color: visual.text,
            fontWeight: FontWeight.bold,
            fontSize: 15,
          ),
        ),
      ),
      Semantics(
        label: 'Cerrar importación',
        button: true,
        child: IconButton(
          icon: const Icon(Icons.close_rounded, size: 18),
          onPressed: _saving ? null : () => Navigator.of(context).pop(),
        ),
      ),
    ],
  );

  List<Widget> _buildMappingStep(
    AutomationVisualPalette visual,
    List<String> columns,
  ) => [
    _buildDropdown('Nombre / Artículo *', _mapping.nameColumn, columns, (v) {
      setState(() => _mapping = _mapping.copyWith(nameColumn: v));
    }),
    _buildDropdown('Precio / Valor *', _mapping.priceColumn, columns, (v) {
      setState(() => _mapping = _mapping.copyWith(priceColumn: v));
    }),
    _buildDropdown('Existencias / Stock', _mapping.stockColumn, columns, (v) {
      setState(() => _mapping = _mapping.copyWith(stockColumn: v));
    }),
    _buildDropdown('Categoría (opcional)', _mapping.categoryColumn, columns, (
      v,
    ) {
      setState(() => _mapping = _mapping.copyWith(categoryColumn: v));
    }),
    _buildDropdown(
      'Código / Referencia (opcional)',
      _mapping.skuColumn,
      columns,
      (v) {
        setState(() => _mapping = _mapping.copyWith(skuColumn: v));
      },
    ),
    _buildDropdown(
      'Descripción / Detalles (opcional)',
      _mapping.detailsColumn,
      columns,
      (v) => setState(() => _mapping = _mapping.copyWith(detailsColumn: v)),
    ),
    const SizedBox(height: 12),
    FilledButton(
      onPressed: _mapping.isValid ? _runValidation : null,
      style: FilledButton.styleFrom(
        backgroundColor: visual.accent,
        foregroundColor: Colors.black,
      ),
      child: const Text('Continuar a validación'),
    ),
  ];

  List<Widget> _buildImportStep(AutomationVisualPalette visual) => [
    _buildMetricCard(visual),
    const SizedBox(height: 10),
    SwitchListTile(
      value: _replaceExisting,
      onChanged: _saving
          ? null
          : (value) => setState(() => _replaceExisting = value),
      title: const Text(
        'Reemplazar catálogo completo',
        style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
      ),
      subtitle: const Text(
        'Desactivado fusiona productos y conserva ediciones manuales.',
        style: TextStyle(fontSize: 11),
      ),
      contentPadding: EdgeInsets.zero,
    ),
    const SizedBox(height: 12),
    Row(
      children: [
        Expanded(
          child: OutlinedButton(
            onPressed: _saving ? null : () => setState(() => _currentStep = 0),
            child: const Text('Atrás'),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: FilledButton(
            onPressed: _report!.hasValidData && !_saving ? _commit : null,
            style: FilledButton.styleFrom(
              backgroundColor: visual.accent,
              foregroundColor: Colors.black,
            ),
            child: _saving
                ? const SizedBox.square(
                    dimension: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Guardar y activar'),
          ),
        ),
      ],
    ),
  ];
}
