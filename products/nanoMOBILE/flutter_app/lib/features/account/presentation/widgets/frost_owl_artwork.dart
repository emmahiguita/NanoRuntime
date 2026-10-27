import 'package:flutter/material.dart';

/// El búho es una ilustración, no una captura de botones. Dos degradados estáticos
/// funden sus bordes con el fondo sin ShaderMask ni filtros fuera de pantalla.
class FrostOwlArtwork extends StatelessWidget {
  const FrostOwlArtwork({super.key});
  @override
  Widget build(BuildContext context) => Stack(
    fit: StackFit.expand,
    children: [
      Image.asset(
        'assets/nano/login_frost_owl.png',
        fit: BoxFit.cover,
        cacheWidth: 1000,
        excludeFromSemantics: true,
        filterQuality: FilterQuality.medium,
      ),
      const DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              Color(0xff030d22),
              Color(0x00030d22),
              Color(0x00030d22),
              Color(0xff030d22),
            ],
            stops: [0, 0.14, 0.86, 1],
          ),
        ),
      ),
      const DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xff030d22),
              Color(0x00030d22),
              Color(0x00030d22),
              Color(0xff030d22),
            ],
            stops: [0, 0.12, 0.75, 1],
          ),
        ),
      ),
    ],
  );
}
