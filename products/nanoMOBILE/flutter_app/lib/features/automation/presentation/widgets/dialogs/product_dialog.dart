// QUÉ: crea o edita un producto real del catálogo comercial.
// CÓMO: valida identidad y precio, y delega los campos al formulario responsivo.
// POR QUÉ: mantiene persistencia y presentación separadas en archivos pequeños.
library;

import 'package:flutter/material.dart';

import '../../../engine/business/business_facts.dart';
import '../../automation_visual_theme.dart';
import 'dialog_container_shell.dart';
import 'product_dialog_form.dart';

class ProductDialog extends StatefulWidget {
  const ProductDialog({super.key, this.initial});

  final BusinessProduct? initial;

  @override
  State<ProductDialog> createState() => _ProductDialogState();
}

class _ProductDialogState extends State<ProductDialog> {
  late final TextEditingController _name;
  late final TextEditingController _details;
  late final TextEditingController _price;
  late final TextEditingController _stock;
  late final TextEditingController _sku;
  late final TextEditingController _category;
  late final TextEditingController _variants;
  late bool _isAvailable;
  String? _error;

  @override
  void initState() {
    super.initState();
    final product = widget.initial;
    _name = TextEditingController(text: product?.name ?? '');
    _details = TextEditingController(text: product?.details ?? '');
    _price = TextEditingController(
      text: product != null && product.price > 0 ? '${product.price}' : '',
    );
    _stock = TextEditingController(text: product?.stock?.toString() ?? '');
    _sku = TextEditingController(text: product?.sku ?? '');
    _category = TextEditingController(text: product?.category ?? '');
    _variants = TextEditingController(text: product?.variants.join(', ') ?? '');
    _isAvailable = product?.isAvailable ?? true;
  }

  @override
  void dispose() {
    for (final controller in [
      _name,
      _details,
      _price,
      _stock,
      _sku,
      _category,
      _variants,
    ]) {
      controller.dispose();
    }
    super.dispose();
  }

  void _save() {
    final name = _name.text.trim();
    final price = int.tryParse(_price.text.trim());
    if (name.isEmpty || price == null || price <= 0) {
      setState(() {
        _error = name.isEmpty
            ? 'El nombre del producto es obligatorio.'
            : 'Ingresa un precio válido mayor a 0.';
      });
      return;
    }
    final sku = _sku.text.trim();
    final category = _category.text.trim();
    Navigator.of(context).pop(
      BusinessProduct(
        id:
            widget.initial?.id ??
            DateTime.now().microsecondsSinceEpoch.toString(),
        name: name,
        details: _details.text.trim(),
        price: price,
        stock: int.tryParse(_stock.text.trim()),
        sku: sku.isEmpty ? null : sku,
        category: category.isEmpty ? null : category,
        variants: _variants.text
            .split(',')
            .map((value) => value.trim())
            .where((value) => value.isNotEmpty)
            .toList(),
        isAvailable: _isAvailable,
        imagePath: widget.initial?.imagePath,
        isManualEdit: true,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final visual = AutomationVisual.of(context);
    final isEditing = widget.initial != null;
    return DialogContainerShell(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 14, 12, 10),
            child: Row(
              children: [
                Icon(
                  isEditing ? Icons.edit_note_rounded : Icons.add_business,
                  color: visual.accent,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    isEditing ? 'Editar producto' : 'Nuevo producto / servicio',
                    style: TextStyle(
                      color: visual.text,
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: ProductDialogForm(
              name: _name,
              details: _details,
              price: _price,
              stock: _stock,
              sku: _sku,
              category: _category,
              variants: _variants,
              isAvailable: _isAvailable,
              error: _error,
              onAvailabilityChanged: (value) =>
                  setState(() => _isAvailable = value),
            ),
          ),
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 8, 14, 10),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Cancelar'),
                ),
                const SizedBox(width: 8),
                FilledButton(
                  onPressed: _save,
                  child: Text(isEditing ? 'Actualizar' : 'Guardar'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
