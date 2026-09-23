import 'package:flutter/material.dart';
import '../../../../core/theme/design_tokens.dart';
import '../../../../core/theme/nano_type.dart';
import '../../../../core/widgets/nano_optical_surface.dart';

/// QUÉ HACE:
/// Campo de entrada de texto premium con estética Nano Glass y foco dinámico.
///
/// CÓMO FUNCIONA:
/// Envuelve un [TextFormField] sobre una superficie translúcida [NanoOpticalSurface],
/// activando el resplandor de borde óptico cuando recibe foco. Soporta reveal
/// de contraseña, prefijos/sufijos y validaciones de formato inline.
///
/// POR QUÉ:
/// Reemplaza cajas de texto genéricas por una interfaz de alta precisión ciber-minimalista.
class NanoGlassField extends StatefulWidget {
  final TextEditingController controller;
  final String label;
  final String? hint;
  final String? helperText;
  final IconData? prefixIcon;
  final bool isPassword;
  final TextInputType keyboardType;
  final TextInputAction textInputAction;
  final String? Function(String?)? validator;
  final FocusNode? focusNode;
  final ValueChanged<String>? onFieldSubmitted;

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
  });

  @override
  State<NanoGlassField> createState() => _NanoGlassFieldState();
}

class _NanoGlassFieldState extends State<NanoGlassField> {
  bool _obscured = true;
  late final FocusNode _effectiveFocusNode;
  bool _hasFocus = false;

  @override
  void initState() {
    super.initState();
    _obscured = widget.isPassword;
    _effectiveFocusNode = widget.focusNode ?? FocusNode();
    _effectiveFocusNode.addListener(_handleFocusChange);
  }

  void _handleFocusChange() {
    if (mounted && _hasFocus != _effectiveFocusNode.hasFocus) {
      setState(() => _hasFocus = _effectiveFocusNode.hasFocus);
    }
  }

  @override
  void dispose() {
    if (widget.focusNode == null) {
      _effectiveFocusNode.removeListener(_handleFocusChange);
      _effectiveFocusNode.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = NanoThemeExtension.of(context).colors;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              widget.label,
              style: NanoType.caption(colors.onSurfaceVariant).copyWith(
                fontWeight: FontWeight.w600,
                fontSize: 12,
              ),
            ),
            if (widget.helperText != null)
              Text(
                widget.helperText!,
                style: NanoType.caption(colors.primary).copyWith(
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                ),
              ),
          ],
        ),
        const SizedBox(height: 6),
        NanoOpticalSurface(
          borderRadius: NanoRadius.medium,
          isActive: _hasFocus,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 3),
          child: TextFormField(
            controller: widget.controller,
            focusNode: _effectiveFocusNode,
            obscureText: widget.isPassword && _obscured,
            keyboardType: widget.keyboardType,
            textInputAction: widget.textInputAction,
            validator: widget.validator,
            onFieldSubmitted: widget.onFieldSubmitted,
            style: NanoType.body(colors.onSurface),
            cursorColor: colors.primary,
            decoration: InputDecoration(
              isDense: true,
              border: InputBorder.none,
              hintText: widget.hint,
              hintStyle: NanoType.caption(colors.onSurfaceVariant.withValues(alpha: 0.55)),
              prefixIcon: widget.prefixIcon != null
                  ? Icon(
                      widget.prefixIcon,
                      color: _hasFocus ? colors.primary : colors.onSurfaceVariant,
                      size: 19,
                    )
                  : null,
              prefixIconConstraints: const BoxConstraints(minWidth: 32, minHeight: 32),
              suffixIcon: widget.isPassword
                  ? IconButton(
                      icon: Icon(
                        _obscured
                            ? Icons.visibility_outlined
                            : Icons.visibility_off_outlined,
                        color: _hasFocus ? colors.primary : colors.onSurfaceVariant,
                        size: 19,
                      ),
                      onPressed: () => setState(() => _obscured = !_obscured),
                    )
                  : null,
            ),
          ),
        ),
      ],
    );
  }
}
