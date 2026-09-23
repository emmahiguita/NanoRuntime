part of 'automation_rules_screen.dart';

/// QUÉ HACE:
/// Widgets visuales complementarios para la lista de reglas de automatización.
///
/// CÓMO FUNCIONA:
/// Provee filas de detalle clave-valor, encabezados temáticos con iconos,
/// etiquetas de contacto y el estado vacío estilizado con Material Expressive.
///
/// POR QUÉ:
/// Centraliza componentes atómicos reutilizables evitando duplicación y
/// manteniendo los componentes principales por debajo de 200 líneas.
class _DetailRow extends StatelessWidget {
  const _DetailRow({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final visual = AutomationVisual.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 68,
            child: Text(
              label,
              style: TextStyle(color: visual.textMuted, fontSize: 11, fontWeight: FontWeight.w600),
            ),
          ),
          Expanded(
            child: Text(
              value,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: visual.text, fontSize: 12, height: 1.35),
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title, this.icon, this.imageAsset})
      : assert(icon != null || imageAsset != null);

  final String title;
  final IconData? icon;
  final String? imageAsset;

  @override
  Widget build(BuildContext context) {
    final visual = AutomationVisual.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 14, 4, 8),
      child: Row(
        children: [
          if (imageAsset != null)
            Image.asset(imageAsset!, width: 18, height: 18, fit: BoxFit.contain)
          else
            Icon(icon!, color: visual.accent, size: 16),
          const SizedBox(width: 8),
          Text(
            title,
            style: TextStyle(color: visual.text, fontSize: 13, fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }
}

class _ContactLabel extends StatelessWidget {
  const _ContactLabel({required this.contact, required this.visual});
  final String contact;
  final AutomationVisualPalette visual;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
      child: Text(
        contact,
        style: TextStyle(color: visual.textMuted, fontSize: 12, fontWeight: FontWeight.w600),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.visual});
  final AutomationVisualPalette visual;

  @override
  Widget build(BuildContext context) {
    return AutomationSurfaceCard(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 28),
        child: Column(
          children: [
            Icon(Icons.rule_rounded, color: visual.textMuted, size: 32),
            const SizedBox(height: 10),
            Text('Sin reglas todavía',
                style: TextStyle(color: visual.text, fontSize: 14, fontWeight: FontWeight.w600)),
            const SizedBox(height: 4),
            Text(
              'Pídele a Nano en el chat: "responde X a Y" y la regla aparecerá aquí.',
              textAlign: TextAlign.center,
              style: TextStyle(color: visual.textMuted, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }
}

class _RuleExpandedDetails extends StatelessWidget {
  const _RuleExpandedDetails({
    required this.rule,
    required this.visual,
    required this.outcomeLabel,
    required this.lastFired,
    required this.onEdit,
    required this.onDelete,
    required this.dangerColor,
  });

  final ScheduledRule rule;
  final AutomationVisualPalette visual;
  final String outcomeLabel;
  final DateTime? lastFired;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final Color dangerColor;

  @override
  Widget build(BuildContext context) {
    final mediaText = rule.action == RuleAction.sendMedia
        ? (rule.mediaPath ?? 'sin archivo (regla incompleta)')
        : rule.message.isNotEmpty
            ? rule.message
            : rule.dynamicReply ? 'dinámico (LLM local por conversación)' : null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 10),
        Divider(color: visual.inputFill, height: 1),
        const SizedBox(height: 10),
        _DetailRow(label: 'Disparo', value: _RuleCard._triggerLabel(rule.trigger)),
        _DetailRow(label: 'Acción', value: rule.action.label),
        if (mediaText != null)
          _DetailRow(label: rule.action == RuleAction.sendMedia ? 'Archivo' : 'Texto', value: mediaText),
        _DetailRow(
          label: 'Estado',
          value: '$outcomeLabel · ${lastFired == null ? "nunca disparó" : _RuleCard._ddmmy(lastFired!)}',
        ),
        _DetailRow(label: 'Creada', value: _RuleCard._ddmmy(rule.createdAt)),
        _DetailRow(label: 'ID', value: rule.id),
        const SizedBox(height: 4),
        Align(
          alignment: Alignment.centerRight,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextButton.icon(
                onPressed: onEdit,
                icon: const Icon(Icons.edit_outlined, size: 17),
                label: const Text('Editar'),
              ),
              const SizedBox(width: 8),
              TextButton.icon(
                onPressed: onDelete,
                icon: const Icon(Icons.delete_outline_rounded, size: 17),
                label: const Text('Borrar'),
                style: TextButton.styleFrom(foregroundColor: dangerColor),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
