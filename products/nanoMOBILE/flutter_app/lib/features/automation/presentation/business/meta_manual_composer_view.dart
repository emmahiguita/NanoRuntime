part of 'meta_manual_composer.dart';

/// Controles adaptables; los callbacks conservan estado y autoridad manual.
extension _ComposerView on _ComposerState {
  Widget _buildEditor(BuildContext context) => SafeArea(
    top: false,
    child: Padding(
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 8),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (_notice != null)
            Text(_notice!, style: Theme.of(context).textTheme.bodySmall),
          if (_file != null || _template != null)
            Text(_file?.name ?? 'Plantilla: ${_template!['name']}'),
          TextField(
            controller: _text,
            enabled: !_busy && _requestId == null,
            minLines: 1,
            maxLines: 3,
            decoration: const InputDecoration(
              hintText: 'Escribe una respuesta',
              border: OutlineInputBorder(),
            ),
          ),
          Wrap(
            spacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              IconButton(
                tooltip: 'Adjuntar archivo',
                onPressed: _busy || _requestId != null ? null : _attach,
                icon: const Icon(Icons.attach_file),
              ),
              TextButton(
                onPressed: _busy || _requestId != null ? null : _chooseTemplate,
                child: const Text('Plantilla'),
              ),
              FilledButton.icon(
                onPressed: _busy ? null : _send,
                icon: Icon(_busy ? Icons.hourglass_top : Icons.send_outlined),
                label: Text(_busy ? 'Enviando…' : 'Enviar'),
              ),
            ],
          ),
          Text(
            'Envío manual${widget.lineLabel.isEmpty ? '' : ' ? ${widget.lineLabel}'}',
            style: Theme.of(context).textTheme.labelSmall,
          ),
        ],
      ),
    ),
  );
}
