// QUÉ: ejecuta la selección y carga de fuentes comerciales.
// CÓMO: transforma archivos/URLs en una configuración y abre el asistente de importación.
// POR QUÉ: deja la hoja visual enfocada únicamente en presentar opciones.
library;

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart' hide DataTable;

import '../../engine/connectors/business_connector_models.dart';
import '../../engine/connectors/business_data_connector_service.dart';
import 'business_import_wizard_dialog.dart';
import 'business_remote_source_dialog.dart';

abstract final class BusinessConnectorActions {
  static Future<void> pickLocalFile(
    BuildContext context,
    BusinessDataConnectorService service,
  ) async {
    final result = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['xlsx', 'csv', 'tsv'],
    );
    if (result == null ||
        result.files.single.path == null ||
        !context.mounted) {
      return;
    }
    final path = result.files.single.path!;
    final name = result.files.single.name;
    final type = name.toLowerCase().endsWith('.xlsx')
        ? BusinessSourceType.excel
        : BusinessSourceType.csv;
    await launchWizard(
      context,
      service,
      BusinessSourceConfig(id: path, name: name, type: type, sourceUri: path),
    );
  }

  static Future<void> pickSqliteFile(
    BuildContext context,
    BusinessDataConnectorService service,
  ) async {
    final result = await FilePicker.pickFiles(type: FileType.any);
    if (result == null ||
        result.files.single.path == null ||
        !context.mounted) {
      return;
    }
    final path = result.files.single.path!;
    final name = result.files.single.name;
    await launchWizard(
      context,
      service,
      BusinessSourceConfig(
        id: path,
        name: name,
        type: BusinessSourceType.sqlite,
        sourceUri: path,
      ),
    );
  }

  static Future<void> promptUrl(
    BuildContext context,
    BusinessDataConnectorService service,
    BusinessSourceType type,
  ) async {
    final isSheets = type == BusinessSourceType.googleSheets;
    final input = await showDialog<BusinessRemoteSourceInput>(
      context: context,
      useRootNavigator: true,
      builder: (_) => BusinessRemoteSourceDialog(isSheets: isSheets),
    );
    if (input == null || !context.mounted) return;
    await launchWizard(
      context,
      service,
      BusinessSourceConfig(
        id: input.url,
        name: isSheets ? 'Google Sheets' : 'API REST',
        type: type,
        sourceUri: input.url,
        authToken: input.authToken,
      ),
    );
  }

  static Future<void> launchWizard(
    BuildContext context,
    BusinessDataConnectorService service,
    BusinessSourceConfig config,
  ) async {
    // El panel se desmonta al cerrarse; el Navigator raíz permanece disponible.
    final navigator = Navigator.of(context, rootNavigator: true);
    final messenger = ScaffoldMessenger.maybeOf(context);
    navigator.pop();
    try {
      final table = await service.loadSourceTable(config);
      if (!navigator.mounted) return;
      await showDialog(
        context: navigator.context,
        useRootNavigator: true,
        builder: (_) =>
            BusinessImportWizardDialog(table: table, config: config),
      );
    } catch (error) {
      if (messenger == null || !messenger.mounted) return;
      messenger.showSnackBar(
        SnackBar(content: Text('Error cargando fuente: $error')),
      );
    }
  }
}
