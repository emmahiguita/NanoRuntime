import 'package:flutter/material.dart';
import 'package:nanoai/features/automation/presentation/automation_visual_theme.dart';

/// Diálogo profesional para la configuración de horarios de atención comercial.
class HoursEditDialog extends StatefulWidget {
  final String initial;

  const HoursEditDialog({super.key, required this.initial});

  @override
  State<HoursEditDialog> createState() => _HoursEditDialogState();
}

class _HoursEditDialogState extends State<HoursEditDialog> {
  late final TextEditingController _weekdays;
  late final TextEditingController _saturdays;
  late final TextEditingController _sundays;
  late final TextEditingController _offHoursPolicy;
  bool _isRawMode = false;
  late final TextEditingController _rawController;

  @override
  void initState() {
    super.initState();
    _rawController = TextEditingController(text: widget.initial);
    _initFromText(widget.initial);
  }

  void _initFromText(String text) {
    String wk = 'Lunes a Viernes de 8:00 AM a 6:00 PM';
    String sat = 'Sábados de 9:00 AM a 2:00 PM';
    String sun = 'Domingos y festivos: Cerrado';
    String offH = 'Fuera de horario puedes dejar tu mensaje y te responderemos a primera hora al abrir.';

    final clean = text.trim();
    if (clean.isNotEmpty) {
      final parts = clean.split(RegExp(r'\.\s+'));
      for (final p in parts) {
        final lower = p.toLowerCase();
        if (lower.contains('lunes a viernes') || lower.contains('semana') || lower.contains('l-v')) {
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
    final parts = <String>[];
    if (_weekdays.text.trim().isNotEmpty) parts.add(_weekdays.text.trim());
    if (_saturdays.text.trim().isNotEmpty) parts.add(_saturdays.text.trim());
    if (_sundays.text.trim().isNotEmpty) parts.add(_sundays.text.trim());
    if (_offHoursPolicy.text.trim().isNotEmpty) parts.add(_offHoursPolicy.text.trim());

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
                    child: Icon(Icons.schedule_outlined, color: visual.accent, size: 22),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Horario de Atención',
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

            // Content
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: _isRawMode
                    ? Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Indica el horario de apertura y cierre para que la IA responda adecuadamente a los clientes:',
                            style: TextStyle(color: visual.textMuted, fontSize: 13),
                          ),
                          const SizedBox(height: 12),
                          TextField(
                            controller: _rawController,
                            maxLines: 6,
                            style: TextStyle(color: visual.text, fontSize: 14),
                            decoration: InputDecoration(
                              hintText: 'Ej. Lunes a Sábado de 8:00 AM a 7:00 PM. Domingos y festivos cerrado.',
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
                            controller: _weekdays,
                            style: TextStyle(color: visual.text, fontSize: 13.5),
                            decoration: InputDecoration(
                              labelText: 'Lunes a Viernes',
                              hintText: 'Ej. 8:00 AM - 6:00 PM',
                              filled: true,
                              fillColor: visual.inputFill,
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                              isDense: true,
                            ),
                          ),
                          const SizedBox(height: 12),
                          TextField(
                            controller: _saturdays,
                            style: TextStyle(color: visual.text, fontSize: 13.5),
                            decoration: InputDecoration(
                              labelText: 'Sábados',
                              hintText: 'Ej. 9:00 AM - 2:00 PM',
                              filled: true,
                              fillColor: visual.inputFill,
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                              isDense: true,
                            ),
                          ),
                          const SizedBox(height: 12),
                          TextField(
                            controller: _sundays,
                            style: TextStyle(color: visual.text, fontSize: 13.5),
                            decoration: InputDecoration(
                              labelText: 'Domingos y Festivos',
                              hintText: 'Ej. Cerrado o 10:00 AM - 3:00 PM',
                              filled: true,
                              fillColor: visual.inputFill,
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                              isDense: true,
                            ),
                          ),
                          const SizedBox(height: 12),
                          TextField(
                            controller: _offHoursPolicy,
                            maxLines: 2,
                            style: TextStyle(color: visual.text, fontSize: 13.5),
                            decoration: InputDecoration(
                              labelText: 'Política o mensaje fuera de horario',
                              hintText: 'Ej. Deja tu mensaje y responderemos al iniciar labores.',
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
