// delivery_edit_dialog.dart
//
// QUÉ HACE:
// Diálogo profesional con Material Expressive 3 para configuración de envíos, domicilios y logística.
//
// CÓMO FUNCIONA:
// - Provee modo guiado por campos clave (cobertura, tiempos, tarifas, transportadora) o texto libre.
// - Emplea DialogContainerShell para adaptación responsiva fluida en modo Landscape y Portrait (< 160 líneas).
//
// POR QUÉ:
// Asegura que los formularios logísticos quepan ordenadamente en cualquier orientación sin overflows (SOLID - SRP).

import 'package:flutter/material.dart';
import 'package:nanoai/features/automation/presentation/automation_visual_theme.dart';
import 'dialog_container_shell.dart';

class DeliveryEditDialog extends StatefulWidget {
  final String initial;
  const DeliveryEditDialog({super.key, required this.initial});

  @override
  State<DeliveryEditDialog> createState() => _DeliveryEditDialogState();
}

class _DeliveryEditDialogState extends State<DeliveryEditDialog> {
  late final TextEditingController _coverage, _estimatedTime, _costPolicy, _carrier, _rawController;
  bool _isRawMode = false;

  @override
  void initState() {
    super.initState();
    _rawController = TextEditingController(text: widget.initial);
    _initFromText(widget.initial);
  }

  void _initFromText(String text) {
    String cov = 'Envíos a todo el país y domicilios locales', time = 'Locales el mismo día; nacionales de 2 a 3 días hábiles';
    String cost = 'Tarifa fija o gratis por compras superiores a cierto monto', car = 'Mensajería local y transportadora nacional';

    final clean = text.trim();
    if (clean.isNotEmpty) {
      for (final p in clean.split(RegExp(r'\.\s+'))) {
        final lower = p.toLowerCase();
        if (lower.contains('tiempo') || lower.contains('días') || lower.contains('horas')) {
          time = p.replaceFirst(RegExp(r'tiempo estimado:\s*', caseSensitive: false), '').trim();
        } else if (lower.contains('costo') || lower.contains('tarifa') || lower.contains('gratis')) {
          cost = p.replaceFirst(RegExp(r'costos:\s*', caseSensitive: false), '').trim();
        } else if (lower.contains('operado') || lower.contains('transportadora') || lower.contains('mensajería')) {
          car = p.replaceFirst(RegExp(r'operado por:\s*', caseSensitive: false), '').trim();
        } else if (lower.contains('cobertura') || lower.contains('envíos') || lower.contains('domicilio')) {
          cov = p.trim();
        }
      }
    }
    _coverage = TextEditingController(text: cov);
    _estimatedTime = TextEditingController(text: time);
    _costPolicy = TextEditingController(text: cost);
    _carrier = TextEditingController(text: car);
  }

  @override
  void dispose() {
    _coverage.dispose();
    _estimatedTime.dispose();
    _costPolicy.dispose();
    _carrier.dispose();
    _rawController.dispose();
    super.dispose();
  }

  String _buildConsolidated() {
    final parts = <String>[];
    if (_coverage.text.trim().isNotEmpty) parts.add(_coverage.text.trim());
    if (_estimatedTime.text.trim().isNotEmpty) parts.add('Tiempo estimado: ${_estimatedTime.text.trim()}');
    if (_costPolicy.text.trim().isNotEmpty) parts.add('Costos: ${_costPolicy.text.trim()}');
    if (_carrier.text.trim().isNotEmpty) parts.add('Operado por: ${_carrier.text.trim()}');
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
                  child: Icon(Icons.local_shipping_rounded, color: visual.accent, size: 20),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text('Envíos y Domicilios', style: TextStyle(color: visual.text, fontSize: 16, fontWeight: FontWeight.bold)),
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
                        hintText: 'Ej. Domicilios en el área metropolitana por \$8.000. Envíos nacionales por \$15.000 (Interrapidísimo/Envía)...',
                        filled: true,
                        fillColor: visual.inputFill,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                      ),
                    )
                  : Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _field(_coverage, 'Cobertura de entregas', visual, hint: 'Ej. Local y nacional a toda Colombia'),
                        const SizedBox(height: 8),
                        _field(_estimatedTime, 'Tiempo estimado de entrega', visual, hint: 'Ej. 24 a 48 horas hábiles'),
                        const SizedBox(height: 8),
                        _field(_costPolicy, 'Tarifas y condiciones', visual, hint: 'Ej. Gratis por compras mayores a \$100.000'),
                        const SizedBox(height: 8),
                        _field(_carrier, 'Transportadora o mensajería', visual, hint: 'Ej. Domiciliarios propios e Interrapidísimo'),
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
