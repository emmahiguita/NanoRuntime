// location_edit_dialog.dart
//
// QUÉ HACE:
// Diálogo profesional con Material Expressive 3 para configuración de ubicación, sede y dirección comercial.
//
// CÓMO FUNCIONA:
// - Desglosa modalidad (física/virtual), dirección, ciudad, referencia y notas complementarias.
// - Utiliza DialogContainerShell para ajustar la altura y márgenes en Landscape y Portrait (< 160 líneas).
//
// POR QUÉ:
// Previene RenderFlex overflows al abrir teclado en modo horizontal asegurando legibilidad (SOLID - SRP).

import 'package:flutter/material.dart';
import 'package:nanoai/features/automation/presentation/automation_visual_theme.dart';
import 'dialog_container_shell.dart';

class LocationEditDialog extends StatefulWidget {
  final String initial;
  const LocationEditDialog({super.key, required this.initial});

  @override
  State<LocationEditDialog> createState() => _LocationEditDialogState();
}

class _LocationEditDialogState extends State<LocationEditDialog> {
  late final TextEditingController _modality, _address, _city, _reference, _notes, _rawController;
  bool _isRawMode = false;

  @override
  void initState() {
    super.initState();
    _rawController = TextEditingController(text: widget.initial);
    _initFromText(widget.initial);
  }

  void _initFromText(String text) {
    String mod = 'Tienda física y atención virtual', addr = '', c = '', ref = '';
    final extra = <String>[];
    final clean = text.trim();
    if (clean.isNotEmpty) {
      for (final p in clean.split(RegExp(r'\.\s+'))) {
        final lower = p.toLowerCase();
        if (lower.startsWith('dirección:') || lower.startsWith('direccion:')) {
          addr = p.substring(p.indexOf(':') + 1).trim();
        } else if (lower.startsWith('ciudad:') || lower.startsWith('municipio:')) {
          c = p.substring(p.indexOf(':') + 1).trim();
        } else if (lower.startsWith('referencia:')) {
          ref = p.substring(p.indexOf(':') + 1).trim();
        } else if (lower.contains('virtual') || lower.contains('física') || lower.contains('fisica')) {
          mod = p.trim();
        } else if (p.trim().isNotEmpty) {
          extra.add(p.trim());
        }
      }
    }
    _modality = TextEditingController(text: mod);
    _address = TextEditingController(text: addr);
    _city = TextEditingController(text: c);
    _reference = TextEditingController(text: ref);
    _notes = TextEditingController(text: extra.join('. '));
  }

  @override
  void dispose() {
    _modality.dispose();
    _address.dispose();
    _city.dispose();
    _reference.dispose();
    _notes.dispose();
    _rawController.dispose();
    super.dispose();
  }

  String _buildConsolidated() {
    final parts = <String>[];
    if (_modality.text.trim().isNotEmpty) parts.add(_modality.text.trim());
    if (_address.text.trim().isNotEmpty) parts.add('Dirección: ${_address.text.trim()}');
    if (_city.text.trim().isNotEmpty) parts.add('Ciudad: ${_city.text.trim()}');
    if (_reference.text.trim().isNotEmpty) parts.add('Referencia: ${_reference.text.trim()}');
    if (_notes.text.trim().isNotEmpty) parts.add(_notes.text.trim());
    return parts.isEmpty ? widget.initial.trim() : parts.join('. ');
  }

  @override
  Widget build(BuildContext context) {
    final visual = AutomationVisual.of(context);

    return DialogContainerShell(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 12, 8),
            child: Row(
              children: [
                Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(color: visual.accentSoft, borderRadius: BorderRadius.circular(10)),
                  child: Icon(Icons.place_rounded, color: visual.accent, size: 20),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text('Ubicación y Sede', style: TextStyle(color: visual.text, fontSize: 16, fontWeight: FontWeight.bold)),
                ),
                Semantics(
                  label: _isRawMode ? 'Modo guiado' : 'Texto libre',
                  button: true,
                  child: IconButton(
                    icon: Icon(_isRawMode ? Icons.view_list_rounded : Icons.edit_note_rounded, color: visual.accent, size: 22),
                    onPressed: () {
                      if (!_isRawMode) _rawController.text = _buildConsolidated();
                      setState(() => _isRawMode = !_isRawMode);
                    },
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: _isRawMode
                  ? TextField(
                      controller: _rawController,
                      maxLines: 6,
                      style: TextStyle(color: visual.text, fontSize: 13),
                      decoration: InputDecoration(
                        hintText: 'Ej. Calle 10 # 40-20, El Poblado, Medellín. Atención virtual a todo el país.',
                        filled: true,
                        fillColor: visual.inputFill,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                      ),
                    )
                  : Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _field(_modality, 'Modalidad de atención', visual, hint: 'Ej. Tienda física y virtual'),
                        const SizedBox(height: 8),
                        _field(_address, 'Dirección', visual, hint: 'Ej. Cra 43A # 1-50 Local 102'),
                        const SizedBox(height: 8),
                        _field(_city, 'Ciudad / Municipio', visual, hint: 'Ej. Medellín, Antioquia'),
                        const SizedBox(height: 8),
                        _field(_reference, 'Puntos de referencia', visual, hint: 'Ej. Al lado del parque principal'),
                        const SizedBox(height: 8),
                        _field(_notes, 'Notas de llegada o parqueo', visual, hint: 'Ej. Contamos con parqueadero gratuito'),
                      ],
                    ),
            ),
          ),
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 8, 14, 10),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: Text('Cancelar', style: TextStyle(color: visual.textMuted, fontSize: 12)),
                ),
                const SizedBox(width: 8),
                FilledButton(
                  onPressed: () {
                    final res = _isRawMode ? _rawController.text.trim() : _buildConsolidated();
                    Navigator.of(context).pop(res.isNotEmpty ? res : null);
                  },
                  style: FilledButton.styleFrom(
                    backgroundColor: visual.accent,
                    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  child: const Text('Guardar', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _field(TextEditingController ctrl, String label, AutomationVisualPalette visual, {String? hint}) => TextField(
        controller: ctrl,
        style: TextStyle(color: visual.text, fontSize: 12.5),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: TextStyle(fontSize: 11, color: visual.textMuted),
          hintText: hint,
          hintStyle: TextStyle(fontSize: 10, color: visual.textMuted.withValues(alpha: 0.5)),
          filled: true,
          fillColor: visual.inputFill,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
          isDense: true,
          contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        ),
      );
}
