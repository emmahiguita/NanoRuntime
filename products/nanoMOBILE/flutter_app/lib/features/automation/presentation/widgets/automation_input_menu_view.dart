part of 'automation_input_menu.dart';

/// Presenta filas compactas y accesibles sobre el cristal del presentador.
class _AutomationInputMenuView extends StatelessWidget {
  const _AutomationInputMenuView({
    required this.showComplements,
    required this.whatsAppSelected,
    required this.onOpenComplements,
    required this.onBack,
    required this.onChoose,
  });

  final bool showComplements;
  final bool whatsAppSelected;
  final VoidCallback onOpenComplements;
  final VoidCallback onBack;
  final ValueChanged<AutomationInputChoice> onChoose;

  /// Permite desplazar el menú si el teclado o la escala reducen el espacio.
  @override
  Widget build(BuildContext context) => SingleChildScrollView(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: showComplements ? _complements(context) : _attachments(),
    ),
  );

  /// Expone adjuntos y la entrada de navegación sin cabecera adicional.
  List<Widget> _attachments() => [
    _AutomationInputMenuRow(
      label: 'Cámara',
      leading: const Icon(Icons.camera_alt_outlined, size: 18),
      onTap: () => onChoose(AutomationInputChoice.camera),
    ),
    _AutomationInputMenuRow(
      label: 'Fotos',
      leading: const Icon(Icons.photo_outlined, size: 18),
      onTap: () => onChoose(AutomationInputChoice.photos),
    ),
    _AutomationInputMenuRow(
      label: 'Archivos',
      leading: const Icon(Icons.attach_file, size: 18),
      onTap: () => onChoose(AutomationInputChoice.files),
    ),
    const Divider(height: 9),
    _AutomationInputMenuRow(
      label: 'Complementos',
      leading: const Icon(Icons.extension_outlined, size: 18),
      trailing: const Icon(Icons.chevron_right, size: 18),
      onTap: onOpenComplements,
    ),
  ];

  /// Conserva únicamente WhatsApp y refleja la selección recibida del padre.
  List<Widget> _complements(BuildContext context) => [
    Row(
      children: [
        IconButton(
          onPressed: onBack,
          tooltip: 'Volver a adjuntos',
          constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
          iconSize: 18,
          icon: const Icon(Icons.arrow_back),
        ),
        Expanded(
          child: Text(
            'Complementos',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ),
        const SizedBox(width: 12),
      ],
    ),
    _AutomationInputMenuRow(
      label: 'WhatsApp',
      selected: whatsAppSelected,
      leading: const NanoInputToolLogo(
        asset: 'assets/automation/whatsapp_personal_icon.png',
        size: 20,
      ),
      trailing: whatsAppSelected ? const Icon(Icons.check, size: 18) : null,
      onTap: () => onChoose(AutomationInputChoice.whatsapp),
    ),
  ];
}

/// Ofrece un objetivo táctil mínimo de 48 px que crece con el texto.
class _AutomationInputMenuRow extends StatelessWidget {
  const _AutomationInputMenuRow({
    required this.label,
    required this.leading,
    required this.onTap,
    this.trailing,
    this.selected,
  });

  final String label;
  final Widget leading;
  final Widget? trailing;
  final bool? selected;
  final VoidCallback onTap;

  /// Usa el tema y un único icono principal sin crear otra superficie visual.
  @override
  Widget build(BuildContext context) => Semantics(
    selected: selected,
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 48),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          child: Row(
            children: [
              SizedBox(width: 20, child: Center(child: leading)),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  label,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ),
              if (trailing != null) ...[const SizedBox(width: 12), trailing!],
            ],
          ),
        ),
      ),
    ),
  );
}
