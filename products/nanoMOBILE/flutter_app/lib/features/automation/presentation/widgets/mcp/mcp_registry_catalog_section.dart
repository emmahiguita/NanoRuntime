import 'package:flutter/material.dart';

import '../../../engine/mcp/mcp_registry_catalog_source.dart';
import '../../../engine/mcp/mcp_store_catalog.dart';
import '../../automation_visual_theme.dart';
import 'mcp_registry_entry_card.dart';

/// Directorio de metadatos públicos; los registros no se tratan como paquetes instalados.
class McpRegistryCatalogSection extends StatefulWidget {
  const McpRegistryCatalogSection({
    super.key,
    required this.visual,
    required this.onConnect,
  });

  final AutomationVisualPalette visual;
  final ValueChanged<McpStoreItem> onConnect;

  @override
  State<McpRegistryCatalogSection> createState() =>
      _McpRegistryCatalogSectionState();
}

class _McpRegistryCatalogSectionState extends State<McpRegistryCatalogSection> {
  late final McpRegistryCatalogSource _source;
  final TextEditingController _search = TextEditingController();
  List<McpRegistryEntry> _entries = const [];
  String? _cursor;
  String? _error;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _source = McpRegistryCatalogSource();
    _load();
  }

  @override
  void dispose() {
    _source.dispose();
    _search.dispose();
    super.dispose();
  }

  /// Carga una página real del registro y conserva los resultados anteriores al paginar.
  Future<void> _load({bool next = false}) async {
    if (_loading) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final page = await _source.search(
        query: _search.text,
        cursor: next ? _cursor : null,
      );
      if (!mounted) return;
      setState(() {
        _entries = next ? [..._entries, ...page.entries] : page.entries;
        _cursor = page.nextCursor;
      });
    } catch (error) {
      if (mounted) {
        setState(
          () => _error = error is McpRegistryException
              ? error.message
              : 'Comprueba tu conexión a Internet e inténtalo de nuevo.',
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final visual = widget.visual;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Directorio público MCP',
          style: TextStyle(
            color: visual.text,
            fontSize: 16,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Metadatos oficiales en vista previa. La ficha no verifica ni instala el servidor.',
          style: TextStyle(color: visual.textMuted, fontSize: 13, height: 1.35),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _search,
                style: TextStyle(color: visual.text, fontSize: 14),
                textInputAction: TextInputAction.search,
                onSubmitted: (_) => _load(),
                decoration: InputDecoration(
                  hintText: 'Buscar por nombre MCP',
                  hintStyle: TextStyle(color: visual.textMuted, fontSize: 13),
                  filled: true,
                  fillColor: visual.cardStart,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            IconButton.filledTonal(
              tooltip: 'Buscar en el registro público',
              onPressed: _loading ? null : () => _load(),
              icon: const Icon(Icons.search_rounded),
            ),
          ],
        ),
        if (_loading) const LinearProgressIndicator(minHeight: 2),
        if (_error != null)
          _message(
            'No se pudo consultar el registro. $_error',
            visual,
            action: TextButton(
              onPressed: _load,
              child: const Text('Reintentar'),
            ),
          ),
        if (!_loading && _error == null && _entries.isEmpty)
          _message(
            'No hay fichas para esta búsqueda. Revisa el nombre o intenta otra vez.',
            visual,
          ),
        for (final entry in _entries)
          McpRegistryEntryCard(
            entry: entry,
            visual: visual,
            onConnect: widget.onConnect,
          ),
        if (_cursor != null)
          Align(
            alignment: Alignment.center,
            child: TextButton.icon(
              onPressed: _loading ? null : () => _load(next: true),
              icon: const Icon(Icons.expand_more_rounded),
              label: const Text('Cargar más fichas'),
            ),
          ),
      ],
    );
  }

  /// Mantiene los estados vacíos y de error legibles con el tema activo.
  Widget _message(
    String text,
    AutomationVisualPalette visual, {
    Widget? action,
  }) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 12),
    child: Column(
      children: [
        Text(text, style: TextStyle(color: visual.textMuted, fontSize: 13)),
        if (action != null) action,
      ],
    ),
  );
}
