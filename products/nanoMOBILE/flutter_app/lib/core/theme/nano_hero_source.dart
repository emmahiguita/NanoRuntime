// QUÉ: vincula la tarjeta visible con el contenedor de su ruta, sin otra pantalla.
// CÓMO: Hero conserva el hueco y transporta solo la presentación de origen.
// POR QUÉ: la vista destino se monta una sola vez; sus servicios no vuelan duplicados.
import 'package:flutter/material.dart';
import 'nano_motion.dart';

const nanoPersonalHeroTag = 'automation.personal';
const nanoBusinessHeroTag = 'automation.business';

class NanoHeroSource extends StatelessWidget {
  const NanoHeroSource({super.key, required this.tag, required this.builder});
  final String tag;
  final WidgetBuilder builder;

  @override
  Widget build(BuildContext context) => HeroMode(
    enabled: !NanoMotion.reduceMotion(context),
    child: Hero(
      tag: tag,
      createRectTween: nanoHeroRectTween,
      flightShuttleBuilder: nanoHeroCardFlight,
      child: Builder(builder: builder),
    ),
  );
}

/// Misma curva en vuelo y recorte; en pop se evalúa el trayecto al revés.
Tween<Rect?> nanoHeroRectTween(Rect? begin, Rect? end) =>
    RectTween(begin: begin, end: end); // Hero ya aplica fastOutSlowIn.

/// Solo copia el widget visual de la tarjeta, nunca el agente o sus pestañas.
/// Tamaño fijo al inicio: no relayout ni deformación del texto durante el vuelo.
Widget nanoHeroCardFlight(
  BuildContext context,
  Animation<double> animation,
  HeroFlightDirection direction,
  BuildContext from,
  BuildContext to,
) {
  final origin = direction == HeroFlightDirection.push ? from : to;
  final card = (origin.widget as Hero).child;
  final size = origin.size!;
  final theme = Theme.of(origin);
  return IgnorePointer(
    child: AnimatedBuilder(
      animation: animation,
      child: Theme(
        data: theme,
        child: SizedBox(width: size.width, height: size.height, child: card),
      ),
      builder: (context, child) => Opacity(
        opacity: 1 - const Interval(0, 0.30).transform(animation.value),
        child: Align(alignment: Alignment.topLeft, child: child),
      ),
    ),
  );
}
