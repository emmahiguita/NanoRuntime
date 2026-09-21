part of 'personalization_studio_screen.dart';

/// PERSONALIZATION-STUDIO-CONTACTS-TAB — Pestaña de Contactos y Políticas de Agente.
///
/// **QUÉ HACE:**
/// Gestiona la asignación del Agente EMMA a contactos individuales o globales,
/// permitiendo configurar retardos de respuesta (delay) y vincular conversaciones reales.
///
/// **CÓMO FUNCIONA:**
/// Integra WhatsAppReplyDelayCard, selector de perfiles vinculados, botón de creación
/// de contactos manuales y menú contextual para asociar identidades de mensajería.
///
/// **POR QUÉ:**
/// Separa la gestión de relaciones de la pantalla principal, garantizando código mantenible,
/// modular y estrictamente menor a 200 líneas de código.
class _PersonalizationStudioContactsTab extends StatelessWidget {
  final List<_Scope> contacts;
  final bool canEdit;
  final VoidCallback onImport;
  final VoidCallback onNewContact;
  final ValueChanged<_Scope> onSelectAndEdit;
  final ValueChanged<_Scope> onBind;
  final ValueChanged<_Scope> onDelete;

  const _PersonalizationStudioContactsTab({
    required this.contacts,
    required this.canEdit,
    required this.onImport,
    required this.onNewContact,
    required this.onSelectAndEdit,
    required this.onBind,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 90),
      children: [
        _LearnBanner(onImport: !canEdit ? null : onImport),
        const WhatsAppReplyDelayCard(),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
          decoration: BoxDecoration(
            color: const Color(0x0CFFFFFF),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: const Color(0x1FFFFFFF), width: 0.8),
          ),
          child: const Text(
            'Solo las conversaciones vinculadas reciben su estilo específico. Si falta un contacto, recibe un mensaje suyo para obtener su identidad de forma segura.',
            style: TextStyle(fontSize: 10, color: Colors.white70, height: 1.25),
          ),
        ),
        const SizedBox(height: 4),
        OutlinedButton.icon(
          onPressed: !canEdit ? null : onNewContact,
          icon: const Icon(Icons.person_search_rounded, size: 14, color: Color(0xFF25D366)),
          label: const Text('Reconocer contacto con WhatsApp', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.white)),
          style: OutlinedButton.styleFrom(
            side: const BorderSide(color: Color(0x3025D366)),
            backgroundColor: const Color(0x1025D366),
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
        ),
        for (final contact in contacts)
          Card(
            margin: const EdgeInsets.only(bottom: 6),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(9),
              side: const BorderSide(color: Color(0x22FFFFFF), width: 0.7),
            ),
            color: const Color(0x10FFFFFF),
            child: ListTile(
              dense: true,
              title: Text(contact.label, style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600)),
              subtitle: Text(
                '${contact.id.startsWith('contact:') ? 'Vinculado' : 'Sin vincular'} · ${contact.profile?.facts['styleRegister'] ?? 'neutral'} · ${contact.profile?.facts['learnStyle'] == 'false' ? 'No usar para estilo' : 'Importación permitida'}',
                style: const TextStyle(fontSize: 9.5, color: Colors.white60),
              ),
              onTap: !canEdit ? null : () => onSelectAndEdit(contact),
              trailing: PopupMenuButton<String>(
                enabled: canEdit,
                onSelected: (action) {
                  if (action == 'bind') onBind(contact);
                  if (action == 'delete') onDelete(contact);
                },
                itemBuilder: (_) => [
                  if (!contact.id.startsWith('contact:'))
                    const PopupMenuItem(
                      value: 'bind',
                      child: Text('Vincular a conversación', style: TextStyle(fontSize: 11)),
                    ),
                  if (contact.profile != null)
                    const PopupMenuItem(
                      value: 'delete',
                      child: Text('Eliminar perfil', style: TextStyle(fontSize: 11, color: Colors.redAccent)),
                    ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}
