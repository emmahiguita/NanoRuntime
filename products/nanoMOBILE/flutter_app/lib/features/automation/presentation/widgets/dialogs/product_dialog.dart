import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:nanoai/features/automation/engine/business/business_facts.dart';
import 'package:nanoai/features/automation/presentation/automation_visual_theme.dart';
import 'dialog_container_shell.dart';

// product_dialog.dart
//
// QUÉ HACE:
// Diálogo profesional con Material Expressive para agregar o editar productos y servicios del catálogo.
//
// CÓMO FUNCIONA:
// - Captura nombre, detalles, precio y stock numérico con validación y formateo de miles.
// - Utiliza DialogContainerShell para adaptar dimensiones en Landscape y Portrait sin desbordar con teclado.
//
// POR QUÉ:
// Asegura edición limpia y accesible de inventario en cualquier orientación (< 200 líneas).

class ProductDialog extends StatefulWidget {
  final BusinessProduct? initial;
  const ProductDialog({super.key, this.initial});

  @override
  State<ProductDialog> createState() => _ProductDialogState();
}

class _ProductDialogState extends State<ProductDialog> {
  late final TextEditingController _nameController, _detailsController, _priceController, _stockController;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.initial?.name ?? '');
    _detailsController = TextEditingController(text: widget.initial?.details ?? '');
    _priceController = TextEditingController(
      text: widget.initial != null && widget.initial!.price > 0 ? widget.initial!.price.toString() : '',
    );
    _stockController = TextEditingController(
      text: widget.initial?.stock != null ? widget.initial!.stock.toString() : '',
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _detailsController.dispose();
    _priceController.dispose();
    _stockController.dispose();
    super.dispose();
  }

  void _save() {
    final name = _nameController.text.trim();
    final rawPrice = _priceController.text.replaceAll(RegExp(r'[^\d]'), '').trim();
    final price = int.tryParse(rawPrice);

    if (name.isEmpty) {
      setState(() => _errorMessage = 'El nombre del producto es obligatorio.');
      return;
    }
    if (price == null || price <= 0) {
      setState(() => _errorMessage = 'Ingresa un precio válido mayor a 0.');
      return;
    }

    final rawStock = _stockController.text.replaceAll(RegExp(r'[^\d]'), '').trim();
    final stock = rawStock.isNotEmpty ? int.tryParse(rawStock) : null;

    final product = BusinessProduct(
      id: widget.initial?.id ?? DateTime.now().microsecondsSinceEpoch.toString(),
      name: name,
      details: _detailsController.text.trim(),
      price: price,
      stock: stock,
    );

    Navigator.of(context).pop(product);
  }

  @override
  Widget build(BuildContext context) {
    final visual = AutomationVisual.of(context);
    final isEditing = widget.initial != null;

    return DialogContainerShell(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 14, 12, 10),
            child: Row(
              children: [
                Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(color: visual.accentSoft, borderRadius: BorderRadius.circular(10)),
                  child: Icon(isEditing ? Icons.edit_note_rounded : Icons.add_business_rounded, color: visual.accent, size: 20),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(isEditing ? 'Editar producto' : 'Nuevo producto / servicio', style: TextStyle(color: visual.text, fontSize: 16, fontWeight: FontWeight.w700)),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _field(_nameController, 'Nombre del producto *', visual, hint: 'Ej. Hamburguesa Doble Queso'),
                  const SizedBox(height: 8),
                  _field(_detailsController, 'Descripción o ingredientes', visual, hint: 'Ej. Carne 150g, queso cheddar, papas', maxLines: 2),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        flex: 3,
                        child: _field(_priceController, 'Precio (\$ COP) *', visual, hint: 'Ej. 25000', isNumber: true),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        flex: 2,
                        child: _field(_stockController, 'Stock (opcional)', visual, hint: 'Ej. 50', isNumber: true),
                      ),
                    ],
                  ),
                  if (_errorMessage != null) ...[
                    const SizedBox(height: 8),
                    Text(_errorMessage!, style: const TextStyle(color: Colors.redAccent, fontSize: 11, fontWeight: FontWeight.w600)),
                  ],
                ],
              ),
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
                  child: Text('Cancelar', style: TextStyle(color: visual.textMuted, fontSize: 12)),
                ),
                const SizedBox(width: 8),
                FilledButton(
                  onPressed: _save,
                  style: FilledButton.styleFrom(
                    backgroundColor: visual.accent,
                    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  child: Text(isEditing ? 'Actualizar' : 'Guardar', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _field(TextEditingController ctrl, String label, AutomationVisualPalette visual, {String? hint, int maxLines = 1, bool isNumber = false}) => TextField(
        controller: ctrl,
        maxLines: maxLines,
        keyboardType: isNumber ? TextInputType.number : TextInputType.text,
        inputFormatters: isNumber ? [FilteringTextInputFormatter.digitsOnly] : null,
        style: TextStyle(color: visual.text, fontSize: 12.5),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: TextStyle(fontSize: 11, color: visual.textMuted),
          hintText: hint,
          hintStyle: TextStyle(fontSize: 10, color: visual.textMuted.withValues(alpha: 0.5)),
          filled: true,
          fillColor: visual.inputFill,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
          isDense: true,
          contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        ),
      );
}
