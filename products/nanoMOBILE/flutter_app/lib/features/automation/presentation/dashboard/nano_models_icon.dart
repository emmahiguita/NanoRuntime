import 'package:flutter/material.dart';

/// User-provided Nano identity; the row owns its label and navigation callback.
class NanoModelsIcon extends StatelessWidget {
  const NanoModelsIcon({super.key, this.size = 36});
  final double size;

  /// Decodes at device density; adds no glow, frame, animation or extra blur.
  @override
  Widget build(BuildContext context) => ExcludeSemantics(
    child: Image.asset(
      'assets/nano/nano_models_owl.png',
      width: size,
      height: size,
      fit: BoxFit.contain,
      cacheWidth: (size * MediaQuery.devicePixelRatioOf(context)).ceil(),
      filterQuality: FilterQuality.medium,
    ),
  );
}
