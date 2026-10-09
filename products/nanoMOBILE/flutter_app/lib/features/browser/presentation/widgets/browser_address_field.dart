import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../domain/browser_url_resolver.dart';

/// Barra de dirección estilo cápsula iOS Safari con tipografía nítida y sin solapamiento.
///
/// - QUÉ HACE: Renderiza la dirección o campo de búsqueda con iconos de seguridad y recarga.
/// - CÓMO FUNCIONA: Mantiene la consistencia de ancho entre edición y lectura sin saltos ni bugs.
/// - POR QUÉ: Garantiza legibilidad 100% y elimina cualquier solapamiento visual (<200 líneas).
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

    return Container(
      height: 40,
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withValues(alpha: 0.08) : Colors.black.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: _editing
              ? (isDark ? const Color(0xFF38BDF8) : const Color(0xFF2563EB))
              : (isDark ? Colors.white.withValues(alpha: 0.14) : Colors.black.withValues(alpha: 0.08)),
          width: _editing ? 1.2 : 0.8,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const SizedBox(width: 10),
          Icon(
            _editing
                ? CupertinoIcons.search
                : (isSecure ? CupertinoIcons.lock_shield_fill : CupertinoIcons.globe),
            size: 15,
            color: _editing
                ? (isDark ? const Color(0xFF38BDF8) : const Color(0xFF2563EB))
                : (isSecure ? const Color(0xFF38BDF8) : (isDark ? Colors.white60 : Colors.black45)),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _editing
                ? TextField(
                    controller: _text,
                    focusNode: _focus,
                    keyboardType: TextInputType.url,
                    textInputAction: TextInputAction.go,
                    autocorrect: false,
                    enableSuggestions: false,
                    cursorColor: isDark ? const Color(0xFF38BDF8) : const Color(0xFF2563EB),
                    style: TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w500,
                      color: isDark ? Colors.white : const Color(0xFF0F172A),
                    ),
                    onSubmitted: (_) => _submit(),
                    onChanged: (_) => setState(() {}),
                    onTapOutside: (_) => _focus.unfocus(),
                    decoration: InputDecoration(
                      hintText: 'Buscar o ingresar URL',
                      hintStyle: TextStyle(
                        fontSize: 13,
                        color: isDark ? Colors.white38 : Colors.black38,
                      ),
                      border: InputBorder.none,
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(vertical: 9),
                    ),
                  )
                : Semantics(
                    button: true,
                    label: 'Editar dirección: ${widget.url}',
                    child: InkWell(
                      borderRadius: BorderRadius.circular(20),
                      onTap: _begin,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        child: Text(
                          display.isEmpty ? 'Buscar o ingresar URL' : display,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w600,
                            color: isDark ? Colors.white : const Color(0xFF0F172A),
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
                  size: 16,
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
