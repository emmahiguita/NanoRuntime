// QUÉ: Campo de texto editable para la barra de direcciones de Nano Browser.
// CÓMO: Encapsula el TextField configurado para entrada de URL con acción 'go'.
// POR QUÉ: Extraído de BrowserAddressField para respetar el límite de 200 líneas.

import 'package:flutter/material.dart';

class BrowserAddressEditInput extends StatelessWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final bool isDark;
  final Color activeColor;
  final VoidCallback onSubmitted;
  final ValueChanged<String> onChanged;

  const BrowserAddressEditInput({
    super.key,
    required this.controller,
    required this.focusNode,
    required this.isDark,
    required this.activeColor,
    required this.onSubmitted,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      focusNode: focusNode,
      keyboardType: TextInputType.url,
      textInputAction: TextInputAction.go,
      autocorrect: false,
      enableSuggestions: false,
      cursorColor: activeColor,
      style: TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w500,
        color: isDark ? Colors.white : const Color(0xFF0F172A),
      ),
      onSubmitted: (_) => onSubmitted(),
      onChanged: onChanged,
      onTapOutside: (_) => focusNode.unfocus(),
      decoration: InputDecoration(
        hintText: 'Buscar o ingresar URL',
        hintStyle: TextStyle(
          fontSize: 13,
          color: isDark ? Colors.white38 : Colors.black38,
        ),
        border: InputBorder.none,
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(vertical: 8),
      ),
    );
  }
}
