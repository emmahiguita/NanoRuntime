// QUÉ: Barra de dirección estilo cápsula iOS Safari con visualización explícita de protocolo HTTP/HTTPS.
// CÓMO: Analiza seguridad con BrowserAddressFormatter, altura ergonómica de 42dp y modo edición responsivo.
// POR QUÉ: Elimina malformaciones de texto, recortes toscos y clarifica el estado de seguridad (< 160 líneas).

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../domain/browser_url_resolver.dart';
import 'browser_address_edit_input.dart';
import 'browser_address_formatter.dart';
import 'browser_address_label.dart';

class BrowserAddressField extends StatefulWidget {
  final String url, title;
  final bool showTitle;
  final Widget? trailing;
  final ValueChanged<String> onSubmitted;
  final ValueChanged<bool>? onEditingChanged;

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
    widget.onEditingChanged?.call(true);
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
    widget.onEditingChanged?.call(false);
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
    final secInfo = BrowserAddressFormatter.parse(widget.url);
    final activeColor =
        isDark ? const Color(0xFF38BDF8) : const Color(0xFF007AFF);

    return Container(
      height: 42,
      decoration: BoxDecoration(
        color: isDark
            ? Colors.white.withValues(alpha: _editing ? 0.12 : 0.08)
            : Colors.black.withValues(alpha: _editing ? 0.07 : 0.045),
        borderRadius: BorderRadius.circular(21),
        border: Border.all(
          color: _editing
              ? activeColor
              : (isDark
                  ? Colors.white.withValues(alpha: 0.12)
                  : Colors.black.withValues(alpha: 0.08)),
          width: _editing ? 1.2 : 0.8,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const SizedBox(width: 12),
          BrowserAddressLabel.buildIcon(
            isEditing: _editing,
            info: secInfo,
            activeColor: activeColor,
            isDark: isDark,
          ),
          const SizedBox(width: 8),
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
                      borderRadius: BorderRadius.circular(21),
                      onTap: _begin,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 9),
                        child: BrowserAddressLabel(info: secInfo, isDark: isDark),
                      ),
                    ),
                  ),
          ),
          if (_editing && _text.text.isNotEmpty)
            GestureDetector(
              onTap: () => setState(_text.clear),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Icon(
                  CupertinoIcons.clear_circled_solid,
                  size: 16,
                  color: isDark ? Colors.white54 : Colors.black45,
                ),
              ),
            ),
          if (!_editing && widget.trailing != null) widget.trailing!,
          const SizedBox(width: 4),
        ],
      ),
    );
  }
}
