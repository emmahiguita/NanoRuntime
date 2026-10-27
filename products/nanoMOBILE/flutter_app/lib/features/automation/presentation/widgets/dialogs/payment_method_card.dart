// payment_method_card.dart
//
// QUÉ HACE: presenta un método de pago y sus campos editables.
// CÓMO: expande los campos solo cuando el dueño activa el método.
// POR QUÉ: centraliza el estilo y evita duplicación en la vista guiada.

import 'package:flutter/material.dart';
import 'package:nanoai/features/automation/presentation/automation_visual_theme.dart';

class PaymentMethodCard extends StatelessWidget {
  const PaymentMethodCard({
    super.key,
    required this.visual,
    required this.title,
    required this.icon,
    required this.enabled,
    required this.onToggle,
    required this.fields,
  });

  final AutomationVisualPalette visual;
  final String title;
  final IconData icon;
  final bool enabled;
  final ValueChanged<bool> onToggle;
  final List<Widget> fields;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: visual.isDark
            ? Colors.white.withValues(alpha: 0.03)
            : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: enabled
              ? visual.accent.withValues(alpha: 0.35)
              : visual.outline.withValues(alpha: 0.18),
        ),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(
                icon,
                size: 18,
                color: enabled ? visual.accent : visual.textMuted,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: visual.text,
                  ),
                ),
              ),
              Switch(
                value: enabled,
                onChanged: onToggle,
                activeThumbColor: visual.accent,
              ),
            ],
          ),
          if (enabled) ...[
            const Divider(height: 8),
            const SizedBox(height: 4),
            ...fields,
          ],
        ],
      ),
    );
  }
}

class PaymentMethodField extends StatelessWidget {
  const PaymentMethodField(
    this.visual,
    this.label,
    this.initialValue,
    this.onChanged, {
    super.key,
    this.hint = '',
  });

  final AutomationVisualPalette visual;
  final String label;
  final String initialValue;
  final ValueChanged<String> onChanged;
  final String hint;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: TextFormField(
        initialValue: initialValue,
        onChanged: onChanged,
        style: TextStyle(color: visual.text, fontSize: 12),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: TextStyle(fontSize: 10.5, color: visual.textMuted),
          hintText: hint,
          hintStyle: TextStyle(
            fontSize: 10,
            color: visual.textMuted.withValues(alpha: 0.5),
          ),
          filled: true,
          fillColor: visual.inputFill,
          isDense: true,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 10,
            vertical: 8,
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide.none,
          ),
        ),
      ),
    );
  }
}
