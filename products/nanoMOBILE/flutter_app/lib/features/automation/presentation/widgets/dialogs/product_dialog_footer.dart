// product_dialog_footer.dart
//
// QUÉ HACE:
// Barra de acciones inferior fija para guardar o cancelar en el diálogo de producto.
//
// CÓMO FUNCIONA:
// - Botón de texto sutil 'Cancelar' y botón esmeralda prominente 'Guardar producto'.
// - Adaptable al teclado y con feedback visual inmediato.
//
// POR QUÉ:
// Separa las acciones inferiores cumpliendo con la regla de < 200 líneas (< 80 líneas).

library;

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import '../../automation_visual_theme.dart';

class ProductDialogFooter extends StatelessWidget {
  const ProductDialogFooter({
    super.key,
    required this.isEditing,
    required this.onCancel,
    required this.onSave,
  });

  final bool isEditing;
  final VoidCallback onCancel;
  final VoidCallback onSave;

  @override
  Widget build(BuildContext context) {
    final visual = AutomationVisual.of(context);

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
      child: Row(
        children: [
          Expanded(
            child: CupertinoButton(
              onPressed: onCancel,
              padding: const EdgeInsets.symmetric(vertical: 10),
              child: Text(
                'Cancelar',
                style: TextStyle(
                  color: visual.textMuted,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            flex: 2,
            child: CupertinoButton(
              onPressed: onSave,
              padding: const EdgeInsets.symmetric(vertical: 11),
              color: const Color(0xFF10B981),
              borderRadius: BorderRadius.circular(12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    isEditing ? CupertinoIcons.check_mark : CupertinoIcons.plus,
                    size: 16,
                    color: Colors.white,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    isEditing ? 'Actualizar producto' : 'Guardar producto',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
