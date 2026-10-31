part of 'nano_contact_picker_sheet.dart';

/// Sección de contactos o destinos recientes dentro de NanoContactPickerSheet.
///
/// QUÉ HACE:
/// - Muestra un carrusel horizontal con los contactos seleccionados recientemente.
///
/// CÓMO SE CONECTA:
/// - Consume `recentShareContactsProvider` y notifica la selección al coordinador.
///
/// POR QUÉ:
/// - Permite envíos rápidos recurrentes sin escribir en la barra de búsqueda (< 110 líneas).
class _NanoContactPickerRecents extends ConsumerWidget {
  final ValueChanged<WhatsAppContact> onContactSelected;

  const _NanoContactPickerRecents({
    required this.onContactSelected,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final recents = ref.watch(recentShareContactsProvider);
    if (recents.isEmpty) return const SizedBox.shrink();

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final colors = NanoThemeExtension.of(context).colors;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: Row(
            children: [
              Icon(
                Icons.history_rounded,
                size: 14,
                color: colors.primary,
              ),
              const SizedBox(width: 6),
              Text(
                'Recientes',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: isDark ? Colors.white70 : colors.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
        SizedBox(
          height: 74,
          child: ListView.separated(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            scrollDirection: Axis.horizontal,
            itemCount: recents.length,
            separatorBuilder: (_, __) => const SizedBox(width: 10),
            itemBuilder: (context, index) {
              final contact = recents[index];
              final initial = contact.name.trim().isNotEmpty
                  ? contact.name.trim()[0].toUpperCase()
                  : '?';
              return InkWell(
                borderRadius: BorderRadius.circular(16),
                onTap: () => onContactSelected(contact),
                child: SizedBox(
                  width: 64,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      CircleAvatar(
                        radius: 20,
                        backgroundColor: const Color(0xFF25D366).withValues(alpha: 0.18),
                        child: Text(
                          initial,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF15803D),
                          ),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        contact.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w600,
                          color: isDark ? Colors.white : colors.onSurface,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 6),
      ],
    );
  }
}
