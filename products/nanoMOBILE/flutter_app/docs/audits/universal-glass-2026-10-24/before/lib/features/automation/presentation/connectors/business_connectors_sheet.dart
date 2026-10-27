import 'package:flutter/material.dart' hide DataTable;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../engine/connectors/business_connector_models.dart';
import '../../engine/connectors/business_data_connector_service.dart';
import '../automation_visual_theme.dart';
import '../widgets/dialogs/dialog_container_shell.dart';
import 'business_connector_actions.dart';
import 'business_source_option_tile.dart';

// business_connectors_sheet.dart
//
// QUÉ HACE:
// Presenta el panel modal con las fuentes empresariales disponibles (Excel, CSV, Google Sheets, SQLite y REST).
//
// CÓMO FUNCIONA:
// - Delega selección, autenticación remota y carga a BusinessConnectorActions.
// - Despliega el panel modal con useRootNavigator y DialogContainerShell.
// - Mantiene el asistente de importación fuera de la capa visual.
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
      builder: (_) => const Material(
        color: Colors.transparent,
        child: BusinessConnectorsSheet(),
      ),
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
                      Text(
                        'Conectar mis datos',
                        style: TextStyle(
                          color: visual.text,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      Text(
                        'Nano Business · Fuentes empresariales',
                        style: TextStyle(color: visual.textMuted, fontSize: 12),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          BusinessSourceOptionTile(
            icon: Icons.table_view_rounded,
            title: 'Excel y CSV (.xlsx, .csv)',
            subtitle: 'Importa tus productos desde un archivo local',
            badge: 'Local',
            onTap: () =>
                BusinessConnectorActions.pickLocalFile(context, service),
          ),
          BusinessSourceOptionTile(
            icon: Icons.cloud_download_rounded,
            title: 'Google Sheets',
            subtitle: 'Mantén actualizados tus datos comerciales online',
            badge: 'Online',
            onTap: () => BusinessConnectorActions.promptUrl(
              context,
              service,
              BusinessSourceType.googleSheets,
            ),
          ),
          BusinessSourceOptionTile(
            icon: Icons.storage_rounded,
            title: 'Base de datos SQLite',
            subtitle: 'Conecta inventario y catálogo desde archivo .db local',
            badge: 'Avanzado',
            onTap: () =>
                BusinessConnectorActions.pickSqliteFile(context, service),
          ),
          BusinessSourceOptionTile(
            icon: Icons.api_rounded,
            title: 'Sistema empresarial REST',
            subtitle: 'Conexión segura mediante API autorizada (JSON)',
            badge: 'API',
            onTap: () => BusinessConnectorActions.promptUrl(
              context,
              service,
              BusinessSourceType.restApi,
            ),
          ),
          const SizedBox(height: 12),
        ],
      ),
    );
  }
}
