// QUÉ: Barra de dirección estilo cápsula iOS Safari con tipografía nítida y sin solapamiento.
// CÓMO: Mantiene consistencia de ancho entre edición y lectura con indicadores de candado/búsqueda.
// POR QUÉ: Garantiza legibilidad 100% y elimina cualquier solapamiento visual (< 160 líneas).

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../domain/browser_url_resolver.dart';
import 'browser_address_edit_input.dart';

class BrowserAddressField extends StatefulWidget {
  final String url, title;
  final bool showTitle;
  final Widget? trailing;
  final ValueChanged<String> onSubmitted;
  final VoidCallback? onEditingChanged;

  const BrowserAddressField({
    super.key,
    required this.url,
    this.title = '',
    this.showTitle = false,
    this.trailing,
    required this.onSubmitted,
    this.onEditingChanged,
  });

  @override
  State<BrowserAddressField> createState() => _BrowserAddressFieldState();
}

class _BrowserAddressFieldState extends State<BrowserAddressField> {
  late final TextEditingController _text;
  late final FocusNode _focus;
  bool _editing = false;

  @override
  void initState() {
    super.initState();
    _text = TextEditingController(text: widget.url);
    _focus = FocusNode()..addListener(_onFocus);
  }

  @override
  void didUpdateWidget(covariant BrowserAddressField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_editing && widget.url != oldWidget.url) {
      _text.text = widget.url;
    }
  }

  void _onFocus() {
    if (mounted && !_focus.hasFocus && _editing) {
      _finish();
    }
  }

  void _begin() {
    HapticFeedback.selectionClick();
    _text.value = TextEditingValue(
      text: widget.url,
      selection: TextSelection(baseOffset: 0, extentOffset: widget.url.length),
    );
    setState(() => _editing = true);
    widget.onEditingChanged?.call();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _editing) {
        Scrollable.ensureVisible(context, alignment: 0);
        _focus.requestFocus();
      }
    });
  }

  void _finish() {
    setState(() => _editing = false);
    _focus.unfocus();
    widget.onEditingChanged?.call();
  }

  void _submit() {
    final input = _text.text.trim();
    _finish();
    if (input.isNotEmpty) {
      HapticFeedback.lightImpact();
      widget.onSubmitted(BrowserUrlResolver.resolveUrl(input));
    }
  }

  @override
  void dispose() {
    _focus.removeListener(_onFocus);
    _focus.dispose();
    _text.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final host = Uri.tryParse(widget.url)?.host ?? '';
    final display = host.isNotEmpty ? host : widget.url;
    final isSecure = widget.url.startsWith('https://');
    final activeColor =
        isDark ? const Color(0xFF38BDF8) : const Color(0xFF007AFF);

    return Container(
      height: 38,
      decoration: BoxDecoration(
        color: isDark
            ? Colors.white.withValues(alpha: 0.08)
            : Colors.black.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(19),
        border: Border.all(
          color: _editing
              ? activeColor
              : (isDark
                  ? Colors.white.withValues(alpha: 0.12)
                  : Colors.black.withValues(alpha: 0.08)),
          width: _editing ? 1.2 : 0.7,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const SizedBox(width: 10),
          Icon(
            _editing
                ? CupertinoIcons.search
                : (isSecure
                    ? CupertinoIcons.lock_shield_fill
                    : CupertinoIcons.globe),
            size: 14,
            color: _editing || isSecure
                ? activeColor
                : (isDark ? Colors.white60 : Colors.black45),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: _editing
                ? BrowserAddressEditInput(
                    controller: _text,
                    focusNode: _focus,
                    isDark: isDark,
                    activeColor: activeColor,
                    onSubmitted: _submit,
                    onChanged: (_) => setState(() {}),
                  )
                : Semantics(
                    button: true,
                    label: 'Editar dirección: ${widget.url}',
                    child: InkWell(
                      borderRadius: BorderRadius.circular(19),
                      onTap: _begin,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: Text(
                          display.isEmpty ? 'Buscar o ingresar URL' : display,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            letterSpacing: -0.2,
                            color:
                                isDark ? Colors.white : const Color(0xFF0F172A),
                          ),
                        ),
                      ),
                    ),
                  ),
          ),
          if (_editing && _text.text.isNotEmpty)
            GestureDetector(
              onTap: () => setState(_text.clear),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6),
                child: Icon(
                  CupertinoIcons.clear_circled_solid,
                  size: 15,
                  color: isDark ? Colors.white54 : Colors.black45,
                ),
              ),
            ),
          if (widget.trailing != null) widget.trailing!,
          const SizedBox(width: 2),
        ],
      ),
    );
  }
}
