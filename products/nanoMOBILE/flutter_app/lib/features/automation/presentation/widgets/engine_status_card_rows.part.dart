part of 'engine_status_card.dart';

class _CleanCapabilityRow extends StatelessWidget {
  const _CleanCapabilityRow({
    required this.ok,
    required this.okText,
    required this.offText,
  });

  final bool ok;
  final String okText;
  final String offText;

  @override
  Widget build(BuildContext context) {
    final color = ok
        ? AutomationVisual.of(context).success
        : AutomationVisual.of(context).accent;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Container(
            width: 16,
            height: 16,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: color.withValues(alpha: 0.16),
              border: Border.all(
                color: color.withValues(alpha: 0.38),
                width: 1,
              ),
            ),
            child: Container(
              width: 6,
              height: 6,
              decoration: BoxDecoration(
                color: color,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: color.withValues(alpha: 0.65),
                    blurRadius: 4,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              ok ? okText : offText,
              style: TextStyle(
                color: AutomationVisual.of(context).text,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Fila de capacidad con estado humano + dot de color (nunca true/false).
class _CapabilityRow extends StatelessWidget {
  final bool ok;
  final String okText;
  final String offText;
  final NanoColors colors;

  const _CapabilityRow({
    required this.ok,
    required this.okText,
    required this.offText,
    required this.colors,
  });

  @override
  Widget build(BuildContext context) {
    final color = ok ? colors.success : colors.warning;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          Container(
            width: 7,
            height: 7,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: color,
              boxShadow: [
                BoxShadow(color: color.withValues(alpha: 0.5), blurRadius: 5),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Text(
            ok ? okText : offText,
            style: NanoType.body(ok ? colors.onSurface : color),
          ),
        ],
      ),
    );
  }
}
