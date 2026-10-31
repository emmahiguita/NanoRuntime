part of 'nano_contact_picker_sheet.dart';

/// Lista y buscador de contactos de la libreta para NanoContactPickerSheet.
///
/// QUÉ HACE:
/// - Presenta los contactos del dispositivo con badges claros de estado de WhatsApp.
///
/// CÓMO SE CONECTA:
/// - Lee allWhatsAppContactsProvider y contactsPermissionProvider.
///
/// POR QUÉ:
/// - Mantiene la presentación de la agenda desacoplada del contenedor Glass (< 150 líneas).
class _NanoContactPickerList extends ConsumerWidget {
  final String searchQuery;
  final ValueChanged<WhatsAppContact> onContactSelected;

  const _NanoContactPickerList({
    required this.searchQuery,
    required this.onContactSelected,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final colors = NanoThemeExtension.of(context).colors;
    final hasPermAsync = ref.watch(contactsPermissionProvider);

    return hasPermAsync.when(
      loading: () => const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: CircularProgressIndicator(strokeWidth: 2.2),
        ),
      ),
      error: (_, __) => _NanoContactPickerPermissionCard(onContactSelected: onContactSelected),
      data: (hasPermission) {
        if (!hasPermission) {
          return _NanoContactPickerPermissionCard(onContactSelected: onContactSelected);
        }
        return _buildContactsList(context, ref, isDark, colors);
      },
    );
  }

  Widget _buildContactsList(
    BuildContext context,
    WidgetRef ref,
    bool isDark,
    dynamic colors,
  ) {
    final allContacts = ref.watch(allWhatsAppContactsProvider).value ?? const [];
    final cleanQuery = searchQuery.trim().toLowerCase();

    final filtered = cleanQuery.isEmpty
        ? allContacts
        : allContacts.where((c) {
            return c.name.toLowerCase().contains(cleanQuery) ||
                c.number.contains(cleanQuery);
          }).toList();

    if (filtered.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(24),
        child: Center(
          child: Text(
            cleanQuery.isEmpty ? 'No hay contactos disponibles' : 'Sin coincidencias para "$searchQuery"',
            style: TextStyle(
              fontSize: 12,
              color: isDark ? Colors.white54 : colors.onSurfaceVariant,
            ),
          ),
        ),
      );
    }

    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: filtered.length > 25 ? 25 : filtered.length,
      itemBuilder: (context, index) {
        final contact = filtered[index];
        final initial = contact.name.trim().isNotEmpty
            ? contact.name.trim()[0].toUpperCase()
            : '?';
        return ListTile(
          dense: true,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 0),
          leading: CircleAvatar(
            radius: 17,
            backgroundColor: contact.isWhatsAppVerified
                ? const Color(0xFF25D366).withValues(alpha: 0.18)
                : (isDark ? Colors.white12 : const Color(0xFFE2E8F0)),
            child: Text(
              initial,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: contact.isWhatsAppVerified
                    ? const Color(0xFF15803D)
                    : (isDark ? Colors.white70 : colors.onSurface),
              ),
            ),
          ),
          title: Text(
            contact.name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
              color: isDark ? Colors.white : colors.onSurface,
            ),
          ),
          subtitle: Text(
            contact.number.isNotEmpty ? contact.number : contact.jid,
            style: TextStyle(
              fontSize: 11,
              color: isDark ? Colors.white54 : colors.onSurfaceVariant,
            ),
          ),
          trailing: _buildTrailing(context, ref, contact, isDark),
          onTap: () => onContactSelected(contact),
        );
      },
    );
  }

  Widget _buildTrailing(BuildContext context, WidgetRef ref, WhatsAppContact contact, bool isDark) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _buildStatusBadge(contact, isDark),
        if (contact.id.isNotEmpty) ...[
          const SizedBox(width: 4),
          IconButton(
            icon: Icon(Icons.info_outline_rounded, size: 16, color: isDark ? Colors.white54 : Colors.black45),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
            tooltip: 'Ficha de Android',
            onPressed: () {
              ref.read(whatsappContactsServiceProvider).showQuickContact(contact.id);
            },
          ),
        ],
      ],
    );
  }

  Widget _buildStatusBadge(WhatsAppContact contact, bool isDark) {
    // H5: Semántica honesta: 'En agenda' si WhatsApp sincronizó la fila MIME; 'Sin verificar' si es sólo agenda local.
    if (contact.isWhatsAppVerified) {
      final label = contact.isBusiness ? 'WA Business' : 'En agenda';
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
        decoration: BoxDecoration(
          color: const Color(0xFF25D366).withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          label,
          style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF15803D)),
        ),
      );
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
      decoration: BoxDecoration(
        color: isDark ? Colors.white10 : const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        'Abrir chat',
        style: TextStyle(fontSize: 10, color: isDark ? Colors.white60 : Colors.black54),
      ),
    );
  }
}
