// product_dialog_form.dart
//
// QUÉ: Presenta los campos editables de producto/servicio incluyendo foto o video.
// CÓMO: Usa scroll, preview multimedia y campos compactos para portrait y landscape.
// POR QUÉ: Evita overflow y deja al diálogo principal solo la validación (< 175 líneas).

library;

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../automation_visual_theme.dart';

class ProductDialogForm extends StatelessWidget {
  const ProductDialogForm({
    super.key,
    required this.name,
    required this.details,
    required this.price,
    required this.stock,
    required this.sku,
    required this.category,
    required this.variants,
    required this.isAvailable,
    required this.onAvailabilityChanged,
    this.imagePath,
    required this.onPickMedia,
    required this.onRemoveMedia,
    this.error,
  });

  final TextEditingController name, details, price, stock, sku, category, variants;
  final bool isAvailable;
  final ValueChanged<bool> onAvailabilityChanged;
  final String? imagePath;
  final VoidCallback onPickMedia;
  final VoidCallback onRemoveMedia;
  final String? error;

  @override
  Widget build(BuildContext context) {
    final visual = AutomationVisual.of(context);
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _mediaPicker(visual),
          const SizedBox(height: 10),
          _field(name, 'Nombre del producto *', visual),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(child: _field(category, 'Categoría', visual)),
              const SizedBox(width: 8),
              Expanded(child: _field(sku, 'SKU / Ref', visual)),
            ],
          ),
          const SizedBox(height: 8),
          _field(details, 'Descripción o ficha técnica', visual, maxLines: 2),
          const SizedBox(height: 8),
          _field(variants, 'Variantes separadas por coma', visual),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(flex: 3, child: _field(price, 'Precio *', visual, numeric: true)),
              const SizedBox(width: 8),
              Expanded(flex: 2, child: _field(stock, 'Stock', visual, numeric: true)),
            ],
          ),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(color: visual.inputFill, borderRadius: BorderRadius.circular(10)),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    'Disponible para WhatsApp y Tienda',
                    style: TextStyle(color: visual.text, fontSize: 11.5, fontWeight: FontWeight.w600),
                  ),
                ),
                Switch.adaptive(value: isAvailable, activeTrackColor: visual.accent, onChanged: onAvailabilityChanged),
              ],
            ),
          ),
          if (error != null) ...[
            const SizedBox(height: 8),
            Text(error!, style: const TextStyle(color: Colors.redAccent, fontSize: 11, fontWeight: FontWeight.w600)),
          ],
        ],
      ),
    );
  }

  Widget _mediaPicker(AutomationVisualPalette visual) {
    final hasMedia = imagePath != null && imagePath!.isNotEmpty;
    final isAsset = hasMedia && imagePath!.startsWith('assets/');
    final isFile = hasMedia && !isAsset && File(imagePath!).existsSync();

    return InkWell(
      onTap: onPickMedia,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        height: 72,
        decoration: BoxDecoration(
          color: visual.inputFill,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: visual.accent.withValues(alpha: 0.3)),
        ),
        clipBehavior: Clip.antiAlias,
        child: hasMedia
            ? Row(
                children: [
                  SizedBox(
                    width: 72,
                    height: 72,
                    child: isAsset
                        ? Image.asset(imagePath!, fit: BoxFit.cover)
                        : (isFile ? Image.file(File(imagePath!), fit: BoxFit.cover) : const Icon(Icons.image)),
                  ),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Text('Foto / Video adjuntado', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600)),
                  ),
                  IconButton(icon: const Icon(Icons.close, size: 18), onPressed: onRemoveMedia),
                ],
              )
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.add_photo_alternate_outlined, color: visual.accent, size: 20),
                  const SizedBox(width: 8),
                  Text('Adjuntar Foto o Video del Producto', style: TextStyle(color: visual.accent, fontSize: 12, fontWeight: FontWeight.w600)),
                ],
              ),
      ),
    );
  }

  Widget _field(
    TextEditingController controller,
    String label,
    AutomationVisualPalette visual, {
    int maxLines = 1,
    bool numeric = false,
  }) => TextField(
    controller: controller,
    maxLines: maxLines,
    keyboardType: numeric ? TextInputType.number : TextInputType.text,
    inputFormatters: numeric ? [FilteringTextInputFormatter.digitsOnly] : null,
    style: TextStyle(color: visual.text, fontSize: 12.5),
    decoration: InputDecoration(
      labelText: label,
      labelStyle: TextStyle(fontSize: 11, color: visual.textMuted),
      filled: true,
      fillColor: visual.inputFill,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
      isDense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
    ),
  );
}
