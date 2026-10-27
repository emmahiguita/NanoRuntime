part of 'business_store_product_detail_sheet.dart';

/// Acciones existentes con áreas táctiles amplias. Al ampliar texto se apilan
/// para conservar sus etiquetas; compartir abre el flujo real del catálogo.
class _ProductDetailActions extends StatelessWidget {
  const _ProductDetailActions({required this.onEdit, required this.onShare});
  final VoidCallback onEdit, onShare;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final edit = OutlinedButton.icon(
        onPressed: onEdit,
        style: OutlinedButton.styleFrom(minimumSize: const Size(0, 48)),
        icon: const Icon(Icons.edit_outlined, size: 18),
        label: const Text('Editar'),
      );
      final share = FilledButton.icon(
        onPressed: onShare,
        style: FilledButton.styleFrom(minimumSize: const Size(0, 48)),
        icon: const Icon(Icons.ios_share_rounded, size: 18),
        label: const Text('Compartir'),
      );
      if (constraints.maxWidth < 300 || MediaQuery.textScalerOf(context).scale(14) > 22) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [share, const SizedBox(height: 8), edit],
        );
      }
      return Row(
        children: [
          Expanded(child: edit),
          const SizedBox(width: 12),
          Expanded(child: share),
        ],
      );
    },
  );
}
