import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:nanoai/features/automation/engine/business/business_facts.dart';
import 'package:nanoai/features/automation/presentation/automation_visual_theme.dart';

/// Diálogo profesional para agregar o editar productos del catálogo comercial.
class ProductDialog extends StatefulWidget {
  final BusinessProduct? initial;

  const ProductDialog({super.key, this.initial});

  @override
  State<ProductDialog> createState() => _ProductDialogState();
}

class _ProductDialogState extends State<ProductDialog> {
  late final TextEditingController _nameController;
  late final TextEditingController _detailsController;
  late final TextEditingController _priceController;
  late final TextEditingController _stockController;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.initial?.name ?? '');
    _detailsController =
        TextEditingController(text: widget.initial?.details ?? '');
    _priceController = TextEditingController(
      text: widget.initial != null && widget.initial!.price > 0
          ? widget.initial!.price.toString()
          : '',
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

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 440),
        decoration: BoxDecoration(
          color: visual.isDark ? const Color(0xFF0F172A) : Colors.white,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: visual.isDark
                ? Colors.white.withValues(alpha: 0.16)
                : const Color(0xFFCBD5E1),
            width: 1.2,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.35),
              blurRadius: 28,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(22),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: visual.accentSoft,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      isEditing ? Icons.edit_note_rounded : Icons.add_business_rounded,
                      color: visual.accent,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      isEditing ? 'Editar producto' : 'Nuevo producto o servicio',
                      style: TextStyle(
                        color: visual.text,
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.4,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              TextField(
                controller: _nameController,
                autofocus: !isEditing,
                style: TextStyle(color: visual.text, fontSize: 14),
                decoration: InputDecoration(
                  labelText: 'Nombre del producto',
                  hintText: 'Ej. Hamburguesa Especial, Silla Gamer',
                  labelStyle: TextStyle(color: visual.textMuted),
                  filled: true,
                  fillColor: visual.inputFill,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _detailsController,
                style: TextStyle(color: visual.text, fontSize: 14),
                decoration: InputDecoration(
                  labelText: 'Variante o descripción corta (opcional)',
                  hintText: 'Ej. Talla M, Combo con papas, 256GB',
                  labelStyle: TextStyle(color: visual.textMuted),
                  filled: true,
                  fillColor: visual.inputFill,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    flex: 3,
                    child: TextField(
                      controller: _priceController,
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      style: TextStyle(color: visual.text, fontSize: 14),
                      decoration: InputDecoration(
                        labelText: 'Precio en pesos (\$)',
                        hintText: 'Ej. 25000',
                        prefixText: '\$ ',
                        labelStyle: TextStyle(color: visual.textMuted),
                        filled: true,
                        fillColor: visual.inputFill,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    flex: 2,
                    child: TextField(
                      controller: _stockController,
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      style: TextStyle(color: visual.text, fontSize: 14),
                      decoration: InputDecoration(
                        labelText: 'Stock (opcional)',
                        hintText: 'Ej. 10',
                        labelStyle: TextStyle(color: visual.textMuted),
                        filled: true,
                        fillColor: visual.inputFill,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              if (_errorMessage != null) ...[
                const SizedBox(height: 12),
                Text(
                  _errorMessage!,
                  style: const TextStyle(
                    color: Color(0xFFEF4444),
                    fontSize: 12.5,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
              const SizedBox(height: 22),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    style: TextButton.styleFrom(
                      foregroundColor: visual.textMuted,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 10,
                      ),
                    ),
                    child: const Text('Cancelar'),
                  ),
                  const SizedBox(width: 8),
                  FilledButton(
                    onPressed: _save,
                    style: FilledButton.styleFrom(
                      backgroundColor: visual.accent,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 22,
                        vertical: 10,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    child: Text(isEditing ? 'Actualizar' : 'Agregar'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
