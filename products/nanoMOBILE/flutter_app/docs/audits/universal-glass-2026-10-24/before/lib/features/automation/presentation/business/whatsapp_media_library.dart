import 'dart:async';
import 'package:flutter/material.dart';
import '../../application/whatsapp_media_catalog_client.dart';
import 'whatsapp_media_library_tile.dart';

/// Biblioteca separada de mensajes: un archivo encontrado no prueba su chat.
class WhatsAppMediaLibrary extends StatefulWidget {
  const WhatsAppMediaLibrary({super.key});
  static Future<void> show(BuildContext context) => showModalBottomSheet<void>(
    context: context,
    useRootNavigator: true,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (_) => const FractionallySizedBox(
      heightFactor: .9,
      child: WhatsAppMediaLibrary(),
    ),
  );
  @override
  State<WhatsAppMediaLibrary> createState() => _WhatsAppMediaLibraryState();
}

class _WhatsAppMediaLibraryState extends State<WhatsAppMediaLibrary> {
  final _client = WhatsAppMediaCatalogClient();
  final _rows = <String, Map<String, dynamic>>{};
  bool _indexing = false, _reading = false, _more = false;
  bool _reload = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    // Primero lee SQLite; la enumeración incremental no bloquea la primera pintura.
    unawaited(_read());
    unawaited(_sync());
  }

  /// Solo existe durante esta biblioteca. Cerrar impide solicitar el siguiente lote.
  Future<void> _sync() async {
    if (_indexing) return;
    setState(() {
      _indexing = true;
      _error = null;
    });
    _client.clearThumbnails();
    try {
      Map<String, dynamic> result;
      do {
        result = await _client.scan();
        if (!mounted) return;
        await _read();
        // Cede entre lotes; no encola todo el almacenamiento de una vez.
        await Future<void>.delayed(const Duration(milliseconds: 40));
      } while (mounted && result['hasMore'] == true);
    } catch (_) {
      if (mounted) {
        _error =
            'No se pudo indexar. Revisa los permisos de fotos, vídeos y audio. Requiere Android 11 o posterior.';
      }
    } finally {
      if (mounted) setState(() => _indexing = false);
    }
  }

  /// Cursor compuesto: la página anterior no depende del número de filas recientes.
  Future<void> _read({bool earlier = false}) async {
    if (!mounted) return;
    if (_reading) {
      _reload = true;
      return;
    }
    _reading = true;
    try {
      final values = _ordered;
      final page = await _client.page(
        before: earlier && values.isNotEmpty ? values.last : null,
      );
      if (!mounted) return;
      setState(() {
        for (final raw in (page['rows'] as List? ?? [])) {
          final row = Map<String, dynamic>.from(raw as Map);
          _rows['${row['uri']}'] = row;
        }
        if (earlier || values.length <= 60) _more = page['hasMore'] == true;
      });
    } catch (_) {
      if (mounted) setState(() => _error = 'No se pudo leer el índice local.');
    } finally {
      _reading = false;
      if (mounted && _reload) {
        _reload = false;
        unawaited(_read());
      }
    }
  }

  List<Map<String, dynamic>> get _ordered =>
      _rows.values.toList()..sort((a, b) {
        final time = int.parse(
          '${b['modified']}',
        ).compareTo(int.parse('${a['modified']}'));
        return time != 0 ? time : '${b['uri']}'.compareTo('${a['uri']}');
      });

  @override
  Widget build(BuildContext context) {
    final rows = _ordered;
    return Material(
      // El tema glass puede ser transparente: aísla el texto del modal inferior.
      color: Theme.of(context).brightness == Brightness.dark
          ? const Color(0xFF0F172A)
          : const Color(0xFFF8FAFC),
      child: Column(
        children: [
          ListTile(
            title: const Text('Multimedia de WhatsApp'),
            subtitle: const Text(
              'Archivos autorizados · sin asignación automática a chats',
            ),
            trailing: IconButton(
              tooltip: 'Cerrar biblioteca',
              icon: const Icon(Icons.close),
              onPressed: () => Navigator.pop(context),
            ),
          ),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              'Solo archivos publicados en MediaStore del almacenamiento principal. No incluye caché privada, archivos ocultos ni todos los PDF.',
            ),
          ),
          Row(
            children: [
              TextButton.icon(
                onPressed: _indexing ? null : _sync,
                icon: const Icon(Icons.sync),
                label: const Text('Actualizar índice'),
              ),
              if (_more)
                TextButton(
                  onPressed: _reading ? null : () => _read(earlier: true),
                  child: const Text('Más archivos'),
                ),
            ],
          ),
          if (_indexing) const LinearProgressIndicator(minHeight: 2),
          if (_error != null)
            Padding(padding: const EdgeInsets.all(12), child: Text(_error!)),
          Expanded(
            child: rows.isEmpty
                ? const Center(
                    child: Text('Sin archivos indexados accesibles.'),
                  )
                : GridView.builder(
                    padding: const EdgeInsets.all(12),
                    gridDelegate:
                        const SliverGridDelegateWithMaxCrossAxisExtent(
                          maxCrossAxisExtent: 220,
                          mainAxisSpacing: 8,
                          crossAxisSpacing: 8,
                          mainAxisExtent: 190,
                        ),
                    itemCount: rows.length,
                    itemBuilder: (_, i) => WhatsAppMediaLibraryTile(
                      key: ValueKey(
                        '${rows[i]['uri']}|${rows[i]['generation']}',
                      ),
                      row: rows[i],
                      client: _client,
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}
