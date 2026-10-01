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
      builder: (ctx) =>
          DatabaseShellConnectDialog(controller: controller, colors: colors),
    );
  }

  @override
  State<DatabaseShellConnectDialog> createState() =>
      _DatabaseShellConnectDialogState();
}

class _DatabaseShellConnectDialogState
    extends State<DatabaseShellConnectDialog> {
  late final TextEditingController _pathController;
  String? _validationError;
  bool _connecting = false;

  @override
  void initState() {
    super.initState();
    _pathController = TextEditingController();
  }

  @override
  void dispose() {
    _pathController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final rawPath = _pathController.text.trim();
    try {
      final safePath = DatabaseSecurityGuard.validateAndSanitizePath(rawPath);
      setState(() => _connecting = true);
      final ok = await widget.controller.importFromShellPath(safePath);
      if (!mounted) return;
      if (ok) {
        Navigator.pop(context);
      } else {
        setState(() {
          _connecting = false;
          _validationError = 'No se pudo abrir el archivo indicado.';
        });
      }
    } on DatabaseSecurityException catch (secErr) {
      setState(() {
        _connecting = false;
        _validationError = secErr.message;
      });
    } catch (e) {
      setState(() {
        _connecting = false;
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
          const Text('Conectar ruta local', style: TextStyle(fontSize: 16)),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Escribe la ruta real de un CSV, TSV, XLSX o SQLite generado o guardado en el dispositivo.',
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
              hintText: '/ruta/al/archivo.csv',
              errorText: _validationError,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              isDense: true,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Para buscar visualmente, usa “Cargar archivo” en la barra de tablas.',
            style: TextStyle(fontSize: 11),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: _connecting ? null : () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: colors.primary,
            foregroundColor: Colors.white,
          ),
          onPressed: _connecting ? null : _submit,
          child: _connecting
              ? const SizedBox.square(
                  dimension: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Conectar'),
        ),
      ],
    );
  }
}
