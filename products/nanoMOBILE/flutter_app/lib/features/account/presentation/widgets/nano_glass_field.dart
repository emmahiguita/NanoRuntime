import 'package:flutter/material.dart';
import '../../../../core/theme/design_tokens.dart';
import '../../../../core/theme/nano_type.dart';
import '../../../../core/widgets/nano_optical_surface.dart';

/// QUÉ HACE:
/// Campo de entrada de texto premium con estética Nano Glass.
///
/// CÓMO FUNCIONA:
/// Envuelve un [TextFormField] sobre una superficie translúcida [NanoOpticalSurface],
/// con soporte para reveal de contraseña, iconos directos y mensajes de error inline.
///
/// POR QUÉ:
/// Reemplaza las cajas blancas o grises planas de Material tradicional, integrándose
/// armoniosamente en la atmósfera visual Cyber Emerald / Obsidian Slate de Nano.
class NanoGlassField extends StatefulWidget {
  final TextEditingController controller;
  final String label;
  final String? hint;
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

  @override
  void initState() {
    super.initState();
    _obscured = widget.isPassword;
  }

  @override
  Widget build(BuildContext context) {
    final colors = NanoThemeExtension.of(context).colors;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          widget.label,
          style: NanoType.caption(colors.onSurfaceVariant),
        ),
        const SizedBox(height: 6),
        NanoOpticalSurface(
          borderRadius: NanoRadius.medium,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
          child: TextFormField(
            controller: widget.controller,
            focusNode: widget.focusNode,
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
              hintStyle: NanoType.caption(colors.onSurfaceVariant.withValues(alpha: 0.6)),
              prefixIcon: widget.prefixIcon != null
                  ? Icon(widget.prefixIcon, color: colors.primary, size: 20)
                  : null,
              prefixIconConstraints: const BoxConstraints(minWidth: 32, minHeight: 32),
              suffixIcon: widget.isPassword
                  ? IconButton(
                      icon: Icon(
                        _obscured
                            ? Icons.visibility_outlined
                            : Icons.visibility_off_outlined,
                        color: colors.onSurfaceVariant,
                        size: 20,
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
