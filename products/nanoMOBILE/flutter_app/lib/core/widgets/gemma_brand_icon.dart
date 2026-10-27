// QUÉ: muestra el símbolo original de Gemma publicado por Google DeepMind.
// CÓMO: usa el PNG oficial, sin recolorear, con giro opcional y accesible.
// POR QUÉ: identifica Gemma sin confundirla con Gemini ni sustituirla por una «G».
import 'package:flutter/material.dart';
import 'official_model_brand_icon.dart';

class GemmaBrandIcon extends StatelessWidget {
  const GemmaBrandIcon({super.key, this.size = 38, this.animate = true});
  final double size;
  final bool animate;

  @override
  Widget build(BuildContext context) => OfficialModelBrandIcon(
    asset: 'assets/nano/gemma_official.png',
    brand: 'Gemma',
    size: size,
    animate: animate,
  );
}
