part of 'business_store_product_detail_sheet.dart';

class _ProductDetailActions extends StatelessWidget {
  final Color onSurface;
  final VoidCallback onEdit;
  final VoidCallback onShare;

  const _ProductDetailActions({
    required this.onSurface,
    required this.onEdit,
    required this.onShare,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: CupertinoButton(
            onPressed: onEdit,
            padding: const EdgeInsets.symmetric(vertical: 11),
            color: const Color(0x331E293B),
            borderRadius: BorderRadius.circular(12),
            child: Text(
              'Editar',
              style: TextStyle(
                color: onSurface,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          flex: 2,
          child: CupertinoButton(
            onPressed: onShare,
            padding: const EdgeInsets.symmetric(vertical: 11),
            color: const Color(0xFF087BFF),
            borderRadius: BorderRadius.circular(12),
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(CupertinoIcons.share, size: 15, color: Colors.white),
                SizedBox(width: 6),
                Text(
                  'Enviar / Compartir',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
