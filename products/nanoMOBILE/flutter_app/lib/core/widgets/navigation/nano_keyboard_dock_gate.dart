// QUÉ: oculta la barra global al escribir en un campo propio del módulo.
// CÓMO: un FocusNode observa solo su subárbol y mantiene vivo el editor oculto.
// POR QUÉ: búsqueda local no debe mostrar otra barra de escritura encima.
library;

import 'package:flutter/material.dart';

class NanoKeyboardDockGate extends StatefulWidget {
  const NanoKeyboardDockGate({super.key, required this.child});
  final Widget child;
  @override
  State<NanoKeyboardDockGate> createState() => _NanoKeyboardDockGateState();
}

class _NanoKeyboardDockGateState extends State<NanoKeyboardDockGate> {
  late final FocusNode _focus;
  @override
  void initState() {
    super.initState();
    _focus = FocusNode()..addListener(_onFocus);
  }

  /// El cambio de foco reconstruye solo el límite del dock, no el módulo.
  void _onFocus() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _focus.removeListener(_onFocus);
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Visibility(
    visible: MediaQuery.viewInsetsOf(context).bottom == 0 || _focus.hasFocus,
    maintainState: true,
    child: Focus(focusNode: _focus, child: widget.child),
  );
}
