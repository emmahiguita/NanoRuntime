part of 'nano_contact_picker_sheet.dart';

/// Tarjeta de permisos y selector alternativo sin acceso global.
///
/// QUÉ HACE:
/// - Ofrece activar permiso READ_CONTACTS o seleccionar 1 contacto vía ACTION_PICK.
///
/// POR QUÉ:
/// - Separa la gestión de permisos del listado de contactos (< 100 líneas).
class _NanoContactPickerPermissionCard extends ConsumerWidget {
  final ValueChanged<WhatsAppContact> onContactSelected;

  const _NanoContactPickerPermissionCard({
    required this.onContactSelected,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final colors = NanoThemeExtension.of(context).colors;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? const Color(0x301E293B) : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? Colors.white12 : const Color(0xFFE2E8F0),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(Icons.contacts_outlined, size: 20, color: colors.primary),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Búsqueda en agenda desactivada',
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                    color: isDark ? Colors.white : colors.onSurface,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'Puedes conceder acceso para buscar en tu agenda o seleccionar un contacto puntual con el selector nativo sin dar acceso general.',
            style: TextStyle(
              fontSize: 11,
              color: isDark ? Colors.white60 : colors.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () async {
                    final contact = await ref
                        .read(whatsappContactsServiceProvider)
                        .pickSingleContact();
                    if (contact != null) onContactSelected(contact);
                  },
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  child: const Text('Elegir de agenda', style: TextStyle(fontSize: 11)),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: ElevatedButton(
                  onPressed: () async {
                    await ref
                        .read(whatsappContactsServiceProvider)
                        .requestPermission();
                    ref.invalidate(contactsPermissionProvider);
                    ref.invalidate(allWhatsAppContactsProvider);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: colors.primary,
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  child: const Text(
                    'Activar búsqueda',
                    style: TextStyle(fontSize: 11, color: Colors.white, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
