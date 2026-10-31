// nano_nav_constants.dart — Constantes dimensionales y reservas de espacio para la navegación.
// QUÉ HACE:
// Define las reservas de scroll y márgenes para que el contenido no quede solapado con el dock compacto.
//
// CÓMO FUNCIONA:
// Constantes tipadas en píxeles lógicos adaptadas al dock optimizado en vertical y horizontal.
//
// POR QUÉ:
// Centraliza la fuente de verdad geométrica de Nano AI con altura reducida y mayor espacio libre.
library;

/// Reserva de espacio inferior en el scroll vertical para alojar el panel de navegación y el de escritura compactos.
const double kNanoBarScrollReserve = 116.0;

/// Reserva de espacio inferior en el scroll para dispositivos en orientación horizontal (Landscape).
const double kNanoBarScrollReserveLandscape = 104.0;

/// Separación base inferior en modo vertical.
const double kNanoDockGapPortrait = 12.0;

/// Separación base inferior en modo horizontal.
const double kNanoDockGapLandscape = 8.0;

/// Altura base del dock en estado de reposo (sin campo multilínea expandido).
const double kNanoInitialDockHeight = 54.0;

/// Reposo opcional para paneles secundarios.
const Duration kNanoDockIdleCollapseDelay = Duration(seconds: 5);
