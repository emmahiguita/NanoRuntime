import 'package:flutter/cupertino.dart';

/// Búsqueda real por nombre y carpeta, con controlador sincronizado.
class BusinessLibrarySearchBar extends StatefulWidget {
  final String query;
  final bool isDark;
  final ValueChanged<String> onQuery;

  const BusinessLibrarySearchBar({
    super.key,
    required this.query,
    required this.isDark,
    required this.onQuery,
  });

  @override
  State<BusinessLibrarySearchBar> createState() =>
      _BusinessLibrarySearchBarState();
}

class _BusinessLibrarySearchBarState extends State<BusinessLibrarySearchBar> {
  late final TextEditingController _controller = TextEditingController(
    text: widget.query,
  );

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
    padding: const EdgeInsets.fromLTRB(16, 4, 16, 3),
    child: CupertinoSearchTextField(
      controller: _controller,
      onChanged: widget.onQuery,
      onSuffixTap: () {
        _controller.clear();
        widget.onQuery('');
      },
      placeholder: 'Buscar documentos',
      backgroundColor: const Color(0x70101B2A),
      borderRadius: BorderRadius.circular(12),
      prefixIcon: const Icon(
        CupertinoIcons.search,
        size: 18,
        color: Color(0xFFA9BDD2),
      ),
      suffixIcon: const Icon(
        CupertinoIcons.xmark_circle_fill,
        size: 17,
        color: Color(0xFF8095AB),
      ),
      style: const TextStyle(color: Color(0xFFE6EEF7), fontSize: 13),
      placeholderStyle: const TextStyle(color: Color(0xFF8095AB), fontSize: 12),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 11),
    ),
  );
}
