// QUÉ: área útil del módulo sin descontar dos veces el teclado.
// CÓMO: consume el inset una vez y lo retira del MediaQuery descendiente.
// POR QUÉ: los Scaffold interiores ya no reducen otra vez su cuerpo a cero.
library;

import 'package:flutter/material.dart';

class NanoDockViewport extends StatelessWidget {
  const NanoDockViewport({
    super.key,
    required this.child,
    required this.keyboardInset,
    required this.reserve,
    required this.fullBleed,
    required this.protectTop,
  });
  final Widget child;
  final double keyboardInset, reserve;
  final bool fullBleed, protectTop;
  @override
  Widget build(BuildContext context) => SafeArea(
    top: protectTop && !fullBleed,
    bottom: false,
    child: Padding(
      padding: EdgeInsets.only(
        bottom: fullBleed
            ? 0
            : keyboardInset > 0
            ? keyboardInset
            : reserve,
      ),
      // Este límite conserva tamaño/foco y deja a otros hosts gestionar sus insets.
      child: MediaQuery.removeViewInsets(
        context: context,
        removeBottom: !fullBleed,
        child: child,
      ),
    ),
  );
}
