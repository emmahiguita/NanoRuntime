part of 'nano_contact_picker_sheet.dart';

/// Sección de accesos directos a aplicaciones (WhatsApp Personal, Business y Sistema).
///
/// QUÉ HACE:
/// - Muestra botones para abrir directamente WhatsApp sin contacto fijado o delegar al sistema.
///
/// POR QUÉ:
/// - Desacopla los destinos rápidos de la estructura principal (< 90 líneas).
class _NanoContactPickerApps extends StatelessWidget {
  final NanoSharePayload payload;

  const _NanoContactPickerApps({required this.payload});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Row(
        children: [
          Expanded(
            child: _buildAppChip(
              icon: Icons.chat_rounded,
              label: 'WhatsApp',
              color: const Color(0xFF25D366),
              onTap: () {
                Navigator.of(context).pop();
                NanoShareCoordinator.dispatchDirectApp(
                  context: context,
                  payload: payload,
                  isBusiness: false,
                );
              },
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _buildAppChip(
              icon: Icons.store_rounded,
              label: 'WA Business',
              color: const Color(0xFF128C7E),
              onTap: () {
                Navigator.of(context).pop();
                NanoShareCoordinator.dispatchDirectApp(
                  context: context,
                  payload: payload,
                  isBusiness: true,
                );
              },
            ),
          ),
          const SizedBox(width: 8),
          _buildSystemShareChip(context),
        ],
      ),
    );
  }

  Widget _buildAppChip({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withValues(alpha: 0.35)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 14, color: color),
            const SizedBox(width: 4),
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: color),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSystemShareChip(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: () {
        Navigator.of(context).pop();
        NanoShareCoordinator.dispatchToSystemSharesheet(payload: payload);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
        decoration: BoxDecoration(
          color: isDark ? Colors.white10 : const Color(0xFFF1F5F9),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: isDark ? Colors.white12 : const Color(0xFFE2E8F0)),
        ),
        child: const Icon(Icons.more_horiz_rounded, size: 16),
      ),
    );
  }
}
