// nano_address_bar.dart — Barra de direcciones unificada para Nano Browser estilo Safari.
// QUÉ HACE: Presenta y edita la URL con un único contorno visual, selección elegante y controles integrados.
// CÓMO FUNCIONA: TextSelectionTheme personalizado, TextField sin bordes internos y borrado en línea.
// POR QUÉ: Elimina dobles bordes (azul/verde), resaltado verde excesivo y apariencia recargada (< 175 líneas).
library;

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../domain/browser_url_resolver.dart';
import 'browser_address_formatter.dart';
import 'browser_address_label.dart';

class NanoAddressBar extends StatefulWidget {
  final String url, title;
  final Widget? trailing;
  final ValueChanged<String> onSubmitted;
  final ValueChanged<bool>? onEditingChanged;
  final VoidCallback? onCancel;

  const NanoAddressBar({
    super.key,
    required this.url,
    this.title = '',
    this.trailing,
    required this.onSubmitted,
    this.onEditingChanged,
    this.onCancel,
  });

  @override
  State<NanoAddressBar> createState() => _NanoAddressBarState();
}

class _NanoAddressBarState extends State<NanoAddressBar> {
  late final TextEditingController _controller;
  late final FocusNode _focusNode;
  bool _isEditing = false;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.url);
    _focusNode = FocusNode()..addListener(_onFocusChange);
  }

  @override
  void didUpdateWidget(covariant NanoAddressBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_isEditing && widget.url != oldWidget.url) {
      _controller.text = widget.url;
    }
  }

  void _onFocusChange() {
    if (!mounted) return;
    if (_focusNode.hasFocus && !_isEditing) {
      _begin();
    } else if (!_focusNode.hasFocus && _isEditing) {
      _finish();
    }
    setState(() {});
  }

  void _begin() {
    HapticFeedback.selectionClick();
    _controller.value = TextEditingValue(
      text: widget.url,
      selection: TextSelection(baseOffset: 0, extentOffset: widget.url.length),
    );
    setState(() => _isEditing = true);
    widget.onEditingChanged?.call(true);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _isEditing && !_focusNode.hasFocus) {
        _focusNode.requestFocus();
      }
    });
  }

  void _finish() {
    setState(() => _isEditing = false);
    _focusNode.unfocus();
    widget.onEditingChanged?.call(false);
  }

  void _submit() {
    final input = _controller.text.trim();
    _finish();
    if (input.isNotEmpty) {
      HapticFeedback.lightImpact();
      widget.onSubmitted(BrowserUrlResolver.resolveUrl(input));
    }
  }

  @override
  void dispose() {
    _focusNode.removeListener(_onFocusChange);
    _focusNode.dispose();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final secInfo = BrowserAddressFormatter.parse(widget.url);
    final background = isDark ? const Color(0xFF1E2430) : const Color(0xFFF1F5F9);
    final foreground = isDark ? Colors.white : const Color(0xFF0F172A);

    // Único borde visual del componente: neutro en reposo, nítido en foco
    final borderColor = _isEditing
        ? (isDark ? const Color(0xFFA9B9C8) : const Color(0xFF64748B))
        : (isDark ? Colors.white.withValues(alpha: 0.10) : Colors.black.withValues(alpha: 0.08));

    return TextSelectionTheme(
      data: TextSelectionThemeData(
        selectionColor: isDark ? const Color(0x4038BDF8) : const Color(0x334D708C),
        cursorColor: isDark ? const Color(0xFF38BDF8) : const Color(0xFF526B82),
      ),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        height: 48,
        decoration: BoxDecoration(
          color: background,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: borderColor, width: _isEditing ? 1.0 : 0.8),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const SizedBox(width: 12),
            BrowserAddressLabel.buildIcon(
              isEditing: _isEditing,
              info: secInfo,
              activeColor: isDark ? const Color(0xFF38BDF8) : const Color(0xFF2563EB),
              isDark: isDark,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _isEditing
                  ? TextField(
                      controller: _controller,
                      focusNode: _focusNode,
                      maxLines: 1,
                      textAlignVertical: TextAlignVertical.center,
                      keyboardType: TextInputType.url,
                      textInputAction: TextInputAction.go,
                      autocorrect: false,
                      enableSuggestions: false,
                      style: TextStyle(
                        fontSize: 14.5,
                        fontWeight: FontWeight.w500,
                        color: foreground,
                        letterSpacing: -0.2,
                      ),
                      // El TextField NO dibuja bordes para evitar doble contorno
                      decoration: InputDecoration(
                        hintText: 'Buscar o ingresar dirección web',
                        hintStyle: TextStyle(
                          fontSize: 13.5,
                          color: isDark ? Colors.white38 : Colors.black38,
                        ),
                        isCollapsed: true,
                        border: InputBorder.none,
                        enabledBorder: InputBorder.none,
                        focusedBorder: InputBorder.none,
                        errorBorder: InputBorder.none,
                        disabledBorder: InputBorder.none,
                        contentPadding: EdgeInsets.zero,
                      ),
                      onSubmitted: (_) => _submit(),
                      onChanged: (_) => setState(() {}),
                    )
                  : Semantics(
                      button: true,
                      label: 'Editar dirección: ${widget.url}',
                      child: InkWell(
                        borderRadius: BorderRadius.circular(16),
                        onTap: _begin,
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: BrowserAddressLabel(info: secInfo, isDark: isDark),
                        ),
                      ),
                    ),
            ),
            if (_isEditing && _controller.text.isNotEmpty)
              IconButton(
                tooltip: 'Borrar dirección',
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                icon: Icon(
                  CupertinoIcons.clear_circled_solid,
                  size: 17,
                  color: isDark ? Colors.white54 : Colors.black45,
                ),
                onPressed: () {
                  _controller.clear();
                  _focusNode.requestFocus();
                  setState(() {});
                },
              ),
            if (!_isEditing && widget.trailing != null) widget.trailing!,
            const SizedBox(width: 6),
          ],
        ),
      ),
    );
  }
}
