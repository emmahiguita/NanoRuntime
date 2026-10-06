part of 'conversation_detail_sheet.dart';

extension ConversationDetailLibrary on _ConversationDetailSheetState {
  String? _verifiedAttachmentContact() => ConversationPhoneResolver.resolve(
    conversationId: canonicalConversationId(widget.item.conversationId),
    displayName: widget.item.displayName,
    lastMessage: widget.item.lastMessage,
    store: ref.read(conversationMemoryStoreProvider),
    personaContext: ref.read(personaContextProvider),
    deviceContacts: ref.read(allWhatsAppContactsProvider).value,
  );

  Future<void> _organizeFileInNano() async {
    try {
      final picked = await FilePicker.pickFiles(type: FileType.any);
      final file = picked?.files.single;
      if (file == null || file.path == null) return;
      if (!mounted) return;
      final suggested = NanoMediaCategory.forFileName(file.name);
      final visual = AutomationVisual.of(context);
      final category = await showModalBottomSheet<String>(
        context: context,
        backgroundColor: visual.isDark ? const Color(0xFF0F172A) : Colors.white,
        builder: (ctx) => SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 18, 16, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Guardar en una carpeta de Nano',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 8),
                for (final folder in NanoMediaCategory.all)
                  ListTile(
                    leading: Icon(
                      _folderIcon(folder.id),
                      color: folder.id == suggested
                          ? const Color(0xFF2563EB)
                          : visual.textMuted,
                    ),
                    title: Text(
                      folder.title,
                      style: TextStyle(color: visual.text),
                    ),
                    subtitle: Text(
                      folder.subtitle,
                      style: TextStyle(color: visual.textMuted),
                    ),
                    trailing: folder.id == suggested
                        ? const Icon(
                            Icons.check_circle_rounded,
                            color: Color(0xFF10B981),
                          )
                        : null,
                    onTap: () => Navigator.pop(ctx, folder.id),
                  ),
              ],
            ),
          ),
        ),
      );
      if (category == null || !mounted) return;
      _safeSetState(() {
        _busy = true;
        _statusText = 'Guardando ${file.name} en Nano...';
      });
      final savedPath = await const WhatsAppMediaShare().copyToCatalog(
        file.path!,
        category: category,
      );
      _safeSetState(
        () => _statusText = savedPath == null
            ? 'No se pudo guardar el archivo en la biblioteca de Nano.'
            : 'Guardado en ${_folderName(category)}: ${file.name}',
      );
    } catch (error) {
      _safeSetState(() => _statusText = 'Error al guardar el archivo: $error');
    } finally {
      _safeSetState(() => _busy = false);
    }
  }

  Future<void> _showNanoLibrary() async {
    const share = WhatsAppMediaShare();
    final filesFuture = share.listCatalog();
    String? selectedCategory;
    final visual = AutomationVisual.of(context);
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: visual.isDark ? const Color(0xFF0B1220) : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) => StatefulBuilder(
        builder: (ctx, setSheetState) => SafeArea(
          child: SizedBox(
            height: MediaQuery.sizeOf(ctx).height * 0.82,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 18, 12, 10),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.folder_copy_rounded,
                        color: Color(0xFF2563EB),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Biblioteca de Nano',
                              style: TextStyle(
                                color: visual.text,
                                fontSize: 18,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            Text(
                              'Archivos guardados en este dispositivo',
                              style: TextStyle(
                                color: visual.textMuted,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.pop(ctx),
                        icon: Icon(Icons.close_rounded, color: visual.text),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: FutureBuilder<List<NanoCatalogFile>>(
                    future: filesFuture,
                    builder: (ctx, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Center(child: CircularProgressIndicator());
                      }
                      if (snapshot.hasError) {
                        return Center(
                          child: Text(
                            'No se pudo cargar la biblioteca.',
                            style: TextStyle(color: visual.textMuted),
                          ),
                        );
                      }
                      final files = snapshot.data ?? const <NanoCatalogFile>[];
                      final visible = selectedCategory == null
                          ? files
                          : files
                                .where(
                                  (file) => file.category == selectedCategory,
                                )
                                .toList();
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SizedBox(
                            height: 104,
                            child: ListView(
                              scrollDirection: Axis.horizontal,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 14,
                              ),
                              children: [
                                _folderTile(
                                  visual,
                                  title: 'Todos',
                                  count: files.length,
                                  selected: selectedCategory == null,
                                  icon: Icons.folder_rounded,
                                  onTap: () => setSheetState(
                                    () => selectedCategory = null,
                                  ),
                                ),
                                for (final folder in NanoMediaCategory.all)
                                  _folderTile(
                                    visual,
                                    title: folder.title,
                                    count: files
                                        .where(
                                          (file) => file.category == folder.id,
                                        )
                                        .length,
                                    selected: selectedCategory == folder.id,
                                    icon: _folderIcon(folder.id),
                                    onTap: () => setSheetState(
                                      () => selectedCategory = folder.id,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.fromLTRB(20, 8, 20, 4),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    selectedCategory == null
                                        ? 'Archivos recientes'
                                        : _folderName(selectedCategory!),
                                    style: TextStyle(
                                      color: visual.text,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                                TextButton.icon(
                                  onPressed: () {
                                    Navigator.pop(ctx);
                                    _organizeFileInNano();
                                  },
                                  icon: const Icon(Icons.add_rounded, size: 18),
                                  label: const Text('Importar'),
                                ),
                              ],
                            ),
                          ),
                          Expanded(
                            child: visible.isEmpty
                                ? Center(
                                    child: Padding(
                                      padding: const EdgeInsets.all(24),
                                      child: Column(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(
                                            Icons.folder_open_rounded,
                                            size: 42,
                                            color: visual.textMuted,
                                          ),
                                          const SizedBox(height: 10),
                                          Text(
                                            'Esta carpeta aún no tiene archivos.',
                                            style: TextStyle(
                                              color: visual.textMuted,
                                            ),
                                          ),
                                          const SizedBox(height: 8),
                                          FilledButton.icon(
                                            onPressed: () {
                                              Navigator.pop(ctx);
                                              _organizeFileInNano();
                                            },
                                            icon: const Icon(Icons.add_rounded),
                                            label: const Text(
                                              'Agregar archivo',
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  )
                                : ListView.separated(
                                    padding: const EdgeInsets.fromLTRB(
                                      12,
                                      0,
                                      12,
                                      20,
                                    ),
                                    itemCount: visible.length,
                                    separatorBuilder: (_, __) => Divider(
                                      color: visual.textMuted.withValues(
                                        alpha: 0.16,
                                      ),
                                      height: 1,
                                    ),
                                    itemBuilder: (ctx, index) {
                                      final file = visible[index];
                                      return ListTile(
                                        leading: CircleAvatar(
                                          backgroundColor: visual.isDark
                                              ? Colors.white10
                                              : const Color(0xFFF1F5F9),
                                          child: Icon(
                                            _fileIcon(file.name),
                                            color: _fileColor(file.name),
                                          ),
                                        ),
                                        title: Text(
                                          file.name,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(
                                            color: visual.text,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                        subtitle: Text(
                                          '${_folderName(file.category)} · ${_humanFileSize(file.sizeBytes)}',
                                          style: TextStyle(
                                            color: visual.textMuted,
                                            fontSize: 12,
                                          ),
                                        ),
                                        trailing: const Icon(
                                          Icons.send_rounded,
                                          size: 19,
                                        ),
                                        onTap: () {
                                          Navigator.pop(ctx);
                                          _shareCatalogFile(file);
                                        },
                                      );
                                    },
                                  ),
                          ),
                        ],
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _folderTile(
    AutomationVisualPalette visual, {
    required String title,
    required int count,
    required bool selected,
    required IconData icon,
    required VoidCallback onTap,
  }) => SizedBox(
    width: 146,
    child: Card(
      color: selected
          ? (visual.isDark ? const Color(0xFF172B4D) : const Color(0xFFEFF6FF))
          : (visual.isDark ? const Color(0xFF131D2E) : const Color(0xFFF8FAFC)),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                icon,
                color: selected ? const Color(0xFF2563EB) : visual.textMuted,
              ),
              const Spacer(),
              Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: visual.text,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Text(
                '$count archivos',
                style: TextStyle(color: visual.textMuted, fontSize: 10),
              ),
            ],
          ),
        ),
      ),
    ),
  );

  Future<void> _shareCatalogFile(NanoCatalogFile file) async {
    if (_busy) return;
    _safeSetState(() {
      _busy = true;
      _statusText = 'Preparando ${file.name}...';
    });
    try {
      final contact = _verifiedAttachmentContact();
      if (contact == null || contact.length < 7) {
        _safeSetState(
          () => _statusText =
              'No hay un número verificable para ${widget.item.displayName}.',
        );
        return;
      }
      const share = WhatsAppMediaShare();
      final returnsToNano = await share.isAccessibilityEnabled();
      final ok = await share.shareFile(
        path: file.path,
        contact: contact,
        caption: _inputController.text.trim(),
        packageName: widget.item.packageName,
        autoSend: true,
      );
      _safeSetState(
        () => _statusText = !ok
            ? 'No se pudo abrir ${file.name} en WhatsApp.'
            : returnsToNano
            ? 'Archivo preparado en WhatsApp. Nano regresará al finalizar; verifica el envío.'
            : 'Archivo abierto en WhatsApp. Confirma Enviar allí para completar.',
      );
    } catch (error) {
      _safeSetState(() => _statusText = 'Error al adjuntar el archivo: $error');
    } finally {
      _safeSetState(() => _busy = false);
    }
  }

  String _folderName(String id) =>
      NanoMediaCategory.all
          .where((folder) => folder.id == id)
          .map((folder) => folder.title)
          .firstOrNull ??
      'Documentos';

  static IconData _folderIcon(String id) => switch (id) {
    NanoMediaCategory.products => Icons.inventory_2_rounded,
    NanoMediaCategory.reports => Icons.assessment_rounded,
    NanoMediaCategory.photos => Icons.photo_library_rounded,
    NanoMediaCategory.videos => Icons.video_library_rounded,
    _ => Icons.folder_copy_rounded,
  };

  static IconData _fileIcon(String name) {
    final category = NanoMediaCategory.forFileName(name);
    if (category == NanoMediaCategory.photos) return Icons.image_rounded;
    if (category == NanoMediaCategory.videos) return Icons.video_file_rounded;
    if (name.toLowerCase().endsWith('.pdf'))
      return Icons.picture_as_pdf_rounded;
    return Icons.insert_drive_file_rounded;
  }

  static Color _fileColor(String name) => name.toLowerCase().endsWith('.pdf')
      ? const Color(0xFFEF4444)
      : NanoMediaCategory.forFileName(name) == NanoMediaCategory.photos
      ? const Color(0xFF059669)
      : NanoMediaCategory.forFileName(name) == NanoMediaCategory.videos
      ? const Color(0xFF2563EB)
      : const Color(0xFF64748B);

  static String _humanFileSize(int bytes) => bytes < 1024
      ? '$bytes B'
      : bytes < 1024 * 1024
      ? '${(bytes / 1024).toStringAsFixed(0)} KB'
      : '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
}
