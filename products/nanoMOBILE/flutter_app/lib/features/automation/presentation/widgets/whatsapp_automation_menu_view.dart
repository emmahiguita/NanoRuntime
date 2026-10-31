part of 'whatsapp_automation_menu.dart';

/// Funciones del componente activo y su formulario de destinatario.
/// Conserva los callbacks reales; el fundido no deja filas antiguas pulsables.
extension _WhatsAppMenuView on _WhatsAppActionsState {
  Widget _buildMenu(BuildContext context) => AnimatedSwitcher(
    duration: MediaQuery.disableAnimationsOf(context)
        ? Duration.zero
        : const Duration(milliseconds: 150),
    layoutBuilder: (current, previous) => Stack(
      alignment: Alignment.topLeft,
      children: [
        for (final child in previous)
          IgnorePointer(child: ExcludeSemantics(child: child)),
        if (current != null) current,
      ],
    ),
    child: SingleChildScrollView(
      key: ValueKey(_action),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _header(context),
          const Divider(height: 1, indent: 10, endIndent: 10),
          if (_action == null) ...[
            // Solo estas tres funciones necesitan resolver un destinatario.
            for (final entry in [
              ('Abrir chat', Icons.forum_outlined, _WhatsAppMenuAction.open),
              (
                'Redactar mensaje',
                Icons.edit_outlined,
                _WhatsAppMenuAction.compose,
              ),
              if (widget.attachment != null)
                (
                  'Enviar adjunto',
                  Icons.attach_file_rounded,
                  _WhatsAppMenuAction.attach,
                ),
            ])
              _row(context, entry.$1, () => _select(entry.$3), icon: entry.$2),
            _row(
              context,
              'Responder en chat visible',
              () => _stage('Responde en este chat: '),
              icon: Icons.reply_rounded,
              detail: 'Usa el búho sobre el chat abierto',
            ),
            _row(
              context,
              'Solicitar ventana flotante',
              () => _stage('Abre WhatsApp en ventana flotante'),
              icon: Icons.picture_in_picture_alt_rounded,
              detail: 'Requiere soporte de Android',
            ),
            _row(
              context,
              'Abrir WhatsApp',
              () => _stage('Abre WhatsApp'),
              icon: Icons.open_in_new_rounded,
            ),
            for (final entry in widget.extraActions.entries)
              _row(context, entry.key, () => _stage(entry.value)),
          ] else
            _recipientForm(context),
        ],
      ),
    ),
  );

  /// La cabecera conserva un único regreso y crece con la escala del texto.
  Widget _header(BuildContext context) => Row(
    children: [
      IconButton(
        tooltip: 'Volver',
        onPressed: _closing ? null : _back,
        icon: const Icon(Icons.chevron_left_rounded, size: 18),
        constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
      ),
      Expanded(
        child: Text(_title, style: Theme.of(context).textTheme.titleSmall),
      ),
    ],
  );

  /// Un campo y una acción preparan el borrador; no representan otro editor
  /// de mensajes ni ejecutan el envío. El scroll permite verlos sobre el teclado.
  Widget _recipientForm(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(8, 12, 8, 4),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          controller: _recipient,
          readOnly: _closing,
          style: Theme.of(context).textTheme.bodyMedium,
          decoration: InputDecoration(
            labelText: 'Destinatario',
            hintText: 'Nombre, número o @usuario',
            errorText: _error,
            errorMaxLines: 3,
            isDense: true,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 10,
            ),
          ),
          textInputAction: TextInputAction.done,
          onSubmitted: (_) => _prepare(),
        ),
        const SizedBox(height: 8),
        Align(
          alignment: AlignmentDirectional.centerEnd,
          child: FilledButton(
            style: FilledButton.styleFrom(minimumSize: const Size(0, 40)),
            onPressed: _closing ? null : _prepare,
            child: Text(
              _action == _WhatsAppMenuAction.attach
                  ? 'Preparar adjunto'
                  : 'Preparar orden',
            ),
          ),
        ),
      ],
    ),
  );

  /// El título describe la acción vigente; no añade estados ni funciones.
  String get _title => switch (_action) {
    _WhatsAppMenuAction.open => 'Abrir chat',
    _WhatsAppMenuAction.compose => 'Redactar mensaje',
    _WhatsAppMenuAction.attach => 'Enviar adjunto',
    null => 'WhatsApp',
  };

  /// Iconos y relleno pequeños con área táctil mínima de 48 y texto adaptable.
  Widget _row(
    BuildContext context,
    String text,
    VoidCallback onTap, {
    IconData? icon,
    String? detail,
  }) => ListTile(
    minTileHeight: 48,
    dense: true,
    minLeadingWidth: 20,
    horizontalTitleGap: 10,
    minVerticalPadding: 4,
    contentPadding: const EdgeInsets.symmetric(horizontal: 10),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    leading: Icon(
      icon,
      size: 18,
      color: Theme.of(context).colorScheme.onSurfaceVariant,
    ),
    title: Text(text, style: Theme.of(context).textTheme.bodyMedium),
    subtitle: detail == null
        ? null
        : Text(detail, style: Theme.of(context).textTheme.bodySmall),
    onTap: onTap,
  );
}
