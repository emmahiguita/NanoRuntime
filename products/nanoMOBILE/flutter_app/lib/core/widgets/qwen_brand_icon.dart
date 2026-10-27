// QUÉ: conserva la identidad original de Qwen y la API usada por sus pantallas.
// CÓMO: delega imagen y movimiento al componente común de marcas verificadas.
// POR QUÉ: evita duplicar animadores al incorporar otras familias de modelos.
import 'package:flutter/material.dart';
import 'official_model_brand_icon.dart';

class QwenBrandIcon extends StatelessWidget {
  const QwenBrandIcon({super.key, this.size = 38, this.animate = true});
  final double size;
  final bool animate;

  @override
  Widget build(BuildContext context) => OfficialModelBrandIcon(
    asset: 'assets/nano/qwen_official.png',
    brand: 'Qwen',
    size: size,
    animate: animate,
  );
}
