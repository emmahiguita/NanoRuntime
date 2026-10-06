import 'package:flutter/material.dart';
import '../../domain/browser_url_resolver.dart';
import 'browser_icon_button.dart';

/// Editor único para barra principal y tarjetas; conserva borrador mientras hay foco.
/// No reduce la fuente en horizontal ni afirma validar certificados HTTPS.
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

  /// Los recursos pertenecen al editor, no se recrean por progreso o rotación.
  @override
  void initState() {
    super.initState();
    _text = TextEditingController(text: widget.url);
    _focus = FocusNode()..addListener(_onFocus);
  }

  /// Una redirección actualiza la dirección sin pisar lo que el usuario escribe.
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

  /// Cambia primero la vista y solicita foco después de montar el TextField.
  void _begin() {
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

  /// Una sola notificación al terminar; evita callbacks duplicados al perder foco.
  void _finish() {
    setState(() => _editing = false);
    _focus.unfocus();
    widget.onEditingChanged?.call();
  }

  void _submit() {
    final input = _text.text.trim();
    _finish();
    if (input.isNotEmpty) {
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

  /// El texto crece con accesibilidad; no se encierra en alturas de 26–30 píxeles.
  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    if (_editing) {
      return TextField(
        controller: _text,
        focusNode: _focus,
        keyboardType: TextInputType.url,
        textInputAction: TextInputAction.go,
        autocorrect: false,
        enableSuggestions: false,
        onSubmitted: (_) => _submit(),
        onChanged: (_) => setState(() {}),
        onTapOutside: (_) => _focus.unfocus(),
        decoration: InputDecoration(
          hintText: 'Dirección o búsqueda',
          filled: true,
          isDense: true,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 12,
            vertical: 14,
          ),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          suffixIcon: BrowserIconButton(
            icon: Icons.clear_rounded,
            label: 'Borrar dirección',
            onPressed: _text.text.isEmpty ? null : () => setState(_text.clear),
          ),
        ),
      );
    }
    final host = Uri.tryParse(widget.url)?.host ?? '';
    final display = host.isNotEmpty ? host : widget.url;
    return Material(
      color: colors.surfaceContainerHighest,
      borderRadius: BorderRadius.circular(12),
      child: Row(
        children: [
          Expanded(
            child: Semantics(
              button: true,
              label: 'Editar dirección: ${widget.url}',
              child: InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: _begin,
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 12,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (widget.showTitle && widget.title.isNotEmpty)
                        Text(
                          widget.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.labelLarge,
                        ),
                      Text(
                        display.isEmpty ? 'Dirección o búsqueda' : display,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          if (widget.trailing != null) widget.trailing!,
        ],
      ),
    );
  }
}
