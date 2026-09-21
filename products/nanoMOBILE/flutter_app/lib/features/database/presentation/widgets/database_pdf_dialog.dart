import 'package:flutter/material.dart';
import 'package:nanoai/core/theme/design_tokens.dart';
import '../../application/database_studio_controller.dart';

/// Modal bottom sheet para configurar, previsualizar y compartir informes ejecutivos en PDF
class DatabasePdfDialog extends StatefulWidget {
  final DatabaseStudioController controller;
  final NanoColors colors;

  const DatabasePdfDialog({
    super.key,
    required this.controller,
    required this.colors,
  });

  static Future<void> show(
    BuildContext context, {
    required DatabaseStudioController controller,
    required NanoColors colors,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: colors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => DatabasePdfDialog(
        controller: controller,
        colors: colors,
      ),
    );
  }

  @override
  State<DatabasePdfDialog> createState() => _DatabasePdfDialogState();
}

class _DatabasePdfDialogState extends State<DatabasePdfDialog> {
  late final TextEditingController _titleCtrl;
  late final TextEditingController _notesCtrl;

  @override
  void initState() {
    super.initState();
    _titleCtrl = TextEditingController(text: 'Informe Ejecutivo - Datos Shell');
    _notesCtrl = TextEditingController(
      text: 'Generado automáticamente desde NanoAI Data Studio.',
    );
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = widget.colors;
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Padding(
      padding: EdgeInsets.fromLTRB(20, 20, 20, bottomInset + 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.picture_as_pdf_rounded, color: colors.primary),
              const SizedBox(width: 8),
              const Text(
                'Generar Informe Ejecutivo PDF',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _titleCtrl,
            decoration: InputDecoration(
              labelText: 'Título del Informe',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              isDense: true,
            ),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _notesCtrl,
            maxLines: 2,
            decoration: InputDecoration(
              labelText: 'Notas o Conclusiones',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              isDense: true,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.share_rounded, size: 16),
                  label: const Text('Compartir PDF'),
                  onPressed: () {
                    Navigator.pop(context);
                    widget.controller.shareCurrentReport(
                      title: _titleCtrl.text.trim(),
                    );
                  },
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: colors.primary,
                    foregroundColor: Colors.white,
                  ),
                  icon: const Icon(Icons.print_rounded, size: 16),
                  label: const Text('Ver / Imprimir'),
                  onPressed: () {
                    Navigator.pop(context);
                    widget.controller.generateAndPreviewPdfReport(
                      title: _titleCtrl.text.trim(),
                      notes: _notesCtrl.text.trim(),
                    );
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
