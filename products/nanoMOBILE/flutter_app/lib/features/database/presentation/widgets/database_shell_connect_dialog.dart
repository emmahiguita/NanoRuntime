import 'package:flutter/material.dart';
import 'package:nanoai/core/theme/design_tokens.dart';
import '../../application/database_studio_controller.dart';
import '../../domain/database_security_guard.dart';

/// Diálogo modular para conectar hojas de cálculo y tablas desde el entorno Shell
class DatabaseShellConnectDialog extends StatefulWidget {
  final DatabaseStudioController controller;
  final NanoColors colors;

  const DatabaseShellConnectDialog({
    super.key,
    required this.controller,
    required this.colors,
  });

  static Future<void> show(
    BuildContext context, {
    required DatabaseStudioController controller,
    required NanoColors colors,
  }) {
    return showDialog(
      context: context,
      builder: (ctx) => DatabaseShellConnectDialog(
        controller: controller,
        colors: colors,
      ),
    );
  }

  @override
  State<DatabaseShellConnectDialog> createState() => _DatabaseShellConnectDialogState();
}

class _DatabaseShellConnectDialogState extends State<DatabaseShellConnectDialog> {
  late final TextEditingController _pathController;
  String? _validationError;

  @override
  void initState() {
    super.initState();
    _pathController = TextEditingController(
      text: '/data/data/dev.nanoai.mobile/files/nano/reporte.csv',
    );
  }

  @override
  void dispose() {
    _pathController.dispose();
    super.dispose();
  }

  void _submit() async {
    final rawPath = _pathController.text.trim();
    try {
      final safePath = DatabaseSecurityGuard.validateAndSanitizePath(rawPath);
      final messenger = ScaffoldMessenger.of(context);
      Navigator.pop(context);

      final ok = await widget.controller.importFromShellPath(safePath);
      if (!mounted) return;
      if (!ok) {
        messenger.showSnackBar(
          SnackBar(
            content: Text('No se pudo conectar con $safePath'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    } on DatabaseSecurityException catch (secErr) {
      setState(() {
        _validationError = secErr.message;
      });
    } catch (e) {
      setState(() {
        _validationError = 'Error de ruta: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = widget.colors;

    return AlertDialog(
      backgroundColor: colors.surface,
      title: Row(
        children: [
          Icon(Icons.terminal_rounded, color: colors.primary),
          const SizedBox(width: 8),
          const Text('Conectar Hoja Shell', style: TextStyle(fontSize: 16)),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Indique la ruta del archivo CSV o TSV generado por scripts o comandos dentro del entorno Shell:',
            style: TextStyle(fontSize: 12),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _pathController,
            onChanged: (_) {
              if (_validationError != null) {
                setState(() => _validationError = null);
              }
            },
            style: const TextStyle(fontFamily: 'JetBrainsMono', fontSize: 12),
            decoration: InputDecoration(
              labelText: 'Ruta absoluta en Shell',
              hintText: '/data/data/dev.nanoai.mobile/files/nano/...',
              errorText: _validationError,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              isDense: true,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            children: [
              ActionChip(
                label: const Text('reporte.csv', style: TextStyle(fontSize: 10)),
                onPressed: () {
                  setState(() {
                    _pathController.text = '/data/data/dev.nanoai.mobile/files/nano/reporte.csv';
                    _validationError = null;
                  });
                },
              ),
              ActionChip(
                label: const Text('metricas.tsv', style: TextStyle(fontSize: 10)),
                onPressed: () {
                  setState(() {
                    _pathController.text = '/data/data/dev.nanoai.mobile/files/nano/metricas.tsv';
                    _validationError = null;
                  });
                },
              ),
              ActionChip(
                label: const Text('Descargas SD', style: TextStyle(fontSize: 10)),
                onPressed: () {
                  setState(() {
                    _pathController.text = '/sdcard/Download/datos.csv';
                    _validationError = null;
                  });
                },
              ),
            ],
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: colors.primary,
            foregroundColor: Colors.white,
          ),
          onPressed: _submit,
          child: const Text('Conectar'),
        ),
      ],
    );
  }
}
