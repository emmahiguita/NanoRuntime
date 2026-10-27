part of 'conversation_pdf_viewer.dart';

extension _ConversationPdfViewerActions on _ConversationPdfPreviewState {
  Future<void> _renameFile() async {
    final controller = TextEditingController(text: _currentName);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final newName = await NanoGlassDialog.show<String>(
      context: context,
      title: 'Renombrar documento',
      subtitle: 'Modifica el nombre visible de este PDF',
      icon: Icons.edit_note_rounded,
      iconColor: const Color(0xFF38BDF8),
      content: TextField(
        controller: controller,
        autofocus: true,
        style: TextStyle(
          color: isDark ? Colors.white : const Color(0xFF0F172A),
          fontSize: 13.5,
        ),
        decoration: InputDecoration(
          hintText: 'Nombre del archivo',
          filled: true,
          fillColor: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 14,
            vertical: 10,
          ),
        ),
      ),
      actions: [
        NanoMetallicButton(
          label: 'Cancelar',
          style: NanoMetallicButtonStyle.subtle,
          onPressed: () => Navigator.pop(context),
        ),
        NanoMetallicButton(
          label: 'Guardar',
          icon: Icons.check_rounded,
          style: NanoMetallicButtonStyle.primary,
          onPressed: () => Navigator.pop(context, controller.text.trim()),
        ),
      ],
    );

    if (newName != null && newName.isNotEmpty && newName != _currentName) {
      if (widget.source.isLocal && widget.source.localFile != null) {
        final f = widget.source.localFile!;
        final targetExt = newName.toLowerCase().endsWith('.pdf')
            ? newName
            : '$newName.pdf';
        try {
          await f.rename('${f.parent.path}/$targetExt');
        } catch (_) {}
      }
      setState(() => _currentName = newName);
    }
  }

  Widget _buildHeader(Uint8List? bytes) {
    final onSurface = Theme.of(context).colorScheme.onSurface;
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 2, 8, 6),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: const Color(0xFFEF4444).withValues(alpha: 0.20),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(
              Icons.picture_as_pdf_rounded,
              color: Color(0xFFF87171),
              size: 18,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              _currentName,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: onSurface,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Semantics(
            label: 'Renombrar PDF',
            button: true,
            child: IconButton(
              icon: Icon(
                Icons.drive_file_rename_outline_rounded,
                color: onSurface.withValues(alpha: 0.75),
                size: 18,
              ),
              onPressed: _renameFile,
            ),
          ),
          if (bytes != null) ...[
            Semantics(
              label: 'Imprimir PDF',
              button: true,
              child: IconButton(
                icon: Icon(
                  Icons.print_rounded,
                  color: onSurface.withValues(alpha: 0.75),
                  size: 18,
                ),
                onPressed: () => Printing.layoutPdf(
                  name: _currentName,
                  onLayout: (_) async => bytes,
                ),
              ),
            ),
            Semantics(
              label: 'Compartir PDF',
              button: true,
              child: IconButton(
                icon: Icon(
                  Icons.share_rounded,
                  color: onSurface.withValues(alpha: 0.75),
                  size: 18,
                ),
                onPressed: () => Printing.sharePdf(
                  bytes: bytes,
                  filename: _currentName.toLowerCase().endsWith('.pdf')
                      ? _currentName
                      : '$_currentName.pdf',
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildError(Object? error) => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.error_outline_rounded,
            color: Colors.amber,
            size: 36,
          ),
          const SizedBox(height: 8),
          const Text(
            'No se pudo visualizar el PDF',
            style: TextStyle(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 4),
          Text('$error', textAlign: TextAlign.center, maxLines: 2),
          const SizedBox(height: 12),
          NanoMetallicButton(
            label: 'Reintentar',
            icon: Icons.refresh_rounded,
            onPressed: () => setState(() => _document = _loadDocument()),
          ),
        ],
      ),
    ),
  );
}
