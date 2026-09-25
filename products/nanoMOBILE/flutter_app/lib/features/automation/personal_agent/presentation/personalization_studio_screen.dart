import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nanoai/core/services/nano_runtime_api.dart';
import '../../domain/whatsapp_contact.dart';
import '../../application/whatsapp_contacts_provider.dart';
import '../../engine/messaging/conversation_key.dart';
import '../../engine/messaging/tone_profile.dart';
import '../../engine/language/conversation_semantic_tag.dart';
import '../../engine/notifications/notification_object.dart';
import '../application/persona_context.dart';
import '../application/persona_import.dart';
import '../application/persona_repository.dart';
import '../domain/persona_example.dart';
import '../domain/persona_profile.dart';
import '../domain/personal_memory.dart';
import 'package:nanoai/features/automation/presentation/widgets/whatsapp_reply_delay_card.dart';
import '../../presentation/widgets/conversation_semantic_badge.dart';
import '../application/personal_style_seed.dart';

part 'personalization_studio_actions.dart';
part 'personalization_studio_actions_dialogs.dart';
part 'personalization_studio_actions_import.dart';
part 'personalization_studio_loader.dart';
part 'personalization_studio_dialog_models.dart';
part 'personalization_studio_style_dialog.dart';
part 'personalization_studio_example_dialog.dart';
part 'personalization_studio_example_dialog_fields.dart';
part 'personalization_studio_diagram.dart';
part 'personalization_studio_example_card.dart';
part 'personalization_studio_header.dart';
part 'personalization_studio_examples_tab.dart';
part 'personalization_studio_contacts_tab.dart';
part 'personalization_studio_memories_tab.dart';
part 'personalization_studio_imports_tab.dart';
part 'personalization_studio_memory_dialog.dart';
part 'personalization_studio_import_review.dart';
part 'personalization_studio_single_input_dialog.dart';
part 'personalization_studio_whatsapp_picker.dart';

/// PERSONALIZATION-STUDIO-SCREEN — Orquestador del Agente Personal EMMA.
///
/// **QUÉ HACE:**
/// Coordina la personalización de EMMA: perfiles de estilo, memorias declarativas,
/// frases de ejemplo multirrespuesta y sincronización con contactos de mensajería.
///
/// **CÓMO FUNCIONA:**
/// Ensambla vistas modulares desacopladas de menos de 200 líneas cada una,
/// consumiendo PersonaRepository sobre SQLite sin procesos zombi ni bloqueos.
///
/// **POR QUÉ:**
/// Previene cuellos de botella en la UI, elimina errores de Overlay mediante
/// BottomSheets modales con rootNavigator y garantiza adherencia estricta a SOLID.
class PersonalizationStudioScreen extends ConsumerStatefulWidget {
  final int initialIndex;
  const PersonalizationStudioScreen({super.key, this.initialIndex = 0});

  @override
  ConsumerState<PersonalizationStudioScreen> createState() =>
      _PersonalizationStudioScreenState();
}

class _PersonalizationStudioScreenState
    extends ConsumerState<PersonalizationStudioScreen> {
  final _repo = PersonaRepository.instance;
  String _scope = 'owner';
  String? _error;
  bool _busy = false, _loading = true, _importing = false;
  int _reloadGeneration = 0;
  bool get _working => _busy || _loading || _importing;
  bool get _canEdit => !_working && _error == null;
  Map<String, _Scope> _scopes = {
    'owner': const _Scope('owner', 'Estilo global del dueño'),
  };
  Map<String, dynamic> _summary = {};
  PersonaProfile? _owner;
  List<PersonaExample> _examples = [];
  List<PersonalMemory> _memories = [];

  void _safeSetState(VoidCallback fn) {
    if (mounted) setState(fn);
  }

  @override
  void initState() {
    super.initState();
    unawaited(_reload());
  }

  @override
  Widget build(BuildContext context) {
    final contacts = _scopes.values
        .where((s) => s.id != 'owner' && !s.id.startsWith('role:'))
        .toList();
    final batches = (_summary['batches'] as List? ?? const [])
        .whereType<Map>()
        .toList();

    return DefaultTabController(
      length: 4,
      initialIndex: widget.initialIndex,
      child: Scaffold(
        appBar: AppBar(
          title: const Text(
            'Agente Personal · EMMA',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
          ),
          actions: [
            Semantics(
              label: 'Ayuda',
              button: true,
              child: IconButton(
                icon: const Icon(Icons.help_outline, size: 20),
                onPressed: _openHelpSheet,
              ),
            ),
          ],
          bottom: const TabBar(
            isScrollable: true,
            tabs: [
              Tab(text: 'Frases'),
              Tab(text: 'Contactos'),
              Tab(text: 'Memorias'),
              Tab(text: 'Historial'),
            ],
          ),
        ),
        body: Column(
          children: [
            if (_working) const LinearProgressIndicator(minHeight: 2),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.all(8),
                child: Text(
                  'Error: $_error',
                  style: const TextStyle(fontSize: 10, color: Colors.redAccent),
                ),
              ),
            _PersonalizationStudioHeader(
              summary: _summary,
              scope: _scope,
              scopes: _scopes,
              canEdit: _canEdit,
              working: _working,
              onSelectScope: _selectScope,
              onEditStyle: () {
                final cur =
                    _scopes[_scope] ??
                    _scopes['owner'] ??
                    const _Scope('owner', 'Estilo global del dueño');
                _editStyle(cur);
              },
              onOrganizeLearning: () => _run(() async {
                final count = await ensurePersonalStyleSeed(_repo);
                _notice(
                  'Aprendizaje organizado: $count frases artificiales retiradas.',
                );
              }),
              onRefresh: _reload,
            ),
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
                      () => _repo.updateExample(
                        e,
                        tone: {...e.tone, 'enabled': '$v'},
                      ),
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
            ),
          ],
        ),
      ),
    );
  }
}
