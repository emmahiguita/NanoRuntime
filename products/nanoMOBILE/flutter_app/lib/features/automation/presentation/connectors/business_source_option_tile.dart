// QUÉ: representa una fuente importable en el panel comercial.
// CÓMO: usa una fila Material compacta con icono, descripción y categoría.
// POR QUÉ: separa presentación reutilizable del flujo de conexión.
library;

import 'package:flutter/material.dart';

import '../automation_visual_theme.dart';

class BusinessSourceOptionTile extends StatelessWidget {
  const BusinessSourceOptionTile({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.badge,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final String badge;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final visual = AutomationVisual.of(context);
    return ListTile(
      leading: Container(
        width: 38,
        height: 38,
        decoration: BoxDecoration(
          color: visual.accentSoft,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, color: visual.accent, size: 20),
      ),
      title: Text(
        title,
        style: TextStyle(
          color: visual.text,
          fontWeight: FontWeight.w600,
          fontSize: 13,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: TextStyle(color: visual.textMuted, fontSize: 11),
      ),
      trailing: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: visual.accentSoft,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          badge,
          style: TextStyle(
            color: visual.accent,
            fontSize: 10,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      onTap: onTap,
    );
  }
}
