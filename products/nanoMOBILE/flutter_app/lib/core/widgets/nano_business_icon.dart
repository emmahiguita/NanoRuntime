// nano_business_icon.dart — Icono distintivo iOS de Nano Negocio (Búho + WhatsApp).
// QUÉ HACE: Renderiza el icono oficial de Nano Negocio estilo iOS con arte de cristal.
// CÓMO FUNCIONA: Despliega directamente assets/nano/nano_business_owl.png con escalado nítido y semántica accesible.
// POR QUÉ: Reemplazo directo, inmediato y limpio sin decoraciones redundantes.
library;

import 'package:flutter/material.dart';

class NanoBusinessIcon extends StatelessWidget {
  const NanoBusinessIcon({
    super.key,
    this.size = 32,
    this.isTile = true,
  });

  final double size;
  final bool isTile;

  static const String assetPath = 'assets/nano/nano_business_owl.png';

  @override
  Widget build(BuildContext context) {
    final dpr = MediaQuery.devicePixelRatioOf(context);

    return Semantics(
      image: true,
      label: 'Nano Negocio',
      child: Image.asset(
        assetPath,
        width: size,
        height: size,
        fit: BoxFit.contain,
        filterQuality: FilterQuality.medium,
        cacheWidth: (size * (dpr > 0 ? dpr : 1.0) * 1.5).ceil(),
        excludeFromSemantics: true,
      ),
    );
  }
}
