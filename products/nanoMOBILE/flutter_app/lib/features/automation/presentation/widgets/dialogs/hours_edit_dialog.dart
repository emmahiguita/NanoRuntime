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
import 'guided_fact_dialog.dart';

class HoursEditDialog extends StatefulWidget {
  final String initial;
  const HoursEditDialog({super.key, required this.initial});

  @override
  State<HoursEditDialog> createState() => _HoursEditDialogState();
}

class _HoursEditDialogState extends State<HoursEditDialog> {
  late final TextEditingController _weekdays,
      _saturdays,
      _sundays,
      _offHoursPolicy,
      _rawController;
  bool _isRawMode = false;

  @override
  void initState() {
    super.initState();
    _rawController = TextEditingController(text: widget.initial);
    _initFromText(widget.initial);
  }

  void _initFromText(String text) {
    String wk = 'Lunes a Viernes de 8:00 AM a 6:00 PM',
        sat = 'Sábados de 9:00 AM a 2:00 PM';
    String sun = 'Domingos y festivos: Cerrado';
    String offH =
        'Fuera de horario puedes dejar tu mensaje y te responderemos a primera hora al abrir.';

    final clean = text.trim();
    if (clean.isNotEmpty) {
      for (final p in clean.split(RegExp(r'\.\s+'))) {
        final lower = p.toLowerCase();
        if (lower.contains('lunes') ||
            lower.contains('semana') ||
            lower.contains('l-v')) {
          wk = p.trim();
        } else if (lower.contains('sábado') || lower.contains('sabado')) {
          sat = p.trim();
        } else if (lower.contains('domingo') || lower.contains('festivo')) {
          sun = p.trim();
        } else if (lower.contains('fuera de horario') ||
            lower.contains('cerrado') ||
            lower.contains('abrir')) {
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
    final parts = [
      _weekdays.text.trim(),
      _saturdays.text.trim(),
      _sundays.text.trim(),
      _offHoursPolicy.text.trim(),
    ].where((s) => s.isNotEmpty).toList();
    return parts.isEmpty ? widget.initial.trim() : parts.join('. ');
  }

  @override
  Widget build(BuildContext context) {
    return GuidedFactDialog(
      title: 'Horarios de Atención',
      icon: Icons.schedule_rounded,
      isRawMode: _isRawMode,
      rawController: _rawController,
      rawHint: 'Ej. Lunes a Sábado de 8:00 AM a 8:00 PM. Domingos cerrado.',
      onToggleMode: () {
        if (!_isRawMode) {
          _rawController.text = _buildConsolidated();
        }
        setState(() => _isRawMode = !_isRawMode);
      },
      onSave: () {
        final result = _isRawMode
            ? _rawController.text.trim()
            : _buildConsolidated();
        Navigator.of(context).pop(result.isNotEmpty ? result : null);
      },
      guidedFields: [
        GuidedFactField(
          controller: _weekdays,
          label: 'Lunes a Viernes',
          hint: 'Ej. 8:00 AM a 6:00 PM',
        ),
        const SizedBox(height: 8),
        GuidedFactField(
          controller: _saturdays,
          label: 'Sábados',
          hint: 'Ej. 9:00 AM a 2:00 PM o Cerrado',
        ),
        const SizedBox(height: 8),
        GuidedFactField(
          controller: _sundays,
          label: 'Domingos y Festivos',
          hint: 'Ej. Cerrado o 10:00 AM a 2:00 PM',
        ),
        const SizedBox(height: 8),
        GuidedFactField(
          controller: _offHoursPolicy,
          label: 'Fuera de horario',
          hint: 'Ej. Responderemos a primera hora al abrir',
        ),
      ],
    );
  }
}
