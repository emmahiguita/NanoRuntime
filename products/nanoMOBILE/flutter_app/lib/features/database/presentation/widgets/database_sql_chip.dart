// QUÉ: botón compacto para insertar fragmentos SQL.
// CÓMO: aplica estilo monoespaciado y comunica el toque por callback.
// POR QUÉ: evita duplicar decoración dentro de la consola SQL.

import 'package:flutter/material.dart';

class DatabaseSqlChip extends StatelessWidget {
  final String label;
  final VoidCallback? onTap;
  const DatabaseSqlChip({super.key, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    borderRadius: BorderRadius.circular(4),
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: Colors.grey.withValues(alpha: onTap == null ? 0.05 : 0.12),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontFamily: 'JetBrainsMono',
          fontSize: 10,
          fontWeight: FontWeight.w600,
          color: onTap == null ? Theme.of(context).disabledColor : null,
        ),
      ),
    ),
  );
}
