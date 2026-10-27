// QUÉ: siluetas propias para significados que antes reutilizaban otro glifo.
// CÓMO: traza geometría vectorial sin fondo en una retícula de 24 unidades.
// POR QUÉ: documentos, cámara, nube, batería y analíticas deben distinguirse.
part of 'feather_core_icon.dart';

class FeatherCoreSymbol extends StatelessWidget {
  const FeatherCoreSymbol({
    super.key,
    required this.type,
    required this.size,
    required this.color,
  });
  final FeatherCoreType type;
  final double size;
  final Color color;
  static bool supports(FeatherCoreType type) => const {
    FeatherCoreType.documents,
    FeatherCoreType.camera,
    FeatherCoreType.cloud,
    FeatherCoreType.battery,
    FeatherCoreType.analytics,
    FeatherCoreType.location,
    FeatherCoreType.calendar,
    FeatherCoreType.businessCatalog,
    FeatherCoreType.payments,
    FeatherCoreType.delivery,
    FeatherCoreType.devTools,
  }.contains(type);
  @override
  Widget build(BuildContext context) => CustomPaint(
    size: Size.square(size),
    painter: _FeatherSymbolPainter(type, color),
  );
}

class _FeatherSymbolPainter extends CustomPainter {
  const _FeatherSymbolPainter(this.type, this.color);
  final FeatherCoreType type;
  final Color color;
  @override
  void paint(Canvas canvas, Size size) {
    canvas.scale(size.width / 24, size.height / 24);
    final pen = Paint()
      ..color = color
      ..strokeWidth = 1.55
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke;
    final fill = Paint()..color = color;
    void line(double x, double y, double xx, double yy) =>
        canvas.drawLine(Offset(x, y), Offset(xx, yy), pen);
    void box(double x, double y, double w, double h, [double r = 2]) =>
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromLTWH(x, y, w, h),
            Radius.circular(r),
          ),
          pen,
        );
    switch (type) {
      case FeatherCoreType.documents:
        canvas.drawPath(
          Path()
            ..moveTo(6, 2)
            ..lineTo(14, 2)
            ..lineTo(19, 7)
            ..lineTo(19, 22)
            ..lineTo(5, 22)
            ..lineTo(5, 3)
            ..close(),
          pen,
        );
        line(14, 2, 14, 7);
        line(14, 7, 19, 7);
        for (final y in [11.0, 15.0, 19.0]) {
          line(8, y, 15, y);
        }
      case FeatherCoreType.camera:
        box(2, 7, 20, 14, 3);
        box(7, 3, 10, 4, 1);
        canvas.drawCircle(const Offset(12, 14), 4.2, pen);
        canvas.drawCircle(const Offset(19, 10), .8, fill);
      case FeatherCoreType.cloud:
        canvas.drawPath(
          Path()
            ..moveTo(6, 19)
            ..cubicTo(-1, 19, 0, 10, 6, 10)
            ..cubicTo(6, 1, 19, 1, 19, 11)
            ..cubicTo(25, 11, 25, 19, 19, 19)
            ..close(),
          pen,
        );
      case FeatherCoreType.battery:
        box(5, 4, 14, 18, 3);
        line(9, 1, 15, 1);
        canvas.drawPath(
          Path()
            ..moveTo(13, 8)
            ..lineTo(10, 13)
            ..lineTo(14, 13)
            ..lineTo(11, 18),
          pen,
        );
      case FeatherCoreType.analytics:
        box(3, 16, 4, 6, .6);
        box(10, 12, 4, 10, .6);
        box(17, 7, 4, 15, .6);
        canvas.drawPath(
          Path()
            ..moveTo(3, 11)
            ..lineTo(9, 6)
            ..lineTo(14, 8)
            ..lineTo(21, 2),
          pen,
        );
      case FeatherCoreType.location:
        canvas.drawPath(
          Path()
            ..moveTo(12, 22)
            ..cubicTo(10, 19, 4, 13, 4, 9)
            ..cubicTo(4, -1, 20, -1, 20, 9)
            ..cubicTo(20, 13, 14, 19, 12, 22),
          pen,
        );
        canvas.drawCircle(const Offset(12, 9), 2.5, pen);
      case FeatherCoreType.calendar:
        box(2, 5, 20, 17, 3);
        line(7, 2, 7, 8);
        line(17, 2, 17, 8);
        line(2, 11, 22, 11);
        for (final x in [7.0, 12.0, 17.0]) {
          canvas.drawCircle(Offset(x, 16), .9, fill);
        }
      case FeatherCoreType.businessCatalog:
        box(3, 4, 18, 17, 2);
        line(8, 4, 8, 21);
        box(11, 8, 6, 5, 1);
        line(11, 17, 17, 17);
      case FeatherCoreType.payments:
        box(2, 5, 20, 15, 3);
        line(2, 10, 22, 10);
        line(5, 16, 10, 16);
      case FeatherCoreType.delivery:
        box(1, 5, 13, 13, 1);
        box(14, 10, 8, 8, 1);
        canvas.drawCircle(const Offset(6, 19), 2.3, pen);
        canvas.drawCircle(const Offset(18, 19), 2.3, pen);
      case FeatherCoreType.devTools:
        canvas.drawPath(
          Path()
            ..moveTo(12, 1)
            ..lineTo(22, 7)
            ..lineTo(22, 18)
            ..lineTo(12, 23)
            ..lineTo(2, 18)
            ..lineTo(2, 7)
            ..close(),
          pen,
        );
        canvas.drawPath(
          Path()
            ..moveTo(8, 9)
            ..lineTo(5, 12)
            ..lineTo(8, 15),
          pen,
        );
        canvas.drawPath(
          Path()
            ..moveTo(16, 9)
            ..lineTo(19, 12)
            ..lineTo(16, 15),
          pen,
        );
        line(13, 8, 11, 16);
      default:
        break;
    }
  }

  @override
  bool shouldRepaint(covariant _FeatherSymbolPainter oldDelegate) =>
      type != oldDelegate.type || color != oldDelegate.color;
}
