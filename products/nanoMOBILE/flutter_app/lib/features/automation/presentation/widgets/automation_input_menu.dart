import 'package:flutter/material.dart';

import '../../../../core/widgets/nano_anchored_popover.dart';
import '../../../../core/widgets/navigation/nano_input_tool_logo.dart';

part 'automation_input_menu_view.dart';

/// Devuelve una intención al compositor, que conserva permisos y ejecución.
enum AutomationInputChoice { camera, photos, files, whatsapp }

/// Abre una única superficie anclada al botón de adjuntos.
///
/// [whatsAppSelected] refleja la selección del compositor; elegir una fila
/// devuelve una intención sin abrir aplicaciones ni enviar mensajes.
Future<AutomationInputChoice?> showAutomationInputMenu(
  BuildContext anchor, {
  required bool whatsAppSelected,
}) => showNanoAnchoredPopover<AutomationInputChoice>(
  anchorContext: anchor,
  label: 'Adjuntos y complementos',
  maxWidth: 280,
  builder: (_) => _AutomationInputMenu(whatsAppSelected: whatsAppSelected),
);

/// Mantiene la navegación local dentro de la ruta y el cristal compartidos.
class _AutomationInputMenu extends StatefulWidget {
  const _AutomationInputMenu({required this.whatsAppSelected});

  final bool whatsAppSelected;

  /// La navegación pertenece a esta apertura y se descarta al cerrar la ruta.
  @override
  State<_AutomationInputMenu> createState() => _AutomationInputMenuState();
}

/// Cambia el contenido sin retener vistas salientes ni recursos temporales.
class _AutomationInputMenuState extends State<_AutomationInputMenu> {
  bool _showComplements = false;
  bool _closing = false;

  /// Actualiza la misma superficie; AnimatedSize del presentador adapta su alto.
  void _openComplements() => setState(() => _showComplements = true);

  /// Vuelve a las opciones de adjuntos sin cerrar ni abrir otra ruta.
  void _backToAttachments() => setState(() => _showComplements = false);

  /// Cierra una vez con la intención; el padre decide sus efectos posteriores.
  void _choose(AutomationInputChoice choice) {
    if (_closing) return;
    _closing = true;
    Navigator.of(context).pop(choice);
  }

  /// Delega la lista visual y deja el movimiento reducido al presentador común.
  @override
  Widget build(BuildContext context) => _AutomationInputMenuView(
    showComplements: _showComplements,
    whatsAppSelected: widget.whatsAppSelected,
    onOpenComplements: _openComplements,
    onBack: _backToAttachments,
    onChoose: _choose,
  );
}
