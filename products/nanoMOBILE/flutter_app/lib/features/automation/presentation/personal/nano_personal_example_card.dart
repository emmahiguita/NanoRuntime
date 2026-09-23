/// NANO-PERSONAL-EXAMPLE-CARD — Tarjeta rica y profesional de Frase e Intención Aprendida.
/// Muestra categoría, mensaje de entrada con variantes, opciones rotativas y acciones directas.
library;

import 'package:flutter/material.dart';
import '../../personal_agent/domain/persona_example.dart';
import '../automation_visual_theme.dart';

class NanoPersonalExampleCard extends StatefulWidget {
  final PersonaExample example;
  final ValueChanged<bool>? onToggleEnabled;
  final VoidCallback? onEdit, onAddResponse, onDelete;

  const NanoPersonalExampleCard({
    super.key,
    required this.example,
    this.onToggleEnabled,
    this.onEdit,
    this.onAddResponse,
    this.onDelete,
  });

  @override
  State<NanoPersonalExampleCard> createState() => _NanoPersonalExampleCardState();
}

class _NanoPersonalExampleCardState extends State<NanoPersonalExampleCard> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final visual = AutomationVisual.of(context);
    final ex = widget.example;
    final isEn = ex.enabled;
    final responses = ex.responseOptions;
    final total = responses.length;
    final visibleCount = _expanded ? total : (total > 3 ? 3 : total);
    final otherInVars = ex.incomingVariants.where((v) => v != ex.displayTrigger).toList();
    final tag = ex.category.split('·').first.trim();

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: visual.surface.withValues(alpha: isEn ? 0.75 : 0.35),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isEn ? visual.accent.withValues(alpha: 0.35) : visual.outline.withValues(alpha: 0.15),
          width: 0.9,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Cabecera: Etiqueta + Estado Switch
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(
                  color: visual.accent.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: visual.accent.withValues(alpha: 0.3), width: 0.6),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.label_outline_rounded, size: 11, color: visual.accent),
                    const SizedBox(width: 4),
                    Text(tag, style: TextStyle(fontSize: 9.5, color: visual.accent, fontWeight: FontWeight.w700)),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Text('$total ${total == 1 ? 'respuesta' : 'respuestas'}', style: TextStyle(fontSize: 10, color: visual.textMuted)),
              const Spacer(),
              SizedBox(height: 22, child: Switch(value: isEn, onChanged: widget.onToggleEnabled)),
            ],
          ),
          const SizedBox(height: 8),

          // Sección Entrada
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('📥 ', style: TextStyle(fontSize: 12)),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      ex.displayTrigger,
                      style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.bold, color: visual.text),
                    ),
                    if (otherInVars.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Text(
                          'O también: “${otherInVars.take(2).join('”, “')}”${otherInVars.length > 2 ? ' ...' : ''}',
                          style: TextStyle(fontSize: 10.5, fontStyle: FontStyle.italic, color: visual.textMuted),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          const Divider(height: 1, color: Colors.white10),
          const SizedBox(height: 8),

          // Sección Salida (Respuestas rotativas)
          Text('📤 Nano responderá con:', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: visual.textMuted)),
          const SizedBox(height: 4),
          for (int i = 0; i < visibleCount; i++)
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('• ', style: TextStyle(color: visual.accent, fontSize: 13, fontWeight: FontWeight.bold)),
                  Expanded(
                    child: Text(
                      '“${responses[i].text}”',
                      style: TextStyle(
                        fontSize: 11.5,
                        height: 1.25,
                        color: responses[i].enabled ? visual.text.withValues(alpha: 0.90) : visual.textMuted,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ),
                  if (responses[i].tone.isNotEmpty && responses[i].tone != 'cotidiana')
                    Container(
                      margin: const EdgeInsets.only(left: 6),
                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                      decoration: BoxDecoration(
                        color: visual.accent.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(color: visual.accent.withValues(alpha: 0.35), width: 0.5),
                      ),
                      child: Text(
                        responses[i].tone,
                        style: TextStyle(fontSize: 8.5, color: visual.accent, fontWeight: FontWeight.w600),
                      ),
                    ),
                ],
              ),
            ),
          if (total > 3)
            InkWell(
              onTap: () => setState(() => _expanded = !_expanded),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Text(
                  _expanded ? '▲ Mostrar menos' : '+${total - 3} respuestas más...',
                  style: const TextStyle(fontSize: 10, color: Color(0xFFFFD54F), fontWeight: FontWeight.w700),
                ),
              ),
            ),
          const SizedBox(height: 6),

          // Botones de acción
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              _btn('Editar', Icons.edit_outlined, const Color(0xFF81C784), widget.onEdit),
              const SizedBox(width: 10),
              _btn('+ Respuesta', Icons.add_circle_outline, visual.accent, widget.onAddResponse),
              const SizedBox(width: 10),
              _btn('Eliminar', Icons.delete_outline, const Color(0xFFE57373), widget.onDelete),
            ],
          ),
        ],
      ),
    );
  }

  Widget _btn(String label, IconData icon, Color color, VoidCallback? onTap) {
    return InkWell(
      borderRadius: BorderRadius.circular(6),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 12, color: color),
            const SizedBox(width: 4),
            Text(label, style: TextStyle(fontSize: 10.5, color: color, fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }
}
