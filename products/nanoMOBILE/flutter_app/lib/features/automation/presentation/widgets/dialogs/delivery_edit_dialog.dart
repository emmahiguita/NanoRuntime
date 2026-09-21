import 'package:flutter/material.dart';
import 'package:nanoai/features/automation/presentation/automation_visual_theme.dart';

/// Diálogo profesional para la configuración de envíos, domicilios y logística.
class DeliveryEditDialog extends StatefulWidget {
  final String initial;

  const DeliveryEditDialog({super.key, required this.initial});

  @override
  State<DeliveryEditDialog> createState() => _DeliveryEditDialogState();
}

class _DeliveryEditDialogState extends State<DeliveryEditDialog> {
  late final TextEditingController _coverage;
  late final TextEditingController _estimatedTime;
  late final TextEditingController _costPolicy;
  late final TextEditingController _carrier;
  bool _isRawMode = false;
  late final TextEditingController _rawController;

  @override
  void initState() {
    super.initState();
    _rawController = TextEditingController(text: widget.initial);
    _initFromText(widget.initial);
  }

  void _initFromText(String text) {
    String cov = 'Envíos a todo el país y domicilios locales';
    String time = 'Locales el mismo día; nacionales de 2 a 3 días hábiles';
    String cost = 'Tarifa fija o gratis por compras superiores a cierto monto';
    String car = 'Mensajería local y transportadora nacional';

    final clean = text.trim();
    if (clean.isNotEmpty) {
      final parts = clean.split(RegExp(r'\.\s+'));
      for (final p in parts) {
        final lower = p.toLowerCase();
        if (lower.contains('tiempo estimado') || lower.contains('días') || lower.contains('dias') || lower.contains('horas')) {
          time = p.replaceFirst(RegExp(r'tiempo estimado:\s*', caseSensitive: false), '').trim();
        } else if (lower.contains('costo') || lower.contains('tarifa') || lower.contains('gratis')) {
          cost = p.replaceFirst(RegExp(r'costos:\s*', caseSensitive: false), '').trim();
        } else if (lower.contains('operado por') || lower.contains('transportadora') || lower.contains('mensajería') || lower.contains('mensajeria')) {
          car = p.replaceFirst(RegExp(r'operado por:\s*', caseSensitive: false), '').trim();
        } else if (lower.contains('cobertura') || lower.contains('envíos') || lower.contains('envios') || lower.contains('domicilio')) {
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
                    child: Icon(Icons.local_shipping_outlined, color: visual.accent, size: 22),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Envíos y Domicilios',
                      style: TextStyle(
                        color: visual.text,
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.4,
                      ),
                    ),
                  ),
                  // Semantics en lugar de Tooltip: previene el fallo "No Overlay" (cajas rojas con texto amarillo)
                  // al evitar llamadas a Overlay.of(context) en sub-árboles de diálogo.
                  Semantics(
                    label: _isRawMode ? 'Modo guiado' : 'Texto libre',
                    button: true,
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
                            'Configura las condiciones de entrega para que el asistente informe tiempos y precios de envío:',
                            style: TextStyle(color: visual.textMuted, fontSize: 13),
                          ),
                          const SizedBox(height: 12),
                          TextField(
                            controller: _rawController,
                            maxLines: 6,
                            style: TextStyle(color: visual.text, fontSize: 14),
                            decoration: InputDecoration(
                              hintText: 'Ej. Domicilios en el área metropolitana \$8.000. Gratis por compras > \$100.000.',
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
                            controller: _coverage,
                            style: TextStyle(color: visual.text, fontSize: 13.5),
                            decoration: InputDecoration(
                              labelText: 'Cobertura (ej. Nacional, Área metropolitana)',
                              filled: true,
                              fillColor: visual.inputFill,
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                              isDense: true,
                            ),
                          ),
                          const SizedBox(height: 12),
                          TextField(
                            controller: _estimatedTime,
                            style: TextStyle(color: visual.text, fontSize: 13.5),
                            decoration: InputDecoration(
                              labelText: 'Tiempo estimado de entrega',
                              hintText: 'Ej. 1 a 2 horas o 24-48 horas hábiles',
                              filled: true,
                              fillColor: visual.inputFill,
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                              isDense: true,
                            ),
                          ),
                          const SizedBox(height: 12),
                          TextField(
                            controller: _costPolicy,
                            style: TextStyle(color: visual.text, fontSize: 13.5),
                            decoration: InputDecoration(
                              labelText: 'Tarifas y condiciones de envío gratis',
                              hintText: 'Ej. \$10.000 fijo o gratis a partir de \$150.000',
                              filled: true,
                              fillColor: visual.inputFill,
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                              isDense: true,
                            ),
                          ),
                          const SizedBox(height: 12),
                          TextField(
                            controller: _carrier,
                            style: TextStyle(color: visual.text, fontSize: 13.5),
                            decoration: InputDecoration(
                              labelText: 'Operador logístico / Empresa de mensajería',
                              hintText: 'Ej. Envía, Servientrega, Mensajeros Urbanos',
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
