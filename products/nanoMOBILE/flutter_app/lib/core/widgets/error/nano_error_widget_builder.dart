import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kDebugMode;

String? _lastBuildError;

// QUÉ HACE:
// Provee un widget de error resiliente con diseño Material 3 Expressive
// en reemplazo del ErrorWidget por defecto de Flutter.
//
// CÓMO FUNCIONA:
// - Recibe el fallo visual ya reportado por Flutter; no lo corrige ni lo oculta al log.
// - Inyecta un `Directionality` defensivo para garantizar que nunca falle por falta de dirección de texto.
// - Renderiza una cápsula contenida, estilizada con fondo oscuro, borde de advertencia
//   sutil y tipografía Inter, evitando romper la experiencia visual.
//
// POR QUÉ:
// Muestra un estado honesto en lugar del cuadro técnico. La causa debe repararse
// en el componente responsable, nunca declararse solucionada desde ErrorWidget.
Widget buildNanoErrorWidget(FlutterErrorDetails details) {
  final message = details.exceptionAsString();
  // Conserva la causa del componente que sustituimos. Limita mensajes iguales
  // para que una reconstrucción fallida no sature registros ni el teléfono.
  if (kDebugMode && _lastBuildError != message) {
    _lastBuildError = message;
    debugPrint('[nano-ui-build-error] $message');
    debugPrintStack(stackTrace: details.stack, maxFrames: 14);
  }
  final isOverlayError =
      message.contains('No Overlay') || message.contains('Overlay widget');

  return Directionality(
    textDirection: TextDirection.ltr,
    child: Material(
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
                  isOverlayError
                      ? 'No se pudo mostrar este control. Cierra y vuelve a abrir el panel.'
                      : 'No se pudo mostrar este componente.',
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
    ),
  );
}
