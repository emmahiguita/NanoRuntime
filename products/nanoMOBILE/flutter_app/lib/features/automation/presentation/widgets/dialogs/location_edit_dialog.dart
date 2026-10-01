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
import 'guided_fact_dialog.dart';

class LocationEditDialog extends StatefulWidget {
  final String initial;
  const LocationEditDialog({super.key, required this.initial});

  @override
  State<LocationEditDialog> createState() => _LocationEditDialogState();
}

class _LocationEditDialogState extends State<LocationEditDialog> {
  late final TextEditingController _modality,
      _address,
      _city,
      _reference,
      _notes,
      _rawController;
  bool _isRawMode = false;

  @override
  void initState() {
    super.initState();
    _rawController = TextEditingController(text: widget.initial);
    _initFromText(widget.initial);
  }

  void _initFromText(String text) {
    String mod = 'Tienda física y atención virtual',
        addr = '',
        c = '',
        ref = '';
    final extra = <String>[];
    final clean = text.trim();
    if (clean.isNotEmpty) {
      for (final p in clean.split(RegExp(r'\.\s+'))) {
        final lower = p.toLowerCase();
        if (lower.startsWith('dirección:') || lower.startsWith('direccion:')) {
          addr = p.substring(p.indexOf(':') + 1).trim();
        } else if (lower.startsWith('ciudad:') ||
            lower.startsWith('municipio:')) {
          c = p.substring(p.indexOf(':') + 1).trim();
        } else if (lower.startsWith('referencia:')) {
          ref = p.substring(p.indexOf(':') + 1).trim();
        } else if (lower.contains('virtual') ||
            lower.contains('física') ||
            lower.contains('fisica')) {
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
    if (_modality.text.trim().isNotEmpty) {
      parts.add(_modality.text.trim());
    }
    if (_address.text.trim().isNotEmpty) {
      parts.add('Dirección: ${_address.text.trim()}');
    }
    if (_city.text.trim().isNotEmpty) {
      parts.add('Ciudad: ${_city.text.trim()}');
    }
    if (_reference.text.trim().isNotEmpty) {
      parts.add('Referencia: ${_reference.text.trim()}');
    }
    if (_notes.text.trim().isNotEmpty) {
      parts.add(_notes.text.trim());
    }
    return parts.isEmpty ? widget.initial.trim() : parts.join('. ');
  }

  @override
  Widget build(BuildContext context) {
    return GuidedFactDialog(
      title: 'Ubicación y Sede',
      icon: Icons.place_rounded,
      isRawMode: _isRawMode,
      rawController: _rawController,
      rawHint:
          'Ej. Calle 10 # 40-20, El Poblado, Medellín. Atención virtual a todo el país.',
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
          controller: _modality,
          label: 'Modalidad de atención',
          hint: 'Ej. Tienda física y virtual',
        ),
        const SizedBox(height: 8),
        GuidedFactField(
          controller: _address,
          label: 'Dirección',
          hint: 'Ej. Cra 43A # 1-50 Local 102',
        ),
        const SizedBox(height: 8),
        GuidedFactField(
          controller: _city,
          label: 'Ciudad / Municipio',
          hint: 'Ej. Medellín, Antioquia',
        ),
        const SizedBox(height: 8),
        GuidedFactField(
          controller: _reference,
          label: 'Puntos de referencia',
          hint: 'Ej. Al lado del parque principal',
        ),
        const SizedBox(height: 8),
        GuidedFactField(
          controller: _notes,
          label: 'Notas de llegada o parqueo',
          hint: 'Ej. Contamos con parqueadero gratuito',
        ),
      ],
    );
  }
}
