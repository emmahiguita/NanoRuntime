import 'package:flutter/material.dart';

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
    padding: const EdgeInsets.fromLTRB(16, 3, 16, 2),
    child: Container(
      height: 42,
      decoration: BoxDecoration(
        color: const Color(0x70101B2A),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: const Color(0xFF6B829B).withValues(alpha: .55),
        ),
      ),
      child: TextField(
        controller: _controller,
        onChanged: widget.onQuery,
        style: const TextStyle(color: Color(0xFFE6EEF7), fontSize: 12),
        decoration: InputDecoration(
          hintText: 'Buscar documentos',
          hintStyle: const TextStyle(color: Color(0xFF8095AB), fontSize: 11),
          prefixIcon: const Icon(
            Icons.search_rounded,
            size: 18,
            color: Color(0xFFA9BDD2),
          ),
          suffixIcon: widget.query.isEmpty
              ? null
              : IconButton(
                  onPressed: () {
                    _controller.clear();
                    widget.onQuery('');
                  },
                  icon: const Icon(Icons.close_rounded, size: 16),
                  color: const Color(0xFF8FA5BB),
                ),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(vertical: 11),
          isDense: true,
        ),
      ),
    ),
  );
}
