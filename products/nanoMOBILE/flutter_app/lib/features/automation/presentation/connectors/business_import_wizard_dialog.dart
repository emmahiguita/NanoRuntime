import 'package:flutter/material.dart' hide DataTable;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../database/domain/data_models.dart';
import '../../engine/connectors/business_connector_models.dart';
import '../../engine/connectors/business_data_connector_service.dart';
import '../automation_visual_theme.dart';
import '../widgets/dialogs/dialog_container_shell.dart';

// business_import_wizard_dialog.dart
//
// QUÉ HACE:
// Asistente visual en 3 pasos para mapeo, validación estricta y activación
// de productos importados desde fuentes empresariales.
//
// CÓMO FUNCIONA:
// - Paso 1: Muestra correspondencias detectadas y permite reasignar columnas mediante dropdowns.
// - Paso 2: Ejecuta la validación y presenta métricas (filas válidas, duplicados, precios inválidos).
// - Paso 3: Permite elegir entre reemplazo total o fusión incremental, guardando de forma transaccional.
//
// POR QUÉ:
// Asegura una experiencia guiada, amigable y libre de errores en orientación vertical u horizontal (< 200 líneas).

class BusinessImportWizardDialog extends ConsumerStatefulWidget {
  final DataTable table;
  final BusinessSourceConfig config;

  const BusinessImportWizardDialog({super.key, required this.table, required this.config});

  @override
  ConsumerState<BusinessImportWizardDialog> createState() => _BusinessImportWizardDialogState();
}

class _BusinessImportWizardDialogState extends ConsumerState<BusinessImportWizardDialog> {
  int _currentStep = 0;
  late BusinessColumnMapping _mapping;
  BusinessValidationReport? _report;
  bool _replaceExisting = false;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final service = ref.read(businessDataConnectorServiceProvider);
    _mapping = service.proposeMapping(widget.table);
  }

  void _runValidation() {
    final service = ref.read(businessDataConnectorServiceProvider);
    final report = service.validate(table: widget.table, mapping: _mapping);
    setState(() {
      _report = report;
      _currentStep = 1;
    });
  }

  Future<void> _commit() async {
    if (_report == null || !_report!.hasValidData) return;
    setState(() => _saving = true);
    final service = ref.read(businessDataConnectorServiceProvider);
    final ok = await service.commitImport(report: _report!, replaceExisting: _replaceExisting);
    if (mounted) {
      setState(() => _saving = false);
      if (ok) {
        Navigator.of(context).pop(true);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('¡Se importaron ${_report!.validCount} productos con éxito!')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final visual = AutomationVisual.of(context);
    final columns = widget.table.columns;

    return DialogContainerShell(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(Icons.auto_fix_high_rounded, color: visual.accent, size: 22),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _currentStep == 0 ? 'Paso 1 de 2: Asignar Columnas' : 'Paso 2 de 2: Validar e Importar',
                    style: TextStyle(color: visual.text, fontWeight: FontWeight.bold, fontSize: 15),
                  ),
                ),
                IconButton(icon: const Icon(Icons.close_rounded, size: 18), onPressed: () => Navigator.of(context).pop()),
              ],
            ),
            const SizedBox(height: 12),
            if (_currentStep == 0) ...[
              _buildDropdown('Nombre / Artículo *', _mapping.nameColumn, columns, (v) => setState(() => _mapping = _mapping.copyWith(nameColumn: v))),
              _buildDropdown('Precio / Valor *', _mapping.priceColumn, columns, (v) => setState(() => _mapping = _mapping.copyWith(priceColumn: v))),
              _buildDropdown('Existencias / Stock', _mapping.stockColumn, columns, (v) => setState(() => _mapping = _mapping.copyWith(stockColumn: v))),
              _buildDropdown('Código / Referencia', _mapping.skuColumn, columns, (v) => setState(() => _mapping = _mapping.copyWith(skuColumn: v))),
              const SizedBox(height: 12),
              FilledButton(
                onPressed: _mapping.isValid ? _runValidation : null,
                style: FilledButton.styleFrom(backgroundColor: visual.accent, foregroundColor: Colors.black),
                child: const Text('Continuar a Validación'),
              ),
            ] else if (_report != null) ...[
              _buildMetricCard(visual),
              const SizedBox(height: 10),
              SwitchListTile(
                value: _replaceExisting,
                onChanged: (v) => setState(() => _replaceExisting = v),
                title: const Text('Reemplazar catálogo completo', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                subtitle: const Text('Si está inactivo, fusionará con los productos actuales', style: TextStyle(fontSize: 11)),
                contentPadding: EdgeInsets.zero,
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => setState(() => _currentStep = 0),
                      child: const Text('Atrás'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: FilledButton(
                      onPressed: _report!.hasValidData && !_saving ? _commit : null,
                      style: FilledButton.styleFrom(backgroundColor: visual.accent, foregroundColor: Colors.black),
                      child: _saving ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)) : const Text('Guardar y Activar'),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildDropdown(String label, String? current, List<String> items, ValueChanged<String?> onChanged) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: DropdownButtonFormField<String>(
        initialValue: items.contains(current) ? current : null,
        items: [
          const DropdownMenuItem(value: null, child: Text('(Ninguno)', style: TextStyle(fontSize: 12))),
          ...items.map((col) => DropdownMenuItem(value: col, child: Text(col, style: const TextStyle(fontSize: 12)))),
        ],
        onChanged: onChanged,
        decoration: InputDecoration(labelText: label, isDense: true, contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8)),
      ),
    );
  }

  Widget _buildMetricCard(AutomationVisualPalette visual) {
    final r = _report!;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: visual.accentSoft, borderRadius: BorderRadius.circular(12)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Resumen de Validación:', style: TextStyle(color: visual.text, fontWeight: FontWeight.bold, fontSize: 13)),
          const SizedBox(height: 6),
          Text('• Productos válidos para importar: ${r.validCount} de ${r.totalRows}', style: const TextStyle(fontSize: 12)),
          if (r.duplicateCount > 0)
            Text('• Duplicados omitidos: ${r.duplicateCount}', style: const TextStyle(fontSize: 12, color: Colors.amber)),
          if (r.invalidCount > 0)
            Text('• Filas con precio/nombre inválido: ${r.invalidCount}', style: const TextStyle(fontSize: 12, color: Colors.orangeAccent)),
        ],
      ),
    );
  }
}
