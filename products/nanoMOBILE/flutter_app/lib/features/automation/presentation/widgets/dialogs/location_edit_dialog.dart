import 'package:flutter/material.dart';
import 'package:nanoai/features/automation/presentation/automation_visual_theme.dart';

/// Diálogo profesional para la configuración de ubicación, sede y dirección del negocio.
class LocationEditDialog extends StatefulWidget {
  final String initial;

  const LocationEditDialog({super.key, required this.initial});

  @override
  State<LocationEditDialog> createState() => _LocationEditDialogState();
}

class _LocationEditDialogState extends State<LocationEditDialog> {
  late final TextEditingController _modality;
  late final TextEditingController _address;
  late final TextEditingController _city;
  late final TextEditingController _reference;
  late final TextEditingController _notes;
  bool _isRawMode = false;
  late final TextEditingController _rawController;

  @override
  void initState() {
    super.initState();
    _rawController = TextEditingController(text: widget.initial);
    _initFromText(widget.initial);
  }

  void _initFromText(String text) {
    String mod = 'Tienda física y atención virtual';
    String addr = '';
    String c = '';
    String ref = '';
    final extra = <String>[];

    final clean = text.trim();
    if (clean.isNotEmpty) {
      final parts = clean.split(RegExp(r'\.\s+'));
      for (final p in parts) {
        final lower = p.toLowerCase();
        if (lower.startsWith('dirección:') || lower.startsWith('direccion:')) {
          addr = p.substring(p.indexOf(':') + 1).trim();
        } else if (lower.startsWith('ciudad:') || lower.startsWith('municipio:') || lower.startsWith('barrio:')) {
          c = p.substring(p.indexOf(':') + 1).trim();
        } else if (lower.startsWith('referencia:') || lower.startsWith('punto de referencia:')) {
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

    if (parts.isEmpty && widget.initial.trim().isNotEmpty) {
      return widget.initial.trim();
    }
    return parts.join('. ');
  }

  @override
  Widget build(BuildContext context) {
    final visual = AutomationVisual.of(context);

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 460, maxHeight: 650),
        decoration: BoxDecoration(
          color: visual.isDark ? const Color(0xFF0F172A) : Colors.white,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: visual.isDark
                ? Colors.white.withValues(alpha: 0.16)
                : const Color(0xFFCBD5E1),
            width: 1.2,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.35),
              blurRadius: 28,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 18, 14, 12),
              child: Row(
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: visual.accentSoft,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(Icons.location_on_outlined, color: visual.accent, size: 22),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Ubicación del Negocio',
                      style: TextStyle(
                        color: visual.text,
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.4,
                      ),
                    ),
                  ),
                  Tooltip(
                    message: _isRawMode ? 'Modo guiado' : 'Texto libre',
                    child: IconButton(
                      icon: Icon(_isRawMode ? Icons.view_list_rounded : Icons.edit_note_rounded, color: visual.accent),
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

            // Body
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: _isRawMode
                    ? Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Escribe la dirección y puntos de referencia exactamente como deseas que se comuniquen:',
                            style: TextStyle(color: visual.textMuted, fontSize: 13),
                          ),
                          const SizedBox(height: 12),
                          TextField(
                            controller: _rawController,
                            maxLines: 6,
                            style: TextStyle(color: visual.text, fontSize: 14),
                            decoration: InputDecoration(
                              hintText: 'Ej. Calle 10 # 40-20, El Poblado, Medellín. Cerca al parque principal.',
                              filled: true,
                              fillColor: visual.inputFill,
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(14),
                                borderSide: BorderSide.none,
                              ),
                            ),
                          ),
                        ],
                      )
                    : Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          TextField(
                            controller: _modality,
                            style: TextStyle(color: visual.text, fontSize: 13.5),
                            decoration: InputDecoration(
                              labelText: 'Modalidad (Física, Virtual, Ambas)',
                              filled: true,
                              fillColor: visual.inputFill,
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                              isDense: true,
                            ),
                          ),
                          const SizedBox(height: 10),
                          TextField(
                            controller: _address,
                            style: TextStyle(color: visual.text, fontSize: 13.5),
                            decoration: InputDecoration(
                              labelText: 'Dirección exacta',
                              hintText: 'Ej. Cra 43A # 1-50 Local 102',
                              filled: true,
                              fillColor: visual.inputFill,
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                              isDense: true,
                            ),
                          ),
                          const SizedBox(height: 10),
                          TextField(
                            controller: _city,
                            style: TextStyle(color: visual.text, fontSize: 13.5),
                            decoration: InputDecoration(
                              labelText: 'Ciudad y Barrio',
                              hintText: 'Ej. Medellín, El Poblado',
                              filled: true,
                              fillColor: visual.inputFill,
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                              isDense: true,
                            ),
                          ),
                          const SizedBox(height: 10),
                          TextField(
                            controller: _reference,
                            style: TextStyle(color: visual.text, fontSize: 13.5),
                            decoration: InputDecoration(
                              labelText: 'Punto de referencia o cómo llegar',
                              hintText: 'Ej. Frente a la estación del metro',
                              filled: true,
                              fillColor: visual.inputFill,
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                              isDense: true,
                            ),
                          ),
                          const SizedBox(height: 10),
                          TextField(
                            controller: _notes,
                            style: TextStyle(color: visual.text, fontSize: 13.5),
                            decoration: InputDecoration(
                              labelText: 'Notas adicionales (parqueadero, acceso)',
                              filled: true,
                              fillColor: visual.inputFill,
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                              isDense: true,
                            ),
                          ),
                        ],
                      ),
              ),
            ),

            const Divider(height: 1),
            // Actions
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    style: TextButton.styleFrom(
                      foregroundColor: visual.textMuted,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    ),
                    child: const Text('Cancelar'),
                  ),
                  const SizedBox(width: 8),
                  FilledButton(
                    onPressed: () {
                      final res = _isRawMode ? _rawController.text.trim() : _buildConsolidated();
                      Navigator.of(context).pop(res.isNotEmpty ? res : null);
                    },
                    style: FilledButton.styleFrom(
                      backgroundColor: visual.accent,
                      padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 10),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    child: const Text('Guardar'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
