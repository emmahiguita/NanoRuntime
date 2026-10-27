import 'package:flutter/material.dart';
import 'nano_input_tool_logo.dart';

/// Contexto del scope y apertura del menú de la herramienta seleccionada.
/// No ejecutan instrucciones ni añaden otro editor.
@immutable
class NanoInputToolControls {
  const NanoInputToolControls({
    required this.name,
    required this.asset,
    required this.selected,
    required this.onOptions,
    this.onAdd,
    this.attachmentName,
    this.onRemoveAttachment,
    this.notice,
    this.onConfigure,
  });
  final String name, asset;
  final String? notice;
  final VoidCallback? onConfigure;
  final bool selected;
  final ValueChanged<BuildContext> onOptions;

  /// El + abre adjuntos/complementos; el logo conserva sus propias funciones.
  final ValueChanged<BuildContext>? onAdd;
  final String? attachmentName;
  final VoidCallback? onRemoveAttachment;

  @override
  bool operator ==(Object other) =>
      other is NanoInputToolControls &&
      (name, asset, selected, notice, attachmentName) ==
          (
            other.name,
            other.asset,
            other.selected,
            other.notice,
            other.attachmentName,
          );
  @override
  int get hashCode =>
      Object.hash(name, asset, selected, notice, attachmentName);
}

/// El logo abre sus funciones. El estado seleccionado permanece visible
/// y accesible; no usa un punto verde que pudiera sugerir conexión verificada.
class NanoInputToolButton extends StatelessWidget {
  const NanoInputToolButton({
    super.key,
    required this.controls,
    this.enabled = true,
  });
  final NanoInputToolControls controls;
  final bool enabled;

  @override
  Widget build(BuildContext context) => Semantics(
    selected: controls.selected,
    child: IconButton(
      tooltip: 'Opciones de ${controls.name}',
      onPressed: enabled ? () => controls.onOptions(context) : null,
      style: IconButton.styleFrom(
        backgroundColor: controls.selected
            ? Theme.of(context).colorScheme.secondaryContainer
            : Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(13)),
      ),
      constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
      icon: Opacity(
        opacity: controls.selected ? 1 : .58,
        child: NanoInputToolLogo(asset: controls.asset, size: 25),
      ),
    ),
  );
}
