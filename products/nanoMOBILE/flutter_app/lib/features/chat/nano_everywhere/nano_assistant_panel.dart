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
  bool get _busy => const {
    NanoActivity.thinking,
    NanoActivity.acting,
  }.contains(widget.controller.activity);

  void _send() {
    if (_busy) return;
    // Una consulta conversacional produce una sola respuesta; la ruta queda interna.
    widget.controller.submit(widget.input.text);
  }

  @override
  Widget build(BuildContext context) {
    final controller = widget.controller;
    final isMedia = controller.mode == NanoMode.media;
    final screen = MediaQuery.sizeOf(context);
    // QUÉ HACE: Detecta modo horizontal o altura reducida para compactar componentes.
    // CÓMO FUNCIONA: Activa `isCompactLandscape` cuando el ancho supera el alto o alto < 460px.
    // POR QUÉ: Garantiza que todos los controles quepan organizados y usables sin solaparse.
    final isCompactLandscape =
        screen.width > screen.height || screen.height < 460;
    final gap = isCompactLandscape ? 6.0 : 10.0;

    return Material(
      type: MaterialType.transparency,
      child: NanoGlass(
        radius: isCompactLandscape ? 20 : 28,
        // El scroll interno evita overflow con teclado, texto grande o modo horizontal.
        child: SingleChildScrollView(
          padding: isCompactLandscape
              ? const EdgeInsets.fromLTRB(10, 6, 10, 10)
              : const EdgeInsets.fromLTRB(14, 8, 14, 14),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              NanoAssistantHeader(
                isMedia: isMedia,
                onClose: widget.onCollapse,
                compact: isCompactLandscape,
              ),
              SizedBox(height: gap),
              NanoAssistantComposer(
                input: widget.input,
                isMedia: isMedia,
                isListening: controller.activity == NanoActivity.listening,
                audioLevel: widget.audioLevel,
                onVoice: _busy ? null : widget.onVoice,
                onSend: _send,
                compact: isCompactLandscape,
              ),
              SizedBox(height: gap),
              NanoAssistantModeBar(
                currentMode: controller.mode,
                enabled: !_busy,
                onSelect: controller.selectMode,
              ),
              const SizedBox(height: 12),
              NanoAssistantPrimaryAction(
                busy: _busy,
                isMedia: isMedia,
                onPressed: _send,
                onCancel: controller.cancel,
              ),
              if (controller.status.isNotEmpty) ...[
                const SizedBox(height: 8),
                Semantics(
                  liveRegion: true,
                  child: Text(
                    controller.status,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
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
      ),
    );
  }
}
