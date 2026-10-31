// product_dialog_header.dart
//
// QUÉ HACE:
// Encabezado del diálogo de producto con icono temático, título y botón de cierre.
//
// CÓMO FUNCIONA:
// - Despliega icono de bolsa/edición con fondo esmeralda sutil.
// - Muestra título ("Editar producto" / "Nuevo producto") y subtítulo explicativo.
// - Botón circular de cierre en el extremo derecho.
//
// POR QUÉ:
// Separa el encabezado visual del diálogo para mantener la regla de < 200 líneas (< 90 líneas).

library;

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import '../../automation_visual_theme.dart';

class ProductDialogHeader extends StatelessWidget {
  const ProductDialogHeader({
    super.key,
    required this.isEditing,
    required this.onClose,
  });

  final bool isEditing;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final visual = AutomationVisual.of(context);
    final isDark = visual.isDark;

    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 14, 14, 10),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: const Color(0xFF10B981).withValues(alpha: isDark ? 0.22 : 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              isEditing ? CupertinoIcons.pencil : CupertinoIcons.bag_fill,
              color: const Color(0xFF10B981),
              size: 19,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  isEditing ? 'Editar producto' : 'Nuevo producto',
                  style: TextStyle(
                    color: visual.text,
                    fontSize: 16.5,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.3,
                  ),
                ),
                Text(
                  isEditing ? 'Actualiza los datos del catálogo' : 'Ingresa la información comercial',
                  style: TextStyle(
                    color: visual.textMuted,
                    fontSize: 11,
                    fontWeight: FontWeight.w400,
                  ),
                ),
              ],
            ),
          ),
          CupertinoButton(
            onPressed: onClose,
            minimumSize: const Size.square(32),
            padding: EdgeInsets.zero,
            child: Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.05),
                shape: BoxShape.circle,
              ),
              child: Icon(CupertinoIcons.xmark, size: 14, color: visual.text),
            ),
          ),
        ],
      ),
    );
  }
}
