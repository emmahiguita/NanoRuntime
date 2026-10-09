// product_dialog.dart
//
// QUÉ: Crea o edita un producto real del catálogo comercial con foto/video.
// CÓMO: Valida identidad y precio, y provee selector de archivos multimedia.
// POR QUÉ: Mantiene persistencia y presentación separadas en archivos < 180 líneas.

library;

import 'package:file_picker/file_picker.dart';
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
  String? _imagePath;
  String? _error;

  @override
  void initState() {
    super.initState();
    final p = widget.initial;
    _name = TextEditingController(text: p?.name ?? '');
    _details = TextEditingController(text: p?.details ?? '');
    _price = TextEditingController(
      text: p != null && p.price > 0 ? '${p.price}' : '',
    );
    _stock = TextEditingController(text: p?.stock?.toString() ?? '');
    _sku = TextEditingController(text: p?.sku ?? '');
    _category = TextEditingController(text: p?.category ?? '');
    _variants = TextEditingController(text: p?.variants.join(', ') ?? '');
    _isAvailable = p?.isAvailable ?? true;
    _imagePath = p?.imagePath;
  }

  @override
  void dispose() {
    for (final c in [_name, _details, _price, _stock, _sku, _category, _variants]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _pickMedia() async {
    final res = await FilePicker.pickFiles(type: FileType.media);
    if (res != null && res.files.isNotEmpty && res.files.single.path != null) {
      setState(() => _imagePath = res.files.single.path);
    }
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
        id: widget.initial?.id ?? DateTime.now().microsecondsSinceEpoch.toString(),
        name: name,
        details: _details.text.trim(),
        price: price,
        stock: int.tryParse(_stock.text.trim()),
        sku: sku.isEmpty ? null : sku,
        category: category.isEmpty ? null : category,
        variants: _variants.text
            .split(',')
            .map((v) => v.trim())
            .where((v) => v.isNotEmpty)
            .toList(),
        isAvailable: _isAvailable,
        imagePath: _imagePath,
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
                Icon(isEditing ? Icons.edit_note_rounded : Icons.add_business, color: visual.accent),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    isEditing ? 'Editar producto' : 'Nuevo producto / servicio',
                    style: TextStyle(color: visual.text, fontSize: 16, fontWeight: FontWeight.w700),
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
              imagePath: _imagePath,
              error: _error,
              onAvailabilityChanged: (v) => setState(() => _isAvailable = v),
              onPickMedia: _pickMedia,
              onRemoveMedia: () => setState(() => _imagePath = null),
            ),
          ),
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 8, 14, 10),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancelar')),
                const SizedBox(width: 8),
                FilledButton(onPressed: _save, child: Text(isEditing ? 'Actualizar' : 'Guardar')),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
