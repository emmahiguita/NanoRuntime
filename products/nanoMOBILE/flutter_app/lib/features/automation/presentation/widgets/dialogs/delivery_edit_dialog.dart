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
import 'guided_fact_dialog.dart';

class DeliveryEditDialog extends StatefulWidget {
  final String initial;
  const DeliveryEditDialog({super.key, required this.initial});

  @override
  State<DeliveryEditDialog> createState() => _DeliveryEditDialogState();
}

class _DeliveryEditDialogState extends State<DeliveryEditDialog> {
  late final TextEditingController _coverage,
      _estimatedTime,
      _costPolicy,
      _carrier,
      _rawController;
  bool _isRawMode = false;

  @override
  void initState() {
    super.initState();
    _rawController = TextEditingController(text: widget.initial);
    _initFromText(widget.initial);
  }

  void _initFromText(String text) {
    String cov = 'Envíos a todo el país y domicilios locales',
        time = 'Locales el mismo día; nacionales de 2 a 3 días hábiles';
    String cost = 'Tarifa fija o gratis por compras superiores a cierto monto',
        car = 'Mensajería local y transportadora nacional';

    final clean = text.trim();
    if (clean.isNotEmpty) {
      for (final p in clean.split(RegExp(r'\.\s+'))) {
        final lower = p.toLowerCase();
        if (lower.contains('tiempo') ||
            lower.contains('días') ||
            lower.contains('horas')) {
          time = p
              .replaceFirst(
                RegExp(r'tiempo estimado:\s*', caseSensitive: false),
                '',
              )
              .trim();
        } else if (lower.contains('costo') ||
            lower.contains('tarifa') ||
            lower.contains('gratis')) {
          cost = p
              .replaceFirst(RegExp(r'costos:\s*', caseSensitive: false), '')
              .trim();
        } else if (lower.contains('operado') ||
            lower.contains('transportadora') ||
            lower.contains('mensajería')) {
          car = p
              .replaceFirst(
                RegExp(r'operado por:\s*', caseSensitive: false),
                '',
              )
              .trim();
        } else if (lower.contains('cobertura') ||
            lower.contains('envíos') ||
            lower.contains('domicilio')) {
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
    if (_coverage.text.trim().isNotEmpty) {
      parts.add(_coverage.text.trim());
    }
    if (_estimatedTime.text.trim().isNotEmpty) {
      parts.add('Tiempo estimado: ${_estimatedTime.text.trim()}');
    }
    if (_costPolicy.text.trim().isNotEmpty) {
      parts.add('Costos: ${_costPolicy.text.trim()}');
    }
    if (_carrier.text.trim().isNotEmpty) {
      parts.add('Operado por: ${_carrier.text.trim()}');
    }
    return parts.isEmpty ? widget.initial.trim() : parts.join('. ');
  }

  @override
  Widget build(BuildContext context) {
    return GuidedFactDialog(
      title: 'Envíos y Domicilios',
      icon: Icons.local_shipping_rounded,
      isRawMode: _isRawMode,
      rawController: _rawController,
      rawHint:
          'Ej. Domicilios locales con tarifa informada por el negocio. Envíos nacionales con plazo confirmado.',
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
          controller: _coverage,
          label: 'Cobertura de entregas',
          hint: 'Ej. Local y nacional a toda Colombia',
        ),
        const SizedBox(height: 8),
        GuidedFactField(
          controller: _estimatedTime,
          label: 'Tiempo estimado de entrega',
          hint: 'Ej. 24 a 48 horas hábiles',
        ),
        const SizedBox(height: 8),
        GuidedFactField(
          controller: _costPolicy,
          label: 'Tarifas y condiciones',
          hint: 'Ej. Se confirma la tarifa antes de despachar',
        ),
        const SizedBox(height: 8),
        GuidedFactField(
          controller: _carrier,
          label: 'Transportadora o mensajería',
          hint: 'Ej. Domiciliarios propios o transportadora registrada',
        ),
      ],
    );
  }
}
