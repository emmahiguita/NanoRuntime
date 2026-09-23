// nano_motion.dart — Constantes físicas compartidas del asistente flotante.
// QUÉ: Duraciones y curvas de animación para morphing, transiciones y spring.
// CÓMO: abstract final class — no instanciable, solo constantes estáticas.
// POR QUÉ: Un único punto de control evita valores mágicos dispersos (DRY).
import 'package:flutter/animation.dart';

abstract final class NanoMotion {
  static const fast   = Duration(milliseconds: 120);
  static const morph  = Duration(milliseconds: 220);
  static const settle = Duration(milliseconds: 280);
  static const Curve spring = Curves.easeOutCubic;
  static const Curve smooth = Curves.easeOutCubic;
}
