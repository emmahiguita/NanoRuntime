import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'nano_ai_controller.dart';
import 'nano_ai_models.dart';
import 'nano_assistant_panel_components.dart';
import 'nano_assistant_composer.dart';
import 'nano_assistant_panel_sections.dart';
import 'nano_glass.dart';

/// Orquesta secciones pequeñas del asistente sin duplicar controles ni estado.
class NanoAssistantPanel extends StatefulWidget {
  const NanoAssistantPanel({
    super.key,
    required this.controller,
    required this.input,
    required this.audioLevel,
    this.onVoice,
    required this.onCollapse,
  });

  final NanoAiController controller;
  final TextEditingController input;
  final ValueListenable<double> audioLevel;
  final VoidCallback? onVoice;
  final VoidCallback onCollapse;

  @override
  State<NanoAssistantPanel> createState() => _NanoAssistantPanelState();
}

class _NanoAssistantPanelState extends State<NanoAssistantPanel> {
  final _selectedProviderIds = <String>{};

  List<NanoProvider> get _providers => widget.controller.providers
      .where((provider) => provider.supportsProgrammaticQuery)
      .toList();

  bool get _busy => const {
    NanoActivity.thinking,
    NanoActivity.comparing,
    NanoActivity.debating,
    NanoActivity.acting,
  }.contains(widget.controller.activity);

  @override
  void initState() {
    super.initState();
    _selectedProviderIds.addAll(_providers.map((provider) => provider.id));
  }

  @override
  void didUpdateWidget(covariant NanoAssistantPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      _selectedProviderIds
        ..clear()
        ..addAll(_providers.map((provider) => provider.id));
    }
  }

  void _send() {
    if (_busy) return;
    widget.controller.submit(
      widget.input.text,
      selectedIds: _selectedProviderIds,
    );
  }

  @override
  Widget build(BuildContext context) {
    final controller = widget.controller;
    final isMedia = controller.mode == NanoMode.media;

    return Material(
      type: MaterialType.transparency,
      child: NanoGlass(
        radius: 28,
        child: Stack(
          children: [
            const _PanelFeather(),
            // Un solo scroll evita overflow con teclado, zoom de texto o landscape.
            SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(14, 8, 14, 14),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  NanoAssistantHeader(
                    activity: controller.activity,
                    isMedia: isMedia,
                    onClose: widget.onCollapse,
                  ),
                  const SizedBox(height: 10),
                  NanoAssistantComposer(
                    input: widget.input,
                    isMedia: isMedia,
                    isListening: controller.activity == NanoActivity.listening,
                    audioLevel: widget.audioLevel,
                    onVoice: _busy ? null : widget.onVoice,
                    onSend: _send,
                  ),
                  const SizedBox(height: 10),
                  NanoAssistantModeBar(
                    currentMode: controller.mode,
                    enabled: !_busy,
                    onSelect: controller.selectMode,
                  ),
                  if (!isMedia && _providers.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    NanoProviderSelector(
                      providers: _providers,
                      enabled: !_busy,
                      selectedIds: _selectedProviderIds,
                      onChanged: (id, selected) => setState(() {
                        if (selected) {
                          _selectedProviderIds.add(id);
                        } else if (_selectedProviderIds.length > 1) {
                          _selectedProviderIds.remove(id);
                        }
                      }),
                    ),
                  ],
                  const SizedBox(height: 12),
                  NanoAssistantPrimaryAction(
                    busy: _busy,
                    isMedia: isMedia,
                    onPressed: _send,
                    onCancel: controller.cancel,
                  ),
                  if (controller.status.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Semantics(liveRegion: true, child: Text(controller.status,
                      style: Theme.of(context).textTheme.bodySmall)),
                  ],
                  if (isMedia) NanoMediaManagerLink(controller: controller),
                  if (controller.answers.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    NanoAssistantAnswersView(answers: controller.answers),
                  ],
                  if (controller.suggestions.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    NanoAssistantSuggestionChips(
                      suggestions: controller.suggestions,
                      enabled: !_busy,
                      onSelected: (suggestion) {
                        widget.input.text = suggestion;
                        _send();
                      },
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PanelFeather extends StatelessWidget {
  const _PanelFeather();

  @override
  Widget build(BuildContext context) => Positioned(
    right: 8,
    top: 4,
    width: 120,
    height: 80,
    child: IgnorePointer(
      child: Opacity(
        opacity: 0.28,
        child: Image.asset(
          'assets/nano/nano_feather.png',
          fit: BoxFit.contain,
          errorBuilder: (_, __, ___) => const SizedBox.shrink(),
        ),
      ),
    ),
  );
}
