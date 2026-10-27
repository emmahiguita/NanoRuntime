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
  late final FocusScopeNode _focus;
  @override
  void initState() {
    super.initState();
    // El scope observa el foco de los hijos. canRequestFocus=false bloquearía
    // también los TextField descendientes: se excluye solo del recorrido Tab.
    _focus = FocusScopeNode(skipTraversal: true)..addListener(_onFocus);
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
    child: FocusScope(node: _focus, child: widget.child),
  );
}
