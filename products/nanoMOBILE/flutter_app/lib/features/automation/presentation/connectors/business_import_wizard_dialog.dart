import 'package:flutter/material.dart' hide DataTable;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../database/domain/data_models.dart';
import '../../engine/connectors/business_connector_models.dart';
import '../../engine/connectors/business_data_connector_service.dart';
import '../automation_visual_theme.dart';
import '../widgets/dialogs/dialog_container_shell.dart';

part 'business_import_wizard_content.dart';
part 'business_import_wizard_fields.dart';

// business_import_wizard_dialog.dart
//
// QUÉ HACE:
// Asistente visual en 2 pasos para mapeo, validación estricta y activación
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

  const BusinessImportWizardDialog({
    super.key,
    required this.table,
    required this.config,
  });

  @override
  ConsumerState<BusinessImportWizardDialog> createState() =>
      _BusinessImportWizardDialogState();
}

class _BusinessImportWizardDialogState
    extends ConsumerState<BusinessImportWizardDialog> {
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
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.maybeOf(context);
    final service = ref.read(businessDataConnectorServiceProvider);
    final ok = await service.commitImport(
      report: _report!,
      replaceExisting: _replaceExisting,
    );
    if (!mounted) return;
    setState(() => _saving = false);
    if (ok) {
      navigator.pop(true);
      messenger?.showSnackBar(
        SnackBar(
          content: Text(
            '¡Se importaron ${_report!.validCount} productos con éxito!',
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) => _buildContent(context);
}
