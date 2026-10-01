part of 'business_import_wizard_dialog.dart';

// Mantiene campos y métricas separados de la coordinación del importador.
extension _BusinessImportWizardFields on _BusinessImportWizardDialogState {
  Widget _buildDropdown(
    String label,
    String? current,
    List<String> items,
    ValueChanged<String?> onChanged,
  ) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: DropdownButtonFormField<String>(
        initialValue: items.contains(current) ? current : null,
        isExpanded: true,
        items: [
          const DropdownMenuItem(
            value: null,
            child: Text('(Ninguno)', style: TextStyle(fontSize: 12)),
          ),
          ...items.map(
            (column) => DropdownMenuItem(
              value: column,
              child: Text(
                column,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 12),
              ),
            ),
          ),
        ],
        onChanged: _saving ? null : onChanged,
        decoration: InputDecoration(
          labelText: label,
          isDense: true,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 12,
            vertical: 8,
          ),
        ),
      ),
    );
  }

  Widget _buildMetricCard(AutomationVisualPalette visual) {
    final report = _report!;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: visual.accentSoft,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Resumen de validación',
            style: TextStyle(
              color: visual.text,
              fontWeight: FontWeight.bold,
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            '• Productos válidos: ${report.validCount} de ${report.totalRows}',
            style: const TextStyle(fontSize: 12),
          ),
          if (report.duplicateCount > 0)
            Text(
              '• Duplicados omitidos: ${report.duplicateCount}',
              style: const TextStyle(fontSize: 12, color: Colors.amber),
            ),
          if (report.invalidCount > 0)
            Text(
              '• Filas inválidas: ${report.invalidCount}',
              style: const TextStyle(fontSize: 12, color: Colors.orangeAccent),
            ),
        ],
      ),
    );
  }
}
