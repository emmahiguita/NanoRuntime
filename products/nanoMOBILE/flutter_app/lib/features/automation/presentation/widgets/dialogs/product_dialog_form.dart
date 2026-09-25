// QUÉ: presenta los campos editables de producto/servicio.
// CÓMO: usa scroll y campos compactos para portrait, landscape y teclado abierto.
// POR QUÉ: evita overflow y deja al diálogo principal solo la validación.
library;

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
    this.error,
  });

  final TextEditingController name;
  final TextEditingController details;
  final TextEditingController price;
  final TextEditingController stock;
  final TextEditingController sku;
  final TextEditingController category;
  final TextEditingController variants;
  final bool isAvailable;
  final ValueChanged<bool> onAvailabilityChanged;
  final String? error;

  @override
  Widget build(BuildContext context) {
    final visual = AutomationVisual.of(context);
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
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
          _field(details, 'Descripción o ingredientes', visual, maxLines: 2),
          const SizedBox(height: 8),
          _field(variants, 'Variantes separadas por coma', visual),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                flex: 3,
                child: _field(price, 'Precio *', visual, numeric: true),
              ),
              const SizedBox(width: 8),
              Expanded(
                flex: 2,
                child: _field(stock, 'Stock', visual, numeric: true),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: visual.inputFill,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    'Publicado / Disponible para WhatsApp',
                    style: TextStyle(
                      color: visual.text,
                      fontSize: 11.5,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                Switch.adaptive(
                  value: isAvailable,
                  activeTrackColor: visual.accent,
                  onChanged: onAvailabilityChanged,
                ),
              ],
            ),
          ),
          if (error != null) ...[
            const SizedBox(height: 8),
            Text(
              error!,
              style: const TextStyle(
                color: Colors.redAccent,
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ],
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
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide.none,
      ),
      isDense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
    ),
  );
}
