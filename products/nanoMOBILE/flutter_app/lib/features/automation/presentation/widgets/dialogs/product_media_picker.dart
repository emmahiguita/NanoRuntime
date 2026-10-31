// product_media_picker.dart
//
// QUÉ HACE:
// Selector y vista previa de multimedia (foto o video) para el producto.
//
// CÓMO FUNCIONA:
// - Muestra miniatura de 60×60 dp con bordes suaves si hay archivo seleccionado.
// - Botón 'Añadir fotografía del producto' con icono de cámara en estado vacío.
//
// POR QUÉ:
// Separa el componente multimedia del formulario cumpliendo la regla de < 200 líneas (< 90 líneas).

library;

import 'dart:io';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import '../../automation_visual_theme.dart';

class ProductMediaPicker extends StatelessWidget {
  const ProductMediaPicker({
    super.key,
    required this.imagePath,
    required this.onPickMedia,
    required this.onRemoveMedia,
    required this.visual,
    required this.isDark,
  });

  final String? imagePath;
  final VoidCallback onPickMedia;
  final VoidCallback onRemoveMedia;
  final AutomationVisualPalette visual;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    final hasMedia = imagePath != null && imagePath!.isNotEmpty;
    final isAsset = hasMedia && imagePath!.startsWith('assets/');
    final isFile = hasMedia && !isAsset && File(imagePath!).existsSync();

    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: isDark ? Colors.white12 : const Color(0xFFE2E8F0)),
      ),
      padding: const EdgeInsets.all(8),
      child: hasMedia
          ? Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: SizedBox(
                    width: 60,
                    height: 60,
                    child: isAsset
                        ? Image.asset(imagePath!, fit: BoxFit.cover)
                        : (isFile ? Image.file(File(imagePath!), fit: BoxFit.cover) : const Icon(Icons.image)),
                  ),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text('Foto del producto seleccionada', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                ),
                CupertinoButton(
                  padding: EdgeInsets.zero,
                  onPressed: onPickMedia,
                  child: const Text('Cambiar', style: TextStyle(fontSize: 12)),
                ),
                IconButton(icon: const Icon(Icons.close, size: 18), onPressed: onRemoveMedia),
              ],
            )
          : InkWell(
              onTap: onPickMedia,
              borderRadius: BorderRadius.circular(10),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(CupertinoIcons.camera, color: Color(0xFF10B981), size: 20),
                    const SizedBox(width: 8),
                    Text('Añadir fotografía del producto', style: TextStyle(color: isDark ? Colors.white : const Color(0xFF0F172A), fontSize: 13, fontWeight: FontWeight.w600)),
                  ],
                ),
              ),
            ),
    );
  }
}
