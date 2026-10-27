import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart' show Theme;

/// Búsqueda real por nombre y carpeta, con controlador sincronizado.
class BusinessLibrarySearchBar extends StatefulWidget {
  final String query;
  final bool isDark;
  final ValueChanged<String> onQuery;
  final String placeholder;
  final EdgeInsetsGeometry padding;

  const BusinessLibrarySearchBar({
    super.key,
    required this.query,
    required this.isDark,
    required this.onQuery,
    this.placeholder = 'Buscar documentos',
    this.padding = const EdgeInsets.fromLTRB(16, 4, 16, 3),
  });

  @override
  State<BusinessLibrarySearchBar> createState() => _BusinessLibrarySearchBarState();
}

class _BusinessLibrarySearchBarState extends State<BusinessLibrarySearchBar> {
  late final TextEditingController _controller = TextEditingController(text: widget.query);

  @override
  void didUpdateWidget(covariant BusinessLibrarySearchBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.query != _controller.text) {
      _controller.value = TextEditingValue(
        text: widget.query,
        selection: TextSelection.collapsed(offset: widget.query.length),
      );
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Padding(
    padding: widget.padding,
    child: CupertinoSearchTextField(
      controller: _controller,
      onChanged: widget.onQuery,
      onSuffixTap: () {
        _controller.clear();
        widget.onQuery('');
      },
      placeholder: widget.placeholder,
      backgroundColor: Theme.of(
        context,
      ).colorScheme.surfaceContainerHighest.withValues(alpha: widget.isDark ? .30 : .45),
      cursorColor: Theme.of(context).colorScheme.primary,
      borderRadius: BorderRadius.circular(12),
      prefixIcon: Icon(CupertinoIcons.search, size: 18, color: Theme.of(context).colorScheme.onSurfaceVariant),
      suffixIcon: Icon(
        CupertinoIcons.xmark_circle_fill,
        size: 17,
        color: Theme.of(context).colorScheme.onSurfaceVariant,
      ),
      style: TextStyle(color: Theme.of(context).colorScheme.onSurface, fontSize: 13),
      placeholderStyle: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, fontSize: 12),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 11),
    ),
  );
}
