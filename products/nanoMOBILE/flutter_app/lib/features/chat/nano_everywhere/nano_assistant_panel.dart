// nano_assistant_panel.dart — Panel de respuestas expandido del asistente.
// QUÉ: UI del asistente Nano con opciones interactivas para responder y voz.
// CÓMO: Renderiza estado del NanoAiController. Sin Tooltip ni PopupMenuButton.
// POR QUÉ: Opciones para responder dinámicas (no frases robóticas), inmune al error
//          "No Overlay" y estrictamente menor a 200 líneas de código.
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'nano_ai_controller.dart';
import 'nano_ai_models.dart';
import 'nano_answer_card.dart';
import 'nano_glass.dart';
import 'nano_voice_wave.dart';

class NanoAssistantPanel extends StatefulWidget {
  const NanoAssistantPanel({
    super.key,
    required this.controller,
    required this.input,
    required this.audioLevel,
    required this.onVoice,
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
  bool _showNativeApps = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final ctrl = widget.controller;
    final busy = {NanoActivity.thinking, NanoActivity.comparing,
      NanoActivity.debating, NanoActivity.acting}.contains(ctrl.activity);

    return Material(
      type: MaterialType.transparency,
      child: NanoGlass(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(13, 11, 13, 13),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(children: [
                const Icon(Icons.auto_awesome_rounded, size: 17, color: Color(0xFF318AFF)),
                const SizedBox(width: 6),
                Expanded(child: Text('Nano está contigo', style: theme.textTheme.labelLarge)),
                Semantics(
                  label: 'Contraer asistente', button: true,
                  child: IconButton(
                    onPressed: widget.onCollapse,
                    icon: const Icon(Icons.keyboard_arrow_down_rounded),
                  ),
                ),
              ]),
              TextField(
                controller: widget.input,
                minLines: 1, maxLines: 3,
                textInputAction: TextInputAction.send,
                onSubmitted: (_) => ctrl.submit(widget.input.text),
                decoration: InputDecoration(
                  hintText: 'Pregunta algo…', filled: true,
                  fillColor: theme.colorScheme.surface,
                  border: OutlineInputBorder(borderSide: BorderSide.none, borderRadius: BorderRadius.circular(26)),
                  prefixIcon: const Icon(Icons.auto_awesome_outlined),
                  suffixIcon: Semantics(
                    label: 'Enviar consulta', button: true,
                    child: IconButton(
                      icon: const Icon(Icons.arrow_upward_rounded),
                      onPressed: () => ctrl.submit(widget.input.text),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 6),
              Row(children: [
                if (widget.onVoice != null)
                  Semantics(
                    label: 'Dictar por voz', button: true,
                    child: IconButton(onPressed: widget.onVoice, icon: const Icon(Icons.mic_rounded)),
                  ),
                if (ctrl.activity == NanoActivity.listening)
                  NanoVoiceWave(audioLevel: widget.audioLevel),
                const Spacer(),
                if (busy)
                  Semantics(
                    label: 'Cancelar consulta', button: true,
                    child: IconButton(onPressed: ctrl.cancel, icon: const Icon(Icons.stop_circle_outlined)),
                  ),
              ]),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(children: [
                  _chip(ctrl, NanoMode.quick, 'Consulta', Icons.bolt_rounded),
                  _chip(ctrl, NanoMode.compare, 'Comparar', Icons.compare_arrows_rounded),
                  _chip(ctrl, NanoMode.debate, 'Debate', Icons.forum_outlined),
                  _chip(ctrl, NanoMode.action, 'Acción', Icons.auto_fix_high_rounded),
                ]),
              ),
              if (ctrl.status.isNotEmpty)
                Align(
                  alignment: Alignment.centerLeft,
                  child: Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text(ctrl.status, maxLines: 2, overflow: TextOverflow.ellipsis, style: theme.textTheme.bodySmall),
                  ),
                ),
              // Opciones interactivas para responder (no frases robóticas)
              if (ctrl.suggestions.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: ctrl.suggestions.map((s) => Padding(
                        padding: const EdgeInsets.only(right: 5),
                        child: ActionChip(
                          avatar: const Icon(Icons.touch_app_outlined, size: 14),
                          label: Text(s, style: theme.textTheme.labelSmall),
                          onPressed: () { widget.input.text = s; ctrl.submit(s); },
                        ),
                      )).toList(),
                    ),
                  ),
                ),
              if (ctrl.answers.isNotEmpty)
                ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 180),
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: ctrl.answers.length,
                    itemBuilder: (_, i) => NanoAnswerCard(answer: ctrl.answers[i]),
                  ),
                ),
              if (ctrl.providers.any((p) => p.kind == NanoProviderKind.nativeApp))
                _nativeApps(theme, ctrl),
            ],
          ),
        ),
      ),
    );
  }

  Widget _nativeApps(ThemeData theme, NanoAiController ctrl) {
    final apps = ctrl.providers.where((p) => p.kind == NanoProviderKind.nativeApp).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        InkWell(
          onTap: () => setState(() => _showNativeApps = !_showNativeApps),
          borderRadius: BorderRadius.circular(8),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 4),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Text('Abrir en otra app de IA', style: theme.textTheme.labelSmall),
                Icon(_showNativeApps ? Icons.arrow_drop_up : Icons.arrow_drop_down, size: 18),
              ],
            ),
          ),
        ),
        if (_showNativeApps)
          Wrap(
            spacing: 6, runSpacing: 4, alignment: WrapAlignment.end,
            children: apps.map((p) => ActionChip(
              label: Text(p.name),
              onPressed: () async {
                final pkg = p.androidPackage;
                if (pkg != null) await ctrl.askNativeApp(pkg, widget.input.text);
              },
            )).toList(),
          ),
      ],
    );
  }

  Widget _chip(NanoAiController c, NanoMode m, String lbl, IconData ic) => Padding(
    padding: const EdgeInsets.only(right: 5),
    child: ChoiceChip(
      avatar: Icon(ic, size: 16), label: Text(lbl),
      selected: c.mode == m,
      onSelected: (_) { HapticFeedback.selectionClick(); c.selectMode(m); },
    ),
  );
}
