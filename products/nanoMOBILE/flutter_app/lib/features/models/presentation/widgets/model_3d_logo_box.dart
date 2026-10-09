// QUÉ: portada compacta sin brillos, biseles ni sombras coloreadas.
// CÓMO: marco neutro estilo iOS; el icono conserva sus colores de marca originales.
// POR QUÉ: aporta identidad sin competir con el nombre ni el estado del modelo.
import 'package:flutter/material.dart';
import 'model_brand_logo.dart';
import 'model_catalog_types.dart';
import 'model_catalog_surface.dart';

class Model3DLogoBox extends StatelessWidget {
  final UnifiedModelItem item;
  final double size;
  const Model3DLogoBox({super.key, required this.item, this.size = 64});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: modelCatalogSurface(context),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Center(
        child: ModelBrandLogo(
          name: item.name,
          isDetected: !item.isCatalog,
          size: size * 0.62,
        ),
      ),
    );
  }
}
