part of 'personalization_studio_screen.dart';

/// QUÉ: ensambla las pestañas de frases, contactos, memorias e historial.
/// CÓMO: conecta cada vista existente con las acciones CRUD de su pantalla.
/// POR QUÉ: conserva el orquestador bajo 200 líneas sin duplicar vistas ni lógica.
extension _PersonalizationStudioTabs on _PersonalizationStudioScreenState {
  Widget _personalizationTabs(List<_Scope> contacts, List<Map> batches) =>
      Expanded(
        child: TabBarView(
          children: [
            _PersonalizationStudioExamplesTab(
              examples: _examples,
              canEdit: _canEdit,
              onAddPhrase: () => _editExample(),
              onAddTemplate: () => _editExample(template: true),
              onEditExample: (e) => _editExample(example: e),
              onAddResponse: _addResponseToExample,
              onDeleteExample: _deleteExampleConfirmed,
              onToggleExample: (e, v) => _run(
                () =>
                    _repo.updateExample(e, tone: {...e.tone, 'enabled': '$v'}),
              ),
              onLoadMore: _loadMoreExamples,
            ),
            _PersonalizationStudioContactsTab(
              contacts: contacts,
              canEdit: _canEdit,
              onImport: _import,
              onNewContact: _newContact,
              onSelectAndEdit: (c) {
                _selectScope(c.id);
                unawaited(_editStyle(c));
              },
              onBind: _bind,
              onDelete: _deleteContactConfirmed,
            ),
            _PersonalizationStudioMemoriesTab(
              memories: _memories,
              scopes: _scopes,
              canEdit: _canEdit,
              onAddMemory: () => _editMemory(),
              onEditMemory: (m) => _editMemory(m),
              onToggleMemory: (m) => _run(
                () => _repo.savePersonalMemory(
                  m.copyWith(
                    metadata: {...m.metadata, 'enabled': '${!m.enabled}'},
                  ),
                ),
              ),
              onDeleteMemory: _deleteMemoryConfirmed,
              onLoadMore: _loadMoreMemories,
            ),
            _PersonalizationStudioImportsTab(
              batches: batches,
              canEdit: _canEdit,
              onViewOrigin: _viewBatchOrigin,
              onDeleteBatch: _deleteBatch,
              metadataParser: _batchMetadata,
              dateFormatter: _batchDate,
            ),
          ],
        ),
      );
}
