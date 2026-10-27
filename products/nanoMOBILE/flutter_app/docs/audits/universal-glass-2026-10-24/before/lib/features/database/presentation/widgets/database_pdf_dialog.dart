// QUÉ: configura un informe real, editable y ordenable antes de generarlo.
// CÓMO: recoge título/notas y propaga las secciones activas al exportador.
// POR QUÉ: una sola configuración alimenta vista previa y compartición.

import 'package:flutter/material.dart';
import 'package:nanoai/core/theme/design_tokens.dart';
import 'package:nanoai/features/automation/presentation/widgets/conversation_pdf_viewer.dart';
import '../../application/database_studio_controller.dart';
import '../../domain/report_section.dart';
import 'database_report_section_editor.dart';

class DatabasePdfDialog extends StatefulWidget {
  final DatabaseStudioController controller;
  final NanoColors colors;

  const DatabasePdfDialog({super.key, required this.controller, required this.colors});

  static Future<void> show(
    BuildContext context, {
    required DatabaseStudioController controller,
    required NanoColors colors,
  }) => showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: colors.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (_) => DatabasePdfDialog(controller: controller, colors: colors),
  );

  @override
  State<DatabasePdfDialog> createState() => _DatabasePdfDialogState();
}

class _DatabasePdfDialogState extends State<DatabasePdfDialog> {
  late final TextEditingController _title;
  late final TextEditingController _notes;
  List<ReportSection> _order = List.of(kDefaultReportSections);
  final Set<ReportSection> _enabled = Set.of(kDefaultReportSections);
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _title = TextEditingController(text: 'Informe ejecutivo de datos');
    _notes = TextEditingController();
  }

  @override
  void dispose() {
    _title.dispose();
    _notes.dispose();
    super.dispose();
  }

  List<ReportSection> get _selected =>
      _order.where(_enabled.contains).toList(growable: false);

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
    return AnimatedPadding(
      duration: const Duration(milliseconds: 180),
      padding: EdgeInsets.fromLTRB(16, 12, 16, bottomInset + 16),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _header(),
            const SizedBox(height: 14),
            TextField(
              controller: _title,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                labelText: 'Título del informe',
                border: OutlineInputBorder(),
                isDense: true,
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _notes,
              maxLines: 2,
              decoration: const InputDecoration(
                labelText: 'Notas o conclusiones (opcional)',
                border: OutlineInputBorder(),
                isDense: true,
              ),
            ),
            const SizedBox(height: 14),
            DatabaseReportSectionEditor(
              order: _order,
              enabled: _enabled,
              onReorder: (value) => setState(() => _order = value),
              onToggle: _toggle,
            ),
            const SizedBox(height: 10),
            _actions(),
          ],
        ),
      ),
    );
  }

  Widget _header() => Row(
    children: [
      Icon(Icons.picture_as_pdf_rounded, color: widget.colors.primary),
      const SizedBox(width: 8),
      const Expanded(
        child: Text(
          'Diseñar informe PDF',
          style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
        ),
      ),
      IconButton(
        visualDensity: VisualDensity.compact,
        onPressed: _busy ? null : () => Navigator.pop(context),
        icon: const Icon(Icons.close_rounded),
      ),
    ],
  );

  Widget _actions() => Row(
    children: [
      Expanded(
        child: OutlinedButton.icon(
          onPressed: _busy ? null : () => _submit(share: true),
          icon: const Icon(Icons.share_rounded, size: 17),
          label: const Text('Compartir'),
        ),
      ),
      const SizedBox(width: 10),
      Expanded(
        child: FilledButton.icon(
          onPressed: _busy ? null : () => _submit(share: false),
          icon: _busy
              ? const SizedBox.square(
                  dimension: 15,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.visibility_rounded, size: 17),
          label: const Text('Crear y ver'),
        ),
      ),
    ],
  );

  // Mantiene al menos una sección para impedir documentos vacíos.
  void _toggle(ReportSection section) => setState(() {
    _enabled.contains(section) ? _enabled.remove(section) : _enabled.add(section);
  });

  // Ejecuta ambas salidas con la misma selección y evita dobles pulsaciones.
  Future<void> _submit({required bool share}) async {
    FocusScope.of(context).unfocus();
    setState(() => _busy = true);
    final rawTitle = _title.text.trim();
    final title = rawTitle.isEmpty ? null : rawTitle;
    if (share) {
      final shared = await widget.controller.shareCurrentReport(
        title: title,
        notes: _notes.text.trim(),
        sections: _selected,
      );
      if (!mounted) return;
      setState(() => _busy = false);
      if (shared) Navigator.pop(context);
      return;
    }
    final path = await widget.controller.exportPdf(
      title: title,
      notes: _notes.text.trim(),
      sections: _selected,
    );
    if (!mounted) return;
    setState(() => _busy = false);
    if (path == null) return;
    final navigator = Navigator.of(context);
    navigator.pop();
    if (!navigator.mounted) return;
    await ConversationPdfViewer.show(
      navigator.context,
      pathOrUrl: path,
      title: title ?? 'Informe de datos',
    );
  }
}
