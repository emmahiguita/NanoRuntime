import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'terminal_text_style.dart';

/// Un único editor ligado a la sesión activa; no depende de la navegación global.
class TerminalCommandBar extends StatelessWidget {
  const TerminalCommandBar({
    super.key,
    required this.controller,
    required this.focusNode,
    required this.onSubmit,
    required this.onOpenLibrary,
    required this.onToggleDirect,
    required this.onInstallPackages,
    this.directInput = false,
  });
  final TextEditingController controller;
  final FocusNode focusNode;
  final ValueChanged<String> onSubmit;
  final VoidCallback onOpenLibrary;
  final VoidCallback onToggleDirect;
  final VoidCallback onInstallPackages;
  final bool directInput;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(8, 6, 8, 8),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Expanded(
          child: CallbackShortcuts(
            bindings: {
              const SingleActivator(LogicalKeyboardKey.enter): () =>
                  onSubmit(controller.text),
              const SingleActivator(LogicalKeyboardKey.numpadEnter): () =>
                  onSubmit(controller.text),
            },
            child: TextField(
              controller: controller,
              focusNode: focusNode,
              style: terminalTextStyle,
              autocorrect: false,
              enableSuggestions: false,
              smartDashesType: SmartDashesType.disabled,
              smartQuotesType: SmartQuotesType.disabled,
              textInputAction: TextInputAction.send,
              minLines: 1,
              maxLines: 3,
              onSubmitted: onSubmit,
              decoration: const InputDecoration(
                hintText: 'Escribe un comando…',
                prefixIcon: Icon(Icons.chevron_right_rounded),
                filled: true,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.all(Radius.circular(16)),
                ),
              ),
            ),
          ),
        ),
        ValueListenableBuilder<TextEditingValue>(
          valueListenable: controller,
          builder: (context, value, _) => IconButton(
            tooltip: 'Ejecutar comando',
            onPressed: value.text.trim().isEmpty
                ? null
                : () => onSubmit(value.text),
            icon: const Icon(Icons.arrow_upward_rounded),
          ),
        ),
        PopupMenuButton<String>(
          tooltip: 'Opciones de terminal',
          onSelected: (value) {
            if (value == 'saved') onOpenLibrary();
            if (value == 'direct') onToggleDirect();
            if (value == 'packages') onInstallPackages();
          },
          itemBuilder: (_) => [
            const PopupMenuItem(
              value: "packages",
              child: Text("Instalar paquetes"),
            ),
            CheckedPopupMenuItem(
              value: "direct",
              checked: directInput,
              child: const Text("Entrada directa (teclado físico)"),
            ),
            const PopupMenuItem(
              value: 'saved',
              child: Text('Comandos guardados'),
            ),
          ],
        ),
      ],
    ),
  );
}
