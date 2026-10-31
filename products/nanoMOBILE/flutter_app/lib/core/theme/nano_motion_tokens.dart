// nano_motion_tokens.dart — Tokens centralizados de movimiento e interacción táctil.
// QUÉ HACE: Define duraciones, curvas y respuestas elásticas consistentes para Nano.
// CÓMO FUNCIONA: Consulta las preferencias de accesibilidad del sistema y amortigua transiciones.
// POR QUÉ: Respeta la reducción de movimiento y garantiza una tasa de cuadros estable en M3/iOS.
library;

import 'package:flutter/material.dart';

/// Tokens de duración universales de Nano Mobile.
abstract final class NanoMotionTokens {
  /// Respuesta táctil inmediata al presionar botones e iconos: 90–140 ms.
  static const Duration touchResponse = Duration(milliseconds: 110);

  /// Transición elástica de tarjetas y paneles de superficie: 160–220 ms.
  static const Duration cardTransition = Duration(milliseconds: 180);

  /// Selectores, menús desplegables y cápsulas de estado: 200–280 ms.
  static const Duration selectorTransition = Duration(milliseconds: 240);

  /// Aparición progresiva (staggered reveal) de listas y grupos: 220–340 ms.
  static const Duration staggeredReveal = Duration(milliseconds: 260);

  /// Vuelo cinemático Hero entre pantallas de agentes: 320–450 ms.
  static const Duration heroFlight = Duration(milliseconds: 360);

  /// Transición suave de cambio de tema (Claro / Oscuro): 250–350 ms.
  static const Duration themeChange = Duration(milliseconds: 280);

  /// Curva principal para despegue enérgico y aterrizaje suave.
  static const Curve emphasized = Cubic(0.20, 0.00, 0.00, 1.00);

  /// Curva de desaceleración suave para entradas y aperturas.
  static const Curve standardDecel = Cubic(0.00, 0.00, 0.20, 1.00);

  /// Curva de respuesta táctil elástica (liquid glass).
  static const Curve touchPress = Cubic(0.15, 0.85, 0.35, 1.00);

  /// Verifica si el usuario activó la reducción de movimiento en el sistema.
  static bool reduceMotion(BuildContext context) {
    return MediaQuery.disableAnimationsOf(context);
  }

  /// Retorna la duración adaptada considerando accesibilidad (Duration.zero si reducido).
  static Duration adapt(BuildContext context, Duration duration) {
    return reduceMotion(context) ? Duration.zero : duration;
  }
}
