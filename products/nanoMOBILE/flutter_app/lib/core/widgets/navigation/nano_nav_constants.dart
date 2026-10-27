// nano_nav_constants.dart — Constantes dimensionales y reservas de espacio para la navegación.
// QUÉ HACE: Define las reservas de scroll y márgenes para que el contenido no quede solapado con el dock.
// CÓMO FUNCIONA: Constantes tipadas en píxeles lógicos adaptadas a orientación vertical y horizontal.
// POR QUÉ: Centraliza la fuente de verdad geométrica de Nano AI (Single Source of Truth).
library;

/// Reserva de espacio inferior en el scroll vertical para que la barra flotante no tape elementos interactivos.
const double kNanoBarScrollReserve = 108.0;

/// Reserva de espacio inferior en el scroll para dispositivos en orientación horizontal (Landscape).
const double kNanoBarScrollReserveLandscape = 104.0;

/// Separación base inferior en modo vertical.
const double kNanoDockGapPortrait = 16.0;

/// Separación base inferior en modo horizontal.
const double kNanoDockGapLandscape = 12.0;

/// Altura base del dock en estado de reposo (sin campo multilínea expandido).
const double kNanoInitialDockHeight = 68.0;

/// Reposo necesario antes de volver al destino reducido, siempre identificable.
const Duration kNanoDockIdleCollapseDelay = Duration(seconds: 5);
