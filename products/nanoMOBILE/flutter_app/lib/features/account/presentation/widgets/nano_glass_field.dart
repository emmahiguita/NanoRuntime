import 'package:flutter/material.dart';

/// Campo Material compartido: foco nativo, validación y contraseña.
/// TextFormField posee su foco interno; un FocusNode externo pertenece al padre.
class NanoGlassField extends StatefulWidget {
  final TextEditingController controller;
  final String label;
  final String? hint, helperText;
  final IconData? prefixIcon;
  final bool isPassword;
  final TextInputType keyboardType;
  final TextInputAction textInputAction;
  final String? Function(String?)? validator;
  final FocusNode? focusNode;
  final ValueChanged<String>? onFieldSubmitted;
  final int minLines, maxLines;
  const NanoGlassField({
    super.key,
    required this.controller,
    required this.label,
    this.hint,
    this.helperText,
    this.prefixIcon,
    this.isPassword = false,
    this.keyboardType = TextInputType.text,
    this.textInputAction = TextInputAction.next,
    this.validator,
    this.focusNode,
    this.onFieldSubmitted,
    this.minLines = 1,
    this.maxLines = 1,
  });

  @override
  State<NanoGlassField> createState() => _NanoGlassFieldState();
}

class _NanoGlassFieldState extends State<NanoGlassField> {
  bool _obscured = true;

  /// Decoración nativa para foco/errores, sin un filtro GPU por cada campo.
  /// Ayudas y errores envuelven líneas cuando hay poco ancho disponible.
  @override
  Widget build(BuildContext context) => TextFormField(
    controller: widget.controller,
    focusNode: widget.focusNode,
    obscureText: widget.isPassword && _obscured,
    keyboardType: widget.keyboardType,
    textInputAction: widget.textInputAction,
    validator: widget.validator,
    onFieldSubmitted: widget.onFieldSubmitted,
    minLines: widget.isPassword ? 1 : widget.minLines,
    maxLines: widget.isPassword ? 1 : widget.maxLines,
    decoration: InputDecoration(
      labelText: widget.label,
      hintText: widget.hint,
      helperText: widget.helperText,
      helperMaxLines: 3,
      errorMaxLines: 3,
      filled: true,
      alignLabelWithHint: widget.maxLines > 1,
      prefixIcon: widget.prefixIcon == null ? null : Icon(widget.prefixIcon),
      suffixIcon: widget.isPassword
          ? IconButton(
              tooltip: _obscured ? 'Mostrar contraseña' : 'Ocultar contraseña',
              icon: Icon(
                _obscured
                    ? Icons.visibility_outlined
                    : Icons.visibility_off_outlined,
              ),
              onPressed: () => setState(() => _obscured = !_obscured),
            )
          : null,
    ),
  );
}
