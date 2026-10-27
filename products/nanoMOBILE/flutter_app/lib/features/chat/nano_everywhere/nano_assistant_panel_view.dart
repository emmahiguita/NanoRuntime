part of 'nano_assistant_panel.dart';

/// Composición del diseño aprobado: una cabecera, un selector y un editor.
/// El desplazamiento permite texto ampliado y horizontal sin recortar funciones.
extension _NanoAssistantPanelView on _NanoAssistantPanelState {
  Widget _buildPanel(BuildContext context) {
    final controller = widget.controller;
    final screen = MediaQuery.sizeOf(context);
    final compact = screen.width > screen.height || screen.height < 460;
    final colors = Theme.of(context).colorScheme;
    final tool = NanoAssistantTool.fromKey(_activeTool);
    return Align(
      alignment: Alignment.topCenter,
      child: Material(
        type: MaterialType.transparency,
        child: NanoGlass(
          radius: compact ? 24 : 28,
          child: SingleChildScrollView(
            padding: EdgeInsets.all(compact ? 12 : 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                NanoAssistantHeader(
                  onClose: widget.onCollapse,
                  compact: compact,
                  activity: controller.activity,
                  onHistory: () {
                    widget.onCollapse();
                    final root = AppRouter.rootNavigatorKey.currentContext;
                    if (root != null) showAutomationHistory(root);
                  },
                  onExpand: () {
                    widget.onCollapse();
                    AppRouter.router.go(
                      _activeTool == 'Chat' ? '/chat' : '/automation',
                    );
                  },
                ),
                const SizedBox(height: 12),
                NanoAssistantToolSelector(
                  activeTool: _activeTool,
                  enabled: !_busy,
                  onSelected: _handleToolSelected,
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(4, 8, 4, 12),
                  child: Text(
                    tool.description,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: colors.onSurfaceVariant,
                      height: 1.4,
                    ),
                  ),
                ),
                if (_busy || controller.status.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Text(
                      _preparing ? 'Comprobando permisos…' : controller.status,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: colors.onSurfaceVariant,
                      ),
                    ),
                  ),
                for (final res in controller.detectedMedia)
                  NanoMediaDownloadRow(
                    resource: res,
                    onDownload: (url, audioOnly) {
                      if (!_busy) controller.downloadMedia([res]);
                    },
                  ),
                if (controller.answers.isNotEmpty) ...[
                  NanoAssistantAnswersView(
                    answers: controller.answers,
                    onSpeak: widget.onSpeak,
                  ),
                  const SizedBox(height: 8),
                ],
                if (controller.suggestions.isNotEmpty) ...[
                  NanoAssistantSuggestionChips(
                    suggestions: controller.suggestions,
                    enabled: !_busy,
                    // Preparar una sugerencia no debe ejecutar efectos externos.
                    onSelected: (text) => widget.input.text = text,
                  ),
                  const SizedBox(height: 8),
                ],
                if (const [
                      'Auto',
                      'WhatsApp',
                      'Pantalla',
                    ].contains(_activeTool) &&
                    _access.ready != true)
                  TextButton.icon(
                    onPressed: _access.configure,
                    icon: const Icon(Icons.accessibility_new_rounded, size: 18),
                    label: const Text('Activar accesibilidad de Nano'),
                  ),
                _attachmentView(),
                NanoAssistantComposer(
                  input: widget.input,
                  isListening: controller.activity == NanoActivity.listening,
                  audioLevel: widget.audioLevel,
                  onVoice: _busy ? null : widget.onVoice,
                  onSend: _send,
                  onAdd: _pickAttachment,
                  onCancel: _cancelAction,
                  hintText: _getHint(),
                  compact: compact,
                  busy: _busy,
                  screenReaderMode: _activeTool == 'Pantalla',
                  actionLabel: _activeTool == 'Chat'
                      ? 'Consultar'
                      : _activeTool == 'Pantalla'
                      ? 'Leer pantalla'
                      : _activeTool == 'Media'
                      ? 'Buscar archivos'
                      : 'Ejecutar',
                ),
                if (!_busy)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      'Seleccionar prepara. Ejecutar inicia la acción.',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: colors.onSurfaceVariant,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
