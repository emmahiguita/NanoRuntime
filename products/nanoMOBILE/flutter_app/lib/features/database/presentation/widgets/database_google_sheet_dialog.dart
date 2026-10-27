// database_google_sheet_dialog.dart
//
// QUÉ HACE:
// Diálogo y centro de conexión y automatización en tiempo real con Google Sheets.
//
// CÓMO FUNCIONA:
// - Provee conexión automática en un toque a la hoja de cálculo en vivo.
// - Permite ingresar cualquier enlace público de Google Sheets o Web App de Apps Script.
// - Muestra el estado activo de sincronización continua (cada 10s) con botón para forzar refresco inmediato.
// - Incluye opción de abrir la vista colaborativa en el navegador interno.
//
// POR QUÉ:
// Resuelve la petición de sincronización automática y bidireccional en tiempo real con Sheets
// sin datos sintéticos forzados ni configuraciones complejas (< 200 líneas).

library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import '../../application/database_studio_controller.dart';
import '../../application/google_sheets_sync_service.dart';

abstract final class DatabaseGoogleSheetDialog {
  /// QUÉ: Abre el modal interactivo de conexión y configuración de Google Sheets.
  /// CÓMO: Inyecta el controlador de Data Studio y administra el ciclo de vida de los inputs.
  /// POR QUÉ: Separa la presentación del diálogo de la vista principal del estudio.
  static Future<void> show(
    BuildContext context,
    DatabaseStudioController controller,
  ) async {
    final state = controller.currentState;
    final currentSheet = state.currentTable;
    final isAlreadyConnected = currentSheet?.isGoogleSheet == true;

    final input = TextEditingController(
      text: isAlreadyConnected
          ? currentSheet!.sourceUrl!
          : GoogleSheetsSyncService.defaultAutomatedSheetUrl,
    );
    final endpointInput = TextEditingController(
      text: isAlreadyConnected
          ? currentSheet!.syncEndpointUrl ?? ''
          : '',
    );

    await showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (ctx, setState) {
          final isLiveActive = controller.currentState.isLiveSyncActive;

          return AlertDialog(
            title: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: const Color(0xFF10B981).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.table_chart_rounded,
                    color: Color(0xFF10B981),
                    size: 20,
                  ),
                ),
                const SizedBox(width: 10),
                const Expanded(
                  child: Text(
                    'Google Sheets · Tiempo Real',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Estado de sincronización en vivo si ya está conectada
                  if (isAlreadyConnected && isLiveActive)
                    Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: const Color(0xFF10B981).withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: const Color(0xFF10B981).withValues(alpha: 0.35),
                        ),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.sensors_rounded,
                            size: 16,
                            color: Color(0xFF10B981),
                          ),
                          const SizedBox(width: 8),
                          const Expanded(
                            child: Text(
                              'Sincronización activa: revisión continua cada 10s',
                              style: TextStyle(
                                fontSize: 11,
                                color: Color(0xFF10B981),
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          TextButton(
                            style: TextButton.styleFrom(
                              padding: const EdgeInsets.symmetric(horizontal: 8),
                              minimumSize: Size.zero,
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            ),
                            onPressed: () async {
                              await controller.syncGoogleSheetsNow();
                              setState(() {});
                            },
                            child: const Text('Sincronizar ahora', style: TextStyle(fontSize: 11)),
                          ),
                        ],
                      ),
                    ),

                  const Text(
                    'Conecta tu hoja de Google Sheets. NanoAI detectará cambios y los sincronizará en tiempo real. Puedes usar el botón de conexión automática o pegar tu propio enlace.',
                    style: TextStyle(fontSize: 12),
                  ),
                  const SizedBox(height: 12),

                  // Botón de conexión automática en un toque
                  FilledButton.tonalIcon(
                    style: FilledButton.styleFrom(
                      minimumSize: const Size.fromHeight(38),
                      backgroundColor: const Color(0xFF10B981).withValues(alpha: 0.15),
                      foregroundColor: const Color(0xFF10B981),
                    ),
                    icon: const Icon(Icons.bolt_rounded, size: 18),
                    label: const Text(
                      '⚡ Auto-conectar hoja en tiempo real',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                    ),
                    onPressed: () async {
                      input.text = GoogleSheetsSyncService.defaultAutomatedSheetUrl;
                      final ok = await controller.autoConnectGoogleSheets();
                      if (ok && dialogContext.mounted) {
                        Navigator.pop(dialogContext);
                      }
                    },
                  ),
                  const SizedBox(height: 12),

                  TextField(
                    controller: input,
                    autofocus: false,
                    style: const TextStyle(fontSize: 12.5, fontFamily: 'JetBrainsMono'),
                    decoration: const InputDecoration(
                      labelText: 'Enlace de Google Sheets',
                      hintText: 'https://docs.google.com/spreadsheets/d/...',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                    onChanged: (_) => setState(() {}),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: endpointInput,
                    style: const TextStyle(fontSize: 12.5, fontFamily: 'JetBrainsMono'),
                    decoration: const InputDecoration(
                      labelText: 'Web App de Apps Script (opcional, para edición bidireccional)',
                      hintText: 'https://script.google.com/macros/s/.../exec',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                  ),
                  const SizedBox(height: 10),
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      minimumSize: const Size.fromHeight(34),
                    ),
                    icon: const Icon(Icons.code_rounded, size: 15),
                    label: const Text(
                      'Copiar puente de sincronización (Apps Script)',
                      style: TextStyle(fontSize: 11),
                    ),
                    onPressed: () {
                      Clipboard.setData(
                        ClipboardData(text: GoogleSheetsSyncService.appsScriptTemplate),
                      );
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text(
                            'Script copiado al portapapeles. Pégalo en Extensiones > Apps Script.',
                          ),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: const Text('Cerrar'),
              ),
              OutlinedButton.icon(
                icon: const Icon(Icons.open_in_browser_rounded, size: 15),
                label: const Text('Abrir en vivo'),
                onPressed: () {
                  Navigator.pop(dialogContext);
                  final target = input.text.trim().isEmpty
                      ? GoogleSheetsSyncService.defaultAutomatedSheetUrl
                      : input.text.trim();
                  context.push('/browser?url=' + Uri.encodeComponent(target));
                },
              ),
              FilledButton.icon(
                icon: const Icon(Icons.sync_rounded, size: 16),
                label: const Text('Sincronizar tabla'),
                onPressed: () async {
                  final text = input.text.trim();
                  if (text.isEmpty) return;
                  final endpoint = endpointInput.text.trim();
                  final ok = await controller.connectRealtimeGoogleSheet(
                    text,
                    syncEndpointUrl: endpoint.isEmpty ? null : endpoint,
                  );
                  if (ok && dialogContext.mounted) {
                    Navigator.pop(dialogContext);
                  } else if (dialogContext.mounted) {
                    final error = controller.currentState.errorMessage;
                    ScaffoldMessenger.of(dialogContext).showSnackBar(
                      SnackBar(
                        content: Text(error ?? 'No se pudo conectar Google Sheets'),
                      ),
                    );
                  }
                },
              ),
            ],
          );
        },
      ),
    );
    input.dispose();
    endpointInput.dispose();
  }
}
