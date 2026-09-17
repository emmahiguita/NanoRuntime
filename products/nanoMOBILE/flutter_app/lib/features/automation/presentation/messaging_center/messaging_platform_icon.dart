import 'package:flutter/material.dart';
import '../../domain/messaging_platform.dart';

/// Renderiza el logo/icono oficial y nítido de la plataforma de mensajería
/// con precisión vectorial, relieves, gradientes auténticos y sombras de marca.
class MessagingPlatformIcon extends StatelessWidget {
  final MessagingPlatform platform;
  final double size;
  final double borderRadius;

  const MessagingPlatformIcon({
    super.key,
    required this.platform,
    this.size = 40,
    this.borderRadius = 12,
  });

  @override
  Widget build(BuildContext context) {
    if (platform == MessagingPlatform.whatsapp) {
      return Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(borderRadius),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF25D366).withValues(alpha: 0.30),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(borderRadius),
          child: Image.asset(
            'assets/automation/whatsapp_personal_icon.png',
            width: size,
            height: size,
            fit: BoxFit.cover,
          ),
        ),
      );
    }
    if (platform == MessagingPlatform.whatsappBusiness) {
      return Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(borderRadius),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF00FF88).withValues(alpha: 0.30),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(borderRadius),
          child: Image.asset(
            'assets/automation/whatsapp_business_icon.png',
            width: size,
            height: size,
            fit: BoxFit.cover,
          ),
        ),
      );
    }

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(borderRadius),
        gradient: LinearGradient(
          colors: platform.gradientColors,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: platform.primaryColor.withValues(alpha: 0.38),
            blurRadius: 8,
            offset: const Offset(0, 2.5),
          ),
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.25),
            blurRadius: 4,
            offset: const Offset(0, 1),
          ),
        ],
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.16),
          width: 0.8,
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(borderRadius),
        child: Center(
          child: _buildExactPlatformLogo(),
        ),
      ),
    );
  }

  Widget _buildExactPlatformLogo() {
    final s = size;
    switch (platform) {
      case MessagingPlatform.whatsapp:
      case MessagingPlatform.whatsappBusiness:
        return const SizedBox.shrink();

      case MessagingPlatform.telegram:
        return Transform.translate(
          offset: Offset(-s * 0.02, s * 0.02),
          child: Transform.rotate(
            angle: -0.18,
            child: Icon(
              Icons.send_rounded,
              color: Colors.white,
              size: s * 0.54,
            ),
          ),
        );

      case MessagingPlatform.gmail:
        return Stack(
          alignment: Alignment.center,
          children: [
            Container(
              width: s * 0.62,
              height: s * 0.46,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(3),
              ),
              child: CustomPaint(
                painter: _GmailEnvelopePainter(),
              ),
            ),
          ],
        );

      case MessagingPlatform.slack:
        return _SlackLogo(size: s * 0.62);

      case MessagingPlatform.instagram:
        return Stack(
          alignment: Alignment.center,
          children: [
            Container(
              width: s * 0.54,
              height: s * 0.54,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(s * 0.16),
                border: Border.all(color: Colors.white, width: s * 0.065),
              ),
            ),
            Container(
              width: s * 0.26,
              height: s * 0.26,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: s * 0.06),
              ),
            ),
            Positioned(
              top: s * 0.28,
              right: s * 0.28,
              child: Container(
                width: s * 0.07,
                height: s * 0.07,
                decoration: const BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                ),
              ),
            ),
          ],
        );

      case MessagingPlatform.facebook:
        return Transform.translate(
          offset: Offset(s * 0.03, s * 0.04),
          child: Text(
            'f',
            style: TextStyle(
              color: Colors.white,
              fontSize: s * 0.72,
              fontWeight: FontWeight.w900,
              fontFamily: 'Roboto',
              height: 1.0,
            ),
          ),
        );

      case MessagingPlatform.x:
        return Text(
          '𝕏',
          style: TextStyle(
            color: Colors.white,
            fontSize: s * 0.55,
            fontWeight: FontWeight.w800,
            height: 1.0,
          ),
        );

      case MessagingPlatform.linkedin:
        return Text(
          'in',
          style: TextStyle(
            color: Colors.white,
            fontSize: s * 0.54,
            fontWeight: FontWeight.w900,
            letterSpacing: -0.8,
            height: 1.0,
          ),
        );

      case MessagingPlatform.other:
        return Icon(
          Icons.more_horiz_rounded,
          color: Colors.white,
          size: s * 0.6,
        );
    }
  }
}

/// Dibuja el logo de 4 colores icónico de Slack con cuadrícula de alta precisión.
class _SlackLogo extends StatelessWidget {
  final double size;
  const _SlackLogo({required this.size});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _SlackPainter(),
      ),
    );
  }
}

class _SlackPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final r = w * 0.12;

    void pill(double x, double y, double w, double h, Color c) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(Rect.fromLTWH(x, y, w, h), Radius.circular(r)),
        Paint()..color = c,
      );
    }

    // Cuatro colores característicos de Slack
    const red = Color(0xFFE01E5A);
    const blue = Color(0xFF36C5F0);
    const green = Color(0xFF2EB67D);
    const yellow = Color(0xFFECB22E);

    final s = w;
    pill(s * 0.38, 0, s * 0.24, s * 0.44, red);
    pill(s * 0.14, s * 0.22, s * 0.2, s * 0.2, red);

    pill(s * 0.56, s * 0.38, s * 0.44, s * 0.24, blue);
    pill(s * 0.58, s * 0.14, s * 0.2, s * 0.2, blue);

    pill(s * 0.38, s * 0.56, s * 0.24, s * 0.44, green);
    pill(s * 0.66, s * 0.58, s * 0.2, s * 0.2, green);

    pill(0, s * 0.38, s * 0.44, s * 0.24, yellow);
    pill(s * 0.22, s * 0.66, s * 0.2, s * 0.2, yellow);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Dibuja la icónica 'M' geométrica tricolor de Gmail.
class _GmailEnvelopePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    final redPaint = Paint()..color = const Color(0xFFEA4335);
    final bluePaint = Paint()..color = const Color(0xFF4285F4);
    final yellowPaint = Paint()..color = const Color(0xFFFBBC05);
    final greenPaint = Paint()..color = const Color(0xFF34A853);

    // Barra izquierda azul
    canvas.drawRect(Rect.fromLTWH(0, 0, w * 0.22, h), bluePaint);
    // Barra derecha verde
    canvas.drawRect(Rect.fromLTWH(w * 0.78, 0, w * 0.22, h), greenPaint);

    // Diagonal izquierda roja
    final pLeft = Path()
      ..moveTo(0, 0)
      ..lineTo(w * 0.5, h * 0.62)
      ..lineTo(w * 0.5, h * 0.4)
      ..lineTo(w * 0.22, 0)
      ..close();
    canvas.drawPath(pLeft, redPaint);

    // Diagonal derecha roja
    final pRight = Path()
      ..moveTo(w, 0)
      ..lineTo(w * 0.5, h * 0.62)
      ..lineTo(w * 0.5, h * 0.4)
      ..lineTo(w * 0.78, 0)
      ..close();
    canvas.drawPath(pRight, redPaint);

    // Vértice superior amarillo
    final pYellow = Path()
      ..moveTo(w * 0.5, h * 0.62)
      ..lineTo(w * 0.5, h * 0.4)
      ..lineTo(w * 0.78, 0)
      ..lineTo(w * 0.78, h * 0.22)
      ..close();
    canvas.drawPath(pYellow, yellowPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
