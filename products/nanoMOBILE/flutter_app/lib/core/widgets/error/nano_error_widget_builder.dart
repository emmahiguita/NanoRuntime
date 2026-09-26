import 'package:flutter/material.dart';

/// QUÉ HACE:
/// Provee un widget de error resiliente con diseño Material 3 Expressive
/// en reemplazo del ErrorWidget por defecto de Flutter.
///
/// CÓMO FUNCIONA:
/// Captura [FlutterErrorDetails] en cualquier árbol de widgets y renderiza
/// una cápsula contenida, estilizada con fondo oscuro, borde de advertencia
/// sutil y tipografía Inter, evitando romper la experiencia visual.
///
/// POR QUÉ:
/// Erradica las cajas rojas con texto amarillo ("cajas rojas con texto amarillo")
/// y excepciones "No Overlay widget found", garantizando una interfaz elegante
/// y profesional incluso ante fallos transitorios en tiempo de render.
Widget buildNanoErrorWidget(FlutterErrorDetails details) {
  return Material(
    color: Colors.transparent,
    child: Center(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: const Color(0xFF0F172A),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: const Color(0xFFEF4444).withValues(alpha: 0.35),
            width: 1.0,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.25),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.info_outline_rounded,
              color: Color(0xFFF87171),
              size: 16,
            ),
            const SizedBox(width: 10),
            Flexible(
              child: Text(
                details.exceptionAsString(),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: Color(0xFFE2E8F0),
                  decoration: TextDecoration.none,
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
