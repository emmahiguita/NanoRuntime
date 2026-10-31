part of 'nano_automation_icon.dart';

/// Shared SVG geometry; no parsing or asset loading during paint.
List<Path> _nanoGlyphPaths(NanoAutomationGlyph glyph) => switch (glyph) {
  NanoAutomationGlyph.messaging => [
    Path()
      ..moveTo(5, 5)
      ..lineTo(27, 5)
      ..lineTo(29, 8)
      ..lineTo(29, 26)
      ..lineTo(3, 26)
      ..lineTo(3, 8)
      ..close(),
    Path()
      ..moveTo(3, 20)
      ..lineTo(8, 20)
      ..lineTo(11, 26)
      ..moveTo(29, 20)
      ..lineTo(24, 20)
      ..lineTo(21, 26),
    Path()
      ..moveTo(11, 12)
      ..lineTo(11, 9)
      ..lineTo(16, 11)
      ..lineTo(21, 9)
      ..lineTo(21, 12)
      ..cubicTo(24, 14, 23, 20, 19, 22)
      ..cubicTo(17, 23, 15, 23, 13, 22)
      ..cubicTo(9, 20, 8, 14, 11, 12)
      ..close(),
    Path()
      ..moveTo(12, 16)
      ..cubicTo(12, 13, 15, 13, 15, 16)
      ..cubicTo(15, 19, 12, 19, 12, 16)
      ..close(),
    Path()
      ..moveTo(17, 16)
      ..cubicTo(17, 13, 20, 13, 20, 16)
      ..cubicTo(20, 19, 17, 19, 17, 16)
      ..close(),
    Path()
      ..moveTo(15, 20)
      ..lineTo(16, 21)
      ..lineTo(17, 20),
  ],
  NanoAutomationGlyph.connections => [
    Path()
      ..moveTo(11, 12)
      ..lineTo(11, 9)
      ..lineTo(16, 11)
      ..lineTo(21, 9)
      ..lineTo(21, 12)
      ..cubicTo(24, 14, 23, 20, 19, 22)
      ..cubicTo(17, 23, 15, 23, 13, 22)
      ..cubicTo(9, 20, 8, 14, 11, 12)
      ..close(),
    Path()
      ..moveTo(12, 16)
      ..cubicTo(12, 13, 15, 13, 15, 16)
      ..cubicTo(15, 19, 12, 19, 12, 16)
      ..close(),
    Path()
      ..moveTo(17, 16)
      ..cubicTo(17, 13, 20, 13, 20, 16)
      ..cubicTo(20, 19, 17, 19, 17, 16)
      ..close(),
    Path()
      ..moveTo(15, 20)
      ..lineTo(16, 21)
      ..lineTo(17, 20),
    Path()
      ..moveTo(16, 6)
      ..lineTo(16, 3)
      ..moveTo(6, 16)
      ..lineTo(3, 16)
      ..moveTo(26, 16)
      ..lineTo(29, 16)
      ..moveTo(16, 26)
      ..lineTo(16, 29),
    Path()
      ..moveTo(14, 3)
      ..lineTo(18, 3)
      ..moveTo(3, 14)
      ..lineTo(3, 18)
      ..moveTo(29, 14)
      ..lineTo(29, 18)
      ..moveTo(14, 29)
      ..lineTo(18, 29),
  ],
  NanoAutomationGlyph.chat => [
    Path()
      ..moveTo(6, 4)
      ..lineTo(26, 4)
      ..cubicTo(28, 4, 29, 5, 29, 7)
      ..lineTo(29, 23)
      ..cubicTo(29, 25, 28, 26, 26, 26)
      ..lineTo(13, 26)
      ..lineTo(6, 30)
      ..lineTo(6, 26)
      ..cubicTo(4, 26, 3, 25, 3, 23)
      ..lineTo(3, 7)
      ..cubicTo(3, 5, 4, 4, 6, 4)
      ..close(),
    Path()
      ..moveTo(11, 12)
      ..lineTo(11, 9)
      ..lineTo(16, 11)
      ..lineTo(21, 9)
      ..lineTo(21, 12)
      ..cubicTo(24, 14, 23, 20, 19, 22)
      ..cubicTo(17, 23, 15, 23, 13, 22)
      ..cubicTo(9, 20, 8, 14, 11, 12)
      ..close(),
    Path()
      ..moveTo(12, 16)
      ..cubicTo(12, 13, 15, 13, 15, 16)
      ..cubicTo(15, 19, 12, 19, 12, 16)
      ..close(),
    Path()
      ..moveTo(17, 16)
      ..cubicTo(17, 13, 20, 13, 20, 16)
      ..cubicTo(20, 19, 17, 19, 17, 16)
      ..close(),
    Path()
      ..moveTo(15, 20)
      ..lineTo(16, 21)
      ..lineTo(17, 20),
  ],
  NanoAutomationGlyph.sessions => [
    Path()
      ..moveTo(7, 23)
      ..lineTo(3, 23)
      ..lineTo(3, 3)
      ..lineTo(24, 3)
      ..lineTo(24, 7),
    Path()
      ..moveTo(8, 8)
      ..lineTo(29, 8)
      ..lineTo(29, 29)
      ..lineTo(8, 29)
      ..close(),
    Path()
      ..moveTo(8, 13)
      ..lineTo(29, 13)
      ..moveTo(12, 10)
      ..lineTo(13, 10),
    Path()
      ..moveTo(13, 19)
      ..lineTo(13, 16)
      ..lineTo(18, 18)
      ..lineTo(23, 16)
      ..lineTo(23, 19)
      ..cubicTo(26, 26, 10, 26, 13, 19)
      ..close(),
    Path()
      ..moveTo(16, 21)
      ..lineTo(16, 22)
      ..moveTo(20, 21)
      ..lineTo(20, 22),
  ],
};
