import 'package:flutter/material.dart';

/// Reutiliza el recurso Nano con un recorte de presentación: el margen negro
/// del lienzo no debe convertirse en un cuadro opaco dentro del cristal.
class NanoInputToolLogo extends StatelessWidget {
  const NanoInputToolLogo({super.key, required this.asset, required this.size});
  final String asset;
  final double size;

  @override
  Widget build(BuildContext context) => SizedBox.square(
    dimension: size,
    child: ClipRRect(
      borderRadius: BorderRadius.circular(size * .28),
      child: Transform.scale(
        scale: 1.17,
        child: Image.asset(asset, fit: BoxFit.cover),
      ),
    ),
  );
}
