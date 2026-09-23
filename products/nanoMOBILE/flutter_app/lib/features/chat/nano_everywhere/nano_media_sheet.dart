// nano_media_sheet.dart — Vista interactiva de selección y descarga en lote.
// QUÉ: Presenta los archivos descubiertos (vídeo, imágenes, audio) con casillas y botón de descarga.
// CÓMO: Permite marcar/desmarcar individualmente o en lote y delega la descarga en NanoAiController.
// POR QUÉ: Mantiene nano_assistant_panel.dart compacto (<200 líneas) separando la UI de descargas.
import 'package:flutter/material.dart';
import 'nano_ai_controller.dart';
import 'nano_ai_models.dart';

class NanoMediaSheet extends StatefulWidget {
  const NanoMediaSheet({super.key, required this.controller});
  final NanoAiController controller;

  @override
  State<NanoMediaSheet> createState() => _NanoMediaSheetState();
}

class _NanoMediaSheetState extends State<NanoMediaSheet> {
  final _selected = <NanoMediaResource>{};

  @override
  void initState() {
    super.initState();
    _selected.addAll(widget.controller.detectedMedia);
  }

  @override
  Widget build(BuildContext context) {
    final items = widget.controller.detectedMedia;
    if (items.isEmpty) return const SizedBox.shrink();

    final t = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Text('${_selected.length}/${items.length} seleccionados', style: t.textTheme.labelMedium),
              const Spacer(),
              TextButton(
                onPressed: () => setState(() {
                  if (_selected.length == items.length) {
                    _selected.clear();
                  } else {
                    _selected.addAll(items);
                  }
                }),
                child: Text(_selected.length == items.length ? 'Limpiar' : 'Todos'),
              ),
            ],
          ),
          ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 180),
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: items.length,
              itemBuilder: (context, i) {
                final item = items[i];
                final isChecked = _selected.contains(item);
                return CheckboxListTile(
                  dense: true,
                  value: isChecked,
                  title: Text(item.title, maxLines: 1, overflow: TextOverflow.ellipsis),
                  subtitle: Text('${item.typeLabel} · ${item.quality ?? "Original"}'),
                  secondary: Icon(_iconFor(item.type), color: const Color(0xFF23C6C1)),
                  onChanged: (val) => setState(() {
                    if (val == true) {
                      _selected.add(item);
                    } else {
                      _selected.remove(item);
                    }
                  }),
                );
              },
            ),
          ),
          const SizedBox(height: 6),
          FilledButton.icon(
            onPressed: _selected.isEmpty
                ? null
                : () => widget.controller.downloadMedia(_selected.toList()),
            icon: const Icon(Icons.download_rounded),
            label: Text('Descargar (${_selected.length})'),
          ),
        ],
      ),
    );
  }

  IconData _iconFor(NanoMediaType type) => switch (type) {
    NanoMediaType.video => Icons.play_circle_fill_rounded,
    NanoMediaType.image => Icons.image_rounded,
    NanoMediaType.audio => Icons.audiotrack_rounded,
    NanoMediaType.document => Icons.description_rounded,
  };
}
