// product_dialog_form.dart
//
// QUÉ HACE:
// Formulario estructurado en 4 secciones lógicas para nuevo producto o edición comercial.
//
// CÓMO FUNCIONA:
// - 1. Información del producto (foto, nombre, categoría, SKU, descripción).
// - 2. Precio e inventario (precio con prefijo '$', cantidad disponible).
// - 3. Variantes (control de opciones con guía de sintaxis).
// - 4. Publicación (interruptor para habilitar en canales conectados).
//
// POR QUÉ:
// Elimina la dispersión de campos redondeados y aporta jerarquía visual sólida (< 175 líneas).

library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../automation_visual_theme.dart';
import 'product_media_picker.dart';

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
  final VoidCallback onPickMedia, onRemoveMedia;
  final String? error;

  @override
  Widget build(BuildContext context) {
    final visual = AutomationVisual.of(context);
    final isDark = visual.isDark;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(18, 12, 18, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (error != null) _errorBanner(error!),
          _sectionHeader('INFORMACIÓN DEL PRODUCTO', isDark),
          const SizedBox(height: 8),
          ProductMediaPicker(
            imagePath: imagePath,
            onPickMedia: onPickMedia,
            onRemoveMedia: onRemoveMedia,
            visual: visual,
            isDark: isDark,
          ),
          const SizedBox(height: 10),
          _field(name, 'Nombre del producto *', 'Ej. Camiseta Nano AI', visual, isDark),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(child: _field(category, 'Categoría', 'Ej. Ropa', visual, isDark)),
              const SizedBox(width: 10),
              Expanded(child: _field(sku, 'SKU / Referencia', 'Ej. REF-01', visual, isDark)),
            ],
          ),
          const SizedBox(height: 10),
          _field(details, 'Descripción o ficha técnica', 'Detalles, material, especificaciones...', visual, isDark, maxLines: 2),
          const SizedBox(height: 16),
          _sectionHeader('PRECIO E INVENTARIO', isDark),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                flex: 3,
                child: _field(price, 'Precio *', '0', visual, isDark, numeric: true, prefix: r'$ '),
              ),
              const SizedBox(width: 10),
              Expanded(
                flex: 2,
                child: _field(stock, 'Stock disponible', 'Ej. 10', visual, isDark, numeric: true),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _sectionHeader('VARIANTES', isDark),
          const SizedBox(height: 8),
          _field(variants, 'Opciones o variantes', 'Ej. S, M, L o Negro, Blanco', visual, isDark),
          const SizedBox(height: 4),
          Text(
            'Separa con comas las opciones para que el cliente elija en chat.',
            style: TextStyle(fontSize: 11, color: isDark ? Colors.white38 : const Color(0xFF94A3B8)),
          ),
          const SizedBox(height: 16),
          _sectionHeader('PUBLICACIÓN', isDark),
          const SizedBox(height: 8),
          _availabilityCard(visual, isDark),
        ],
      ),
    );
  }

  Widget _errorBanner(String message) => Container(
    margin: const EdgeInsets.only(bottom: 12),
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
    decoration: BoxDecoration(
      color: Colors.red.withValues(alpha: 0.12),
      borderRadius: BorderRadius.circular(10),
      border: Border.all(color: Colors.red.withValues(alpha: 0.3)),
    ),
    child: Row(
      children: [
        const Icon(Icons.error_outline, size: 16, color: Colors.redAccent),
        const SizedBox(width: 8),
        Expanded(child: Text(message, style: const TextStyle(color: Colors.redAccent, fontSize: 12, fontWeight: FontWeight.w600))),
      ],
    ),
  );

  Widget _sectionHeader(String title, bool isDark) => Text(
    title,
    style: TextStyle(
      fontSize: 11,
      fontWeight: FontWeight.w700,
      letterSpacing: 0.6,
      color: isDark ? Colors.white54 : const Color(0xFF64748B),
    ),
  );

  Widget _availabilityCard(AutomationVisualPalette visual, bool isDark) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
    decoration: BoxDecoration(
      color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: isDark ? Colors.white12 : const Color(0xFFE2E8F0)),
    ),
    child: Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Disponible en WhatsApp y Tienda', style: TextStyle(color: isDark ? Colors.white : const Color(0xFF0F172A), fontSize: 13, fontWeight: FontWeight.w600)),
              const SizedBox(height: 2),
              Text('Permite a la IA recomendar y cotizar este artículo.', style: TextStyle(color: isDark ? Colors.white54 : const Color(0xFF64748B), fontSize: 11)),
            ],
          ),
        ),
        Switch.adaptive(value: isAvailable, activeTrackColor: const Color(0xFF10B981), onChanged: onAvailabilityChanged),
      ],
    ),
  );

  Widget _field(TextEditingController c, String label, String hint, AutomationVisualPalette visual, bool isDark, {int maxLines = 1, bool numeric = false, String? prefix}) => TextField(
    controller: c,
    maxLines: maxLines,
    keyboardType: numeric ? TextInputType.number : TextInputType.text,
    inputFormatters: numeric ? [FilteringTextInputFormatter.digitsOnly] : null,
    style: TextStyle(color: isDark ? Colors.white : const Color(0xFF0F172A), fontSize: 13),
    decoration: InputDecoration(
      labelText: label,
      hintText: hint,
      prefixText: prefix,
      prefixStyle: TextStyle(color: isDark ? Colors.white70 : const Color(0xFF0F172A), fontWeight: FontWeight.w700),
      labelStyle: TextStyle(fontSize: 12, color: isDark ? Colors.white60 : const Color(0xFF64748B)),
      floatingLabelBehavior: FloatingLabelBehavior.always,
      filled: true,
      fillColor: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: isDark ? Colors.white12 : const Color(0xFFCBD5E1))),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: isDark ? Colors.white12 : const Color(0xFFCBD5E1))),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFF10B981), width: 1.5)),
      isDense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
    ),
  );
}
