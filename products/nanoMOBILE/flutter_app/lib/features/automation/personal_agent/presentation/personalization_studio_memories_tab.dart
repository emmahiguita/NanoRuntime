part of 'personalization_studio_screen.dart';

/// PERSONALIZATION-STUDIO-MEMORIES-TAB — Pestaña de Hechos y Memorias.
///
/// **QUÉ HACE:**
/// Muestra y administra los hechos clave y memorias aprendidas o declaradas por el usuario
/// para que el Agente EMMA conozca detalles personales y profesionales sin alucinaciones.
///
/// **CÓMO FUNCIONA:**
/// Renderiza una lista con micro-tipografía iOS Glass, botón de adición rápida, estado de
/// vigencia (activa/caducada/desactivada) y menú popup para alternar o eliminar.
///
/// **POR QUÉ:**
/// Separa la gestión de hechos durables en SQLite de la vista principal, manteniendo
/// código modular y estrictamente menor a 200 líneas de código.
class _PersonalizationStudioMemoriesTab extends StatelessWidget {
  final List<PersonalMemory> memories;
  final Map<String, _Scope> scopes;
  final bool canEdit;
  final VoidCallback onAddMemory;
  final ValueChanged<PersonalMemory> onEditMemory;
  final ValueChanged<PersonalMemory> onToggleMemory;
  final ValueChanged<PersonalMemory> onDeleteMemory;
  final VoidCallback? onLoadMore;

  const _PersonalizationStudioMemoriesTab({
    required this.memories,
    required this.scopes,
    required this.canEdit,
    required this.onAddMemory,
    required this.onEditMemory,
    required this.onToggleMemory,
    required this.onDeleteMemory,
    this.onLoadMore,
  });

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 90),
      children: [
        TextButton.icon(
          onPressed: !canEdit ? null : onAddMemory,
          icon: const Icon(Icons.note_add_outlined, size: 14),
          label: const Text('Agregar memoria', style: TextStyle(fontSize: 11)),
        ),
        if (memories.isEmpty)
          const Padding(
            padding: EdgeInsets.all(16),
            child: Center(
              child: Text(
                'Sin memorias declaradas. Los hechos históricos no se convierten en estado actual.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 11, color: Colors.grey),
              ),
            ),
          ),
        for (final memory in memories)
          Card(
            margin: const EdgeInsets.only(bottom: 6),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(9),
              side: const BorderSide(color: Color(0x22FFFFFF), width: 0.7),
            ),
            color: const Color(0x10FFFFFF),
            child: ListTile(
              dense: true,
              title: Text('${memory.key}: ${memory.value}', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
              subtitle: Text(
                '${personalMemoryKinds[memory.kind] ?? memory.kind} · ${memory.enabled ? memory.expired ? 'Caducada' : 'Activa' : 'Desactivada'} · ${scopes[memory.scopeKey]?.label ?? memory.scopeKey}',
                style: const TextStyle(fontSize: 9, color: Colors.white60),
              ),
              onTap: !canEdit ? null : () => onEditMemory(memory),
              trailing: PopupMenuButton<String>(
                enabled: canEdit,
                onSelected: (action) {
                  if (action == 'toggle') onToggleMemory(memory);
                  if (action == 'delete') onDeleteMemory(memory);
                },
                itemBuilder: (_) => [
                  PopupMenuItem(
                    value: 'toggle',
                    child: Text(memory.enabled ? 'Desactivar' : 'Activar', style: const TextStyle(fontSize: 11)),
                  ),
                  const PopupMenuItem(
                    value: 'delete',
                    child: Text('Eliminar', style: TextStyle(fontSize: 11, color: Colors.redAccent)),
                  ),
                ],
              ),
            ),
          ),
        if (memories.length >= 100 && onLoadMore != null)
          TextButton(
            onPressed: !canEdit ? null : onLoadMore,
            child: const Text('Cargar más memorias', style: TextStyle(fontSize: 11)),
          ),
      ],
    );
  }
}
