import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart' hide DataTable;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../engine/connectors/business_connector_models.dart';
import '../../engine/connectors/business_data_connector_service.dart';
import '../automation_visual_theme.dart';
import '../widgets/dialogs/dialog_container_shell.dart';
import 'business_import_wizard_dialog.dart';

// business_connectors_sheet.dart
//
// QUÉ HACE:
// Presenta el panel modal con las fuentes empresariales disponibles (Excel, CSV, Google Sheets, SQLite y REST).
//
// CÓMO FUNCIONA:
// - Utiliza FilePicker para seleccionar archivos locales (SAF en Android).
// - Despliega cuadros de diálogo modales con useRootNavigator: true y DialogContainerShell.
// - Transfiere la tabla cargada al asistente de importación (BusinessImportWizardDialog).
//
// POR QUÉ:
// Ofrece una experiencia limpia, usable y profesional adaptada a Material Expressive 3 (< 200 líneas).

class BusinessConnectorsSheet extends ConsumerWidget {
  const BusinessConnectorsSheet({super.key});

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const Material(color: Colors.transparent, child: BusinessConnectorsSheet()),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final visual = AutomationVisual.of(context);
    final service = ref.read(businessDataConnectorServiceProvider);

    return DialogContainerShell(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 16, 8),
            child: Row(
              children: [
                Icon(Icons.hub_rounded, color: visual.accent, size: 24),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Conectar mis datos', style: TextStyle(color: visual.text, fontWeight: FontWeight.bold, fontSize: 16)),
                      Text('Nano Business · Fuentes empresariales', style: TextStyle(color: visual.textMuted, fontSize: 12)),
                    ],
                  ),
                ),
                IconButton(icon: const Icon(Icons.close_rounded), onPressed: () => Navigator.of(context).pop()),
              ],
            ),
          ),
          const Divider(height: 1),
          _SourceOptionTile(
            icon: Icons.table_view_rounded,
            title: 'Excel y CSV (.xlsx, .csv)',
            subtitle: 'Importa tus productos desde un archivo local',
            badge: 'Local',
            onTap: () => _pickLocalFile(context, service),
          ),
          _SourceOptionTile(
            icon: Icons.cloud_download_rounded,
            title: 'Google Sheets',
            subtitle: 'Mantén actualizados tus datos comerciales online',
            badge: 'Online',
            onTap: () => _promptUrl(context, service, BusinessSourceType.googleSheets),
          ),
          _SourceOptionTile(
            icon: Icons.storage_rounded,
            title: 'Base de datos SQLite',
            subtitle: 'Conecta inventario y catálogo desde archivo .db local',
            badge: 'Avanzado',
            onTap: () => _pickSqliteFile(context, service),
          ),
          _SourceOptionTile(
            icon: Icons.api_rounded,
            title: 'Sistema empresarial REST',
            subtitle: 'Conexión segura mediante API autorizada (JSON)',
            badge: 'API',
            onTap: () => _promptUrl(context, service, BusinessSourceType.restApi),
          ),
          const SizedBox(height: 12),
        ],
      ),
    );
  }

  Future<void> _pickLocalFile(BuildContext context, BusinessDataConnectorService service) async {
    final result = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['xlsx', 'csv', 'tsv'],
    );
    if (result != null && result.files.single.path != null && context.mounted) {
      final path = result.files.single.path!;
      final name = result.files.single.name;
      final type = name.endsWith('.xlsx') ? BusinessSourceType.excel : BusinessSourceType.csv;
      _launchWizard(context, service, BusinessSourceConfig(id: path, name: name, type: type, sourceUri: path));
    }
  }

  Future<void> _pickSqliteFile(BuildContext context, BusinessDataConnectorService service) async {
    final result = await FilePicker.pickFiles(type: FileType.any);
    if (result != null && result.files.single.path != null && context.mounted) {
      final path = result.files.single.path!;
      final name = result.files.single.name;
      _launchWizard(context, service, BusinessSourceConfig(id: path, name: name, type: BusinessSourceType.sqlite, sourceUri: path));
    }
  }

  Future<void> _promptUrl(BuildContext context, BusinessDataConnectorService service, BusinessSourceType type) async {
    final controller = TextEditingController();
    final isSheets = type == BusinessSourceType.googleSheets;
    final confirmed = await showDialog<bool>(
      context: context,
      useRootNavigator: true,
      builder: (ctx) => AlertDialog(
        title: Text(isSheets ? 'URL de Google Sheets' : 'Endpoint API REST'),
        content: TextField(
          controller: controller,
          decoration: InputDecoration(
            hintText: isSheets ? 'https://docs.google.com/spreadsheets/d/...' : 'https://api.negocio.com/v1/productos',
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Conectar')),
        ],
      ),
    );
    if (confirmed == true && controller.text.trim().isNotEmpty && context.mounted) {
      final uri = controller.text.trim();
      _launchWizard(context, service, BusinessSourceConfig(id: uri, name: isSheets ? 'Google Sheets' : 'API REST', type: type, sourceUri: uri));
    }
  }

  Future<void> _launchWizard(BuildContext context, BusinessDataConnectorService service, BusinessSourceConfig config) async {
    Navigator.of(context).pop();
    try {
      final table = await service.loadSourceTable(config);
      if (context.mounted) {
        showDialog(
          context: context,
          useRootNavigator: true,
          builder: (_) => BusinessImportWizardDialog(table: table, config: config),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error cargando fuente: $e')));
      }
    }
  }
}

class _SourceOptionTile extends StatelessWidget {
  final IconData icon;
  final String title, subtitle, badge;
  final VoidCallback onTap;

  const _SourceOptionTile({required this.icon, required this.title, required this.subtitle, required this.badge, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final visual = AutomationVisual.of(context);
    return ListTile(
      leading: Container(
        width: 38,
        height: 38,
        decoration: BoxDecoration(color: visual.accentSoft, borderRadius: BorderRadius.circular(10)),
        child: Icon(icon, color: visual.accent, size: 20),
      ),
      title: Text(title, style: TextStyle(color: visual.text, fontWeight: FontWeight.w600, fontSize: 13)),
      subtitle: Text(subtitle, style: TextStyle(color: visual.textMuted, fontSize: 11)),
      trailing: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(color: visual.accentSoft, borderRadius: BorderRadius.circular(8)),
        child: Text(badge, style: TextStyle(color: visual.accent, fontSize: 10, fontWeight: FontWeight.bold)),
      ),
      onTap: onTap,
    );
  }
}
