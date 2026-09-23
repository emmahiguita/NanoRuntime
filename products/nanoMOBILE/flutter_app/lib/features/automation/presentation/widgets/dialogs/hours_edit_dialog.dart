// hours_edit_dialog.dart
//
// QUÉ HACE:
// Diálogo profesional con Material Expressive 3 para configuración de horarios comerciales y política fuera de servicio.
//
// CÓMO FUNCIONA:
// - Provee campos desglosados (semana, sábados, domingos/festivos, fuera de horario) o texto libre directo.
// - Utiliza DialogContainerShell para ajustar la altura y márgenes en Landscape y Portrait (< 160 líneas).
//
// POR QUÉ:
// Mantiene el diseño usable, legible y compacto en cualquier tamaño o rotación de pantalla (SOLID - SRP).

import 'package:flutter/material.dart';
import 'package:nanoai/features/automation/presentation/automation_visual_theme.dart';
import 'dialog_container_shell.dart';

class HoursEditDialog extends StatefulWidget {
  final String initial;
  const HoursEditDialog({super.key, required this.initial});

  @override
  State<HoursEditDialog> createState() => _HoursEditDialogState();
}

class _HoursEditDialogState extends State<HoursEditDialog> {
  late final TextEditingController _weekdays, _saturdays, _sundays, _offHoursPolicy, _rawController;
  bool _isRawMode = false;

  @override
  void initState() {
    super.initState();
    _rawController = TextEditingController(text: widget.initial);
    _initFromText(widget.initial);
  }

  void _initFromText(String text) {
    String wk = 'Lunes a Viernes de 8:00 AM a 6:00 PM', sat = 'Sábados de 9:00 AM a 2:00 PM';
    String sun = 'Domingos y festivos: Cerrado';
    String offH = 'Fuera de horario puedes dejar tu mensaje y te responderemos a primera hora al abrir.';

    final clean = text.trim();
    if (clean.isNotEmpty) {
      for (final p in clean.split(RegExp(r'\.\s+'))) {
        final lower = p.toLowerCase();
        if (lower.contains('lunes') || lower.contains('semana') || lower.contains('l-v')) {
          wk = p.trim();
        } else if (lower.contains('sábado') || lower.contains('sabado')) {
          sat = p.trim();
        } else if (lower.contains('domingo') || lower.contains('festivo')) {
          sun = p.trim();
        } else if (lower.contains('fuera de horario') || lower.contains('cerrado') || lower.contains('abrir')) {
          offH = p.trim();
        }
      }
    }
    _weekdays = TextEditingController(text: wk);
    _saturdays = TextEditingController(text: sat);
    _sundays = TextEditingController(text: sun);
    _offHoursPolicy = TextEditingController(text: offH);
  }

  @override
  void dispose() {
    _weekdays.dispose();
    _saturdays.dispose();
    _sundays.dispose();
    _offHoursPolicy.dispose();
    _rawController.dispose();
    super.dispose();
  }

  String _buildConsolidated() {
    final parts = [_weekdays.text.trim(), _saturdays.text.trim(), _sundays.text.trim(), _offHoursPolicy.text.trim()]
        .where((s) => s.isNotEmpty)
        .toList();
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
                  child: Icon(Icons.schedule_rounded, color: visual.accent, size: 20),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text('Horarios de Atención', style: TextStyle(color: visual.text, fontSize: 16, fontWeight: FontWeight.bold)),
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
                        hintText: 'Ej. Lunes a Sábado de 8:00 AM a 8:00 PM. Domingos cerrado.',
                        filled: true,
                        fillColor: visual.inputFill,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                      ),
                    )
                  : Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _field(_weekdays, 'Lunes a Viernes', visual, hint: 'Ej. 8:00 AM a 6:00 PM'),
                        const SizedBox(height: 8),
                        _field(_saturdays, 'Sábados', visual, hint: 'Ej. 9:00 AM a 2:00 PM o Cerrado'),
                        const SizedBox(height: 8),
                        _field(_sundays, 'Domingos y Festivos', visual, hint: 'Ej. Cerrado o 10:00 AM a 2:00 PM'),
                        const SizedBox(height: 8),
                        _field(_offHoursPolicy, 'Fuera de horario', visual, hint: 'Ej. Responderemos a primera hora al abrir'),
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
