/// PERSONALIZATION-STUDIO-IMPORT-01 — Pantalla de revisión de importaciones.
///
/// **QUÉ HACE:**
/// Permite revisar, seleccionar y verificar los candidatos de mensajes importados.
///
/// **CÓMO FUNCIONA:**
/// Implementa una lista seleccionable tipo Sliver con barra inferior segura.
///
/// **POR QUÉ:**
/// Otorga al usuario control total sobre las respuestas que entrenarán al agente personal.
part of 'personalization_studio_screen.dart';

class _ImportReview extends StatefulWidget {
  const _ImportReview({required this.preview, required this.scopeLabel});
  final PersonaImportPreview preview;
  final String scopeLabel;
  @override
  State<_ImportReview> createState() => _ImportReviewState();
}

class _ImportReviewState extends State<_ImportReview> {
  late final Set<int> _selected = {
    for (var i = 0; i < widget.preview.candidates.length; i++) i,
  };
  bool _ownerVerified = false;

  @override
  Widget build(BuildContext context) {
    final needsOwner = _selected.any(
      (i) => !{'template', 'memory'}.contains(widget.preview.candidates[i].kind),
    );
    return Scaffold(
      appBar: AppBar(title: const Text('Revisar antes de guardar')),
      body: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(
                    '${widget.preview.fileName}\nDestino: ${widget.scopeLabel}\n'
                    '${widget.preview.candidates.length} candidatos; ${_selected.length} seleccionados.',
                  ),
                ),
                if (widget.preview.warnings.isNotEmpty)
                  ExpansionTile(
                    title: Text('${widget.preview.warnings.length} avisos de importación'),
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(12),
                        child: Text(widget.preview.warnings.join('\n')),
                      ),
                    ],
                  ),
                CheckboxListTile(
                  title: const Text('Seleccionar todos los candidatos'),
                  value: widget.preview.candidates.isNotEmpty &&
                      _selected.length == widget.preview.candidates.length,
                  onChanged: widget.preview.candidates.isEmpty ? null : (v) {
                    setState(() {
                      _selected.clear();
                      if (v == true) {
                        _selected.addAll(List.generate(widget.preview.candidates.length, (i) => i));
                      }
                    });
                  },
                ),
                if (needsOwner)
                  CheckboxListTile(
                    title: const Text('Confirmo que las respuestas seleccionadas las escribí yo'),
                    value: _ownerVerified,
                    onChanged: (v) => setState(() => _ownerVerified = v ?? false),
                  ),
              ],
            ),
          ),
          SliverList.builder(
            itemCount: widget.preview.candidates.length,
            itemBuilder: (context, i) {
              final candidate = widget.preview.candidates[i];
              return CheckboxListTile(
                value: _selected.contains(i),
                onChanged: (v) => setState(() {
                  if (v == true) {
                    _selected.add(i);
                  } else {
                    _selected.remove(i);
                  }
                }),
                title: Text(candidate.title),
                subtitle: Text(candidate.preview),
              );
            },
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: FilledButton.icon(
            onPressed: _selected.isEmpty || (needsOwner && !_ownerVerified)
                ? null
                : () => Navigator.pop(
                    context,
                    _ImportSelection(Set.of(_selected), _ownerVerified),
                  ),
            icon: const Icon(Icons.save_outlined),
            label: Text('Guardar ${_selected.length} seleccionados'),
          ),
        ),
      ),
    );
  }
}
